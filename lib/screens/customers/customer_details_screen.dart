import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/customer.dart';

import '../../services/customer_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';
import 'package:file_selector/file_selector.dart';

import '../../services/transaction_service.dart';

import '../payments/payment_screen.dart';

import '../purchases/add_purchase_screen.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsScreen({super.key, required this.customer});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  double currentBalance = 0;

  bool isLoading = true;

  List<Map<String, dynamic>> ledgerEntries = [];

  bool _isRefreshingFromDataChange = false;

  bool _isOwner = false;

  final String _selectedHistorySection = 'purchases';
  String _activeTab = 'ledger';
  String _selectedLedgerFilter = 'All';

  @override
  void initState() {
    super.initState();

    TransactionService.dataVersion.addListener(_handleTransactionDataChanged);

    _loadRole();

    _isRefreshingFromDataChange = true;

    _loadCustomerData().whenComplete(() {
      _isRefreshingFromDataChange = false;
    });
  }

  @override
  void dispose() {
    TransactionService.dataVersion.removeListener(
      _handleTransactionDataChanged,
    );

    super.dispose();
  }

  void _handleTransactionDataChanged() {
    if (_isRefreshingFromDataChange || !mounted) {
      return;
    }

    _isRefreshingFromDataChange = true;

    Future<void>.microtask(() async {
      try {
        await _loadCustomerData();
      } finally {
        _isRefreshingFromDataChange = false;
      }
    });
  }

  Future<void> _loadRole() async {
    try {
      final supabase = Supabase.instance.client;

      final role = await supabase.rpc('get_my_role');

      if (!mounted) return;

      setState(() {
        _isOwner = role?.toString() == 'owner';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isOwner = false;
      });
    }
  }

  Customer get _displayCustomer =>
      CustomerService.getCustomerById(widget.customer.id) ?? widget.customer;

  // ------------------------------------------------------------

  // LOAD CUSTOMER DATA

  // ------------------------------------------------------------

  Future<void> _loadCustomerData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await TransactionService.loadCustomerBalances();

      final balance = await TransactionService.getCurrentBalanceFromLedger(
        customerId: widget.customer.id,

        openingBalance: _displayCustomer.openingBalance,
      );

      final ledger = await TransactionService.getCustomerLedger(
        widget.customer.id,
      );

      if (!mounted) return;

      setState(() {
        currentBalance = balance;

        ledgerEntries = ledger;

        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load customer history: $error')),
      );
    }
  }

  Future<void> _refreshCustomerData() async {
    if (_isRefreshingFromDataChange) {
      return;
    }

    _isRefreshingFromDataChange = true;

    try {
      await _loadCustomerData();
    } finally {
      _isRefreshingFromDataChange = false;
    }
  }

  Future<void> _editCustomer() async {
    final businessNameController = TextEditingController(
      text: _displayCustomer.businessName,
    );

    final locationController = TextEditingController(
      text: _displayCustomer.location,
    );

    final phoneController = TextEditingController(text: _displayCustomer.phone);

    final formKey = GlobalKey<FormState>();

    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,

      barrierDismissible: !isSaving,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (!formKey.currentState!.validate()) return;

              setDialogState(() {
                isSaving = true;
              });

              final success = await CustomerService.updateCustomer(
                customerId: widget.customer.id,

                businessName: businessNameController.text,

                location: locationController.text,

                phone: phoneController.text,
              );

              if (!mounted || !dialogContext.mounted) return;

              if (success) {
                Navigator.pop(dialogContext, true);
              } else {
                setDialogState(() {
                  isSaving = false;
                });

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      CustomerService.errorMessage ??
                          'Could not update customer.',
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Edit Customer'),

              content: Form(
                key: formKey,

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      TextFormField(
                        controller: businessNameController,

                        textInputAction: TextInputAction.next,

                        decoration: const InputDecoration(
                          labelText: 'Business name',

                          prefixIcon: Icon(Icons.business_outlined),
                        ),

                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Business name is required.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: locationController,

                        textInputAction: TextInputAction.next,

                        decoration: const InputDecoration(
                          labelText: 'Location',

                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),

                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Location is required.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: phoneController,

                        keyboardType: TextInputType.phone,

                        textInputAction: TextInputAction.done,

                        decoration: const InputDecoration(
                          labelText: 'Phone number',

                          prefixIcon: Icon(Icons.phone_outlined),
                        ),

                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required.';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext, false),

                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: isSaving ? null : save,

                  child: isSaving
                      ? const SizedBox(
                          width: 20,

                          height: 20,

                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    businessNameController.dispose();

    locationController.dispose();

    phoneController.dispose();

    if (saved == true && mounted) {
      final updatedCustomer = CustomerService.getCustomerById(
        widget.customer.id,
      );

      if (updatedCustomer != null) {
        setState(() {});
      }

      await _refreshCustomerData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer updated successfully.')),
      );
    }
  }

  // ------------------------------------------------------------

  // NEW PURCHASE

  // ------------------------------------------------------------

  // ------------------------------------------------------------

  // CALL CUSTOMER

  // ------------------------------------------------------------

  Future<void> _callCustomer() async {
    final phone = _displayCustomer.phone.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This customer does not have a phone number.'),
        ),
      );

      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);

    try {
      final launched = await launchUrl(uri);

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer.')),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not call customer: $error')),
      );
    }
  }

  Future<void> _whatsappCustomer() async {
    final rawPhone = _displayCustomer.phone.trim();

    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This customer does not have a phone number.'),
        ),
      );

      return;
    }

    var phone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (phone.startsWith('+')) {
      phone = phone.substring(1);
    } else if (phone.length == 10) {
      phone = '91$phone';
    }

    final uri = Uri.parse('https://wa.me/$phone');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp: $error')),
      );
    }
  }

  // ------------------------------------------------------------

  // CUSTOMER STATEMENT PDF

  // ------------------------------------------------------------

  Future<void> _exportCustomerStatement() async {
    Uint8List? generatedPdfBytes;

    if (ledgerEntries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no transactions to export yet.'),
        ),
      );
      return;
    }

    try {
      final customer = _displayCustomer;
      final pdf = pw.Document();

      double totalPurchases = 0;
      double totalSettled = 0;
      double totalDiscount = 0;
      double totalReceived = 0;
      double totalReturns = 0;

      final exportEntries = List<Map<String, dynamic>>.from(ledgerEntries);
      exportEntries.sort((a, b) {
        final dateA = DateTime.tryParse(
          a['transaction_date']?.toString() ?? '',
        );
        final dateB = DateTime.tryParse(
          b['transaction_date']?.toString() ?? '',
        );

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

      for (final entry in exportEntries) {
        final type = entry['entry_type']?.toString() ?? '';
        final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
        final discount = (entry['discount'] as num?)?.toDouble() ?? 0;
        final amountReceived =
            (entry['amount_received'] as num?)?.toDouble() ??
            (amount - discount);

        if (type == 'purchase') {
          totalPurchases += amount;
        } else if (type == 'payment') {
          totalSettled += amount;
          totalDiscount += discount;
          totalReceived += amountReceived;
        } else if (type == 'return') {
          totalReturns += amount;
        }
      }

      final generatedAt = _formatDate(DateTime.now().toIso8601String());

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(28),
          ),
          build: (context) {
            return [
              pw.Text(
                'CUSTOMER STATEMENT',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                customer.businessName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Location: ${customer.location}'),
              pw.Text('Phone: ${customer.phone}'),
              pw.Text('Generated: $generatedAt'),
              pw.SizedBox(height: 18),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfSummaryItem('Purchases', _money(totalPurchases)),
                    _pdfSummaryItem('Returns', _money(totalReturns)),
                    _pdfSummaryItem('Settled', _money(totalSettled)),
                    _pdfSummaryItem('Discount', _money(totalDiscount)),
                    _pdfSummaryItem('Received', _money(totalReceived)),
                    _pdfSummaryItem('Balance Due', _money(currentBalance)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Transaction History',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellPadding: const pw.EdgeInsets.all(5),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                headers: const [
                  'Date',
                  'Type',
                  'Amount',
                  'Discount',
                  'Received',
                  'Balance',
                  'Received By',
                ],
                data: exportEntries.map((entry) {
                  final type = entry['entry_type']?.toString() ?? '';
                  final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
                  final discount = (entry['discount'] as num?)?.toDouble() ?? 0;
                  final received =
                      (entry['amount_received'] as num?)?.toDouble() ??
                      (amount - discount);
                  final balanceAfter =
                      (entry['balance_after'] as num?)?.toDouble() ?? 0;
                  final profile = entry['profiles'];
                  final receivedBy = profile is Map
                      ? profile['name']?.toString() ?? 'User'
                      : 'User';

                  return [
                    _formatDate(entry['transaction_date']),
                    type == 'purchase'
                        ? 'Purchase'
                        : type == 'return'
                        ? 'Sales Return'
                        : 'Payment',
                    _money(amount),
                    type == 'payment' ? _money(discount) : 'Rs. 0.00',
                    type == 'payment' ? _money(received) : 'Rs. 0.00',
                    _money(balanceAfter),
                    receivedBy,
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Current Amount Due: ${_money(currentBalance)}',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'This statement is generated from the business payment ledger.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      generatedPdfBytes = bytes;

      if (bytes.isEmpty) {
        throw Exception('PDF generation returned an empty file.');
      }

      final safeName = customer.businessName
          .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final fileName =
          '${safeName.isEmpty ? 'customer' : safeName}_statement.pdf';

      // macOS sandbox does not allow the app to write directly to ~/Downloads.
      // Ask the user for a destination through the native Save dialog instead.
      final saveLocation = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF Document', extensions: ['pdf']),
        ],
      );

      if (saveLocation == null) {
        return;
      }

      final outputFile = XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/pdf',
      );
      await outputFile.saveTo(saveLocation.path);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Customer statement saved successfully:\n${saveLocation.path}',
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              try {
                await Process.run('open', [saveLocation.path]);
              } catch (openError) {
                debugPrint('CUSTOMER STATEMENT OPEN ERROR: $openError');
              }
            },
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('CUSTOMER STATEMENT EXPORT ERROR: $error');
      debugPrint('CUSTOMER STATEMENT EXPORT STACK: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export customer statement: $error'),
          duration: const Duration(seconds: 8),
          action: generatedPdfBytes != null && generatedPdfBytes.isNotEmpty
              ? SnackBarAction(
                  label: 'Share',
                  onPressed: () async {
                    try {
                      await Printing.sharePdf(
                        bytes: generatedPdfBytes!,
                        filename: 'customer_statement.pdf',
                      );
                    } catch (shareError) {
                      debugPrint('CUSTOMER STATEMENT SHARE ERROR: $shareError');
                    }
                  },
                )
              : null,
        ),
      );
    }
  }

  pw.Widget _pdfSummaryItem(String title, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,

      children: [
        pw.Text(
          title,

          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),

        pw.SizedBox(height: 3),

        pw.Text(
          value,

          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _newPurchase() async {
    await Navigator.push(
      context,

      MaterialPageRoute(builder: (_) => const AddPurchaseScreen()),
    );

    await _refreshCustomerData();
  }

  // ------------------------------------------------------------

  // RECORD PAYMENT

  // ------------------------------------------------------------

  Future<void> _recordPayment() async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => PaymentScreen(customer: _displayCustomer),
      ),
    );

    await _refreshCustomerData();
  }

  // ------------------------------------------------------------

  // EDIT PURCHASE

  // ------------------------------------------------------------

  Future<void> _editPurchase(Map<String, dynamic> entry) async {
    final entryId = entry['id']?.toString();

    if (entryId == null || entryId.isEmpty) {
      return;
    }

    final originalAmount = (entry['amount'] as num?)?.toDouble() ?? 0;

    final originalNotes = entry['notes']?.toString() ?? '';

    DateTime originalDate;

    try {
      originalDate = DateTime.parse(
        entry['transaction_date'].toString(),
      ).toLocal();
    } catch (_) {
      originalDate = DateTime.now();
    }

    final amountController = TextEditingController(
      text: originalAmount.toStringAsFixed(2),
    );

    final notesController = TextEditingController(text: originalNotes);

    DateTime selectedDate = originalDate;

    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,

      barrierDismissible: !isSaving,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final amount = double.tryParse(amountController.text.trim());

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid purchase amount.'),
                  ),
                );

                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              final transactionDate = DateTime(
                selectedDate.year,

                selectedDate.month,

                selectedDate.day,

                originalDate.hour,

                originalDate.minute,

                originalDate.second,
              );

              try {
                await Supabase.instance.client.rpc(
                  'update_purchase',

                  params: {
                    'p_entry_id': entryId,

                    'p_amount': amount,

                    'p_notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),

                    'p_transaction_date': transactionDate
                        .toUtc()
                        .toIso8601String(),
                  },
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isSaving = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Could not update purchase: $error')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Edit Purchase'),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    TextField(
                      controller: amountController,

                      enabled: !isSaving,

                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),

                      decoration: const InputDecoration(
                        labelText: 'Purchase Amount',

                        prefixText: 'Rs. ',
                      ),
                    ),

                    const SizedBox(height: 16),

                    InkWell(
                      onTap: isSaving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: dialogContext,

                                initialDate: selectedDate,

                                firstDate: DateTime(2000),

                                lastDate: DateTime(2100),
                              );

                              if (picked == null) return;

                              setDialogState(() {
                                selectedDate = picked;
                              });
                            },

                      borderRadius: BorderRadius.circular(12),

                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Purchase Date',

                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),

                        child: Text(_formatDate(selectedDate)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: notesController,

                      enabled: !isSaving,

                      maxLines: 3,

                      textCapitalization: TextCapitalization.sentences,

                      decoration: const InputDecoration(
                        labelText: 'New Order / Note',

                        hintText: 'Optional new order or note',

                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),

                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: isSaving ? null : save,

                  child: isSaving
                      ? const SizedBox(
                          width: 20,

                          height: 20,

                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();

    notesController.dispose();

    if (result != true || !mounted) {
      return;
    }

    await _refreshAfterPurchaseChange();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase updated successfully.')),
    );
  }

  // ------------------------------------------------------------

  // DELETE PURCHASE

  // ------------------------------------------------------------

  bool _isPurchaseFullyPaid(Map<String, dynamic> purchase) {
    if (purchase['entry_type']?.toString() != 'purchase') {
      return false;
    }

    final purchaseId = purchase['id']?.toString();
    final balanceBefore = (purchase['balance_before'] as num?)?.toDouble() ?? 0;

    if (purchaseId == null || purchaseId.isEmpty) {
      return false;
    }

    final chronologicalEntries = List<Map<String, dynamic>>.from(ledgerEntries)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(
          a['transaction_date']?.toString() ?? '',
        );
        final dateB = DateTime.tryParse(
          b['transaction_date']?.toString() ?? '',
        );

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

    final purchaseIndex = chronologicalEntries.indexWhere(
      (entry) => entry['id']?.toString() == purchaseId,
    );

    if (purchaseIndex < 0) {
      return false;
    }

    for (
      var index = purchaseIndex + 1;
      index < chronologicalEntries.length;
      index++
    ) {
      final laterEntry = chronologicalEntries[index];

      if (laterEntry['entry_type']?.toString() != 'payment') {
        continue;
      }

      final paymentBalanceAfter = (laterEntry['balance_after'] as num?)
          ?.toDouble();

      if (paymentBalanceAfter != null &&
          paymentBalanceAfter <= balanceBefore + 0.01) {
        return true;
      }
    }

    return false;
  }

  bool _isAccidentalPurchase(Map<String, dynamic> purchase) {
    if (purchase['entry_type']?.toString() != 'purchase') {
      return false;
    }

    if (_isPurchaseFullyPaid(purchase)) {
      return false;
    }

    final purchaseId = purchase['id']?.toString();
    if (purchaseId == null || purchaseId.isEmpty) {
      return false;
    }

    final chronologicalEntries = List<Map<String, dynamic>>.from(ledgerEntries)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(
          a['transaction_date']?.toString() ?? '',
        );
        final dateB = DateTime.tryParse(
          b['transaction_date']?.toString() ?? '',
        );

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

    final purchaseIndex = chronologicalEntries.indexWhere(
      (entry) => entry['id']?.toString() == purchaseId,
    );

    if (purchaseIndex < 0) {
      return false;
    }

    // An accidental purchase is one that has not been paid at all.
    // Once any payment has been recorded after it, keep it protected
    // until the purchase is fully settled.
    for (
      var index = purchaseIndex + 1;
      index < chronologicalEntries.length;
      index++
    ) {
      if (chronologicalEntries[index]['entry_type']?.toString() == 'payment') {
        return false;
      }
    }

    return true;
  }

  Future<void> _deletePurchase(Map<String, dynamic> entry) async {
    final entryId = entry['id']?.toString();

    if (entryId == null || entryId.isEmpty) {
      return;
    }

    final isPaid = _isPurchaseFullyPaid(entry);
    final isAccidental = _isAccidentalPurchase(entry);

    if (!isPaid && !isAccidental) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This purchase has a payment recorded. It can be removed only after it has been fully paid.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isPaid ? 'Remove Paid Purchase?' : 'Delete Accidental Purchase?',
          ),
          content: Text(
            isPaid
                ? 'This purchase has already been fully paid. It will be removed from the customer transaction history. The payment records will remain unchanged.'
                : 'This purchase has no payment recorded after it. It looks like an accidental purchase entry. Delete it permanently from the customer transaction history?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(isPaid ? 'Remove' : 'Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'delete_purchase',

        params: {'p_entry_id': entryId},
      );

      await _refreshAfterPurchaseChange();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete purchase: $error')),
      );
    }
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'cheque':
        return 'Cheque / Check';
      case 'neft':
        return 'Online - NEFT';
      case 'gpay':
        return 'Online - GPay';
      case 'cash':
      default:
        return 'Cash';
    }
  }

  Future<void> _markChequeBounced(Map<String, dynamic> entry) async {
    final paymentId = entry['id']?.toString();
    if (paymentId == null || paymentId.isEmpty) return;

    final bankChargeController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    bool isSaving = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final bankCharge =
                  double.tryParse(
                    bankChargeController.text.trim().replaceAll(',', ''),
                  ) ??
                  -1;

              if (bankCharge < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid bank charge.')),
                );
                return;
              }

              setDialogState(() => isSaving = true);

              try {
                await Supabase.instance.client.rpc(
                  'record_bounced_cheque',
                  params: {
                    'p_payment_id': paymentId,
                    'p_bank_charge': bankCharge,
                    'p_notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    'p_transaction_date': DateTime.now()
                        .toUtc()
                        .toIso8601String(),
                    'p_add_bank_charge': true,
                  },
                );

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!dialogContext.mounted) return;
                setDialogState(() => isSaving = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('Could not mark cheque as bounced: $error'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Cheque Bounced'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailRow(
                      'Cheque Amount',
                      _money((entry['amount'] as num?)?.toDouble() ?? 0),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: bankChargeController,
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Bank Charges',
                        prefixText: '₹ ',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      enabled: !isSaving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        hintText: 'Optional bounce reason / bank reference',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : save,
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Mark Bounced'),
                ),
              ],
            );
          },
        );
      },
    );

    bankChargeController.dispose();
    notesController.dispose();

    if (confirmed == true && mounted) {
      await _refreshCustomerData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cheque bounced. Customer balance updated with the cheque amount and bank charges.',
          ),
        ),
      );
    }
  }

  Future<void> _recordReturn() async {
    final amountController = TextEditingController();

    final notesController = TextEditingController();

    DateTime selectedDate = DateTime.now();

    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final amount = double.tryParse(
                amountController.text.trim().replaceAll(',', ''),
              );

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid return amount.')),
                );

                return;
              }

              if (amount > currentBalance) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Return cannot be greater than the current amount due (${_money(currentBalance)}).',
                    ),
                  ),
                );

                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                await Supabase.instance.client.rpc(
                  'record_return',

                  params: {
                    'p_customer_id': widget.customer.id,

                    'p_amount': amount,

                    'p_notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),

                    'p_transaction_date': DateTime(
                      selectedDate.year,

                      selectedDate.month,

                      selectedDate.day,
                    ).toUtc().toIso8601String(),
                  },
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isSaving = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Could not record return: $error')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Return Products'),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    _detailRow('Current Amount Due', _money(currentBalance)),

                    const SizedBox(height: 16),

                    TextField(
                      controller: amountController,

                      enabled: !isSaving,

                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),

                      decoration: const InputDecoration(
                        labelText: 'Return Amount',

                        hintText: 'e.g. 500',

                        prefixText: 'Rs. ',
                      ),
                    ),

                    const SizedBox(height: 16),

                    InkWell(
                      onTap: isSaving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: dialogContext,

                                initialDate: selectedDate,

                                firstDate: DateTime(2000),

                                lastDate: DateTime(2100),
                              );

                              if (picked == null) return;

                              setDialogState(() {
                                selectedDate = picked;
                              });
                            },

                      borderRadius: BorderRadius.circular(12),

                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Return Date',

                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),

                        child: Text(_formatDate(selectedDate)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: notesController,

                      enabled: !isSaving,

                      maxLines: 3,

                      textCapitalization: TextCapitalization.sentences,

                      decoration: const InputDecoration(
                        labelText: 'Reason / Note',

                        hintText: 'Optional reason or note about the return',

                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),

                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: isSaving ? null : save,

                  child: isSaving
                      ? const SizedBox(
                          width: 20,

                          height: 20,

                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm Return'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();

    notesController.dispose();

    if (result != true || !mounted) {
      return;
    }

    await _refreshAfterPurchaseChange();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Return recorded successfully.')),
    );
  }

  Future<void> _refreshAfterPurchaseChange() async {
    _isRefreshingFromDataChange = true;

    try {
      await TransactionService.loadCustomerBalances();

      await TransactionService.loadTransactions();

      await _loadCustomerData();
    } finally {
      _isRefreshingFromDataChange = false;
    }
  }

  // ------------------------------------------------------------

  // MONEY FORMAT

  // ------------------------------------------------------------

  String _money(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    return 'Rs. ${number.toStringAsFixed(2)}';
  }

  // ------------------------------------------------------------

  // DATE FORMAT

  // ------------------------------------------------------------

  String _formatDate(dynamic value) {
    if (value == null) {
      return '';
    }

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final day = date.day.toString().padLeft(2, '0');

      final month = date.month.toString().padLeft(2, '0');

      final year = date.year.toString();

      final hour = date.hour == 0
          ? 12
          : date.hour > 12
          ? date.hour - 12
          : date.hour;

      final minute = date.minute.toString().padLeft(2, '0');

      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year  '
          '$hour:$minute $period';
    } catch (_) {
      return value.toString();
    }
  }

  // ------------------------------------------------------------

  // DISPLAYED TRANSACTIONS

  // ------------------------------------------------------------

  List<Map<String, dynamic>> get _displayedPurchaseEntries {
    return ledgerEntries
        .where((entry) => entry['entry_type']?.toString() == 'purchase')
        .toList();
  }

  // ------------------------------------------------------------

  // BUILD

  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final customer = _displayCustomer;
    final allEntries = List<Map<String, dynamic>>.from(ledgerEntries)
      ..sort((a, b) {
        final aDate = DateTime.tryParse(
          a['transaction_date']?.toString() ?? '',
        );
        final bDate = DateTime.tryParse(
          b['transaction_date']?.toString() ?? '',
        );
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: Color(0xFF24233A)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          customer.businessName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF171629),
          ),
        ),
        actions: [
          if (_isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: OutlinedButton.icon(
                onPressed: _editCustomer,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4934C8),
                  side: const BorderSide(color: Color(0xFFE4E0F8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshCustomerData,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                    children: [
                      // Compact customer identity and outstanding balance header.
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEAE7F4)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 23,
                              backgroundColor: const Color(0xFFE8E1FF),
                              child: Text(
                                customer.businessName.trim().isEmpty
                                    ? '?'
                                    : customer.businessName
                                          .trim()[0]
                                          .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF4A35C7),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.businessName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Color(0xFF19182B),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: Color(0xFF6B6B83),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          customer.location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF68677D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone_outlined,
                                        size: 13,
                                        color: Color(0xFF6B6B83),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          customer.phone,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF68677D),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 30,
                                              height: 28,
                                            ),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Call customer',
                                        onPressed: _callCustomer,
                                        icon: const Icon(
                                          Icons.call_outlined,
                                          size: 16,
                                          color: Color(0xFF4934C8),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 30,
                                              height: 28,
                                            ),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'WhatsApp customer',
                                        onPressed: _whatsappCustomer,
                                        icon: const Icon(
                                          Icons.chat_outlined,
                                          size: 16,
                                          color: Color(0xFF159A69),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(minWidth: 94),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEEF0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Total Due',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF8D5962),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _money(currentBalance),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFB4232F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tabs arranged like the supplied reference: Ledger / Details / Purchases / Photos.
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEAE7F4)),
                        ),
                        child: Row(
                          children: [
                            _customerTab('Ledger', 'ledger'),
                            _customerTab('Details', 'details'),
                            _customerTab('Purchases', 'purchases'),
                            _customerTab('Photos', 'photos'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_activeTab == 'ledger') ...[
                        _buildLedgerFilterSelector(),
                        const SizedBox(height: 10),
                        _buildLedgerTableHeader(),
                        if (_filteredLedgerEntries(allEntries).isEmpty)
                          _buildEmptyHistory()
                        else
                          ..._filteredLedgerEntries(
                            allEntries,
                          ).map(_buildLedgerEntry),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _exportCustomerStatement,
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 17,
                            ),
                            label: const Text('Export customer statement'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF4934C8),
                            ),
                          ),
                        ),
                      ] else if (_activeTab == 'details') ...[
                        _buildDetailsPanel(),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _exportCustomerStatement,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Export Customer Statement'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _recordReturn,
                            icon: const Icon(Icons.assignment_return_outlined),
                            label: const Text('Record Sales Return'),
                          ),
                        ),
                      ] else if (_activeTab == 'purchases') ...[
                        _sectionHeading(
                          'Purchase History',
                          _displayedPurchaseEntries.length,
                        ),
                        if (_displayedPurchaseEntries.isEmpty)
                          _buildEmptyHistory()
                        else
                          ..._displayedPurchaseEntries.map(_buildLedgerEntry),
                      ] else ...[
                        _sectionHeading('Customer Signatures & Photos', 0),
                        ...ledgerEntries
                            .where(
                              (entry) =>
                                  (entry['signature_path']?.toString() ?? '')
                                      .isNotEmpty,
                            )
                            .map(
                              (entry) => Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFFEAE7F4),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry['transaction_date']?.toString() ??
                                            'Transaction',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _SignaturePreview(
                                        signaturePath: entry['signature_path']
                                            .toString(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        if (!ledgerEntries.any(
                          (entry) => (entry['signature_path']?.toString() ?? '')
                              .isNotEmpty,
                        ))
                          _emptyPhotosCard(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: isLoading
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFEAE7F4))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _recordPayment,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Payment', maxLines: 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF18A66A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _newPurchase,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Purchase', maxLines: 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6245ED),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _customerTab(String label, String value) {
    final selected = _activeTab == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _activeTab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFECE8FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected
                ? const Border(
                    bottom: BorderSide(color: Color(0xFF6245ED), width: 2),
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected
                  ? const Color(0xFF4934C8)
                  : const Color(0xFF55546B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFFF0EFF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Date',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF626179),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Description',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF626179),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Amount',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF626179),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Balance',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF626179),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    final customer = _displayCustomer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAE7F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _detailRow('Business name', customer.businessName),
          _detailRow('Location', customer.location),
          _detailRow('Phone number', customer.phone),
          _detailRow('Opening balance', _money(customer.openingBalance)),
          const Divider(height: 22),
          _detailRow('Current balance', _money(currentBalance)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _callCustomer,
                icon: const Icon(Icons.call_outlined, size: 16),
                label: const Text('Call'),
              ),
              OutlinedButton.icon(
                onPressed: _whatsappCustomer,
                icon: const Icon(Icons.chat_outlined, size: 16),
                label: const Text('WhatsApp'),
              ),
              if (_isOwner)
                OutlinedButton.icon(
                  onPressed: _editCustomer,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit customer'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 3, 2, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222137),
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(fontSize: 12, color: Color(0xFF77758C)),
        ),
      ],
    ),
  );

  Widget _emptyPhotosCard() => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEAE7F4)),
    ),
    child: const Column(
      children: [
        Icon(Icons.photo_library_outlined, size: 38, color: Color(0xFF9A96B6)),
        SizedBox(height: 8),
        Text(
          'No customer signatures or photos yet',
          style: TextStyle(color: Color(0xFF68677D)),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------

  // CUSTOMER HEADER

  // ------------------------------------------------------------

  // ------------------------------------------------------------

  // BALANCE CARD

  // ------------------------------------------------------------

  // ------------------------------------------------------------

  // EMPTY HISTORY

  // ------------------------------------------------------------

  Widget _buildEmptyHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,

              size: 48,

              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 12),

            Text(
              _selectedHistorySection == 'purchases'
                  ? 'No purchases yet'
                  : _selectedHistorySection == 'payments'
                  ? 'No payments received yet'
                  : 'No sales returns yet',

              style: TextStyle(fontSize: 17, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  // Ledger filters: All / New Purchase / Payment Received / Sales.
  Widget _buildLedgerFilterSelector() {
    const filters = <String>[
      'All',
      'New Purchase',
      'Payment Received',
      'Sales',
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAE7F4)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final selected = _selectedLedgerFilter == filter;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ChoiceChip(
                label: Text(filter),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _selectedLedgerFilter = filter);
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFE8E1FF),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF4934C8)
                      : const Color(0xFF55536B),
                ),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFFB9A9FF)
                      : const Color(0xFFEAE7F4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredLedgerEntries(
    List<Map<String, dynamic>> entries,
  ) {
    switch (_selectedLedgerFilter) {
      case 'New Purchase':
        return entries
            .where(
              (entry) =>
                  entry['entry_type']?.toString().toLowerCase() == 'purchase',
            )
            .toList();
      case 'Payment Received':
        return entries.where((entry) {
          final type = entry['entry_type']?.toString().toLowerCase();
          return type == 'payment' ||
              type == 'bounced_check' ||
              entry['is_bounced'] == true;
        }).toList();
      case 'Sales':
        return entries.where((entry) {
          final type = entry['entry_type']?.toString().toLowerCase();
          return type == 'sale' ||
              type == 'sales' ||
              type == 'return' ||
              type == 'sales_return';
        }).toList();
      case 'All':
      default:
        return entries;
    }
  }

  // ------------------------------------------------------------

  // LEDGER ENTRY

  // ------------------------------------------------------------

  Widget _buildLedgerEntry(Map<String, dynamic> entry) {
    final type = entry['entry_type']?.toString() ?? '';

    final isPurchase = type == 'purchase';

    final isReturn = type == 'return';

    final isBouncedCheck = type == 'bounced_check';

    final paymentMethod =
        entry['payment_method']?.toString() ??
        (type == 'payment' ? 'cash' : '');

    final paymentMethodNote = entry['payment_method_note']?.toString() ?? '';

    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;

    final discount = (entry['discount'] as num?)?.toDouble() ?? 0;

    final amountReceived =
        (entry['amount_received'] as num?)?.toDouble() ?? (amount - discount);

    final balanceBefore = (entry['balance_before'] as num?)?.toDouble() ?? 0;

    final balanceAfter = (entry['balance_after'] as num?)?.toDouble() ?? 0;

    final notes = entry['notes']?.toString() ?? '';

    final profile = entry['profiles'];

    final receivedBy = profile is Map
        ? profile['name']?.toString() ?? 'User'
        : 'User';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 21,

                  child: Icon(
                    isPurchase
                        ? Icons.shopping_cart_outlined
                        : isReturn
                        ? Icons.assignment_return_outlined
                        : Icons.payments_outlined,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        isPurchase
                            ? 'New Purchase'
                            : isReturn
                            ? 'Sales Return'
                            : isBouncedCheck
                            ? 'Cheque Bounced'
                            : entry['is_bounced'] == true
                            ? 'Payment Received (Bounced)'
                            : 'Payment Received',

                        style: const TextStyle(
                          fontSize: 17,

                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        _formatDate(entry['transaction_date']),

                        style: TextStyle(
                          fontSize: 12,

                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isPurchase && _isOwner)
                  PopupMenuButton<String>(
                    tooltip: 'Purchase options',
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editPurchase(entry);
                      } else if (value == 'delete_accidental' ||
                          value == 'remove_paid') {
                        _deletePurchase(entry);
                      }
                    },
                    itemBuilder: (context) {
                      final isPaid = _isPurchaseFullyPaid(entry);
                      final isAccidental = _isAccidentalPurchase(entry);

                      return [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit Purchase'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete_accidental',
                          enabled: isAccidental,
                          child: const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline),
                            title: Text('Delete Accidental Purchase'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'remove_paid',
                          enabled: isPaid,
                          child: const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.remove_circle_outline),
                            title: Text('Remove Paid Purchase'),
                          ),
                        ),
                      ];
                    },
                  ),

                if (!isPurchase &&
                    !isReturn &&
                    !isBouncedCheck &&
                    paymentMethod == 'cheque')
                  PopupMenuButton<String>(
                    tooltip: 'Payment options',
                    onSelected: (value) {
                      if (value == 'bounce') {
                        _markChequeBounced(entry);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'bounce',
                        enabled: entry['is_bounced'] != true,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.money_off_csred_outlined),
                          title: Text(
                            entry['is_bounced'] == true
                                ? 'Cheque Already Bounced'
                                : 'Mark Cheque as Bounced',
                          ),
                        ),
                      ),
                    ],
                  ),

                Text(
                  isPurchase || isBouncedCheck
                      ? '+${_money(amount)}'
                      : '-${_money(amount)}',

                  style: TextStyle(
                    fontSize: 18,

                    fontWeight: FontWeight.bold,

                    color:
                        isPurchase ||
                            isBouncedCheck ||
                            entry['is_bounced'] == true
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            if (isPurchase) ...[
              _detailRow('Purchase Amount', _money(amount)),

              const SizedBox(height: 8),

              _detailRow('Balance Before', _money(balanceBefore)),

              const SizedBox(height: 8),

              _detailRow('Balance After', _money(balanceAfter)),
            ] else if (isBouncedCheck) ...[
              _detailRow(
                'Cheque Amount Returned to Due',
                _money(
                  amount - ((entry['bank_charge'] as num?)?.toDouble() ?? 0),
                ),
              ),

              const SizedBox(height: 8),

              _detailRow(
                'Bank Charges',
                _money((entry['bank_charge'] as num?)?.toDouble() ?? 0),
              ),

              const SizedBox(height: 8),

              _detailRow('Total Added to Due', _money(amount)),

              const SizedBox(height: 8),

              _detailRow('Balance Before', _money(balanceBefore)),

              const SizedBox(height: 8),

              _detailRow('Balance After', _money(balanceAfter)),
            ] else if (isReturn) ...[
              _detailRow('Returned Amount', _money(amount)),

              const SizedBox(height: 8),

              _detailRow('Balance Before', _money(balanceBefore)),

              const SizedBox(height: 8),

              _detailRow('Balance After', _money(balanceAfter)),
            ] else ...[
              _detailRow('Amount Settled', _money(amount)),

              const SizedBox(height: 8),

              _detailRow('Discount Given', _money(discount)),

              const SizedBox(height: 8),

              _detailRow('Actually Received', _money(amountReceived)),

              const SizedBox(height: 8),

              _detailRow('Payment Method', _paymentMethodLabel(paymentMethod)),

              if (paymentMethodNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                _detailRow('Payment Method Note', paymentMethodNote),
              ],

              const SizedBox(height: 8),

              _detailRow('Received By', receivedBy),

              const SizedBox(height: 8),

              _detailRow('Balance Before', _money(balanceBefore)),

              const SizedBox(height: 8),

              _detailRow('Balance After', _money(balanceAfter)),
            ],

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.grey.shade100,

                  borderRadius: BorderRadius.circular(8),
                ),

                child: Text('Note: $notes'),
              ),
            ],

            if (!isPurchase &&
                entry['signature_path'] != null &&
                entry['signature_path'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),

              _SignaturePreview(
                signaturePath: entry['signature_path'].toString(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------

  // DETAIL ROW

  // ------------------------------------------------------------

  Widget _detailRow(String title, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: TextStyle(color: Colors.grey.shade700)),
        ),

        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ============================================================

// SIGNATURE PREVIEW

// ============================================================

class _SignaturePreview extends StatefulWidget {
  final String signaturePath;

  const _SignaturePreview({required this.signaturePath});

  @override
  State<_SignaturePreview> createState() => _SignaturePreviewState();
}

class _SignaturePreviewState extends State<_SignaturePreview> {
  Uint8List? signatureBytes;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadSignature();
  }

  Future<void> _loadSignature() async {
    final bytes = await TransactionService.downloadSignature(
      widget.signaturePath,
    );

    if (!mounted) return;

    setState(() {
      signatureBytes = bytes;

      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8),

        child: SizedBox(
          height: 40,

          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (signatureBytes == null || signatureBytes!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Customer Signature',

          style: TextStyle(fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 8),

        Container(
          height: 120,

          width: double.infinity,

          padding: const EdgeInsets.all(8),

          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),

            borderRadius: BorderRadius.circular(8),
          ),

          child: Image.memory(signatureBytes!, fit: BoxFit.contain),
        ),
      ],
    );
  }
}
