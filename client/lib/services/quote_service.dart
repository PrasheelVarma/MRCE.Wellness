import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QuoteService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getTodayQuote() async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    try {
      final data = await _supabase
          .from('quotes')
          .select()
          .eq('post_date', today)
          .maybeSingle();

      if (data != null) {
        return data;
      }

      print("No quote found for today in DB. Initiating Emergency Generation...");
      return await _generateEmergencyQuote(today);

    } catch (e) {
      print("Error in QuoteService: $e");
      return await _getAnyPreviousQuote();
    }
  }

  Future<Map<String, dynamic>?> _generateEmergencyQuote(String dateStr) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) throw Exception("API Key Missing");

      // FIX APPLIED: Using the exact stable model from your verified API list
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final prompt = '''Generate a wellness quote, meaning, and task.
      Return ONLY a JSON object: 
      {"quote_text": "...", "author": "...", "meaning": "...", "task_of_the_day": "..."}''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text == null) throw Exception("AI Response Empty");

      // BULLETPROOF JSON PARSER: Safely strips out Markdown codeblocks
      String rawText = response.text!;
      if (rawText.contains('```')) {
        rawText = rawText.split('```')[1];
        if (rawText.toLowerCase().startsWith('json')) {
          rawText = rawText.substring(4);
        }
      }

      final Map<String, dynamic> generatedQuote = jsonDecode(rawText.trim());

      final dbData = {
        'quote_text': generatedQuote['quote_text'],
        'author': generatedQuote['author'],
        'meaning': generatedQuote['meaning'],
        'task_of_the_day': generatedQuote['task_of_the_day'],
        'post_date': dateStr,
      };

      await _supabase.from('quotes').insert([dbData]);
      return dbData;

    } catch (e) {
      print("Emergency Generation Failed: $e");
      return await _getAnyPreviousQuote();
    }
  }

  Future<Map<String, dynamic>?> _getAnyPreviousQuote() async {
    return await _supabase
        .from('quotes')
        .select()
        .order('post_date', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<void> submitFeedback(String quoteId, String rating, String deviceId) async {
    try {
      await _supabase.from('user_feedback').upsert({
        'quote_id': quoteId,
        'device_id': deviceId,
        'rating': rating,
      });
    } catch (e) {
      print("Feedback failed: $e");
    }
  }
}