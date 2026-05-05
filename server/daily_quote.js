const { createClient } = require('@supabase/supabase-js');
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialize Supabase (Using Service Role to bypass RLS)
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const REQUIRED_FIELDS = ['quote_text', 'author', 'meaning', 'task_of_the_day'];
const MAX_ATTEMPTS = 3;

/** Extract the first valid JSON object from a string, even if Gemini wraps it in markdown. */
function extractJson(text) {
    // Strip markdown code fences if present
    const stripped = text.replace(/```json\s*/gi, '').replace(/```\s*/gi, '').trim();

    // Try parsing the whole string first
    try {
        return JSON.parse(stripped);
    } catch (_) { /* fall through */ }

    // Fall back: find the first {...} block
    const match = stripped.match(/\{[\s\S]*\}/);
    if (!match) throw new Error('No JSON object found in Gemini response');
    return JSON.parse(match[0]);
}

/** Validate that all required fields are present and non-empty strings. */
function validateQuote(obj) {
    for (const field of REQUIRED_FIELDS) {
        if (typeof obj[field] !== 'string' || obj[field].trim() === '') {
            throw new Error(`Missing or empty required field: "${field}"`);
        }
    }
}

async function generateDailyQuote() {
    // 1. Get the current mode from Config
    const { data: config } = await supabase.from('config').select('current_mode').single();
    const mode = config?.current_mode || 'General';
    console.log("Current Mode:", mode);

    // 2. Get last 10 quotes to avoid repeats
    const { data: pastQuotes } = await supabase.from('quotes').select('quote_text').order('created_at', { ascending: false }).limit(10);
    const avoidList = pastQuotes?.map(q => q.quote_text).join(" | ") || "None";

    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
    const prompt = `You are a wellness mentor for MRCE college. Mode: ${mode}. 
        Task: Provide a simple wellness quote (max 2 lines), a 1-sentence meaning, and a 1-sentence 'Task of the Day'.
        Rules: Avoid these concepts: ${avoidList}. Use 8th-grade English.
        Output ONLY valid JSON with no markdown, no explanation: {"quote_text": "...", "author": "...", "meaning": "...", "task_of_the_day": "..."}`;

    let lastError;
    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        try {
            console.log(`Asking Gemini for a quote (attempt ${attempt}/${MAX_ATTEMPTS})...`);
            const result = await model.generateContent(prompt);
            const response = extractJson(result.response.text());
            validateQuote(response);

            // 4. Insert into Supabase for tomorrow (UTC date)
            const tomorrow = new Date();
            tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
            const dateStr = tomorrow.toISOString().split('T')[0];

            console.log("Saving new quote to database for date:", dateStr);
            const { error } = await supabase.from('quotes').insert([
                { ...response, post_date: dateStr }
            ]);

            if (error) throw new Error(`Supabase insert failed: ${error.message}`);
            console.log("✅ Success! Daily quote generated and saved safely.");
            return; // done
        } catch (err) {
            lastError = err;
            console.error(`❌ Attempt ${attempt} failed: ${err.message}`);
            if (attempt < MAX_ATTEMPTS) {
                const delay = attempt * 2000;
                console.log(`Retrying in ${delay / 1000}s...`);
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
    }

    console.error(`❌ All ${MAX_ATTEMPTS} attempts failed. Last error: ${lastError.message}`);
    process.exit(1);
}

console.log("Starting daily quote generation...");
generateDailyQuote();