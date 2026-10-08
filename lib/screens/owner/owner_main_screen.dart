



import 'package:flutter/material.dart';







import '../purchases/add_purchase_screen.dart';



import '../payments/payment_screen.dart';



import '../customers/customers_screen.dart';



import '../../models/customer.dart';



import '../../models/transaction.dart';



import '../../services/customer_service.dart';



import '../../services/transaction_service.dart';



import '../settings/settings_screen.dart';



import 'owner_reports_screen.dart';







class OwnerMainScreen extends StatefulWidget {



  final String userName;







  const OwnerMainScreen({



    super.key,



    this.userName = 'Owner',



  });







  @override



  State<OwnerMainScreen> createState() =>



      _OwnerMainScreenState();



}







class _OwnerMainScreenState



    extends State<OwnerMainScreen> {



  int _selectedIndex = 0;



  bool _isInitialLoading = true;







  @override



  void initState() {



    super.initState();



    WidgetsBinding.instance.addPostFrameCallback((_) {



      if (mounted) {



        _loadData();



      }



    });



  }







  Future<void> _loadData() async {



    if (mounted) {



      setState(() {



        _isInitialLoading = true;



      });



    }







    try {



      await CustomerService.loadCustomers();



      await TransactionService.loadCustomerBalances();



      await TransactionService.loadTransactions();



    } finally {



      if (mounted) {



        setState(() {



          _isInitialLoading = false;



        });



      }



    }



  }







  Future<void> _openAddPurchase() async {



    final result =



        await Navigator.push<bool>(



      context,



      MaterialPageRoute(



        builder: (_) =>



            const AddPurchaseScreen(),



      ),



    );







    if (result == true && mounted) {



      await _loadData();



    }



  }







  void _openCustomers() {



    setState(() {



      _selectedIndex = 1;



    });



  }







  void _openPayments() {



    setState(() {



      _selectedIndex = 2;



    });



  }







  void _openReports() {



    setState(() {



      _selectedIndex = 3;



    });



  }







  Future<void> _openReceivePayment() async {



    final customer = await showModalBottomSheet<Customer>(



      context: context,



      isScrollControlled: true,



      backgroundColor: Colors.transparent,



      builder: (_) => const _PaymentCustomerPicker(),



    );







    if (customer == null || !mounted) return;







    final saved = await Navigator.push<bool>(



      context,



      MaterialPageRoute(



        builder: (_) => PaymentScreen(customer: customer),



      ),



    );







    if (saved == true && mounted) {



      await _loadData();



    }



  }







  void _openSettings() {



    Navigator.push(



      context,



      MaterialPageRoute(



        builder: (_) => SettingsScreen(



          role: 'owner',



          userName: widget.userName,



        ),



      ),



    );



  }







  @override



  Widget build(BuildContext context) {

    final baseTheme = Theme.of(context);

    final colors = ColorScheme.fromSeed(

      seedColor: const Color(0xFF0F766E),

      brightness: baseTheme.brightness,

    );



    final polishedTheme = baseTheme.copyWith(

      colorScheme: colors,

      scaffoldBackgroundColor: colors.surfaceContainerLowest,

      appBarTheme: baseTheme.appBarTheme.copyWith(

        backgroundColor: colors.surfaceContainerLowest,

        surfaceTintColor: Colors.transparent,

        elevation: 0,

        scrolledUnderElevation: 0,

        titleTextStyle: TextStyle(

          color: colors.onSurface,

          fontSize: 20,

          fontWeight: FontWeight.w800,

        ),

      ),

      navigationBarTheme: NavigationBarThemeData(

        height: 72,

        backgroundColor: colors.surface,

        indicatorColor: colors.primary.withValues(alpha:0.12),

        elevation: 8,

        labelTextStyle: WidgetStatePropertyAll(

          TextStyle(

            fontSize: 11,

            fontWeight: FontWeight.w700,

            color: colors.onSurface,

          ),

        ),

      ),

      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(

        filled: true,

        fillColor: colors.surfaceContainerHigh,

        border: OutlineInputBorder(

          borderRadius: BorderRadius.circular(16),

          borderSide: BorderSide.none,

        ),

        enabledBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(16),

          borderSide: BorderSide.none,

        ),

        focusedBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(16),

          borderSide: BorderSide(color: colors.primary, width: 1.5),

        ),

      ),

      cardTheme: baseTheme.cardTheme.copyWith(

        elevation: 0,

        margin: EdgeInsets.zero,

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(18),

        ),

      ),

    );



    final pages = [



      _OwnerHomeContent(



        userName: widget.userName,



        onAddPurchase:



            _openAddPurchase,



        onOpenCustomers:



            _openCustomers,



        onOpenPayments:



            _openPayments,



        onOpenReports:



            _openReports,



        onReceivePayment:



            _openReceivePayment,



        onOpenSettings:



            _openSettings,



        isInitialLoading: _isInitialLoading,



      ),



      const CustomersScreen(),



      const PaymentsScreen(),



      const OwnerReportsScreen(),



    ];







    return Theme(

      data: polishedTheme,

      child: Scaffold(

        body: IndexedStack(

          index: _selectedIndex,

          children: pages,

        ),

        bottomNavigationBar: NavigationBar(

          selectedIndex: _selectedIndex,

          onDestinationSelected: (index) {

            setState(() {

              _selectedIndex = index;

            });

          },

          destinations: const [

            NavigationDestination(

              icon: Icon(Icons.dashboard_outlined),

              selectedIcon: Icon(Icons.dashboard_rounded),

              label: 'Home',

            ),

            NavigationDestination(

              icon: Icon(Icons.people_outline_rounded),

              selectedIcon: Icon(Icons.people_rounded),

              label: 'Customers',

            ),

            NavigationDestination(

              icon: Icon(Icons.payments_outlined),

              selectedIcon: Icon(Icons.payments_rounded),

              label: 'Payments',

            ),

            NavigationDestination(

              icon: Icon(Icons.bar_chart_outlined),

              selectedIcon: Icon(Icons.bar_chart_rounded),

              label: 'Reports',

            ),

          ],

        ),

      ),

    );



  }

}



// ============================================================

// OWNER HOME



// ============================================================







class _OwnerHomeContent



    extends StatelessWidget {



  final String userName;



  final VoidCallback onAddPurchase;



  final VoidCallback onOpenCustomers;



  final VoidCallback onOpenPayments;



  final VoidCallback onOpenReports;



  final VoidCallback onReceivePayment;



  final VoidCallback onOpenSettings;



  final bool isInitialLoading;







  const _OwnerHomeContent({



    required this.userName,



    required this.onAddPurchase,



    required this.onOpenCustomers,



    required this.onOpenPayments,



    required this.onOpenReports,



    required this.onReceivePayment,



    required this.onOpenSettings,



    required this.isInitialLoading,



  });







  String _getGreeting() {



    final hour =



        DateTime.now().hour;







    if (hour < 12) {



      return 'Good morning';



    }







    if (hour < 17) {



      return 'Good afternoon';



    }







    return 'Good evening';



  }







  @override



  Widget build(BuildContext context) {



    final colors =



        Theme.of(context).colorScheme;







    return Scaffold(



      backgroundColor:



          colors.surfaceContainerLowest,



      appBar: AppBar(



        backgroundColor:



            colors.surfaceContainerLowest,



        elevation: 0,



        titleSpacing: 20,



        title: Column(



          crossAxisAlignment:



              CrossAxisAlignment.start,



          children: [



            Text(



              _getGreeting(),



              style: TextStyle(



                fontSize: 11,



                fontWeight:



                    FontWeight.w600,



                color: colors



                    .onSurfaceVariant,



              ),



            ),



            const SizedBox(height: 2),



            const Text(



              'Business Overview',



              style: TextStyle(



                fontSize: 18,



                fontWeight:



                    FontWeight.w800,



              ),



            ),



          ],



        ),



        actions: [



          IconButton(



            tooltip: 'Settings',



            onPressed:



                onOpenSettings,



            icon: const Icon(



              Icons



                  .settings_outlined,



            ),



          ),



          const SizedBox(width: 8),



        ],



      ),



      body: isInitialLoading



          ? Center(



              child: CircularProgressIndicator(



                color: colors.primary,



              ),



            )



          : ValueListenableBuilder<int>(



        valueListenable:



            CustomerService.dataVersion,



        builder: (



          context,



          customerVersion,



          child,



        ) {



          return ValueListenableBuilder<int>(



            valueListenable:



                TransactionService



                    .dataVersion,



            builder: (



              context,



              transactionVersion,



              child,



            ) {



              return RefreshIndicator(



                color: colors.primary,



                backgroundColor:



                    colors.surface,



                onRefresh: () async {



                  await CustomerService



                      .loadCustomers();







                  await TransactionService



                      .loadCustomerBalances();







                  await TransactionService



                      .loadTransactions();



                },



                child: ListView(



                  physics:



                      const AlwaysScrollableScrollPhysics(),



                  padding:



                      const EdgeInsets.fromLTRB(



                    20,



                    8,



                    20,



                    32,



                  ),



                  children: [



                    Text(



                      'Welcome, $userName',



                      style: TextStyle(



                        fontSize: 14,



                        fontWeight:



                            FontWeight.w600,



                        color: colors



                            .onSurfaceVariant,



                      ),



                    ),



                    const SizedBox(



                      height: 18,



                    ),



                    const _DashboardSummary(),



                    const SizedBox(



                      height: 24,



                    ),



                    _PrimaryActionCard(



                      icon: Icons



                          .add_shopping_cart_rounded,



                      title:



                          'New Purchase',



                      subtitle:



                          'Add a purchase and increase a customer balance',



                      onTap:



                          onAddPurchase,



                      colors:



                          colors,



                    ),



                    const SizedBox(



                      height: 26,



                    ),



                    Text(



                      'Quick Actions',



                      style: TextStyle(



                        color:



                            colors.onSurface,



                        fontSize: 18,



                        fontWeight:



                            FontWeight.w800,



                      ),



                    ),



                    const SizedBox(



                      height: 12,



                    ),



                    Row(



                      children: [



                        Expanded(



                          child: _QuickAction(



                            icon: Icons.people_alt_outlined,



                            title: 'Customers',



                            subtitle: 'Manage customers',



                            onTap: onOpenCustomers,



                            colors: colors,



                          ),



                        ),



                        const SizedBox(width: 12),



                        Expanded(



                          child: _QuickAction(



                            icon: Icons.payments_outlined,



                            title: 'Payments',



                            subtitle: 'View collections',



                            onTap: onOpenPayments,



                            colors: colors,



                          ),



                        ),



                      ],



                    ),



                    const SizedBox(height: 12),



                    Row(



                      children: [



                        Expanded(



                          child: _QuickAction(



                            icon: Icons.account_balance_wallet_outlined,



                            title: 'Receive Payment',



                            subtitle: 'Collect from a customer',



                            onTap: onReceivePayment,



                            colors: colors,



                          ),



                        ),



                        const SizedBox(width: 12),



                        Expanded(



                          child: _QuickAction(



                            icon: Icons.bar_chart_rounded,



                            title: 'Reports',



                            subtitle: 'View business reports',



                            onTap: onOpenReports,



                            colors: colors,



                          ),



                        ),



                      ],



                    ),



                    const SizedBox(



                      height: 26,



                    ),



                    Text(



                      'Today',



                      style: TextStyle(



                        color:



                            colors.onSurface,



                        fontSize: 18,



                        fontWeight:



                            FontWeight.w800,



                      ),



                    ),



                    const SizedBox(



                      height: 12,



                    ),



                    const _TodayCard(),



                  ],



                ),



              );



            },



          );



        },



      ),



    );



  }



}







// ============================================================



// PAYMENT CUSTOMER PICKER



// ============================================================







class _PaymentCustomerPicker extends StatefulWidget {



  const _PaymentCustomerPicker();







  @override



  State<_PaymentCustomerPicker> createState() =>



      _PaymentCustomerPickerState();



}







class _PaymentCustomerPickerState



    extends State<_PaymentCustomerPicker> {



  final TextEditingController _searchController =



      TextEditingController();



  String _query = '';







  @override



  void initState() {



    super.initState();



    _searchController.addListener(_onSearchChanged);



  }







  @override



  void dispose() {



    _searchController



      ..removeListener(_onSearchChanged)



      ..dispose();



    super.dispose();



  }







  void _onSearchChanged() {



    if (!mounted) return;



    setState(() {



      _query = _searchController.text.trim().toLowerCase();



    });



  }







  List<Customer> _filteredCustomers() {



    final customers = CustomerService.customers;



    if (_query.isEmpty) return customers;







    return customers.where((customer) {



      return customer.businessName.toLowerCase().contains(_query) ||



          customer.location.toLowerCase().contains(_query) ||



          customer.phone.toLowerCase().contains(_query);



    }).toList();



  }







  @override



  Widget build(BuildContext context) {



    final colors = Theme.of(context).colorScheme;



    final customers = _filteredCustomers();







    return SafeArea(



      child: Container(



        height: MediaQuery.of(context).size.height * 0.82,



        decoration: BoxDecoration(



          color: colors.surface,



          borderRadius: const BorderRadius.vertical(



            top: Radius.circular(24),



          ),



        ),



        child: Column(



          children: [



            const SizedBox(height: 10),



            Container(



              width: 42,



              height: 4,



              decoration: BoxDecoration(



                color: colors.outlineVariant,



                borderRadius: BorderRadius.circular(10),



              ),



            ),



            Padding(



              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),



              child: Row(



                children: [



                  Expanded(



                    child: Text(



                      'Select Customer',



                      style: TextStyle(



                        fontSize: 20,



                        fontWeight: FontWeight.w800,



                        color: colors.onSurface,



                      ),



                    ),



                  ),



                  IconButton(



                    onPressed: () => Navigator.pop(context),



                    icon: const Icon(Icons.close_rounded),



                  ),



                ],



              ),



            ),



            Padding(



              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),



              child: TextField(



                controller: _searchController,



                textInputAction: TextInputAction.search,



                decoration: InputDecoration(



                  hintText: 'Search customer, location or phone',



                  prefixIcon: const Icon(Icons.search_rounded),



                  suffixIcon: _query.isEmpty



                      ? null



                      : IconButton(



                          onPressed: _searchController.clear,



                          icon: const Icon(Icons.clear_rounded),



                        ),



                  filled: true,



                  fillColor: colors.surfaceContainerHighest,



                  border: OutlineInputBorder(



                    borderRadius: BorderRadius.circular(14),



                    borderSide: BorderSide.none,



                  ),



                ),



              ),



            ),



            Expanded(



              child: customers.isEmpty



                  ? Center(



                      child: Text(



                        _query.isEmpty



                            ? 'No customers available.'



                            : 'No matching customers.',



                        style: TextStyle(



                          color: colors.onSurfaceVariant,



                          fontSize: 14,



                        ),



                      ),



                    )



                  : ListView.separated(



                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),



                      itemCount: customers.length,



                      separatorBuilder: (_, _) =>



                          const SizedBox(height: 8),



                      itemBuilder: (context, index) {



                        final customer = customers[index];



                        final balance = TransactionService



                            .getCustomerBalance(customer.id);







                        return Material(



                          color: colors.surfaceContainerLowest,



                          borderRadius: BorderRadius.circular(16),



                          child: InkWell(



                            borderRadius: BorderRadius.circular(16),



                            onTap: () => Navigator.pop(context, customer),



                            child: Padding(



                              padding: const EdgeInsets.all(15),



                              child: Row(



                                children: [



                                  Container(



                                    width: 44,



                                    height: 44,



                                    decoration: BoxDecoration(



                                      color: colors.primaryContainer,



                                      borderRadius: BorderRadius.circular(13),



                                    ),



                                    child: Icon(



                                      Icons.storefront_outlined,



                                      color: Colors.white,



                                    ),



                                  ),



                                  const SizedBox(width: 12),



                                  Expanded(



                                    child: Column(



                                      crossAxisAlignment:



                                          CrossAxisAlignment.start,



                                      children: [



                                        Text(



                                          customer.businessName,



                                          maxLines: 1,



                                          overflow: TextOverflow.ellipsis,



                                          style: TextStyle(



                                            color: colors.onSurface,



                                            fontSize: 14,



                                            fontWeight: FontWeight.w800,



                                          ),



                                        ),



                                        const SizedBox(height: 4),



                                        Text(



                                          customer.location,



                                          maxLines: 1,



                                          overflow: TextOverflow.ellipsis,



                                          style: TextStyle(



                                            color: colors.onSurfaceVariant,



                                            fontSize: 11,



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



                                        '₹${balance.toStringAsFixed(2)}',



                                        style: TextStyle(



                                          color: colors.primary,



                                          fontSize: 13,



                                          fontWeight: FontWeight.w800,



                                        ),



                                      ),



                                      const SizedBox(height: 3),



                                      Text(



                                        'Due',



                                        style: TextStyle(



                                          color: colors.onSurfaceVariant,



                                          fontSize: 10,



                                        ),



                                      ),



                                    ],



                                  ),



                                ],



                              ),



                            ),



                          ),



                        );



                      },



                    ),



            ),



          ],



        ),



      ),



    );



  }



}







// ============================================================



// DASHBOARD SUMMARY



// ============================================================







class _DashboardSummary



    extends StatelessWidget {



  const _DashboardSummary();







  String _formatCurrency(



    double amount,



  ) {



    return '₹${amount.toStringAsFixed(2)}';



  }







  @override



  Widget build(



    BuildContext context,



  ) {



    final colors =



        Theme.of(context).colorScheme;







    final customers =



        CustomerService.customers;







    final outstanding =



        TransactionService.customerBalances



            .values



            .fold<double>(



              0.0,



              (total, balance) => total + balance,



            );







    final collected =



        TransactionService



            .getCollectedToday();







    return Column(



      children: [



        Container(



          width: double.infinity,



          padding:



              const EdgeInsets.all(22),



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



                Color.lerp(colors.primary, Colors.black, 0.38)!,



              ],



            ),



            borderRadius:



                BorderRadius.circular(



              22,



            ),



            boxShadow: [



              BoxShadow(



                color: colors.primary



                    .withValues(alpha:0.18),



                blurRadius: 22,



                offset:



                    const Offset(0, 10),



              ),



            ],



          ),



          child: Column(



            crossAxisAlignment:



                CrossAxisAlignment.start,



            children: [



              Row(



                children: [



                  Container(



                    width: 42,



                    height: 42,



                    decoration:



                        BoxDecoration(



                      color: Colors.white



                          .withValues(alpha: 0.14,



                      ),



                      borderRadius:



                          BorderRadius



                              .circular(12),



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



                          'Money to Receive',



                          style:



                              TextStyle(



                            color:



                                Colors.white,



                            fontSize: 14,



                            fontWeight:



                                FontWeight.w700,



                          ),



                        ),



                        SizedBox(



                          height: 3,



                        ),



                        Text(



                          'Current outstanding balance',



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



                  outstanding,



                ),



                style:



                    const TextStyle(



                  color:



                      Colors.white,



                  fontSize: 33,



                  fontWeight:



                      FontWeight.w800,



                  letterSpacing: -1,



                ),



              ),



              const SizedBox(



                height: 16,



              ),



              Row(



                children: [



                  _SmallWhiteStat(



                    icon: Icons



                        .people_outline_rounded,



                    text:



                        '${customers.length} customers',



                  ),



                  const SizedBox(



                    width: 18,



                  ),



                  _SmallWhiteStat(



                    icon: Icons



                        .payments_outlined,



                    text:



                        '${_formatCurrency(collected)} collected today',



                  ),



                ],



              ),



            ],



          ),



        ),



        const SizedBox(height: 12),



        Row(



          children: [



            Expanded(



              child:



                  _SmallStatCard(



                icon: Icons



                    .people_outline_rounded,



                title:



                    'Customers',



                value:



                    '${customers.length}',



                colors:



                    colors,



              ),



            ),



            const SizedBox(



              width: 12,



            ),



            Expanded(



              child:



                  _SmallStatCard(



                icon: Icons



                    .payments_outlined,



                title:



                    'Collected Today',



                value:



                    _formatCurrency(



                  collected,



                ),



                colors:



                    colors,



              ),



            ),



          ],



        ),



      ],



    );



  }



}







// ============================================================



// PRIMARY ACTION



// ============================================================







class _PrimaryActionCard



    extends StatelessWidget {



  final IconData icon;



  final String title;



  final String subtitle;



  final VoidCallback onTap;



  final ColorScheme colors;







  const _PrimaryActionCard({



    required this.icon,



    required this.title,



    required this.subtitle,



    required this.onTap,



    required this.colors,



  });







  @override



  Widget build(



    BuildContext context,



  ) {



    return Material(



      color: colors.surface,



      borderRadius:



          BorderRadius.circular(18),



      child: InkWell(



        onTap: onTap,



        borderRadius:



            BorderRadius.circular(18),



        child: Container(



          padding:



              const EdgeInsets.all(17),



          decoration:



              BoxDecoration(



            borderRadius:



                BorderRadius.circular(18),



            border: Border.all(



              color:



                  colors.outlineVariant,



            ),



          ),



          child: Row(



            children: [



              Container(



                width: 50,



                height: 50,



                decoration:



                    BoxDecoration(



                  color:



                      colors.primary,



                  borderRadius:



                      BorderRadius.circular(



                    15,



                  ),



                ),



                child: Icon(



                  icon,



                  color:



                      colors.onPrimary,



                  size: 23,



                ),



              ),



              const SizedBox(



                width: 14,



              ),



              Expanded(



                child: Column(



                  crossAxisAlignment:



                      CrossAxisAlignment



                          .start,



                  children: [



                    Text(



                      title,



                      style:



                          TextStyle(



                        color: colors



                            .onSurface,



                        fontSize: 14,



                        fontWeight:



                            FontWeight.w800,



                      ),



                    ),



                    const SizedBox(



                      height: 4,



                    ),



                    Text(



                      subtitle,



                      style:



                          TextStyle(



                        color: colors



                            .onSurfaceVariant,



                        fontSize: 11,



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



    );



  }



}







// ============================================================



// QUICK ACTION



// ============================================================







class _QuickAction



    extends StatelessWidget {



  final IconData icon;



  final String title;



  final String subtitle;



  final VoidCallback onTap;



  final ColorScheme colors;







  const _QuickAction({



    required this.icon,



    required this.title,



    required this.subtitle,



    required this.onTap,



    required this.colors,



  });







  @override



  Widget build(



    BuildContext context,



  ) {



    return Material(



      color: colors.surface,



      borderRadius: BorderRadius.circular(17),



      child: InkWell(



        onTap: onTap,



        borderRadius: BorderRadius.circular(17),



        child: Container(



          padding: const EdgeInsets.all(15),



          decoration: BoxDecoration(



            borderRadius: BorderRadius.circular(17),



            border: Border.all(



              color: colors.outlineVariant,



            ),



          ),



          child: Column(



        crossAxisAlignment:



            CrossAxisAlignment.start,



        children: [



          Container(



            width: 40,



            height: 40,



            decoration:



                BoxDecoration(



              color:



                  colors.primaryContainer,



              borderRadius:



                  BorderRadius.circular(12),



            ),



            child: Icon(



              icon,



              color:



                  colors.onPrimaryContainer,



              size: 20,



            ),



          ),



          const SizedBox(



            height: 12,



          ),



          Text(



            title,



            style: TextStyle(



              color:



                  colors.onSurface,



              fontSize: 13,



              fontWeight:



                  FontWeight.w700,



            ),



          ),



          const SizedBox(



            height: 3,



          ),



          Text(



            subtitle,



            style: TextStyle(



              color: colors



                  .onSurfaceVariant,



              fontSize: 10,



            ),



          ),



          ],



        ),



      ),



      ),



    );



  }



}







// ============================================================



// TODAY CARD



// ============================================================







class _TodayCard



    extends StatelessWidget {



  const _TodayCard();







  String _formatCurrency(



    double amount,



  ) {



    return '₹${amount.toStringAsFixed(2)}';



  }







  @override



  Widget build(



    BuildContext context,



  ) {



    final colors =



        Theme.of(context).colorScheme;







    final collected =



        TransactionService



            .getCollectedToday();







    final payments =



        TransactionService



            .getPaymentsToday();







    return Container(



      padding:



          const EdgeInsets.all(18),



      decoration:



          BoxDecoration(



        color: colors.surface,



        borderRadius:



            BorderRadius.circular(18),



        border: Border.all(



          color:



              colors.outlineVariant,



        ),



      ),



      child: Column(



        children: [



          Row(



            children: [



              Container(



                width: 42,



                height: 42,



                decoration:



                    BoxDecoration(



                  color:



                      colors.primaryContainer,



                  borderRadius:



                      BorderRadius.circular(12),



                ),



                child: Icon(



                  Icons



                      .trending_up_rounded,



                  color:



                      colors.onPrimaryContainer,



                  size: 21,



                ),



              ),



              const SizedBox(



                width: 12,



              ),



              Expanded(



                child: Column(



                  crossAxisAlignment:



                      CrossAxisAlignment



                          .start,



                  children: [



                    Text(



                      "Today's Collection",



                      style:



                          TextStyle(



                        color:



                            colors.onSurface,



                        fontSize: 14,



                        fontWeight:



                            FontWeight.w700,



                      ),



                    ),



                    const SizedBox(



                      height: 3,



                    ),



                    Text(



                      'Payments received today',



                      style:



                          TextStyle(



                        color: colors



                            .onSurfaceVariant,



                        fontSize: 11,



                      ),



                    ),



                  ],



                ),



              ),



              Text(



                _formatCurrency(



                  collected,



                ),



                style:



                    TextStyle(



                  color:



                      colors.primary,



                  fontSize: 16,



                  fontWeight:



                      FontWeight.w800,



                ),



              ),



            ],



          ),



          const SizedBox(



            height: 17,



          ),



          Divider(



            height: 1,



            color:



                colors.outlineVariant,



          ),



          const SizedBox(



            height: 14,



          ),



          Row(



            children: [



              Expanded(



                child: _TodayStat(



                  icon: Icons



                      .receipt_long_outlined,



                  label:



                      'Payments',



                  value:



                      '$payments',



                  colors:



                      colors,



                ),



              ),



              Container(



                width: 1,



                height: 30,



                color:



                    colors.outlineVariant,



              ),



              Expanded(



                child: _TodayStat(



                  icon: Icons



                      .account_balance_wallet_outlined,



                  label:



                      'Collected',



                  value:



                      _formatCurrency(



                    collected,



                  ),



                  colors:



                      colors,



                ),



              ),



            ],



          ),



        ],



      ),



    );



  }



}







// ============================================================



// SMALL STAT CARD



// ============================================================







class _SmallStatCard



    extends StatelessWidget {



  final IconData icon;



  final String title;



  final String value;



  final ColorScheme colors;







  const _SmallStatCard({



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



          const EdgeInsets.all(15),



      decoration:



          BoxDecoration(



        color: colors.surface,



        borderRadius:



            BorderRadius.circular(17),



        border: Border.all(



          color:



              colors.outlineVariant,



        ),



      ),



      child: Row(



        children: [



          Container(



            width: 36,



            height: 36,



            decoration:



                BoxDecoration(



              color:



                  colors.primaryContainer,



              borderRadius:



                  BorderRadius.circular(10),



            ),



            child: Icon(



              icon,



              size: 18,



              color:



                  colors.onPrimaryContainer,



            ),



          ),



          const SizedBox(



            width: 10,



          ),



          Expanded(



            child: Column(



              crossAxisAlignment:



                  CrossAxisAlignment.start,



              children: [



                Text(



                  title,



                  maxLines: 1,



                  overflow:



                      TextOverflow.ellipsis,



                  style:



                      TextStyle(



                    color: colors



                        .onSurfaceVariant,



                    fontSize: 10,



                  ),



                ),



                const SizedBox(



                  height: 3,



                ),



                Text(



                  value,



                  maxLines: 1,



                  overflow:



                      TextOverflow.ellipsis,



                  style:



                      TextStyle(



                    color:



                        colors.onSurface,



                    fontSize: 14,



                    fontWeight:



                        FontWeight.w800,



                  ),



                ),



              ],



            ),



          ),



        ],



      ),



    );



  }



}







// ============================================================



// SMALL WHITE STAT



// ============================================================







class _SmallWhiteStat



    extends StatelessWidget {



  final IconData icon;



  final String text;







  const _SmallWhiteStat({



    required this.icon,



    required this.text,



  });







  @override



  Widget build(



    BuildContext context,



  ) {



    return Flexible(



      child: Row(



        mainAxisSize:



            MainAxisSize.min,



        children: [



          Icon(



            icon,



            size: 14,



            color: Colors.white



                .withValues(alpha:0.82),



          ),



          const SizedBox(



            width: 5,



          ),



          Flexible(



            child: Text(



              text,



              maxLines: 1,



              overflow:



                  TextOverflow.ellipsis,



              style: TextStyle(



                color: Colors.white



                    .withValues(alpha:0.85),



                fontSize: 10,



                fontWeight:



                    FontWeight.w600,



              ),



            ),



          ),



        ],



      ),



    );



  }



}







// ============================================================



// TODAY STAT



// ============================================================







class _TodayStat



    extends StatelessWidget {



  final IconData icon;



  final String label;



  final String value;



  final ColorScheme colors;







  const _TodayStat({



    required this.icon,



    required this.label,



    required this.value,



    required this.colors,



  });







  @override



  Widget build(



    BuildContext context,



  ) {



    return Row(



      mainAxisAlignment:



          MainAxisAlignment.center,



      children: [



        Icon(



          icon,



          size: 17,



          color:



              colors.primary,



        ),



        const SizedBox(



          width: 7,



        ),



        Column(



          crossAxisAlignment:



              CrossAxisAlignment.start,



          children: [



            Text(



              label,



              style: TextStyle(



                color: colors



                    .onSurfaceVariant,



                fontSize: 10,



              ),



            ),



            const SizedBox(



              height: 2,



            ),



            Text(



              value,



              style: TextStyle(



                color:



                    colors.onSurface,



                fontSize: 13,



                fontWeight:



                    FontWeight.w800,



              ),



            ),



          ],



        ),



      ],



    );



  }



}







// ============================================================



// PAYMENTS SCREEN



// ============================================================







class PaymentsScreen extends StatefulWidget {



  const PaymentsScreen({super.key});







  @override



  State<PaymentsScreen> createState() => _PaymentsScreenState();



}







class _PaymentsScreenState extends State<PaymentsScreen> {



  final TextEditingController _searchController = TextEditingController();



  String _searchQuery = '';



  DateTime _selectedDate = DateTime.now();







  @override



  void initState() {



    super.initState();



    _searchController.addListener(_onSearchChanged);



  }







  @override



  void dispose() {



    _searchController.removeListener(_onSearchChanged);



    _searchController.dispose();



    super.dispose();



  }







  void _onSearchChanged() {



    setState(() {



      _searchQuery = _searchController.text.trim().toLowerCase();



    });



  }







  String _formatDate(DateTime date) {



    return '${date.day.toString().padLeft(2, '0')}/'



        '${date.month.toString().padLeft(2, '0')}/'



        '${date.year}';



  }







  List<PaymentTransaction> _filteredPayments() {



    final payments = TransactionService.transactions;







    return payments.where((payment) {



      final paymentDate = payment.transactionDate.toLocal();



      final sameDate =



          paymentDate.year == _selectedDate.year &&



          paymentDate.month == _selectedDate.month &&



          paymentDate.day == _selectedDate.day;







      if (!sameDate) return false;







      if (_searchQuery.isEmpty) return true;







      return payment.customerName.toLowerCase().contains(_searchQuery);



    }).toList();



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







    if (picked == null || !mounted) return;







    setState(() {



      _selectedDate = DateTime(picked.year, picked.month, picked.day);



    });



  }







  String _formatSelectedDate() {



    return '${_selectedDate.day.toString().padLeft(2, '0')}/'



        '${_selectedDate.month.toString().padLeft(2, '0')}/'



        '${_selectedDate.year}';



  }







  Future<void> _deletePayment(PaymentTransaction payment) async {



    final colors = Theme.of(context).colorScheme;







    final confirmed = await showDialog<bool>(



      context: context,



      builder: (dialogContext) {



        return AlertDialog(



          title: const Text('Delete Payment?'),



          content: Text(



            'Delete the payment of ₹${payment.amountReceived.toStringAsFixed(2)} '



            'received from ${payment.customerName}?\n\n'



            'This will restore the customer balance.',



          ),



          actions: [



            TextButton(



              onPressed: () => Navigator.pop(dialogContext, false),



              child: const Text('Cancel'),



            ),



            FilledButton(



              style: FilledButton.styleFrom(



                backgroundColor: colors.error,



                foregroundColor: colors.onError,



              ),



              onPressed: () => Navigator.pop(dialogContext, true),



              child: const Text('Delete Payment'),



            ),



          ],



        );



      },



    );







    if (confirmed != true || !mounted) return;







    final success = await TransactionService.deletePayment(payment.id);







    if (!mounted) return;







    if (success) {



      ScaffoldMessenger.of(context).showSnackBar(



        const SnackBar(



          content: Text('Payment deleted successfully.'),



          behavior: SnackBarBehavior.floating,



        ),



      );



      await TransactionService.loadTransactions();



    } else {



      ScaffoldMessenger.of(context).showSnackBar(



        SnackBar(



          content: Text(



            TransactionService.errorMessage ??



                'Could not delete the payment.',



          ),



          behavior: SnackBarBehavior.floating,



          backgroundColor: colors.error,



        ),



      );



    }



  }







  @override



  Widget build(BuildContext context) {



    final colors = Theme.of(context).colorScheme;







    return Scaffold(



      backgroundColor: colors.surfaceContainerLowest,



      appBar: AppBar(



        title: const Text(



          'Payment History',



          style: TextStyle(fontWeight: FontWeight.w800),



        ),



        backgroundColor: colors.surfaceContainerLowest,



        elevation: 0,



      ),



      body: ValueListenableBuilder<int>(



        valueListenable: TransactionService.dataVersion,



        builder: (context, version, child) {



          final payments = _filteredPayments();







          return RefreshIndicator(



            color: colors.primary,



            backgroundColor: colors.surface,



            onRefresh: TransactionService.loadTransactions,



            child: ListView(



              physics: const AlwaysScrollableScrollPhysics(),



              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),



              children: [



                TextField(



                  controller: _searchController,



                  textInputAction: TextInputAction.search,



                  decoration: InputDecoration(



                    hintText: 'Search customers',



                    prefixIcon: const Icon(Icons.search_rounded),



                    suffixIcon: _searchQuery.isEmpty



                        ? null



                        : IconButton(



                            tooltip: 'Clear search',



                            onPressed: _searchController.clear,



                            icon: const Icon(Icons.clear_rounded),



                          ),



                    filled: true,



                    fillColor: colors.surface,



                    border: OutlineInputBorder(



                      borderRadius: BorderRadius.circular(15),



                      borderSide: BorderSide(color: colors.outlineVariant),



                    ),



                    enabledBorder: OutlineInputBorder(



                      borderRadius: BorderRadius.circular(15),



                      borderSide: BorderSide(color: colors.outlineVariant),



                    ),



                    focusedBorder: OutlineInputBorder(



                      borderRadius: BorderRadius.circular(15),



                      borderSide: BorderSide(color: colors.primary, width: 1.5),



                    ),



                  ),



                ),



                const SizedBox(height: 12),



                InkWell(



                  onTap: _selectDate,



                  borderRadius: BorderRadius.circular(15),



                  child: InputDecorator(



                    decoration: InputDecoration(



                      labelText: 'Payment Date',



                      prefixIcon: const Icon(Icons.calendar_today_outlined),



                      filled: true,



                      fillColor: colors.surface,



                      border: OutlineInputBorder(



                        borderRadius: BorderRadius.circular(15),



                        borderSide: BorderSide(color: colors.outlineVariant),



                      ),



                      enabledBorder: OutlineInputBorder(



                        borderRadius: BorderRadius.circular(15),



                        borderSide: BorderSide(color: colors.outlineVariant),



                      ),



                    ),



                    child: Text(



                      _formatSelectedDate(),



                      style: TextStyle(



                        color: colors.onSurface,



                        fontSize: 14,



                        fontWeight: FontWeight.w600,



                      ),



                    ),



                  ),



                ),



                const SizedBox(height: 12),



                Container(



                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),



                  decoration: BoxDecoration(



                    color: colors.primaryContainer,



                    borderRadius: BorderRadius.circular(15),



                  ),



                  child: Row(



                    children: [



                      Icon(



                        Icons.account_balance_wallet_outlined,



                        color: Colors.white,



                        size: 21,



                      ),



                      const SizedBox(width: 10),



                      Expanded(



                        child: Column(



                          crossAxisAlignment: CrossAxisAlignment.start,



                          children: [



                            Text(



                              'Received on ${_formatSelectedDate()}',



                              style: TextStyle(



                                color: colors.onPrimaryContainer,



                                fontSize: 12,



                                fontWeight: FontWeight.w700,



                              ),



                            ),



                            const SizedBox(height: 3),



                            Text(



                              '₹${payments.fold<double>(0, (sum, payment) => sum + payment.amountReceived).toStringAsFixed(2)}',



                              style: TextStyle(



                                color: colors.onPrimaryContainer,



                                fontSize: 19,



                                fontWeight: FontWeight.w800,



                              ),



                            ),



                          ],



                        ),



                      ),



                      Text(



                        '${payments.length} payment${payments.length == 1 ? '' : 's'}',



                        style: TextStyle(



                          color: colors.onPrimaryContainer,



                          fontSize: 11,



                          fontWeight: FontWeight.w600,



                        ),



                      ),



                    ],



                  ),



                ),



                const SizedBox(height: 16),



                if (TransactionService.isLoading &&



                    TransactionService.transactions.isEmpty)



                  Padding(



                    padding: const EdgeInsets.only(top: 100),



                    child: Center(



                      child: CircularProgressIndicator(color: colors.primary),



                    ),



                  )



                else if (payments.isEmpty)



                  Padding(



                    padding: const EdgeInsets.only(top: 70),



                    child: _EmptyPayments(



                      colors: colors,



                      message: _searchQuery.isEmpty



                          ? 'Payments received from customers will appear here.'



                          : 'No payments found for "${_searchController.text.trim()}".',



                    ),



                  )



                else



                  ...payments.map(



                    (payment) => _PaymentTile(



                      payment: payment,



                      date: _formatDate(payment.transactionDate),



                      colors: colors,



                      onDelete: () => _deletePayment(payment),



                    ),



                  ),



              ],



            ),



          );



        },



      ),



    );



  }



}







// ============================================================



// PAYMENT TILE



// ============================================================







class _PaymentTile extends StatelessWidget {



  final PaymentTransaction payment;



  final String date;



  final ColorScheme colors;



  final VoidCallback onDelete;







  const _PaymentTile({



    required this.payment,



    required this.date,



    required this.colors,



    required this.onDelete,



  });







  @override



  Widget build(BuildContext context) {



    return Container(



      margin: const EdgeInsets.only(bottom: 10),



      padding: const EdgeInsets.all(15),



      decoration: BoxDecoration(



        color: colors.surface,



        borderRadius: BorderRadius.circular(17),



        border: Border.all(color: colors.outlineVariant),



      ),



      child: Row(



        crossAxisAlignment: CrossAxisAlignment.start,



        children: [



          Container(



            width: 42,



            height: 42,



            decoration: BoxDecoration(



              color: colors.primaryContainer,



              borderRadius: BorderRadius.circular(12),



            ),



            child: Icon(



              Icons.payments_outlined,



              color: colors.onPrimaryContainer,



              size: 20,



            ),



          ),



          const SizedBox(width: 12),



          Expanded(



            child: Column(



              crossAxisAlignment: CrossAxisAlignment.start,



              children: [



                Text(



                  payment.customerName,



                  maxLines: 1,



                  overflow: TextOverflow.ellipsis,



                  style: TextStyle(



                    color: colors.onSurface,



                    fontSize: 14,



                    fontWeight: FontWeight.w700,



                  ),



                ),



                const SizedBox(height: 4),



                Text(



                  'Received by: ${payment.receivedBy}',



                  maxLines: 1,



                  overflow: TextOverflow.ellipsis,



                  style: TextStyle(



                    color: colors.onSurfaceVariant,



                    fontSize: 11,



                  ),



                ),



                const SizedBox(height: 3),



                Text(



                  date,



                  style: TextStyle(



                    color: colors.onSurfaceVariant,



                    fontSize: 11,



                  ),



                ),



                const SizedBox(height: 6),



                Text(



                  'Settlement: ₹${payment.amount.toStringAsFixed(2)}  •  '



                  'Received: ₹${payment.amountReceived.toStringAsFixed(2)}',



                  style: TextStyle(



                    color: colors.onSurfaceVariant,



                    fontSize: 10.5,



                    fontWeight: FontWeight.w600,



                  ),



                ),



                if (payment.discount > 0) ...[



                  const SizedBox(height: 3),



                  Text(



                    'Discount: ₹${payment.discount.toStringAsFixed(2)}',



                    style: TextStyle(



                      color: colors.error,



                      fontSize: 10.5,



                      fontWeight: FontWeight.w600,



                    ),



                  ),



                ],



              ],



            ),



          ),



          const SizedBox(width: 6),



          PopupMenuButton<String>(



            tooltip: 'Payment actions',



            onSelected: (value) {



              if (value == 'delete') onDelete();



            },



            itemBuilder: (context) => const [



              PopupMenuItem<String>(



                value: 'delete',



                child: Row(



                  children: [



                    Icon(Icons.delete_outline_rounded),



                    SizedBox(width: 10),



                    Text('Delete Payment'),



                  ],



                ),



              ),



            ],



            icon: Icon(



              Icons.more_vert_rounded,



              color: colors.onSurfaceVariant,



            ),



          ),



        ],



      ),



    );



  }



}







// ============================================================



// EMPTY PAYMENTS



// ============================================================







class _EmptyPayments



    extends StatelessWidget {



  final ColorScheme colors;



  final String message;







  const _EmptyPayments({



    required this.colors,



    this.message = 'Payments received from customers will appear here.',



  });







  @override



  Widget build(



    BuildContext context,



  ) {



    return Center(



      child: Padding(



        padding:



            const EdgeInsets.all(30),



        child: Column(



          mainAxisSize:



              MainAxisSize.min,



          children: [



            Container(



              width: 70,



              height: 70,



              decoration:



                  BoxDecoration(



                color:



                    colors.primaryContainer,



                shape:



                    BoxShape.circle,



              ),



              child: Icon(



                Icons



                    .payments_outlined,



                color: colors



                    .onPrimaryContainer,



                size: 30,



              ),



            ),



            const SizedBox(



              height: 16,



            ),



            Text(



              'No payments yet',



              style:



                  TextStyle(



                color:



                    colors.onSurface,



                fontSize: 17,



                fontWeight:



                    FontWeight.w800,



              ),



            ),



            const SizedBox(



              height: 6,



            ),



            Text(



              message,



              textAlign:



                  TextAlign.center,



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



    );



  }



}







// ============================================================



// REPORTS



// ============================================================







class ReportsPlaceholder extends StatelessWidget {



  const ReportsPlaceholder({super.key});







  @override



  Widget build(BuildContext context) {



    return const OwnerReportsScreen();



  }



}
