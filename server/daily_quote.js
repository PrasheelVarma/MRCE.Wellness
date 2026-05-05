const { createClient } = require('@supabase/supabase-js');
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialize Supabase (Using Service Role to bypass RLS)
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

async function generateDailyQuote() {
    try {
        // 1. Get the current mode from Config
        const { data: config } = await supabase.from('config').select('current_mode').single();
        const mode = config?.current_mode || 'General';

        // 2. Get last 10 quotes to avoid repeats
        const { data: pastQuotes } = await supabase.from('quotes').select('quote_text').order('created_at', { ascending: false }).limit(10);
        const avoidList = pastQuotes?.map(q => q.quote_text).join(", ") || "None";

        // 3. Ask Gemini
        const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
        const prompt = `You are a wellness mentor for MRCE college. Mode: ${mode}. 
        Task: Provide a simple wellness quote (max 2 lines), a 1-sentence meaning, and a 1-sentence 'Task of the Day'.
        Rules: Avoid these concepts: ${avoidList}. Use 8th-grade English.
        Output ONLY JSON: {"quote_text": "...", "author": "...", "meaning": "...", "task_of_the_day": "..."}`;

        const result = await model.generateContent(prompt);
        const response = JSON.parse(result.response.text().replace(/```json|```/g, ""));

        // 4. Insert into Supabase for "Tomorrow" (12:00 AM)
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const dateStr = tomorrow.toISOString().split('T')[0];

        const { error } = await supabase.from('quotes').insert([
            { ...response, post_date: dateStr }
        ]);

        if (error) throw error;
        console.log("✅ Daily quote generated successfully for:", dateStr);

    } catch (err) {
        console.error("❌ Error:", err.message);
        process.exit(1);
    }
}

generateDailyQuote();