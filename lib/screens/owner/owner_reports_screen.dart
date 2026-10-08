import 'dart:math' as math;



import 'package:flutter/material.dart';



import '../../models/transaction.dart';

import '../../services/customer_service.dart';

import '../../services/transaction_service.dart';



class OwnerReportsScreen extends StatelessWidget {

  const OwnerReportsScreen({super.key});



  @override

  Widget build(BuildContext context) {

    return ValueListenableBuilder<int>(

      valueListenable: CustomerService.dataVersion,

      builder: (context, customerVersion, _) {

        return ValueListenableBuilder<int>(

          valueListenable: TransactionService.dataVersion,

          builder: (context, transactionVersion, _) {

            return _ReportsContent(

              key: ValueKey(

                '${customerVersion}_$transactionVersion',

              ),

            );

          },

        );

      },

    );

  }

}



class _ReportsContent extends StatefulWidget {

  const _ReportsContent({super.key});



  @override

  State<_ReportsContent> createState() => _ReportsContentState();

}



class _ReportsContentState extends State<_ReportsContent> {

  String _selectedPeriod = '7 Days';

  bool _loading = false;



  @override

  Widget build(BuildContext context) {

    final transactions = List<PaymentTransaction>.from(

      TransactionService.transactions,

    );



    final customers = CustomerService.customers;



    final chartData = _buildChartData(

      transactions,

      _selectedPeriod,

    );



    final totalCollected = _getTotalCollected(transactions);

    final totalPayments = transactions.length;



    final averagePayment = totalPayments == 0

        ? 0.0

        : totalCollected / totalPayments;



    final outstanding = customers.fold<double>(

      0.0,

      (sum, customer) {

        return sum +

            TransactionService.getCustomerBalance(

              customer.id,

            );

      },

    );



    final todayCollected = TransactionService.getCollectedToday();



    final todayPayments = TransactionService.getPaymentsToday();



    final topCustomers = _getTopCustomers(

      transactions,

    );



    final outstandingCustomers = customers

        .where(

          (customer) =>

              TransactionService.getCustomerBalance(

                customer.id,

              ) >

              0,

        )

        .toList();



    outstandingCustomers.sort(

      (a, b) {

        final balanceA =

            TransactionService.getCustomerBalance(a.id);

        final balanceB =

            TransactionService.getCustomerBalance(b.id);



        return balanceB.compareTo(balanceA);

      },

    );



    return Scaffold(

      backgroundColor: const Color(0xFFF5F8F7),

      body: SafeArea(

        child: RefreshIndicator(

          onRefresh: _refreshData,

          child: ListView(

            padding: const EdgeInsets.fromLTRB(

              24,

              24,

              24,

              40,

            ),

            children: [

              _buildHeader(context),

              const SizedBox(height: 24),



              _buildSummaryCards(

                totalCollected: totalCollected,

                totalPayments: totalPayments,

                averagePayment: averagePayment,

                outstanding: outstanding,

              ),



              const SizedBox(height: 28),



              _buildCollectionChart(

                chartData,

              ),



              const SizedBox(height: 24),



              _buildTodayCard(

                todayCollected,

                todayPayments,

              ),



              const SizedBox(height: 24),



              _buildPaymentActivity(

                transactions,

              ),



              const SizedBox(height: 24),



              _buildTopCustomers(

                topCustomers,

              ),



              const SizedBox(height: 24),



              _buildOutstandingCustomers(

                outstandingCustomers,

              ),



              const SizedBox(height: 24),



              _buildRecentPayments(

                transactions,

              ),

            ],

          ),

        ),

      ),

    );

  }



  Widget _buildHeader(BuildContext context) {

    return Row(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Expanded(

          child: Column(

            crossAxisAlignment:

                CrossAxisAlignment.start,

            children: [

              const Text(

                'Business Reports',

                style: TextStyle(

                  fontSize: 30,

                  fontWeight: FontWeight.w800,

                  color: Color(0xFF102A26),

                ),

              ),

              const SizedBox(height: 6),

              Text(

                'Track collections, payments and outstanding balances.',

                style: TextStyle(

                  fontSize: 14,

                  color: Colors.grey.shade600,

                ),

              ),

            ],

          ),

        ),

        IconButton(

          tooltip: 'Refresh',

          onPressed: _refreshData,

          icon: const Icon(

            Icons.refresh_rounded,

            color: Color(0xFF087F6A),

          ),

        ),

      ],

    );

  }



  Widget _buildSummaryCards({

    required double totalCollected,

    required int totalPayments,

    required double averagePayment,

    required double outstanding,

  }) {

    return LayoutBuilder(

      builder: (context, constraints) {

        final isWide = constraints.maxWidth > 850;



        final cards = [

          _SummaryCard(

            title: 'Total Collected',

            value: _formatMoney(totalCollected),

            icon: Icons.account_balance_wallet_rounded,

            iconColor: const Color(0xFF087F6A),

            backgroundColor: const Color(0xFFE4F5F0),

          ),

          _SummaryCard(

            title: 'Total Payments',

            value: totalPayments.toString(),

            icon: Icons.receipt_long_rounded,

            iconColor: const Color(0xFF0F766E),

            backgroundColor: const Color(0xFFE4F5F0),

          ),

          _SummaryCard(

            title: 'Average Payment',

            value: _formatMoney(averagePayment),

            icon: Icons.payments_rounded,

            iconColor: const Color(0xFF0F766E),

            backgroundColor: const Color(0xFFE4F5F0),

          ),

          _SummaryCard(

            title: 'Outstanding',

            value: _formatMoney(outstanding),

            icon: Icons.pending_actions_rounded,

            iconColor: const Color(0xFFEA580C),

            backgroundColor: const Color(0xFFFFEEE4),

          ),

        ];



        if (isWide) {

          return Row(

            children: [

              Expanded(child: cards[0]),

              const SizedBox(width: 14),

              Expanded(child: cards[1]),

              const SizedBox(width: 14),

              Expanded(child: cards[2]),

              const SizedBox(width: 14),

              Expanded(child: cards[3]),

            ],

          );

        }



        return GridView.builder(

          shrinkWrap: true,

          physics:

              const NeverScrollableScrollPhysics(),

          itemCount: cards.length,

          gridDelegate:

              const SliverGridDelegateWithFixedCrossAxisCount(

            crossAxisCount: 2,

            crossAxisSpacing: 14,

            mainAxisSpacing: 14,

            childAspectRatio: 1.8,

          ),

          itemBuilder: (context, index) {

            return cards[index];

          },

        );

      },

    );

  }



  Widget _buildCollectionChart(

    List<_ChartPoint> points,

  ) {

    final total = points.fold<double>(

      0,

      (sum, point) => sum + point.value,

    );



    return Container(

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(

          color: const Color(0xFFE3EBE8),

        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.035),

            blurRadius: 18,

            offset: const Offset(0, 7),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            crossAxisAlignment:

                CrossAxisAlignment.start,

            children: [

              Expanded(

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,

                  children: [

                    const Text(

                      'Collection Overview',

                      style: TextStyle(

                        fontSize: 20,

                        fontWeight: FontWeight.w800,

                        color: Color(0xFF102A26),

                      ),

                    ),

                    const SizedBox(height: 5),

                    Text(

                      'Payment collections over time',

                      style: TextStyle(

                        fontSize: 13,

                        color: Colors.grey.shade600,

                      ),

                    ),

                  ],

                ),

              ),

              Container(

                padding: const EdgeInsets.symmetric(

                  horizontal: 5,

                  vertical: 5,

                ),

                decoration: BoxDecoration(

                  color: const Color(0xFFF0F5F3),

                  borderRadius:

                      BorderRadius.circular(12),

                ),

                child: Row(

                  children: [

                    _periodButton('7 Days'),

                    _periodButton('30 Days'),

                    _periodButton('12 Months'),

                  ],

                ),

              ),

            ],

          ),



          const SizedBox(height: 22),



          Row(

            children: [

              Container(

                width: 42,

                height: 42,

                decoration: BoxDecoration(

                  color: const Color(0xFFE4F5F0),

                  borderRadius:

                      BorderRadius.circular(12),

                ),

                child: const Icon(

                  Icons.trending_up_rounded,

                  color: Color(0xFF087F6A),

                ),

              ),

              const SizedBox(width: 12),

              Column(

                crossAxisAlignment:

                    CrossAxisAlignment.start,

                children: [

                  Text(

                    _formatMoney(total),

                    style: const TextStyle(

                      fontSize: 21,

                      fontWeight: FontWeight.w800,

                      color: Color(0xFF102A26),

                    ),

                  ),

                  Text(

                    'Collected in $_selectedPeriod',

                    style: TextStyle(

                      fontSize: 12,

                      color: Colors.grey.shade600,

                    ),

                  ),

                ],

              ),

            ],

          ),



          const SizedBox(height: 20),



          SizedBox(

            height: 280,

            width: double.infinity,

            child: points.isEmpty

                ? _buildEmptyChart()

                : CustomPaint(

                    painter: _CollectionChartPainter(

                      points: points,

                    ),

                  ),

          ),

        ],

      ),

    );

  }



  Widget _periodButton(String period) {

    final selected =

        _selectedPeriod == period;



    return GestureDetector(

      onTap: () {

        setState(() {

          _selectedPeriod = period;

        });

      },

      child: AnimatedContainer(

        duration:

            const Duration(milliseconds: 180),

        padding: const EdgeInsets.symmetric(

          horizontal: 12,

          vertical: 8,

        ),

        decoration: BoxDecoration(

          color: selected

              ? const Color(0xFF087F6A)

              : Colors.transparent,

          borderRadius:

              BorderRadius.circular(9),

        ),

        child: Text(

          period,

          style: TextStyle(

            fontSize: 12,

            fontWeight: FontWeight.w700,

            color: selected

                ? Colors.white

                : const Color(0xFF55706A),

          ),

        ),

      ),

    );

  }



  Widget _buildEmptyChart() {

    return Center(

      child: Column(

        mainAxisAlignment:

            MainAxisAlignment.center,

        children: [

          Icon(

            Icons.show_chart_rounded,

            size: 48,

            color: Colors.grey.shade300,

          ),

          const SizedBox(height: 10),

          Text(

            'No payment data for this period',

            style: TextStyle(

              color: Colors.grey.shade500,

              fontWeight: FontWeight.w600,

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildTodayCard(

    double amount,

    int payments,

  ) {

    return Container(

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(

        gradient: const LinearGradient(

          colors: [

            Color(0xFF087F6A),

            Color(0xFF0B927A),

          ],

        ),

        borderRadius: BorderRadius.circular(20),

        boxShadow: [

          BoxShadow(

            color: const Color(0xFF087F6A)

                .withValues(alpha: 0.20),

            blurRadius: 20,

            offset: const Offset(0, 8),

          ),

        ],

      ),

      child: Row(

        children: [

          Container(

            width: 52,

            height: 52,

            decoration: BoxDecoration(

              color: Colors.white

                  .withValues(alpha: 0.16),

              borderRadius:

                  BorderRadius.circular(15),

            ),

            child: const Icon(

              Icons.today_rounded,

              color: Colors.white,

              size: 28,

            ),

          ),

          const SizedBox(width: 16),

          Expanded(

            child: Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,

              children: [

                const Text(

                  "Today's Collection",

                  style: TextStyle(

                    color: Colors.white,

                    fontSize: 14,

                    fontWeight: FontWeight.w600,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  _formatMoney(amount),

                  style: const TextStyle(

                    color: Colors.white,

                    fontSize: 25,

                    fontWeight: FontWeight.w800,

                  ),

                ),

              ],

            ),

          ),

          Container(

            padding: const EdgeInsets.symmetric(

              horizontal: 15,

              vertical: 10,

            ),

            decoration: BoxDecoration(

              color: Colors.white

                  .withValues(alpha: 0.13),

              borderRadius:

                  BorderRadius.circular(12),

            ),

            child: Column(

              children: [

                Text(

                  payments.toString(),

                  style: const TextStyle(

                    color: Colors.white,

                    fontSize: 18,

                    fontWeight: FontWeight.w800,

                  ),

                ),

                const Text(

                  'Payments',

                  style: TextStyle(

                    color: Colors.white70,

                    fontSize: 11,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildPaymentActivity(

    List<PaymentTransaction> transactions,

  ) {

    final now = DateTime.now();



    final today = transactions.where(

      (transaction) =>

          transaction.transactionDate.year ==

              now.year &&

          transaction.transactionDate.month ==

              now.month &&

          transaction.transactionDate.day ==

              now.day,

    );



    final yesterdayDate =

        now.subtract(const Duration(days: 1));



    final yesterday = transactions.where(

      (transaction) =>

          transaction.transactionDate.year ==

              yesterdayDate.year &&

          transaction.transactionDate.month ==

              yesterdayDate.month &&

          transaction.transactionDate.day ==

              yesterdayDate.day,

    );



    final todayAmount = today.fold<double>(

      0,

      (sum, transaction) =>

          sum + transaction.amountReceived,

    );



    final yesterdayAmount =

        yesterday.fold<double>(

      0,

      (sum, transaction) =>

          sum + transaction.amountReceived,

    );



    final change = yesterdayAmount == 0

        ? null

        : ((todayAmount - yesterdayAmount) /

                yesterdayAmount) *

            100;



    return _sectionCard(

      title: 'Payment Activity',

      subtitle:

          'Today compared with yesterday',

      child: Row(

        children: [

          Expanded(

            child: _activityItem(

              'Today',

              _formatMoney(todayAmount),

              '${today.length} payments',

              Icons.today_rounded,

            ),

          ),

          Container(

            width: 1,

            height: 65,

            color: const Color(0xFFE5ECE9),

          ),

          Expanded(

            child: _activityItem(

              'Yesterday',

              _formatMoney(yesterdayAmount),

              '${yesterday.length} payments',

              Icons.history_rounded,

            ),

          ),

          Container(

            width: 1,

            height: 65,

            color: const Color(0xFFE5ECE9),

          ),

          Expanded(

            child: _activityItem(

              'Change',

              change == null

                  ? '—'

                  : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',

              'vs yesterday',

              change == null

                  ? Icons.remove_rounded

                  : change >= 0

                      ? Icons.trending_up_rounded

                      : Icons.trending_down_rounded,

            ),

          ),

        ],

      ),

    );

  }



  Widget _activityItem(

    String title,

    String value,

    String subtitle,

    IconData icon,

  ) {

    return Padding(

      padding: const EdgeInsets.symmetric(

        horizontal: 16,

      ),

      child: Column(

        children: [

          Icon(

            icon,

            color: const Color(0xFF087F6A),

            size: 23,

          ),

          const SizedBox(height: 8),

          Text(

            value,

            style: const TextStyle(

              fontSize: 18,

              fontWeight: FontWeight.w800,

              color: Color(0xFF102A26),

            ),

          ),

          const SizedBox(height: 3),

          Text(

            subtitle,

            style: TextStyle(

              fontSize: 11,

              color: Colors.grey.shade500,

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildTopCustomers(

    List<_CustomerPaymentSummary> customers,

  ) {

    return _sectionCard(

      title: 'Top Customers',

      subtitle:

          'Customers who have made the highest payments',

      child: customers.isEmpty

          ? _emptyMessage(

              'No payment data available yet.',

            )

          : Column(

              children: customers

                  .take(5)

                  .toList()

                  .asMap()

                  .entries

                  .map(

                    (entry) => _customerRankTile(

                      rank: entry.key + 1,

                      customer: entry.value,

                    ),

                  )

                  .toList(),

            ),

    );

  }



  Widget _customerRankTile({

    required int rank,

    required _CustomerPaymentSummary customer,

  }) {

    return Padding(

      padding: const EdgeInsets.symmetric(

        vertical: 8,

      ),

      child: Row(

        children: [

          Container(

            width: 34,

            height: 34,

            alignment: Alignment.center,

            decoration: BoxDecoration(

              color: rank == 1

                  ? const Color(0xFFE4F5F0)

                  : const Color(0xFFF3F6F5),

              borderRadius:

                  BorderRadius.circular(10),

            ),

            child: Text(

              '$rank',

              style: TextStyle(

                fontWeight: FontWeight.w800,

                color: rank == 1

                    ? const Color(0xFF087F6A)

                    : const Color(0xFF60736E),

              ),

            ),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Text(

              customer.name,

              style: const TextStyle(

                fontSize: 14,

                fontWeight: FontWeight.w700,

                color: Color(0xFF213C36),

              ),

              overflow: TextOverflow.ellipsis,

            ),

          ),

          Column(

            crossAxisAlignment:

                CrossAxisAlignment.end,

            children: [

              Text(

                _formatMoney(

                  customer.totalPaid,

                ),

                style: const TextStyle(

                  fontSize: 14,

                  fontWeight: FontWeight.w800,

                  color: Color(0xFF087F6A),

                ),

              ),

              Text(

                '${customer.paymentCount} payments',

                style: TextStyle(

                  fontSize: 10,

                  color: Colors.grey.shade500,

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }



  Widget _buildOutstandingCustomers(

    List<dynamic> customers,

  ) {

    return _sectionCard(

      title: 'Outstanding Customers',

      subtitle:

          'Customers with money still to be collected',

      child: customers.isEmpty

          ? _emptyMessage(

              'No outstanding balances.',

            )

          : Column(

              children: customers

                  .take(7)

                  .map(

                    (customer) {

                      final balance =

                          TransactionService

                              .getCustomerBalance(

                        customer.id,

                      );



                      return Padding(

                        padding:

                            const EdgeInsets.symmetric(

                          vertical: 9,

                        ),

                        child: Row(

                          children: [

                            Container(

                              width: 40,

                              height: 40,

                              decoration: BoxDecoration(

                                color:

                                    const Color(0xFFFFEEE4),

                                borderRadius:

                                    BorderRadius.circular(

                                  12,

                                ),

                              ),

                              child: const Icon(

                                Icons.storefront_rounded,

                                color:

                                    Color(0xFFEA580C),

                                size: 20,

                              ),

                            ),

                            const SizedBox(width: 12),

                            Expanded(

                              child: Text(

                                customer.businessName,

                                style:

                                    const TextStyle(

                                  fontWeight:

                                      FontWeight.w700,

                                  fontSize: 14,

                                  color:

                                      Color(0xFF213C36),

                                ),

                                overflow:

                                    TextOverflow.ellipsis,

                              ),

                            ),

                            Text(

                              _formatMoney(balance),

                              style:

                                  const TextStyle(

                                fontWeight:

                                    FontWeight.w800,

                                fontSize: 14,

                                color:

                                    Color(0xFFEA580C),

                              ),

                            ),

                          ],

                        ),

                      );

                    },

                  )

                  .toList(),

            ),

    );

  }



  Widget _buildRecentPayments(

    List<PaymentTransaction> transactions,

  ) {

    final recent =

        transactions.take(8).toList();



    return _sectionCard(

      title: 'Recent Payments',

      subtitle:

          'Latest payment transactions',

      child: recent.isEmpty

          ? _emptyMessage(

              'No payments recorded yet.',

            )

          : Column(

              children: recent

                  .map(

                    (transaction) =>

                        _recentPaymentTile(

                      transaction,

                    ),

                  )

                  .toList(),

            ),

    );

  }



  Widget _recentPaymentTile(

    PaymentTransaction transaction,

  ) {

    return Padding(

      padding: const EdgeInsets.symmetric(

        vertical: 9,

      ),

      child: Row(

        children: [

          Container(

            width: 42,

            height: 42,

            decoration: BoxDecoration(

              color: const Color(0xFFE4F5F0),

              borderRadius:

                  BorderRadius.circular(12),

            ),

            child: const Icon(

              Icons.arrow_downward_rounded,

              color: Color(0xFF087F6A),

            ),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,

              children: [

                Text(

                  transaction.customerName,

                  style: const TextStyle(

                    fontWeight: FontWeight.w700,

                    fontSize: 14,

                    color: Color(0xFF213C36),

                  ),

                  overflow:

                      TextOverflow.ellipsis,

                ),

                const SizedBox(height: 3),

                Text(

                  _formatDate(

                    transaction.transactionDate,

                  ),

                  style: TextStyle(

                    fontSize: 11,

                    color: Colors.grey.shade500,

                  ),

                ),

              ],

            ),

          ),

          Text(

            '+ ${_formatMoney(transaction.amountReceived)}',

            style: const TextStyle(

              fontSize: 14,

              fontWeight: FontWeight.w800,

              color: Color(0xFF087F6A),

            ),

          ),

        ],

      ),

    );

  }



  Widget _sectionCard({

    required String title,

    required String subtitle,

    required Widget child,

  }) {

    return Container(

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(

          color: const Color(0xFFE3EBE8),

        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.025),

            blurRadius: 16,

            offset: const Offset(0, 6),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Text(

            title,

            style: const TextStyle(

              fontSize: 19,

              fontWeight: FontWeight.w800,

              color: Color(0xFF102A26),

            ),

          ),

          const SizedBox(height: 4),

          Text(

            subtitle,

            style: TextStyle(

              fontSize: 12,

              color: Colors.grey.shade600,

            ),

          ),

          const SizedBox(height: 18),

          child,

        ],

      ),

    );

  }



  Widget _emptyMessage(String message) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.symmetric(

        vertical: 22,

      ),

      child: Center(

        child: Text(

          message,

          style: TextStyle(

            color: Colors.grey.shade500,

            fontSize: 13,

          ),

        ),

      ),

    );

  }



  Future<void> _refreshData() async {

    if (_loading) return;



    setState(() {

      _loading = true;

    });



    await CustomerService.loadCustomers();

    await TransactionService.loadTransactions();



    if (mounted) {

      setState(() {

        _loading = false;

      });

    }

  }



  List<_ChartPoint> _buildChartData(

    List<PaymentTransaction> transactions,

    String period,

  ) {

    final now = DateTime.now();



    if (period == '7 Days') {

      return List.generate(

        7,

        (index) {

          final date = DateTime(

            now.year,

            now.month,

            now.day,

          ).subtract(

            Duration(days: 6 - index),

          );



          final total = transactions

              .where(

                (transaction) =>

                    transaction.transactionDate

                        .year ==

                        date.year &&

                    transaction.transactionDate

                        .month ==

                        date.month &&

                    transaction.transactionDate

                        .day ==

                        date.day,

              )

              .fold<double>(

                0,

                (sum, transaction) =>

                    sum + transaction.amountReceived,

              );



          return _ChartPoint(

            label: _shortDate(date),

            value: total,

          );

        },

      );

    }



    if (period == '30 Days') {

      return List.generate(

        30,

        (index) {

          final date = DateTime(

            now.year,

            now.month,

            now.day,

          ).subtract(

            Duration(days: 29 - index),

          );



          final total = transactions

              .where(

                (transaction) =>

                    transaction.transactionDate

                        .year ==

                        date.year &&

                    transaction.transactionDate

                        .month ==

                        date.month &&

                    transaction.transactionDate

                        .day ==

                        date.day,

              )

              .fold<double>(

                0,

                (sum, transaction) =>

                    sum + transaction.amountReceived,

              );



          return _ChartPoint(

            label: _shortDate(date),

            value: total,

          );

        },

      );

    }



    return List.generate(

      12,

      (index) {

        final monthDate = DateTime(

          now.year,

          now.month - (11 - index),

          1,

        );



        final total = transactions

            .where(

              (transaction) =>

                  transaction.transactionDate.year ==

                      monthDate.year &&

                  transaction.transactionDate.month ==

                      monthDate.month,

            )

            .fold<double>(

              0,

              (sum, transaction) =>

                  sum + transaction.amountReceived,

            );



        return _ChartPoint(

          label: _shortMonth(monthDate),

          value: total,

        );

      },

    );

  }



  double _getTotalCollected(

    List<PaymentTransaction> transactions,

  ) {

    return transactions.fold<double>(

      0,

      (sum, transaction) =>

          sum + transaction.amountReceived,

    );

  }



  List<_CustomerPaymentSummary> _getTopCustomers(

    List<PaymentTransaction> transactions,

  ) {

    final Map<String, _CustomerPaymentSummary>

        summary = {};



    for (final transaction in transactions) {

      final existing =

          summary[transaction.customerId];



      if (existing == null) {

        summary[transaction.customerId] =

            _CustomerPaymentSummary(

          name: transaction.customerName,

          totalPaid: transaction.amountReceived,

          paymentCount: 1,

        );

      } else {

        summary[transaction.customerId] =

            _CustomerPaymentSummary(

          name: existing.name,

          totalPaid:

              existing.totalPaid +

                  transaction.amountReceived,

          paymentCount:

              existing.paymentCount + 1,

        );

      }

    }



    final result = summary.values.toList();



    result.sort(

      (a, b) => b.totalPaid.compareTo(

        a.totalPaid,

      ),

    );



    return result;

  }



  String _formatMoney(double amount) {

    return '₹${amount.toStringAsFixed(2)}';

  }



  String _shortDate(DateTime date) {

    const months = [

      'Jan',

      'Feb',

      'Mar',

      'Apr',

      'May',

      'Jun',

      'Jul',

      'Aug',

      'Sep',

      'Oct',

      'Nov',

      'Dec',

    ];



    return '${date.day} ${months[date.month - 1]}';

  }



  String _shortMonth(DateTime date) {

    const months = [

      'Jan',

      'Feb',

      'Mar',

      'Apr',

      'May',

      'Jun',

      'Jul',

      'Aug',

      'Sep',

      'Oct',

      'Nov',

      'Dec',

    ];



    return months[date.month - 1];

  }



  String _formatDate(DateTime date) {

    const months = [

      'Jan',

      'Feb',

      'Mar',

      'Apr',

      'May',

      'Jun',

      'Jul',

      'Aug',

      'Sep',

      'Oct',

      'Nov',

      'Dec',

    ];



    return '${date.day} ${months[date.month - 1]} ${date.year}';

  }

}



class _SummaryCard extends StatelessWidget {

  final String title;

  final String value;

  final IconData icon;

  final Color iconColor;

  final Color backgroundColor;



  const _SummaryCard({

    required this.title,

    required this.value,

    required this.icon,

    required this.iconColor,

    required this.backgroundColor,

  });



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(

          color: const Color(0xFFE3EBE8),

        ),

      ),

      child: Row(

        children: [

          Container(

            width: 46,

            height: 46,

            decoration: BoxDecoration(

              color: backgroundColor,

              borderRadius:

                  BorderRadius.circular(13),

            ),

            child: Icon(

              icon,

              color: iconColor,

              size: 22,

            ),

          ),

          const SizedBox(width: 13),

          Expanded(

            child: Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  style: TextStyle(

                    fontSize: 11,

                    color: Colors.grey.shade600,

                    fontWeight: FontWeight.w600,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  value,

                  style: const TextStyle(

                    fontSize: 18,

                    fontWeight: FontWeight.w800,

                    color: Color(0xFF102A26),

                  ),

                  overflow:

                      TextOverflow.ellipsis,

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}



class _ChartPoint {

  final String label;

  final double value;



  const _ChartPoint({

    required this.label,

    required this.value,

  });

}



class _CustomerPaymentSummary {

  final String name;

  final double totalPaid;

  final int paymentCount;



  const _CustomerPaymentSummary({

    required this.name,

    required this.totalPaid,

    required this.paymentCount,

  });

}



class _CollectionChartPainter

    extends CustomPainter {

  final List<_ChartPoint> points;



  _CollectionChartPainter({

    required this.points,

  });



  @override

  void paint(

    Canvas canvas,

    Size size,

  ) {

    if (points.isEmpty) return;



    const leftPadding = 58.0;

    const rightPadding = 16.0;

    const topPadding = 18.0;

    const bottomPadding = 38.0;



    final chartWidth =

        size.width -

        leftPadding -

        rightPadding;



    final chartHeight =

        size.height -

        topPadding -

        bottomPadding;



    final maxValue = points.fold<double>(

      0,

      (max, point) =>

          math.max(max, point.value),

    );



    final safeMax =

        maxValue <= 0 ? 100.0 : maxValue;



    final paintGrid = Paint()

      ..color = const Color(0xFFE8EFEC)

      ..strokeWidth = 1;



    final paintLine = Paint()

      ..color = const Color(0xFF087F6A)

      ..strokeWidth = 3

      ..style = PaintingStyle.stroke

      ..strokeCap = StrokeCap.round

      ..strokeJoin = StrokeJoin.round;



    final paintArea = Paint()

      ..color = const Color(0xFF087F6A)

          .withValues(alpha: 0.08)

      ..style = PaintingStyle.fill;



    final paintDot = Paint()

      ..color = const Color(0xFF087F6A)

      ..style = PaintingStyle.fill;



    final textStyle = const TextStyle(

      fontSize: 10,

      color: Color(0xFF758580),

      fontWeight: FontWeight.w500,

    );



    final ySteps = 4;



    for (int i = 0; i <= ySteps; i++) {

      final y =

          topPadding +

          chartHeight -

          (chartHeight * i / ySteps);



      canvas.drawLine(

        Offset(leftPadding, y),

        Offset(

          size.width - rightPadding,

          y,

        ),

        paintGrid,

      );



      final value =

          safeMax * i / ySteps;



      final label = value >= 1000

          ? '₹${(value / 1000).toStringAsFixed(1)}k'

          : '₹${value.toStringAsFixed(0)}';



      final textPainter = TextPainter(

        text: TextSpan(

          text: label,

          style: textStyle,

        ),

        textDirection:

            TextDirection.ltr,

      )..layout();



      textPainter.paint(

        canvas,

        Offset(

          leftPadding -

              textPainter.width -

              9,

          y -

              textPainter.height / 2,

        ),

      );

    }



    final path = Path();



    final areaPath = Path();



    for (int i = 0;

        i < points.length;

        i++) {

      final x = points.length == 1

          ? leftPadding +

              chartWidth / 2

          : leftPadding +

              chartWidth *

                  i /

                  (points.length - 1);



      final y =

          topPadding +

          chartHeight -

          (points[i].value /

                  safeMax) *

              chartHeight;



      if (i == 0) {

        path.moveTo(x, y);

        areaPath.moveTo(x, y);

      } else {

        path.lineTo(x, y);

        areaPath.lineTo(x, y);

      }

    }



    if (points.length > 1) {

      final lastX =

          leftPadding + chartWidth;



      areaPath.lineTo(

        lastX,

        topPadding + chartHeight,

      );



      areaPath.lineTo(

        leftPadding,

        topPadding + chartHeight,

      );



      areaPath.close();



      canvas.drawPath(

        areaPath,

        paintArea,

      );

    }



    canvas.drawPath(

      path,

      paintLine,

    );



    final labelEvery =

        points.length <= 7

            ? 1

            : points.length <= 12

                ? 2

                : 5;



    for (int i = 0;

        i < points.length;

        i += labelEvery) {

      final x = points.length == 1

          ? leftPadding +

              chartWidth / 2

          : leftPadding +

              chartWidth *

                  i /

                  (points.length - 1);



      final y =

          topPadding +

          chartHeight -

          (points[i].value /

                  safeMax) *

              chartHeight;



      canvas.drawCircle(

        Offset(x, y),

        4,

        paintDot,

      );



      final textPainter = TextPainter(

        text: TextSpan(

          text: points[i].label,

          style: textStyle,

        ),

        textDirection:

            TextDirection.ltr,

      )..layout();



      final labelX =

          x - textPainter.width / 2;



      textPainter.paint(

        canvas,

        Offset(

          labelX,

          size.height - 25,

        ),

      );

    }



    if (points.isNotEmpty) {

      final lastIndex =

          points.length - 1;



      final x = points.length == 1

          ? leftPadding +

              chartWidth / 2

          : leftPadding +

              chartWidth *

                  lastIndex /

                  (points.length - 1);



      final y =

          topPadding +

          chartHeight -

          (points[lastIndex].value /

                  safeMax) *

              chartHeight;



      canvas.drawCircle(

        Offset(x, y),

        6,

        Paint()

          ..color = Colors.white

          ..style = PaintingStyle.fill,

      );



      canvas.drawCircle(

        Offset(x, y),

        4,

        paintDot,

      );

    }

  }



  @override

  bool shouldRepaint(

    covariant _CollectionChartPainter oldDelegate,

  ) {

    return oldDelegate.points != points;

  }

}