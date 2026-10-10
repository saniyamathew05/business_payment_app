import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Records a new customer purchase.
  ///
  /// Purchases always add the full purchase amount
  /// to the customer's outstanding balance.
  ///
  /// Only an owner can record a purchase.
  static Future<Map<String, dynamic>?> recordPurchase({
    required String customerId,
    required double amount,
    String? notes,
    DateTime? transactionDate,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('You are not logged in.');
    }

    if (amount <= 0) {
      throw Exception('Purchase amount must be greater than zero.');
    }

    final response = await _supabase.rpc(
      'record_purchase',
      params: {
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
        'p_transaction_date': (transactionDate ?? DateTime.now())
            .toIso8601String(),
      },
    );

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response as Map);
  }
}
