import 'dart:typed_data';



import 'package:flutter/material.dart';

import 'package:signature/signature.dart';

import 'package:supabase_flutter/supabase_flutter.dart';



import '../../models/customer.dart';

import '../../models/transaction.dart';

import '../../services/customer_service.dart';

import '../../services/transaction_service.dart';



class PaymentScreen extends StatefulWidget {

  final Customer customer;



  const PaymentScreen({

    super.key,

    required this.customer,

  });



  @override

  State<PaymentScreen> createState() =>

      _PaymentScreenState();

}



class _PaymentScreenState

    extends State<PaymentScreen> {

  Color get emeraldForeground =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black;

  final TextEditingController _amountController =

      TextEditingController();



  final TextEditingController _discountController =

      TextEditingController(text: '0');



  final TextEditingController _notesController =

      TextEditingController();

  final TextEditingController _paymentMethodNoteController =

      TextEditingController();

  String _paymentMethod = 'cash';



  final SignatureController _signatureController =

      SignatureController(

    penStrokeWidth: 3,

    penColor: Colors.black,

    exportBackgroundColor: Colors.white,

  );



  double _currentBalance = 0;



  bool _isLoadingBalance = true;

  bool _isSaving = false;



  DateTime _selectedDate = DateTime.now();



  @override

  void initState() {

    super.initState();



    _loadBalance();



    _amountController.addListener(_updatePreview);

    _discountController.addListener(_updatePreview);

  }



  @override

  void dispose() {

    _amountController.dispose();

    _discountController.dispose();

    _notesController.dispose();
    _paymentMethodNoteController.dispose();

    _signatureController.dispose();

    super.dispose();

  }



  Future<void> _loadBalance() async {

    setState(() {

      _isLoadingBalance = true;

    });



    final balance =

        await TransactionService

            .getCurrentBalanceFromLedger(

      customerId: widget.customer.id,

      openingBalance:

          widget.customer.openingBalance,

    );



    if (!mounted) {

      return;

    }



    setState(() {

      _currentBalance = balance;

      _isLoadingBalance = false;



      if (_amountController.text.isEmpty) {

        _amountController.text =

            balance.toStringAsFixed(2);

        _amountController.selection =

            TextSelection.fromPosition(

          TextPosition(

            offset:

                _amountController.text.length,

          ),

        );

      }

    });

  }



  void _updatePreview() {

    if (mounted) {

      setState(() {});

    }

  }



  double get _settlementAmount {

    return double.tryParse(

          _amountController.text.trim(),

        ) ??

        0;

  }



  double get _discount {

    return double.tryParse(

          _discountController.text.trim(),

        ) ??

        0;

  }



  double get _amountReceived {

    final result =

        _settlementAmount - _discount;



    if (result < 0) {

      return 0;

    }



    return result;

  }



  double get _remainingBalance {

    final result =

        _currentBalance - _settlementAmount;



    if (result < 0) {

      return 0;

    }



    return result;

  }



  void _setFullBalance() {

    _amountController.text =

        _currentBalance.toStringAsFixed(2);



    _amountController.selection =

        TextSelection.fromPosition(

      TextPosition(

        offset:

            _amountController.text.length,

      ),

    );



    setState(() {});

  }



  void _clearSignature() {

    _signatureController.clear();



    setState(() {});

  }



  Future<void> _selectDate() async {

    final today = DateTime.now();



    final picked = await showDatePicker(

      context: context,

      initialDate: _selectedDate,

      firstDate: DateTime(2000),

      lastDate: DateTime(today.year, today.month, today.day),

      helpText: 'Select payment date',

    );



    if (picked == null || !mounted) {

      return;

    }



    setState(() {

      _selectedDate = DateTime(

        picked.year,

        picked.month,

        picked.day,

      );

    });

  }



  String _formatSelectedDate() {

    final day = _selectedDate.day.toString().padLeft(2, '0');

    final month = _selectedDate.month.toString().padLeft(2, '0');

    return '$day/$month/${_selectedDate.year}';

  }



  Future<String?> _uploadSignature() async {

    final user =

        Supabase.instance.client.auth.currentUser;



    if (user == null) {

      _showMessage(

        'You are not logged in.',

        isError: true,

      );

      return null;

    }



    if (_signatureController.isEmpty) {

      _showMessage(

        'Please collect the customer signature.',

        isError: true,

      );

      return null;

    }



    final bytes =

        await _signatureController.toPngBytes();



    if (bytes == null || bytes.isEmpty) {

      _showMessage(

        'Could not capture the signature.',

        isError: true,

      );

      return null;

    }



    final paymentId =

        DateTime.now()

            .microsecondsSinceEpoch

            .toString();



    final path =

        '${user.id}/$paymentId.png';



    try {

      await Supabase.instance.client.storage

          .from('payment-signatures')

          .uploadBinary(

            path,

            bytes,

            fileOptions:

                const FileOptions(

              contentType: 'image/png',

              upsert: false,

            ),

          );



      return path;

    } catch (error) {

      _showMessage(

        'Could not upload the signature.',

        isError: true,

      );

      return null;

    }

  }



  Future<void> _savePayment() async {

    FocusScope.of(context).unfocus();



    final amount =

        _settlementAmount;



    final discount =

        _discount;



    if (amount <= 0) {

      _showMessage(

        'Enter the amount being settled.',

        isError: true,

      );

      return;

    }



    if (amount > _currentBalance) {

      _showMessage(

        'Settlement amount cannot be greater than the current balance.',

        isError: true,

      );

      return;

    }



    if (discount < 0) {

      _showMessage(

        'Discount cannot be negative.',

        isError: true,

      );

      return;

    }



    if (discount >= amount) {

      _showMessage(

        'Discount must be less than the amount being settled.',

        isError: true,

      );

      return;

    }



    final received =

        amount - discount;



    if (received <= 0) {

      _showMessage(

        'Amount received must be greater than zero.',

        isError: true,

      );

      return;

    }



    if (_signatureController.isEmpty) {

      _showMessage(

        'Please collect the customer signature.',

        isError: true,

      );

      return;

    }



    setState(() {

      _isSaving = true;

    });



    String? signaturePath;



    try {

      signaturePath =

          await _uploadSignature();



      if (signaturePath == null) {

        return;

      }



      final temporaryTransaction =

          PaymentTransaction(

        id: DateTime.now()

            .microsecondsSinceEpoch

            .toString(),

        customerId:

            widget.customer.id,

        customerName:

            widget.customer.businessName,

        amount: amount,

        previousBalance:

            _currentBalance,

        remainingBalance:

            _remainingBalance,

        transactionDate:

            _selectedDate,

        notes:

            _notesController.text.trim(),

        paymentMethod:

            _paymentMethod,

        paymentMethodNote:

            _paymentMethodNoteController.text.trim(),

        signature:

            await _signatureController

                    .toPngBytes() ??

                Uint8List(0),

        signaturePath:

            signaturePath,

      );



      final success =

          await _savePaymentWithDiscount(

        temporaryTransaction,

        discount,

      );



      if (!success) {

        await _deleteUploadedSignature(

          signaturePath,

        );

        return;

      }



      await CustomerService.loadCustomers();

      await TransactionService.loadTransactions();



      if (!mounted) {

        return;

      }



      _showMessage(

        'Payment saved. ₹${received.toStringAsFixed(2)} received.',

      );



      Navigator.pop(context, true);

    } catch (error) {

      if (signaturePath != null) {

        await _deleteUploadedSignature(

          signaturePath,

        );

      }



      if (mounted) {

        _showMessage(

          'Could not save the payment.',

          isError: true,

        );

      }

    } finally {

      if (mounted) {

        setState(() {

          _isSaving = false;

        });

      }

    }

  }



  Future<bool> _savePaymentWithDiscount(

    PaymentTransaction transaction,

    double discount,

  ) async {

    try {

      final selectedPaymentMethod =
          transaction.paymentMethod.trim().toLowerCase();

      const allowedPaymentMethods = {
        'cash',
        'cheque',
        'neft',
        'gpay',
      };

      if (!allowedPaymentMethods.contains(
        selectedPaymentMethod,
      )) {
        throw Exception(
          'Invalid payment method selected.',
        );
      }

      final response =

          await Supabase.instance.client

              .rpc(

        'record_payment',

        params: {

          'p_customer_id':

              transaction.customerId,

          'p_amount':

              transaction.amount,

          'p_discount':

              discount,

          'p_notes':

              transaction.notes.isEmpty

                  ? null

                  : transaction.notes,

          'p_signature_path':

              transaction.signaturePath,

          'p_transaction_date':

              transaction.transactionDate

                  .toIso8601String(),
          'p_payment_method':

              selectedPaymentMethod,

          'p_payment_method_note':

              transaction.paymentMethodNote.isEmpty

                  ? null

                  : transaction.paymentMethodNote,

        },

      );



      final inserted =

          Map<String, dynamic>.from(

        response as Map,

      );



      final savedTransaction =

          PaymentTransaction(

        id:

            inserted['id'] as String,

        customerId:

            inserted['customer_id']

                as String,

        customerName:

            transaction.customerName,

        amount:

            (inserted['amount'] as num)

                .toDouble(),

        previousBalance:

            (inserted['previous_balance']

                    as num)

                .toDouble(),

        remainingBalance:

            (inserted['remaining_balance']

                    as num)

                .toDouble(),

        transactionDate:

            DateTime.parse(

          inserted['transaction_date']

              as String,

        ),

        notes:

            (inserted['notes'] as String?) ??

                '',

        paymentMethod:

            inserted['payment_method']?.toString() ??
                selectedPaymentMethod,

        paymentMethodNote:

            inserted['payment_method_note']?.toString() ??
                _paymentMethodNoteController.text.trim(),

        signature:

            transaction.signature,

        signaturePath:

            inserted['signature_path']

                as String?,

      );



      TransactionService.transactions

          .insert(

        0,

        savedTransaction,

      );



      TransactionService.dataVersion.value++;



      return true;

    } catch (error) {

      final message =

          error.toString();



      if (message.contains(

        'Amount to settle cannot be greater',

      )) {

        _showMessage(

          'Settlement amount is greater than the current balance.',

          isError: true,

        );

      } else if (message.contains(

        'Discount must be less',

      )) {

        _showMessage(

          'Discount must be less than the settlement amount.',

          isError: true,

        );

      } else {

        _showMessage(

          'Could not save the payment. Please try again.',

          isError: true,

        );

      }



      return false;

    }

  }



  Future<void> _deleteUploadedSignature(

    String path,

  ) async {

    try {

      await Supabase.instance.client.storage

          .from('payment-signatures')

          .remove([path]);

    } catch (_) {

      // Do not replace the original payment error

      // with a signature cleanup error.

    }

  }



  void _showMessage(

    String message, {

    bool isError = false,

  }) {

    if (!mounted) {

      return;

    }



    ScaffoldMessenger.of(context)

        .showSnackBar(

      SnackBar(

        content: Text(message),

        backgroundColor:

            isError ? Colors.red : null,

      ),

    );

  }



  @override

  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final received = _amountReceived;
    final remaining = _remainingBalance;
    const emerald = Color(0xFF0F766E);
    const emeraldLight = Color(0xFF2A9D8F);

    final fieldFill = isDark ? const Color(0xFF151B1A) : const Color(0xFFF7F9F8);
    final cardColor = isDark ? const Color(0xFF121817) : Colors.white;

    InputDecoration fieldDecoration({
      String? prefixText,
      String? hintText,
      Widget? prefixIcon,
      Widget? suffixIcon,
      String? helperText,
    }) {
      return InputDecoration(
        prefixText: prefixText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        helperText: helperText,
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A3532) : const Color(0xFFDDE5E2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: emerald, width: 1.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? const Color(0xFF293330) : const Color(0xFFE1E8E5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.customer.businessName.isNotEmpty
                                ? widget.customer.businessName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: emerald,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.customer.businessName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 15, color: colors.onSurfaceVariant),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      widget.customer.location,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: colors.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [isDark ? const Color(0xFF0B4F4A) : emerald, isDark ? const Color(0xFF146C65) : emeraldLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: emerald.withValues(alpha: 0.22), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Current Amount Due',
                          style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 7),
                        _isLoadingBalance
                            ? const SizedBox(
                                width: 27,
                                height: 27,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              )
                            : Text(
                                '₹${_currentBalance.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.black, fontSize: 31, fontWeight: FontWeight.w800),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text('Amount to Settle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: fieldDecoration(
                      prefixText: '₹ ',
                      hintText: '0.00',
                      suffixIcon: TextButton(
                        onPressed: _setFullBalance,
                        child: const Text('FULL', style: TextStyle(color: emerald, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Discount / Amount Forgiven', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: fieldDecoration(
                      prefixText: '₹ ',
                      hintText: '0.00',
                      helperText: 'Enter 0 if there is no discount.',
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: fieldDecoration(prefixIcon: const Icon(Icons.account_balance_wallet_outlined)),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'cheque', child: Text('Cheque / Check')),
                      DropdownMenuItem(value: 'neft', child: Text('Online - NEFT')),
                      DropdownMenuItem(value: 'gpay', child: Text('Online - GPay')),
                    ],
                    onChanged: _isSaving ? null : (value) {
                      if (value == null) return;
                      setState(() => _paymentMethod = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Payment Method Note / Reference', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paymentMethodNoteController,
                    maxLines: 2,
                    decoration: fieldDecoration(hintText: 'Optional cheque number, NEFT reference, GPay note, etc.'),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? const Color(0xFF293330) : const Color(0xFFE1E8E5)),
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(label: 'Amount to settle', value: '₹${_settlementAmount.toStringAsFixed(2)}'),
                        const SizedBox(height: 11),
                        _SummaryRow(label: 'Discount', value: '₹${_discount.toStringAsFixed(2)}'),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Divider()),
                        _SummaryRow(
                          label: 'Amount actually received',
                          value: '₹${received.toStringAsFixed(2)}',
                          bold: true,
                          valueColor: emerald,
                        ),
                        const SizedBox(height: 11),
                        _SummaryRow(
                          label: 'Remaining balance',
                          value: '₹${remaining.toStringAsFixed(2)}',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text('Payment Date', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _isSaving ? null : _selectDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: fieldDecoration(prefixIcon: const Icon(Icons.calendar_today_outlined)),
                      child: Text(
                        _formatSelectedDate(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text('Note', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: fieldDecoration(hintText: 'Optional note'),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Customer Signature', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const Text('Required', style: TextStyle(color: emerald, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF34413E) : const Color(0xFFD8E2DE)),
                      borderRadius: BorderRadius.circular(16),
                      color: emeraldForeground,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearSignature,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(foregroundColor: emerald),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _savePayment,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Payment',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: emerald,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

// SUMMARY ROW

// -----------------------------------------------------------------------------



class _SummaryRow

    extends StatelessWidget {

  final String label;

  final String value;

  final bool bold;

  final Color? valueColor;


  const _SummaryRow({

    required this.label,

    required this.value,

    this.bold = false,

    this.valueColor,

  });



  @override

  Widget build(BuildContext context) {

    return Row(

      mainAxisAlignment:

          MainAxisAlignment.spaceBetween,

      children: [

        Expanded(

          child: Text(

            label,

            style: TextStyle(

              fontWeight:

                  bold

                      ? FontWeight.w600

                      : FontWeight.normal,

            ),

          ),

        ),

        const SizedBox(width: 15),

        Text(

          value,

          style: TextStyle(

            fontWeight:

                bold

                    ? FontWeight.bold

                    : FontWeight.normal,

            fontSize:

                bold ? 16 : 14,

            color: valueColor,

          ),

        ),

      ],

    );

  }

}