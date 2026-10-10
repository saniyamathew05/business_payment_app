import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';

class PaymentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Records a payment using the secure Supabase RPC.
  ///
  /// [amount] is the amount being settled from the customer's balance.
  /// [discount] is the amount forgiven.
  /// The actual money received is calculated by the database:
  ///
  /// amount received = amount - discount
  static Future<PaymentTransaction?> recordPayment({
    required String customerId,
    required String customerName,
    required double amount,
    required double discount,
    required String notes,
    required Uint8List signature,
    required String signaturePath,
    required DateTime transactionDate,
    String paymentMethod = 'cash',
    String paymentMethodNote = '',
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('You are not logged in.');
    }

    if (signaturePath.isEmpty) {
      throw Exception('Signature path is missing.');
    }

    final response = await _supabase.rpc(
      'record_payment',
      params: {
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_discount': discount,
        'p_notes': notes.isEmpty ? null : notes,
        'p_signature_path': signaturePath,
        'p_transaction_date': transactionDate.toIso8601String(),
        // The Supabase record_payment function must accept and save these
        // parameters. Its SQL definition will need to be updated accordingly.
        'p_payment_method': paymentMethod,
        'p_payment_method_note': paymentMethodNote.isEmpty
            ? null
            : paymentMethodNote,
      },
    );

    final inserted = Map<String, dynamic>.from(response as Map);

    final savedAmount = (inserted['amount'] as num).toDouble();

    final savedDiscount = (inserted['discount'] as num?)?.toDouble() ?? 0;

    final savedAmountReceived =
        (inserted['amount_received'] as num?)?.toDouble() ??
        (savedAmount - savedDiscount);

    return PaymentTransaction(
      id: inserted['id'] as String,
      customerId: inserted['customer_id'] as String,
      customerName: customerName,
      amount: savedAmount,
      discount: savedDiscount,
      amountReceived: savedAmountReceived,
      previousBalance: (inserted['previous_balance'] as num).toDouble(),
      remainingBalance: (inserted['remaining_balance'] as num).toDouble(),
      transactionDate: DateTime.parse(inserted['transaction_date'] as String),
      notes: (inserted['notes'] as String?) ?? '',
      signature: signature,
      signaturePath: inserted['signature_path'] as String?,
      paymentMethod: (inserted['payment_method'] as String?) ?? paymentMethod,
      paymentMethodNote:
          (inserted['payment_method_note'] as String?) ?? paymentMethodNote,
      transactionType: 'payment_received',
    );
  }

  /// Deletes a payment.
  ///
  /// Only an owner is allowed to perform this operation.
  /// The actual permission check is enforced by Supabase.
  static Future<bool> deletePayment(String paymentId) async {
    final response = await _supabase.rpc(
      'delete_payment',
      params: {'p_payment_id': paymentId},
    );

    return response == true;
  }
}
