import 'package:flutter/material.dart';



import '../customers/add_customer_screen.dart';

import '../../models/customer.dart';

import '../../services/customer_service.dart';

import '../../services/transaction_service.dart';



class OwnerDashboard extends StatefulWidget {

  const OwnerDashboard({

    super.key,

  });



  @override

  State<OwnerDashboard> createState() =>

      _OwnerDashboardState();

}



class _OwnerDashboardState

    extends State<OwnerDashboard> {

  @override

  void initState() {

    super.initState();



    TransactionService.dataVersion.addListener(

      _refresh,

    );



    CustomerService.dataVersion.addListener(

      _refresh,

    );

  }



  void _refresh() {

    if (mounted) {

      setState(() {});

    }

  }



  @override

  void dispose() {

    TransactionService.dataVersion.removeListener(

      _refresh,

    );



    CustomerService.dataVersion.removeListener(

      _refresh,

    );



    super.dispose();

  }



  Future<void> addCustomer() async {

    final newCustomer =

        await Navigator.push<Customer>(

      context,

      MaterialPageRoute(

        builder: (context) =>

            const AddCustomerScreen(),

      ),

    );



    if (newCustomer != null) {

      try {

        await CustomerService.addCustomer(

          businessName: newCustomer.businessName,

          location: newCustomer.location,

          phone: newCustomer.phone,

          openingBalance: newCustomer.openingBalance,

        );



        if (!mounted) return;



        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text(

              'Customer added successfully.',

            ),

          ),

        );

      } catch (error) {

        if (!mounted) return;



        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(

              'Could not add customer: $error',

            ),

          ),

        );

      }

    }

  }



  String _formatCurrency(

    double amount,

  ) {

    return '₹${amount.toStringAsFixed(2)}';

  }



  String _formatCompactCurrency(

    double amount,

  ) {

    if (amount >= 10000000) {

      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';

    }



    if (amount >= 100000) {

      return '₹${(amount / 100000).toStringAsFixed(1)}L';

    }



    if (amount >= 1000) {

      return '₹${(amount / 1000).toStringAsFixed(1)}K';

    }



    return '₹${amount.toStringAsFixed(0)}';

  }



  String _getGreeting() {

    final hour = DateTime.now().hour;



    if (hour < 12) {

      return 'Good morning';

    }



    if (hour < 17) {

      return 'Good afternoon';

    }



    return 'Good evening';

  }



  @override

  Widget build(

    BuildContext context,

  ) {

    final theme =

        Theme.of(context);



    final colors =

        theme.colorScheme;



    final isDark =

        theme.brightness ==

            Brightness.dark;



    final customers =

        CustomerService.customers;



    final customerCount =

        customers.length;



    final moneyToReceive =

        TransactionService

            .getTotalMoneyToReceive(

      customers,

    );



    final collectedToday =

        TransactionService

            .getCollectedToday();



    final paymentsToday =

        TransactionService

            .getPaymentsToday();



    final totalTransactions =

        TransactionService

            .transactions

            .length;



    return Scaffold(

      backgroundColor:

          colors.surfaceContainerLowest,

      body: SafeArea(

        child: RefreshIndicator(

          color: colors.primary,

          backgroundColor:

              colors.surface,

          onRefresh: () async {

            await CustomerService

                .loadCustomers();



            await TransactionService

                .loadTransactions();

          },

          child:

              SingleChildScrollView(

            physics:

                const AlwaysScrollableScrollPhysics(),

            padding:

                const EdgeInsets.fromLTRB(

              20,

              20,

              20,

              36,

            ),

            child: Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,

              children: [

                // ==================================================

                // HEADER

                // ==================================================



                Row(

                  children: [

                    Expanded(

                      child: Column(

                        crossAxisAlignment:

                            CrossAxisAlignment.start,

                        children: [

                          Text(

                            _getGreeting(),

                            style: TextStyle(

                              fontSize: 13,

                              fontWeight:

                                  FontWeight.w600,

                              color: colors

                                  .onSurfaceVariant,

                            ),

                          ),

                          const SizedBox(

                            height: 5,

                          ),

                          Text(

                            'Owner Dashboard',

                            style: TextStyle(

                              fontSize: 27,

                              fontWeight:

                                  FontWeight.w800,

                              letterSpacing:

                                  -0.7,

                              color: colors

                                  .onSurface,

                            ),

                          ),

                          const SizedBox(

                            height: 4,

                          ),

                          Text(

                            'Your business at a glance.',

                            style: TextStyle(

                              fontSize: 13,

                              color: colors

                                  .onSurfaceVariant,

                            ),

                          ),

                        ],

                      ),

                    ),



                    // Profile-style business icon

                    Container(

                      width: 46,

                      height: 46,

                      decoration:

                          BoxDecoration(

                        color: colors

                            .primaryContainer,

                        borderRadius:

                            BorderRadius

                                .circular(

                          14,

                        ),

                      ),

                      child: Icon(

                        Icons

                            .storefront_rounded,

                        color: colors

                            .onPrimaryContainer,

                        size: 22,

                      ),

                    ),

                  ],

                ),



                const SizedBox(

                  height: 24,

                ),



                // ==================================================

                // OUTSTANDING BALANCE CARD

                // ==================================================



                Container(

                  width:

                      double.infinity,

                  padding:

                      const EdgeInsets.all(

                    22,

                  ),

                  decoration:

                      BoxDecoration(

                    gradient:

                        LinearGradient(

                      begin:

                          Alignment.topLeft,

                      end:

                          Alignment.bottomRight,

                      colors: [

                        colors.primary,

                        isDark

                            ? const Color(

                                0xFF0F766E,

                              )

                            : const Color(

                                0xFF115E59,

                              ),

                      ],

                    ),

                    borderRadius:

                        BorderRadius.circular(

                      22,

                    ),

                    boxShadow: [

                      BoxShadow(

                        color: colors

                            .primary

                            .withValues(alpha: 

                          isDark

                              ? 0.16

                              : 0.18,

                        ),

                        blurRadius: 24,

                        offset:

                            const Offset(

                          0,

                          10,

                        ),

                      ),

                    ],

                  ),

                  child: Column(

                    crossAxisAlignment:

                        CrossAxisAlignment

                            .start,

                    children: [

                      Row(

                        children: [

                          Container(

                            width: 42,

                            height: 42,

                            decoration:

                                BoxDecoration(

                              color: Colors

                                  .white

                                  .withValues(alpha: 

                                0.14,

                              ),

                              borderRadius:

                                  BorderRadius

                                      .circular(

                                12,

                              ),

                            ),

                            child:

                                const Icon(

                              Icons

                                  .account_balance_wallet_outlined,

                              color:

                                  Colors.white,

                              size: 21,

                            ),

                          ),

                          const SizedBox(

                            width: 12,

                          ),

                          const Expanded(

                            child: Column(

                              crossAxisAlignment:

                                  CrossAxisAlignment

                                      .start,

                              children: [

                                Text(

                                  'Total Outstanding',

                                  style:

                                      TextStyle(

                                    color:

                                        Colors.white,

                                    fontSize: 14,

                                    fontWeight:

                                        FontWeight.w600,

                                  ),

                                ),

                                SizedBox(

                                  height: 2,

                                ),

                                Text(

                                  'Amount to be collected',

                                  style:

                                      TextStyle(

                                    color:

                                        Color(

                                      0xBFFFFFFF,

                                    ),

                                    fontSize: 11,

                                  ),

                                ),

                              ],

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(

                        height: 22,

                      ),

                      Text(

                        _formatCurrency(

                          moneyToReceive,

                        ),

                        style:

                            const TextStyle(

                          color:

                              Colors.white,

                          fontSize: 34,

                          fontWeight:

                              FontWeight.w800,

                          letterSpacing:

                              -1.1,

                        ),

                      ),

                      const SizedBox(

                        height: 16,

                      ),

                      Container(

                        height: 1,

                        color: Colors

                            .white

                            .withValues(alpha: 

                          0.14,

                        ),

                      ),

                      const SizedBox(

                        height: 14,

                      ),

                      Row(

                        children: [

                          Icon(

                            Icons

                                .people_outline_rounded,

                            size: 16,

                            color: Colors

                                .white

                                .withValues(alpha: 

                              0.85,

                            ),

                          ),

                          const SizedBox(

                            width: 7,

                          ),

                          Text(

                            '$customerCount ${customerCount == 1 ? 'customer' : 'customers'}',

                            style:

                                TextStyle(

                              color: Colors

                                  .white

                                  .withValues(alpha: 

                                0.88,

                              ),

                              fontSize: 12,

                              fontWeight:

                                  FontWeight.w600,

                            ),

                          ),

                        ],

                      ),

                    ],

                  ),

                ),



                const SizedBox(

                  height: 18,

                ),



                // ==================================================

                // KPI SECTION

                // ==================================================



                Row(

                  children: [

                    Expanded(

                      child:

                          _MetricCard(

                        icon: Icons

                            .payments_outlined,

                        title:

                            'Collected Today',

                        value:

                            _formatCompactCurrency(

                          collectedToday,

                        ),

                        colors:

                            colors,

                      ),

                    ),

                    const SizedBox(

                      width: 12,

                    ),

                    Expanded(

                      child:

                          _MetricCard(

                        icon: Icons

                            .receipt_long_outlined,

                        title:

                            'Payments Today',

                        value:

                            '$paymentsToday',

                        colors:

                            colors,

                      ),

                    ),

                  ],

                ),



                const SizedBox(

                  height: 12,

                ),



                Row(

                  children: [

                    Expanded(

                      child:

                          _MetricCard(

                        icon: Icons

                            .people_outline_rounded,

                        title:

                            'Customers',

                        value:

                            '$customerCount',

                        colors:

                            colors,

                      ),

                    ),

                    const SizedBox(

                      width: 12,

                    ),

                    Expanded(

                      child:

                          _MetricCard(

                        icon: Icons

                            .history_rounded,

                        title:

                            'Transactions',

                        value:

                            '$totalTransactions',

                        colors:

                            colors,

                      ),

                    ),

                  ],

                ),



                const SizedBox(

                  height: 30,

                ),



                // ==================================================

                // QUICK ACTION

                // ==================================================



                _SectionTitle(

                  title: 'Quick Action',

                  colors: colors,

                ),



                const SizedBox(

                  height: 12,

                ),



                Material(

                  color:

                      colors.surface,

                  borderRadius:

                      BorderRadius.circular(

                    18,

                  ),

                  child: InkWell(

                    onTap:

                        addCustomer,

                    borderRadius:

                        BorderRadius.circular(

                      18,

                    ),

                    child:

                        Container(

                      padding:

                          const EdgeInsets.all(

                        17,

                      ),

                      decoration:

                          BoxDecoration(

                        borderRadius:

                            BorderRadius

                                .circular(

                          18,

                        ),

                        border:

                            Border.all(

                          color: colors

                              .outlineVariant,

                        ),

                      ),

                      child: Row(

                        children: [

                          Container(

                            width: 48,

                            height: 48,

                            decoration:

                                BoxDecoration(

                              color: colors

                                  .primaryContainer,

                              borderRadius:

                                  BorderRadius

                                      .circular(

                                13,

                              ),

                            ),

                            child:

                                Icon(

                              Icons

                                  .person_add_alt_1_rounded,

                              color: colors

                                  .onPrimaryContainer,

                              size: 21,

                            ),

                          ),

                          const SizedBox(

                            width: 13,

                          ),

                          Expanded(

                            child:

                                Column(

                              crossAxisAlignment:

                                  CrossAxisAlignment

                                      .start,

                              children: [

                                Text(

                                  'Add Customer',

                                  style:

                                      TextStyle(

                                    color:

                                        colors.onSurface,

                                    fontSize:

                                        14,

                                    fontWeight:

                                        FontWeight.w700,

                                  ),

                                ),

                                const SizedBox(

                                  height: 3,

                                ),

                                Text(

                                  'Create a new customer account',

                                  style:

                                      TextStyle(

                                    color:

                                        colors.onSurfaceVariant,

                                    fontSize:

                                        12,

                                  ),

                                ),

                              ],

                            ),

                          ),

                          Icon(

                            Icons

                                .arrow_forward_ios_rounded,

                            size: 15,

                            color: colors

                                .onSurfaceVariant,

                          ),

                        ],

                      ),

                    ),

                  ),

                ),



                const SizedBox(

                  height: 30,

                ),



                // ==================================================

                // BUSINESS OVERVIEW

                // ==================================================



                _SectionTitle(

                  title:

                      'Business Overview',

                  colors: colors,

                ),



                const SizedBox(

                  height: 12,

                ),



                Container(

                  width:

                      double.infinity,

                  padding:

                      const EdgeInsets.all(

                    19,

                  ),

                  decoration:

                      BoxDecoration(

                    color:

                        colors.surface,

                    borderRadius:

                        BorderRadius.circular(

                      18,

                    ),

                    border:

                        Border.all(

                      color: colors

                          .outlineVariant,

                    ),

                  ),

                  child: Column(

                    children: [

                      _OverviewRow(

                        icon: Icons

                            .account_balance_wallet_outlined,

                        title:

                            'Outstanding balance',

                        value:

                            _formatCurrency(

                          moneyToReceive,

                        ),

                        valueColor:

                            moneyToReceive >

                                    0

                                ? colors

                                    .error

                                : colors

                                    .primary,

                        colors:

                            colors,

                      ),

                      _OverviewDivider(

                        colors:

                            colors,

                      ),

                      _OverviewRow(

                        icon: Icons

                            .payments_outlined,

                        title:

                            'Collected today',

                        value:

                            _formatCurrency(

                          collectedToday,

                        ),

                        valueColor:

                            colors.primary,

                        colors:

                            colors,

                      ),

                      _OverviewDivider(

                        colors:

                            colors,

                      ),

                      _OverviewRow(

                        icon: Icons

                            .storefront_outlined,

                        title:

                            'Registered customers',

                        value:

                            '$customerCount',

                        colors:

                            colors,

                      ),

                      _OverviewDivider(

                        colors:

                            colors,

                      ),

                      _OverviewRow(

                        icon: Icons

                            .receipt_long_outlined,

                        title:

                            'Payments today',

                        value:

                            '$paymentsToday',

                        colors:

                            colors,

                      ),

                    ],

                  ),

                ),



                const SizedBox(

                  height: 30,

                ),



                // ==================================================

                // TODAY'S COLLECTION

                // ==================================================



                _SectionTitle(

                  title:

                      "Today's Collection",

                  colors: colors,

                ),



                const SizedBox(

                  height: 12,

                ),



                Container(

                  width:

                      double.infinity,

                  padding:

                      const EdgeInsets.all(

                    19,

                  ),

                  decoration:

                      BoxDecoration(

                    color:

                        colors.surface,

                    borderRadius:

                        BorderRadius.circular(

                      18,

                    ),

                    border:

                        Border.all(

                      color: colors

                          .outlineVariant,

                    ),

                  ),

                  child: Row(

                    children: [

                      Container(

                        width: 48,

                        height: 48,

                        decoration:

                            BoxDecoration(

                          color: colors

                              .primaryContainer,

                          borderRadius:

                              BorderRadius.circular(

                            14,

                          ),

                        ),

                        child: Icon(

                          Icons

                              .trending_up_rounded,

                          color: colors

                              .onPrimaryContainer,

                          size: 22,

                        ),

                      ),

                      const SizedBox(

                        width: 13,

                      ),

                      Expanded(

                        child: Column(

                          crossAxisAlignment:

                              CrossAxisAlignment

                                  .start,

                          children: [

                            Text(

                              'Payment Collection',

                              style:

                                  TextStyle(

                                color: colors

                                    .onSurface,

                                fontSize: 14,

                                fontWeight:

                                    FontWeight.w700,

                              ),

                            ),

                            const SizedBox(

                              height: 3,

                            ),

                            Text(

                              'Total received today',

                              style:

                                  TextStyle(

                                color: colors

                                    .onSurfaceVariant,

                                fontSize: 12,

                              ),

                            ),

                          ],

                        ),

                      ),

                      Text(

                        _formatCurrency(

                          collectedToday,

                        ),

                        style:

                            TextStyle(

                          color:

                              colors.primary,

                          fontSize: 17,

                          fontWeight:

                              FontWeight.w800,

                        ),

                      ),

                    ],

                  ),

                ),



                const SizedBox(

                  height: 30,

                ),



                // ==================================================

                // FOOTER

                // ==================================================



                Center(

                  child: Text(

                    'Business Payment',

                    style: TextStyle(

                      color: colors

                          .onSurfaceVariant,

                      fontSize: 11,

                      fontWeight:

                          FontWeight.w500,

                    ),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}



// ============================================================

// SECTION TITLE

// ============================================================



class _SectionTitle

    extends StatelessWidget {

  final String title;

  final ColorScheme colors;



  const _SectionTitle({

    required this.title,

    required this.colors,

  });



  @override

  Widget build(

    BuildContext context,

  ) {

    return Text(

      title,

      style: TextStyle(

        color: colors.onSurface,

        fontSize: 18,

        fontWeight: FontWeight.w800,

        letterSpacing: -0.2,

      ),

    );

  }

}



// ============================================================

// METRIC CARD

// ============================================================



class _MetricCard

    extends StatelessWidget {

  final IconData icon;

  final String title;

  final String value;

  final ColorScheme colors;



  const _MetricCard({

    required this.icon,

    required this.title,

    required this.value,

    required this.colors,

  });



  @override

  Widget build(

    BuildContext context,

  ) {

    return Container(

      padding:

          const EdgeInsets.all(16),

      decoration:

          BoxDecoration(

        color: colors.surface,

        borderRadius:

            BorderRadius.circular(

          17,

        ),

        border: Border.all(

          color:

              colors.outlineVariant,

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Container(

            width: 38,

            height: 38,

            decoration:

                BoxDecoration(

              color:

                  colors.primaryContainer,

              borderRadius:

                  BorderRadius.circular(

                11,

              ),

            ),

            child: Icon(

              icon,

              color:

                  colors.onPrimaryContainer,

              size: 19,

            ),

          ),

          const SizedBox(

            height: 13,

          ),

          Text(

            title,

            maxLines: 1,

            overflow:

                TextOverflow.ellipsis,

            style: TextStyle(

              color: colors

                  .onSurfaceVariant,

              fontSize: 11,

              fontWeight:

                  FontWeight.w500,

            ),

          ),

          const SizedBox(

            height: 4,

          ),

          Text(

            value,

            maxLines: 1,

            overflow:

                TextOverflow.ellipsis,

            style: TextStyle(

              color:

                  colors.onSurface,

              fontSize: 19,

              fontWeight:

                  FontWeight.w800,

              letterSpacing: -0.3,

            ),

          ),

        ],

      ),

    );

  }

}



// ============================================================

// OVERVIEW ROW

// ============================================================



class _OverviewRow

    extends StatelessWidget {

  final IconData icon;

  final String title;

  final String value;

  final Color? valueColor;

  final ColorScheme colors;



  const _OverviewRow({

    required this.icon,

    required this.title,

    required this.value,

    required this.colors,

    this.valueColor,

  });



  @override

  Widget build(

    BuildContext context,

  ) {

    return Row(

      children: [

        Container(

          width: 36,

          height: 36,

          decoration:

              BoxDecoration(

            color:

                colors.primaryContainer,

            borderRadius:

                BorderRadius.circular(

              10,

            ),

          ),

          child: Icon(

            icon,

            size: 18,

            color:

                colors.onPrimaryContainer,

          ),

        ),

        const SizedBox(

          width: 11,

        ),

        Expanded(

          child: Text(

            title,

            style: TextStyle(

              color: colors

                  .onSurfaceVariant,

              fontSize: 13,

              fontWeight:

                  FontWeight.w500,

            ),

          ),

        ),

        Text(

          value,

          style: TextStyle(

            color: valueColor ??

                colors.onSurface,

            fontSize: 14,

            fontWeight:

                FontWeight.w800,

          ),

        ),

      ],

    );

  }

}



// ============================================================

// OVERVIEW DIVIDER

// ============================================================



class _OverviewDivider

    extends StatelessWidget {

  final ColorScheme colors;



  const _OverviewDivider({

    required this.colors,

  });



  @override

  Widget build(

    BuildContext context,

  ) {

    return Padding(

      padding:

          const EdgeInsets.symmetric(

        vertical: 13,

      ),

      child: Divider(

        height: 1,

        color:

            colors.outlineVariant,

      ),

    );

  }

}