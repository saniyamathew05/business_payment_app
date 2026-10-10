import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LedgerService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static bool isLoading = false;
  static String? errorMessage;

  static final Map<String, double> customerBalances = {};

  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  // ------------------------------------------------------------
  // LOAD CUSTOMER BALANCES
  // ------------------------------------------------------------

  static Future<void> loadCustomerBalances() async {
    errorMessage = null;

    try {
      final response = await _supabase.rpc('get_customer_balances');

      customerBalances.clear();

      for (final row in response) {
        final customerId = row['customer_id'] as String;

        final balance = (row['balance'] as num).toDouble();

        customerBalances[customerId] = balance;
      }

      dataVersion.value++;
    } catch (error) {
      errorMessage = error.toString();
      dataVersion.value++;
      rethrow;
    }
  }

  static double getCustomerBalance(String customerId) {
    return customerBalances[customerId] ?? 0;
  }

  // ------------------------------------------------------------
  // CUSTOMER LEDGER
  // ------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getCustomerLedger(
    String customerId,
  ) async {
    errorMessage = null;

    try {
      final response = await _supabase
          .from('ledger_entries')
          .select('*, profiles(name)')
          .eq('customer_id', customerId)
          .order('transaction_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      errorMessage = error.toString();
      return [];
    }
  }

  // ------------------------------------------------------------
  // CURRENT BALANCE FROM LEDGER
  // ------------------------------------------------------------

  static Future<double> getCurrentBalanceFromLedger({
    required String customerId,
    required double openingBalance,
  }) async {
    errorMessage = null;

    try {
      final response = await _supabase.rpc('get_customer_balances');

      for (final row in response) {
        if (row['customer_id'] == customerId) {
          return (row['balance'] as num).toDouble();
        }
      }

      return openingBalance;
    } catch (error) {
      errorMessage = error.toString();
      return openingBalance;
    }
  }

  // ------------------------------------------------------------
  // SIGNATURE DOWNLOAD
  // ------------------------------------------------------------

  static Future<Uint8List?> downloadSignature(String? signaturePath) async {
    if (signaturePath == null || signaturePath.isEmpty) {
      return null;
    }

    try {
      final bytes = await _supabase.storage
          .from('payment-signatures')
          .download(signaturePath);

      return bytes;
    } catch (error) {
      errorMessage = error.toString();
      return null;
    }
  }
}
