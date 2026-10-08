

import 'dart:typed_data';



import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';



import '../../services/transaction_service.dart';



class SalesmanPaymentsScreen extends StatefulWidget {

  const SalesmanPaymentsScreen({

    super.key,

  });



  @override

  State<SalesmanPaymentsScreen> createState() =>

      _SalesmanPaymentsScreenState();

}



class _SalesmanPaymentsScreenState

    extends State<SalesmanPaymentsScreen> {

  final SupabaseClient _supabase =

      Supabase.instance.client;



  List<Map<String, dynamic>> _payments = [];



  bool _isLoading = true;



  double get _totalCollected {

    return _payments.fold(

      0.0,

      (total, payment) {

        final amountReceived =

            (payment['amount_received'] as num?)?.toDouble() ??

            ((payment['amount'] as num?)?.toDouble() ?? 0) -

                ((payment['discount'] as num?)?.toDouble() ?? 0);



        return total + amountReceived;

      },

    );

  }



  double get _todayCollected {

    final now = DateTime.now();



    return _payments.fold(

      0.0,

      (total, payment) {

        final dateString =

            payment['transaction_date'] as String?;



        if (dateString == null) {

          return total;

        }



        final date = DateTime.tryParse(dateString)?.toLocal();



        if (date == null) {

          return total;

        }



        if (date.year == now.year &&

            date.month == now.month &&

            date.day == now.day) {

          final amountReceived =

              (payment['amount_received'] as num?)?.toDouble() ??

              ((payment['amount'] as num?)?.toDouble() ?? 0) -

                  ((payment['discount'] as num?)?.toDouble() ?? 0);



          return total + amountReceived;

        }



        return total;

      },

    );

  }



  @override

  void initState() {

    super.initState();

    _loadPayments();

  }



  Future<void> _loadPayments() async {

    if (mounted) {

      setState(() {

        _isLoading = true;

      });

    }



    try {

      final user = _supabase.auth.currentUser;



      if (user == null) {

        throw Exception('You are not logged in.');

      }



      final response = await _supabase

          .from('payments')

          .select(

            '''

            id,

            amount,

            discount,

            amount_received,

            previous_balance,

            remaining_balance,

            transaction_date,

            notes,

            signature_path,

            user_id,

            customer_id,

            customers (

              business_name,

              location,

              phone

            ),

            profiles (

              name

            )

            ''',

          )

          .eq('user_id', user.id)

          .order(

            'transaction_date',

            ascending: false,

          );



      if (!mounted) return;



      setState(() {

        _payments =

            List<Map<String, dynamic>>.from(response);

        _isLoading = false;

      });

    } catch (error) {

      if (!mounted) return;



      setState(() {

        _isLoading = false;

      });



      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: const Text(

            'Could not load payments.',

          ),

          action: SnackBarAction(

            label: 'Retry',

            onPressed: _loadPayments,

          ),

        ),

      );

    }

  }



  String _formatDate(String date) {

    final parsed = DateTime.tryParse(date);



    if (parsed == null) {

      return date;

    }



    final local = parsed.toLocal();



    final day =

        local.day.toString().padLeft(2, '0');



    final month =

        local.month.toString().padLeft(2, '0');



    final year = local.year.toString();



    final hour =

        local.hour.toString().padLeft(2, '0');



    final minute =

        local.minute.toString().padLeft(2, '0');



    return '$day/$month/$year • $hour:$minute';

  }



  Future<void> _openPaymentDetails(

    Map<String, dynamic> payment,

  ) async {

    await Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => SalesmanPaymentDetailsScreen(

          payment: payment,

        ),

      ),

    );

  }



  String _customerName(

    Map<String, dynamic> payment,

  ) {

    final customer = payment['customers'];



    if (customer is Map) {

      return customer['business_name']?.toString() ??

          'Customer';

    }



    return 'Customer';

  }



  String _receiverName(

    Map<String, dynamic> payment,

  ) {

    final profile = payment['profiles'];



    if (profile is Map) {

      return profile['name']?.toString() ?? 'User';

    }



    return 'User';

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text(

          'Payments Received',

          style: TextStyle(

            fontWeight: FontWeight.w700,

          ),

        ),

        actions: [

          IconButton(

            tooltip: 'Refresh',

            onPressed: _isLoading ? null : _loadPayments,

            icon: const Icon(

              Icons.refresh_rounded,

            ),

          ),

          const SizedBox(width: 4),

        ],

      ),

      body: RefreshIndicator(

        onRefresh: _loadPayments,

        child: _isLoading

            ? const Center(

                child: CircularProgressIndicator(),

              )

            : _buildContent(),

      ),

    );

  }



  Widget _buildContent() {

    if (_payments.isEmpty) {

      return ListView(

        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(20),

        children: [

          const SizedBox(height: 90),

          _EmptyPaymentsState(

            onRefresh: _loadPayments,

          ),

        ],

      );

    }



    return ListView(

      physics: const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.fromLTRB(

        16,

        18,

        16,

        30,

      ),

      children: [

        _buildSummaryHeader(),



        const SizedBox(height: 26),



        Row(

          children: [

            const Expanded(

              child: Text(

                'Payment History',

                style: TextStyle(

                  fontSize: 21,

                  fontWeight: FontWeight.w800,

                  letterSpacing: -0.3,

                ),

              ),

            ),

            Container(

              padding: const EdgeInsets.symmetric(

                horizontal: 10,

                vertical: 6,

              ),

              decoration: BoxDecoration(

                color: Theme.of(context)

                    .colorScheme

                    .surfaceContainerHighest,

                borderRadius: BorderRadius.circular(20),

              ),

              child: Text(

                '${_payments.length}',

                style: const TextStyle(

                  fontWeight: FontWeight.w700,

                  fontSize: 12,

                ),

              ),

            ),

          ],

        ),



        const SizedBox(height: 12),



        ..._payments.map(

          (payment) => _buildPaymentCard(payment),

        ),

      ],

    );

  }



  Widget _buildSummaryHeader() {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(

        gradient: LinearGradient(

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [

            Theme.of(context).colorScheme.primary,

            Theme.of(context)

                .colorScheme

                .primary

                .withValues(alpha: 0.82),

          ],

        ),

        borderRadius: BorderRadius.circular(24),

        boxShadow: [

          BoxShadow(

            color: Theme.of(context)

                .colorScheme

                .primary

                .withValues(alpha: 0.20),

            blurRadius: 22,

            offset: const Offset(0, 10),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                padding: const EdgeInsets.all(11),

                decoration: BoxDecoration(

                  color: Colors.white.withValues(alpha: 0.16),

                  borderRadius: BorderRadius.circular(14),

                ),

                child: const Icon(

                  Icons.account_balance_wallet_outlined,

                  color: Colors.white,

                  size: 23,

                ),

              ),

              const SizedBox(width: 12),

              const Expanded(

                child: Text(

                  'Total Payments Received',

                  style: TextStyle(

                    color: Colors.white,

                    fontSize: 15,

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ),

            ],

          ),



          const SizedBox(height: 20),



          Text(

            '₹${_totalCollected.toStringAsFixed(2)}',

            style: const TextStyle(

              color: Colors.white,

              fontSize: 32,

              fontWeight: FontWeight.w800,

              letterSpacing: -0.7,

            ),

          ),



          const SizedBox(height: 5),



          Text(

            'Across all recorded payments',

            style: TextStyle(

              color: Colors.white.withValues(alpha: 0.76),

              fontSize: 13,

            ),

          ),



          const SizedBox(height: 20),



          Row(

            children: [

              Expanded(

                child: _SummaryMetric(

                  title: 'Today',

                  value:

                      '₹${_todayCollected.toStringAsFixed(2)}',

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: _SummaryMetric(

                  title: 'Transactions',

                  value: '${_payments.length}',

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }



  Widget _buildPaymentCard(

    Map<String, dynamic> payment,

  ) {

    final customer = payment['customers'];



    final customerName = _customerName(payment);



    final location = customer is Map

        ? customer['location']?.toString() ?? ''

        : '';



    final receiverName = _receiverName(payment);



    final settlementAmount =

        (payment['amount'] as num?)?.toDouble() ?? 0;



    final discount =

        (payment['discount'] as num?)?.toDouble() ?? 0;



    final amountReceived =

        (payment['amount_received'] as num?)?.toDouble() ??

            (settlementAmount - discount);



    final date =

        payment['transaction_date'] as String? ?? '';



    final hasSignature =

        payment['signature_path'] != null &&

            payment['signature_path']

                .toString()

                .isNotEmpty;



    return Container(

      margin: const EdgeInsets.only(bottom: 11),

      decoration: BoxDecoration(

        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(

          color: Theme.of(context)

              .colorScheme

              .outlineVariant

              .withValues(alpha: 0.50),

        ),

      ),

      child: InkWell(

        borderRadius: BorderRadius.circular(20),

        onTap: () => _openPaymentDetails(payment),

        child: Padding(

          padding: const EdgeInsets.all(15),

          child: Row(

            crossAxisAlignment: CrossAxisAlignment.center,

            children: [

              Container(

                width: 50,

                height: 50,

                decoration: BoxDecoration(

                  color: Theme.of(context)

                      .colorScheme

                      .primaryContainer,

                  borderRadius: BorderRadius.circular(15),

                ),

                child: Icon(

                  Icons.payments_outlined,

                  color: Theme.of(context)

                      .colorScheme

                      .onPrimaryContainer,

                ),

              ),



              const SizedBox(width: 13),



              Expanded(

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      customerName,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(

                        fontWeight: FontWeight.w800,

                        fontSize: 15,

                      ),

                    ),



                    if (location.isNotEmpty) ...[

                      const SizedBox(height: 4),

                      Row(

                        children: [

                          Icon(

                            Icons.location_on_outlined,

                            size: 13,

                            color: Theme.of(context)

                                .colorScheme

                                .onSurfaceVariant,

                          ),

                          const SizedBox(width: 3),

                          Expanded(

                            child: Text(

                              location,

                              maxLines: 1,

                              overflow:

                                  TextOverflow.ellipsis,

                              style: TextStyle(

                                fontSize: 11,

                                color: Theme.of(context)

                                    .colorScheme

                                    .onSurfaceVariant,

                              ),

                            ),

                          ),

                        ],

                      ),

                    ],



                    const SizedBox(height: 5),



                    Text(

                      'Received by $receiverName',

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(

                        fontSize: 11,

                        color: Theme.of(context)

                            .colorScheme

                            .onSurfaceVariant,

                      ),

                    ),



                    const SizedBox(height: 3),



                    Text(

                      _formatDate(date),

                      style: TextStyle(

                        fontSize: 11,

                        color: Theme.of(context)

                            .colorScheme

                            .onSurfaceVariant,

                      ),

                    ),

                  ],

                ),

              ),



              const SizedBox(width: 10),



              Column(

                crossAxisAlignment:

                    CrossAxisAlignment.end,

                children: [

                  Text(

                    '+₹${amountReceived.toStringAsFixed(2)}',

                    style: TextStyle(

                      fontSize: 15,

                      fontWeight: FontWeight.w800,

                      color: Colors.green.shade700,

                    ),

                  ),



                  const SizedBox(height: 7),



                  Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      if (hasSignature)

                        Icon(

                          Icons.draw_outlined,

                          size: 15,

                          color: Theme.of(context)

                              .colorScheme

                              .primary,

                        ),

                      const SizedBox(width: 4),

                      Icon(

                        Icons.chevron_right_rounded,

                        size: 19,

                        color: Theme.of(context)

                            .colorScheme

                            .onSurfaceVariant,

                      ),

                    ],

                  ),

                ],

              ),

            ],

          ),

        ),

      ),

    );

  }

}



// ============================================================

// SUMMARY METRIC

// ============================================================



class _SummaryMetric extends StatelessWidget {

  final String title;

  final String value;



  const _SummaryMetric({

    required this.title,

    required this.value,

  });



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: 14,

        vertical: 12,

      ),

      decoration: BoxDecoration(

        color: Colors.white.withValues(alpha: 0.12),

        borderRadius: BorderRadius.circular(14),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Text(

            title,

            style: TextStyle(

              color: Colors.white.withValues(alpha: 0.72),

              fontSize: 11,

            ),

          ),

          const SizedBox(height: 4),

          Text(

            value,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(

              color: Colors.white,

              fontSize: 16,

              fontWeight: FontWeight.w800,

            ),

          ),

        ],

      ),

    );

  }

}



// ============================================================

// EMPTY STATE

// ============================================================



class _EmptyPaymentsState extends StatelessWidget {

  final VoidCallback onRefresh;



  const _EmptyPaymentsState({

    required this.onRefresh,

  });



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(28),

      decoration: BoxDecoration(

        color: Theme.of(context)

            .colorScheme

            .surfaceContainerHighest

            .withValues(alpha: 0.45),

        borderRadius: BorderRadius.circular(22),

      ),

      child: Column(

        children: [

          Container(

            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(

              color: Theme.of(context)

                  .colorScheme

                  .primaryContainer,

              shape: BoxShape.circle,

            ),

            child: Icon(

              Icons.receipt_long_outlined,

              size: 34,

              color: Theme.of(context)

                  .colorScheme

                  .onPrimaryContainer,

            ),

          ),

          const SizedBox(height: 16),

          const Text(

            'No payments received yet',

            textAlign: TextAlign.center,

            style: TextStyle(

              fontSize: 18,

              fontWeight: FontWeight.w800,

            ),

          ),

          const SizedBox(height: 7),

          Text(

            'Payments received from customers will appear here.',

            textAlign: TextAlign.center,

            style: TextStyle(

              color: Theme.of(context)

                  .colorScheme

                  .onSurfaceVariant,

              height: 1.4,

            ),

          ),

          const SizedBox(height: 18),

          OutlinedButton.icon(

            onPressed: onRefresh,

            icon: const Icon(Icons.refresh_rounded),

            label: const Text('Refresh'),

          ),

        ],

      ),

    );

  }

}



// ============================================================

// PAYMENT DETAILS

// ============================================================



class SalesmanPaymentDetailsScreen

    extends StatefulWidget {

  final Map<String, dynamic> payment;



  const SalesmanPaymentDetailsScreen({

    super.key,

    required this.payment,

  });



  @override

  State<SalesmanPaymentDetailsScreen>

      createState() =>

          _SalesmanPaymentDetailsScreenState();

}



class _SalesmanPaymentDetailsScreenState

    extends State<SalesmanPaymentDetailsScreen> {

  Uint8List? _signature;



  bool _isLoadingSignature = false;

  bool _signatureAttempted = false;



  Future<void> _loadSignature() async {

    final signaturePath =

        widget.payment['signature_path'] as String?;



    if (signaturePath == null ||

        signaturePath.isEmpty) {

      if (mounted) {

        setState(() {

          _signatureAttempted = true;

        });

      }

      return;

    }



    if (mounted) {

      setState(() {

        _isLoadingSignature = true;

      });

    }



    try {

      final bytes =

          await TransactionService.downloadSignature(

        signaturePath,

      );



      if (!mounted) return;



      setState(() {

        _signature = bytes;

        _isLoadingSignature = false;

        _signatureAttempted = true;

      });

    } catch (_) {

      if (!mounted) return;



      setState(() {

        _signature = null;

        _isLoadingSignature = false;

        _signatureAttempted = true;

      });

    }

  }



  String _formatDate(String date) {

    final parsed = DateTime.tryParse(date);



    if (parsed == null) {

      return date;

    }



    final local = parsed.toLocal();



    final day =

        local.day.toString().padLeft(2, '0');



    final month =

        local.month.toString().padLeft(2, '0');



    final year = local.year.toString();



    final hour =

        local.hour.toString().padLeft(2, '0');



    final minute =

        local.minute.toString().padLeft(2, '0');



    return '$day/$month/$year • $hour:$minute';

  }



  @override

  void initState() {

    super.initState();

    _loadSignature();

  }



  @override

  Widget build(BuildContext context) {

    final payment = widget.payment;



    final customer = payment['customers'];

    final profile = payment['profiles'];



    final customerName = customer is Map

        ? customer['business_name']?.toString() ??

            'Customer'

        : 'Customer';



    final location = customer is Map

        ? customer['location']?.toString() ?? ''

        : '';



    final phone = customer is Map

        ? customer['phone']?.toString() ?? ''

        : '';



    final receiverName = profile is Map

        ? profile['name']?.toString() ?? 'User'

        : 'User';



    final settlementAmount =

        (payment['amount'] as num?)?.toDouble() ?? 0;



    final discount =

        (payment['discount'] as num?)?.toDouble() ?? 0;



    final amountReceived =

        (payment['amount_received'] as num?)?.toDouble() ??

            (settlementAmount - discount);



    final previousBalance =

        (payment['previous_balance'] as num?)

                ?.toDouble() ??

            0;



    final remainingBalance =

        (payment['remaining_balance'] as num?)

                ?.toDouble() ??

            0;



    final date =

        payment['transaction_date'] as String? ?? '';



    final notes =

        payment['notes'] as String? ?? '';



    final hasSignaturePath =

        payment['signature_path'] != null &&

            payment['signature_path']

                .toString()

                .isNotEmpty;



    return Scaffold(

      appBar: AppBar(

        title: const Text(

          'Payment Details',

          style: TextStyle(

            fontWeight: FontWeight.w700,

          ),

        ),

      ),

      body: ListView(

        padding: const EdgeInsets.fromLTRB(

          16,

          18,

          16,

          32,

        ),

        children: [

          // Success header

          Container(

            padding: const EdgeInsets.symmetric(

              vertical: 24,

              horizontal: 20,

            ),

            decoration: BoxDecoration(

              color: Theme.of(context)

                  .colorScheme

                  .surfaceContainerHighest

                  .withValues(alpha: 0.45),

              borderRadius: BorderRadius.circular(22),

            ),

            child: Column(

              children: [

                Container(

                  padding: const EdgeInsets.all(13),

                  decoration: BoxDecoration(

                    color: Colors.green

                        .withValues(alpha: 0.12),

                    shape: BoxShape.circle,

                  ),

                  child: const Icon(

                    Icons.check_circle_rounded,

                    size: 46,

                    color: Colors.green,

                  ),

                ),

                const SizedBox(height: 13),

                const Text(

                  'Payment Received',

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    fontSize: 23,

                    fontWeight: FontWeight.w800,

                  ),

                ),

                const SizedBox(height: 6),

                Text(

                  _formatDate(date),

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    color: Theme.of(context)

                        .colorScheme

                        .onSurfaceVariant,

                    fontSize: 13,

                  ),

                ),

              ],

            ),

          ),



          const SizedBox(height: 14),



          // Amount

          Container(

            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(

              gradient: LinearGradient(

                begin: Alignment.topLeft,

                end: Alignment.bottomRight,

                colors: [

                  Theme.of(context)

                      .colorScheme

                      .primaryContainer,

                  Theme.of(context)

                      .colorScheme

                      .primaryContainer

                      .withValues(alpha: 0.65),

                ],

              ),

              borderRadius: BorderRadius.circular(22),

            ),

            child: Column(

              children: [

                Text(

                  'Amount Received',

                  style: TextStyle(

                    color: Theme.of(context)

                        .colorScheme

                        .onPrimaryContainer,

                    fontWeight: FontWeight.w600,

                  ),

                ),

                const SizedBox(height: 6),

                Text(

                  '₹${amountReceived.toStringAsFixed(2)}',

                  style: TextStyle(

                    color: Theme.of(context)

                        .colorScheme

                        .onPrimaryContainer,

                    fontSize: 34,

                    fontWeight: FontWeight.w800,

                    letterSpacing: -0.8,

                  ),

                ),

              ],

            ),

          ),



          const SizedBox(height: 16),



          _InfoCard(

            icon: Icons.storefront_outlined,

            title: 'Customer',

            children: [

              _InfoRow(

                label: 'Business',

                value: customerName,

              ),

              if (location.isNotEmpty)

                _InfoRow(

                  label: 'Location',

                  value: location,

                ),

              if (phone.isNotEmpty)

                _InfoRow(

                  label: 'Phone',

                  value: phone,

                ),

            ],

          ),



          const SizedBox(height: 12),



          _InfoCard(

            icon: Icons.account_balance_wallet_outlined,

            title: 'Payment Information',

            children: [

              _InfoRow(

                label: 'Received by',

                value: receiverName,

              ),

              _InfoRow(

                label: 'Balance before',

                value:

                    '₹${previousBalance.toStringAsFixed(2)}',

              ),

              _InfoRow(

                label: 'Settlement',

                value:

                    '₹${settlementAmount.toStringAsFixed(2)}',

              ),

              if (discount > 0)

                _InfoRow(

                  label: 'Discount',

                  value:

                      '₹${discount.toStringAsFixed(2)}',

                ),

              _InfoRow(

                label: 'Amount received',

                value:

                    '₹${amountReceived.toStringAsFixed(2)}',

              ),

              _InfoRow(

                label: 'Balance after',

                value:

                    '₹${remainingBalance.toStringAsFixed(2)}',

                valueColor: remainingBalance == 0

                    ? Colors.green.shade700

                    : null,

              ),

            ],

          ),



          if (notes.trim().isNotEmpty) ...[

            const SizedBox(height: 12),

            _InfoCard(

              icon: Icons.notes_rounded,

              title: 'Payment Note',

              children: [

                Text(

                  notes,

                  style: const TextStyle(

                    height: 1.45,

                  ),

                ),

              ],

            ),

          ],



          if (hasSignaturePath) ...[

            const SizedBox(height: 12),

            _InfoCard(

              icon: Icons.draw_outlined,

              title: 'Customer Signature',

              children: [

                const SizedBox(height: 2),

                if (_isLoadingSignature)

                  const Padding(

                    padding: EdgeInsets.all(28),

                    child: Center(

                      child: CircularProgressIndicator(),

                    ),

                  ),



                if (!_isLoadingSignature &&

                    _signature != null)

                  Container(

                    width: double.infinity,

                    height: 220,

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius:

                          BorderRadius.circular(14),

                      border: Border.all(

                        color: Theme.of(context)

                            .colorScheme

                            .outlineVariant,

                      ),

                    ),

                    child: Image.memory(

                      _signature!,

                      fit: BoxFit.contain,

                    ),

                  ),



                if (!_isLoadingSignature &&

                    _signature == null &&

                    _signatureAttempted)

                  Container(

                    width: double.infinity,

                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(

                      color: Theme.of(context)

                          .colorScheme

                          .surfaceContainerHighest,

                      borderRadius:

                          BorderRadius.circular(14),

                    ),

                    child: Column(

                      children: [

                        Icon(

                          Icons

                              .image_not_supported_outlined,

                          color: Theme.of(context)

                              .colorScheme

                              .onSurfaceVariant,

                        ),

                        const SizedBox(height: 8),

                        const Text(

                          'Signature could not be loaded.',

                        ),

                      ],

                    ),

                  ),

              ],

            ),

          ],

        ],

      ),

    );

  }

}



// ============================================================

// INFO CARD

// ============================================================



class _InfoCard extends StatelessWidget {

  final IconData icon;

  final String title;

  final List<Widget> children;



  const _InfoCard({

    required this.icon,

    required this.title,

    required this.children,

  });



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(

          color: Theme.of(context)

              .colorScheme

              .outlineVariant

              .withValues(alpha: 0.5),

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                padding: const EdgeInsets.all(8),

                decoration: BoxDecoration(

                  color: Theme.of(context)

                      .colorScheme

                      .primaryContainer,

                  borderRadius:

                      BorderRadius.circular(10),

                ),

                child: Icon(

                  icon,

                  size: 19,

                  color: Theme.of(context)

                      .colorScheme

                      .onPrimaryContainer,

                ),

              ),

              const SizedBox(width: 10),

              Text(

                title,

                style: const TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.w800,

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          ...children,

        ],

      ),

    );

  }

}



// ============================================================

// INFO ROW

// ============================================================



class _InfoRow extends StatelessWidget {

  final String label;

  final String value;

  final Color? valueColor;



  const _InfoRow({

    required this.label,

    required this.value,

    this.valueColor,

  });



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.only(

        bottom: 11,

      ),

      child: Row(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          SizedBox(

            width: 112,

            child: Text(

              label,

              style: TextStyle(

                color: Theme.of(context)

                    .colorScheme

                    .onSurfaceVariant,

                fontSize: 13,

              ),

            ),

          ),

          Expanded(

            child: Text(

              value,

              style: TextStyle(

                fontWeight: FontWeight.w600,

                color: valueColor,

              ),

            ),

          ),

        ],

      ),

    );

  }

}


