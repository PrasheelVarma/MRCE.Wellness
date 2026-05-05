import 'package:supabase_flutter/supabase_flutter.dart';

class QuoteService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getTodayQuote() async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    try {
      // 1. Try to get today's specific quote
      final data = await _supabase
          .from('quotes')
          .select()
          .eq('post_date', today)
          .maybeSingle();

      if (data != null) {
        return data; // Found today's quote!
      }

      // 2. THE FALLBACK: If today is missing, get the most recent quote we have
      final fallbackData = await _supabase
          .from('quotes')
          .select()
          .lte('post_date', today) // Only get quotes from today or the past
          .order('post_date', ascending: false)
          .limit(1)
          .maybeSingle();

      // If we STILL don't have past quotes (e.g., brand new DB), just grab the first one we find (tomorrow's)
      if (fallbackData == null) {
        final anyQuote = await _supabase
            .from('quotes')
            .select()
            .order('post_date', ascending: true)
            .limit(1)
            .maybeSingle();
        return anyQuote;
      }

      return fallbackData;

    } catch (e) {
      print("Error fetching quote: $e");
      return null;
    }
  }

  Future<void> submitFeedback(String quoteId, String rating, String? deviceId) async {
    await _supabase.from('user_feedback').upsert({
      'quote_id': quoteId,
      'device_id': deviceId ?? 'unknown_user',
      'rating': rating,
    });
  }
}