import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';
import 'customer_service.dart';
import 'ledger_service.dart';
import 'payment_service.dart';
import 'signature_service.dart';

class TransactionService {
  static final List<PaymentTransaction> transactions = [];

  static final ValueNotifier<int> dataVersion =
      ValueNotifier<int>(0);

  static final SupabaseClient _supabase =
      Supabase.instance.client;

  static bool isLoading = false;
  static String? errorMessage;

  static Map<String, double> get customerBalances =>
      LedgerService.customerBalances;

  static Future<void> loadTransactions() async {
    isLoading = true;
    errorMessage = null;
    dataVersion.value++;

    try {
      final response = await _supabase
          .from('payments')
          .select('''
            id,
            customer_id,
            user_id,
            amount,
            discount,
            amount_received,
            previous_balance,
            remaining_balance,
            transaction_date,
            notes,
            signature_path,
            payment_method,
            profiles (
              name
            )
          ''')
          .order(
            'transaction_date',
            ascending: false,
          );

      transactions.clear();

      for (final row in response) {
        final customerId =
            row['customer_id'] as String;

        final customer =
            CustomerService.getCustomerById(
          customerId,
        );

        final profile = row['profiles'];

        final receivedBy = profile is Map
            ? profile['name']?.toString() ?? 'Unknown'
            : 'Unknown';

        final amount =
            (row['amount'] as num).toDouble();

        final discount =
            (row['discount'] as num?)?.toDouble() ?? 0;

        final amountReceived =
            (row['amount_received'] as num?)?.toDouble() ??
                (amount - discount);

        transactions.add(
          PaymentTransaction(
            id: row['id'] as String,
            customerId: customerId,
            customerName:
                customer?.businessName ?? 'Customer',
            amount: amount,
            discount: discount,
            amountReceived: amountReceived,
            previousBalance:
                (row['previous_balance'] as num).toDouble(),
            remainingBalance:
                (row['remaining_balance'] as num).toDouble(),
            transactionDate:
                DateTime.parse(
              row['transaction_date'] as String,
            ),
            notes:
                (row['notes'] as String?) ?? '',
            signature:
                Uint8List(0),
            signaturePath:
                row['signature_path'] as String?,
            receivedBy: receivedBy,
            paymentMethod:
                row['payment_method']?.toString() ?? 'cash',
          ),
        );
      }

      await loadCustomerBalances();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      dataVersion.value++;
    }
  }

  static Future<void> loadCustomerBalances() async {
    try {
      await LedgerService.loadCustomerBalances();
      dataVersion.value++;
    } catch (error) {
      errorMessage = error.toString();
      dataVersion.value++;
    }
  }

  static double getCustomerBalance(
    String customerId,
  ) {
    return LedgerService.getCustomerBalance(
      customerId,
    );
  }

  static Future<Uint8List?> downloadSignature(
    String? signaturePath,
  ) async {
    return SignatureService.downloadSignature(
      signaturePath,
    );
  }

  static Future<bool> addTransactionWithSignature(
    PaymentTransaction transaction,
    String? signaturePath,
  ) async {
    errorMessage = null;

    if (signaturePath == null ||
        signaturePath.isEmpty) {
      errorMessage =
          'Signature path is missing.';
      dataVersion.value++;
      return false;
    }

    try {
      final savedTransaction =
          await PaymentService.recordPayment(
        customerId:
            transaction.customerId,
        customerName:
            transaction.customerName,
        amount:
            transaction.amount,
        discount:
            transaction.discount,
        notes:
            transaction.notes,
        signature:
            transaction.signature,
        signaturePath:
            signaturePath,
        transactionDate:
            transaction.transactionDate,
      );

      if (savedTransaction == null) {
        errorMessage =
            'Payment could not be recorded.';
        dataVersion.value++;
        return false;
      }

      final currentUser =
          _supabase.auth.currentUser;

      final currentProfile = currentUser == null
          ? null
          : await _supabase
              .from('profiles')
              .select('name')
              .eq('id', currentUser.id)
              .maybeSingle();

      final receivedBy =
          currentProfile?['name']?.toString() ??
              'Unknown';

      transactions.insert(
        0,
        PaymentTransaction(
          id: savedTransaction.id,
          customerId: savedTransaction.customerId,
          customerName: savedTransaction.customerName,
          amount: savedTransaction.amount,
          discount: savedTransaction.discount,
          amountReceived:
              savedTransaction.amountReceived,
          previousBalance:
              savedTransaction.previousBalance,
          remainingBalance:
              savedTransaction.remainingBalance,
          transactionDate:
              savedTransaction.transactionDate,
          notes: savedTransaction.notes,
          signature:
              savedTransaction.signature,
          signaturePath:
              savedTransaction.signaturePath,
          receivedBy: receivedBy,
        ),
      );

      await loadCustomerBalances();
      dataVersion.value++;

      return true;
    } catch (error) {
      errorMessage = error.toString();
      dataVersion.value++;
      return false;
    }
  }

  static Future<bool> deletePayment(
    String paymentId,
  ) async {
    errorMessage = null;

    try {
      final success =
          await PaymentService.deletePayment(
        paymentId,
      );

      if (success) {
        transactions.removeWhere(
          (transaction) =>
              transaction.id == paymentId,
        );

        await loadCustomerBalances();
        dataVersion.value++;
      }

      return success;
    } catch (error) {
      errorMessage = error.toString();
      dataVersion.value++;
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>>
      getCustomerLedger(
    String customerId,
  ) {
    return LedgerService.getCustomerLedger(
      customerId,
    );
  }

  static Future<double>
      getCurrentBalanceFromLedger({
    required String customerId,
    required double openingBalance,
  }) {
    return LedgerService.getCurrentBalanceFromLedger(
      customerId: customerId,
      openingBalance: openingBalance,
    );
  }

  static double getCurrentBalance({
    required String customerId,
    required double openingBalance,
  }) {
    return LedgerService.getCustomerBalance(
      customerId,
    );
  }

  static List<PaymentTransaction>
      getCustomerTransactions(
    String customerId,
  ) {
    final result = transactions
        .where(
          (transaction) =>
              transaction.customerId == customerId,
        )
        .toList();

    result.sort(
      (a, b) =>
          b.transactionDate.compareTo(
        a.transactionDate,
      ),
    );

    return result;
  }

  static double getCollectedToday() {
    final now = DateTime.now();

    return transactions
        .where(
          (transaction) =>
              transaction.transactionDate.year ==
                  now.year &&
              transaction.transactionDate.month ==
                  now.month &&
              transaction.transactionDate.day ==
                  now.day,
        )
        .fold(
          0.0,
          (sum, transaction) =>
              sum + transaction.amountReceived,
        );
  }

  static double getTotalCollectedToday() {
    return getCollectedToday();
  }

  static int getPaymentsToday() {
    final now = DateTime.now();

    return transactions
        .where(
          (transaction) =>
              transaction.transactionDate.year ==
                  now.year &&
              transaction.transactionDate.month ==
                  now.month &&
              transaction.transactionDate.day ==
                  now.day,
        )
        .length;
  }

  static double getTotalMoneyToReceive(
    List<dynamic> customers,
  ) {
    double total = 0;

    for (final customer in customers) {
      total += LedgerService.getCustomerBalance(
        customer.id,
      );
    }

    return total;
  }
}
