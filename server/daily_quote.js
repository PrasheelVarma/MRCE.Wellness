const { createClient } = require('@supabase/supabase-js');
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialize Supabase (Using Service Role to bypass RLS)
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

async function generateDailyQuote() {
    try {
        console.log("Starting daily quote generation...");

        // 1. Get the current mode from Config
        const { data: config } = await supabase.from('config').select('current_mode').single();
        const mode = config?.current_mode || 'General';
        console.log("Current Mode:", mode);

        // 2. Get last 10 quotes to avoid repeats
        const { data: pastQuotes } = await supabase.from('quotes').select('quote_text').order('created_at', { ascending: false }).limit(10);
        const avoidList = pastQuotes?.map(q => q.quote_text).join(" | ") || "None";

        // 3. Ask Gemini (STRICT CURATOR PROMPT)
        // We explicitly use gemini-1.5-flash because it is the fast, free tier model.
        const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
        const prompt = `You are a highly knowledgeable curator of philosophy and mental health. Today's Mode: ${mode}. 
        Task: Search your knowledge base for a REAL, profound, and historically accurate quote about wellness, mental health, inner peace, or physical health.
        
        STRICT RULES:
        1. DO NOT invent the quote. It MUST be a real quote by a real historical figure, author, or philosopher (e.g., Marcus Aurelius, Lao Tzu, Carl Jung, etc.).
        2. DO NOT mention "MRCE", "Wellness Club", or any promotional language.
        3. The quote must be short (max 2 lines).
        4. Avoid these recent quotes/authors to prevent repeats: ${avoidList}.
        5. Provide a simple 1-sentence 'meaning' and a 1-sentence 'task_of_the_day' related to the quote.
        
        Output ONLY valid JSON: {"quote_text": "...", "author": "...", "meaning": "...", "task_of_the_day": "..."}`;

        console.log("Asking Gemini for a real quote...");
        const result = await model.generateContent(prompt);
        
        // Clean the response (Removes markdown code blocks if the AI accidentally adds them)
        const rawText = result.response.text();
        const cleanJsonString = rawText.replace(/```json/g, "").replace(/```/g, "").trim();
        const response = JSON.parse(cleanJsonString);

        // 4. Insert into Supabase for "Tomorrow" (12:00 AM)
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const dateStr = tomorrow.toISOString().split('T')[0];

        console.log("Saving new quote to database for date:", dateStr);
        const { error } = await supabase.from('quotes').insert([
            { ...response, post_date: dateStr }
        ]);

        if (error) throw error;
        console.log("✅ Success! Daily quote generated and saved safely.");

    } catch (err) {
        console.error("❌ Error during generation:", err.message);
        process.exit(1);
    }
}

generateDailyQuote();