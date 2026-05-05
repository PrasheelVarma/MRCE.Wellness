import 'package:supabase_flutter/supabase_flutter.dart';

class QuoteService {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<Map<String, dynamic>?> getTodayQuote() async {
    // Use UTC date to match the server, which stores post_date in UTC.
    final today = DateTime.now().toUtc().toIso8601String().split('T')[0];

    try {
      final data = await _supabase
          .from('quotes')
          .select()
          .eq('post_date', today)
          .maybeSingle();

      if (data != null) {
        return data;
      }

      // No quote scheduled for today — fall back to the most recent one.
      return await _getLatestScheduledQuote();

    } catch (e) {
      return await _getLatestScheduledQuote();
    }
  }

  Future<Map<String, dynamic>?> _getLatestScheduledQuote() async {
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
      // Feedback is best-effort; silently ignore failures.
    }
  }
}