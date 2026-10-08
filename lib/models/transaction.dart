import 'dart:typed_data';

class PaymentTransaction {
  final String id;
  final String customerId;
  final String customerName;
  final double amount;
  final double discount;
  final double amountReceived;
  final double previousBalance;
  final double remainingBalance;
  final DateTime transactionDate;
  final String notes;
  final Uint8List signature;
  final String? signaturePath;
  final String receivedBy;
  final String paymentMethod;
  final String paymentMethodNote;

  PaymentTransaction({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    this.discount = 0,
    double? amountReceived,
    required this.previousBalance,
    required this.remainingBalance,
    required this.transactionDate,
    required this.notes,
    required this.signature,
    this.signaturePath,
    this.receivedBy = 'Unknown',
    this.paymentMethod = 'cash',
    this.paymentMethodNote = '',
  }) : amountReceived = amountReceived ?? (amount - discount);
}
