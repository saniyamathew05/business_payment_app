



import 'dart:async';



import 'package:flutter/material.dart';



import 'package:supabase_flutter/supabase_flutter.dart';







import '../../models/customer.dart';



import '../payments/payment_screen.dart';



import 'salesman_customer_screen.dart';



import 'salesman_payments_screen.dart';



import '../../services/customer_service.dart';



import '../../services/transaction_service.dart';



import '../settings/settings_screen.dart';







class SalesmanHome extends StatefulWidget {



  final String userName;







  const SalesmanHome({



    super.key,



    required this.userName,



  });







  @override



  State<SalesmanHome> createState() => _SalesmanHomeState();



}







class _SalesmanHomeState extends State<SalesmanHome> {



  final TextEditingController searchController = TextEditingController();







  final SupabaseClient supabase = Supabase.instance.client;







  int selectedIndex = 0;



  bool isLoading = true;



  Timer? _presenceTimer;

  RealtimeChannel? _forceLogoutChannel;

  bool _presenceCheckRunning = false;

  bool _forcedLogoutInProgress = false;







  @override



  void initState() {



    super.initState();



    _loadData();

    _startPresenceMonitoring();

    _startForceLogoutListener();



  }







  void _startPresenceMonitoring() {

    _checkPresence();

    _presenceTimer = Timer.periodic(

      const Duration(seconds: 15),

      (_) => _checkPresence(),

    );

  }



  void _startForceLogoutListener() {

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;



    _forceLogoutChannel?.unsubscribe();



    _forceLogoutChannel = supabase

        .channel('salesman-force-logout-$userId')

        .onPostgresChanges(

          event: PostgresChangeEvent.update,

          schema: 'public',

          table: 'profiles',

          filter: PostgresChangeFilter(

            type: PostgresChangeFilterType.eq,

            column: 'id',

            value: userId,

          ),

          callback: (payload) {

            final forceLogoutAt =

                payload.newRecord['force_logout_at'];



            if (forceLogoutAt != null && !_forcedLogoutInProgress) {

              _handleForceLogout();

            }

          },

        )

        .subscribe();

  }



  Future<void> _handleForceLogout() async {

    if (_forcedLogoutInProgress) return;



    _forcedLogoutInProgress = true;

    _presenceTimer?.cancel();



    try {

      await supabase.auth.signOut();

    } catch (_) {

      // Continue to the login screen even if sign-out reports an error.

    }



    if (!mounted) return;



    Navigator.of(context).pushNamedAndRemoveUntil(

      '/',

      (route) => false,

    );

  }



  Future<void> _checkPresence() async {

    if (!mounted || _presenceCheckRunning || _forcedLogoutInProgress) return;



    final user = supabase.auth.currentUser;

    if (user == null) return;



    _presenceCheckRunning = true;



    try {

      await supabase.rpc('salesman_heartbeat');



      final profile = await supabase

          .from('profiles')

          .select('force_logout_at')

          .eq('id', user.id)

          .maybeSingle();



      final forceLogoutAt = profile?['force_logout_at'];



      if (forceLogoutAt != null && mounted) {

        await _handleForceLogout();

      }

    } catch (_) {

      // Presence must never interrupt the existing salesman features.

    } finally {

      _presenceCheckRunning = false;

    }

  }



  Future<void> _loadData() async {



    if (mounted) {



      setState(() {



        isLoading = true;



      });



    }







    await CustomerService.loadCustomers();



    await TransactionService.loadTransactions();







    if (!mounted) return;







    setState(() {



      isLoading = false;



    });



  }







  List<Customer> get filteredCustomers {



    final query = searchController.text.trim().toLowerCase();







    if (query.isEmpty) {



      return CustomerService.customers;



    }







    return CustomerService.customers.where((customer) {



      return customer.businessName.toLowerCase().contains(query) ||



          customer.location.toLowerCase().contains(query) ||



          customer.phone.contains(query);



    }).toList();



  }







  Future<void> _openCustomer(Customer customer) async {



    await Navigator.push(



      context,



      MaterialPageRoute(



        builder: (_) => SalesmanCustomerDetailsScreen(



          customer: customer,



        ),



      ),



    );







    await _loadData();



  }







  Future<void> _openPaymentScreen(Customer customer) async {



    await Navigator.push(



      context,



      MaterialPageRoute(



        builder: (_) => PaymentScreen(



          customer: customer,



        ),



      ),



    );







    await _loadData();



  }







  void _openPayments() {



    Navigator.push(



      context,



      MaterialPageRoute(



        builder: (_) => const SalesmanPaymentsScreen(),



      ),



    );



  }







  void _openSettings() {



    Navigator.push(



      context,



      MaterialPageRoute(



        builder: (_) => SettingsScreen(



          role: 'salesman',



          userName: widget.userName,



        ),



      ),



    );



  }







  Future<void> _logout() async {



    final shouldLogout = await showDialog<bool>(



      context: context,



      builder: (context) {



        return AlertDialog(



          title: const Text('Log out?'),



          content: const Text(



            'Are you sure you want to log out of this account?',



          ),



          actions: [



            TextButton(



              onPressed: () {



                Navigator.pop(context, false);



              },



              child: const Text('Cancel'),



            ),



            FilledButton(



              onPressed: () {



                Navigator.pop(context, true);



              },



              child: const Text('Log out'),



            ),



          ],



        );



      },



    );







    if (shouldLogout != true) return;







    await supabase.auth.signOut();







    if (!mounted) return;







    Navigator.of(context).pushNamedAndRemoveUntil(



      '/',



      (route) => false,



    );



  }







  Widget _buildHomeTab() {



    final todayCollection = TransactionService.getCollectedToday();



    final paymentsToday = TransactionService.getPaymentsToday();



    final customerCount = CustomerService.customers.length;







    final totalDue = CustomerService.customers.fold<double>(



      0,



      (sum, customer) {



        return sum +



            TransactionService.getCurrentBalance(



              customerId: customer.id,



              openingBalance: customer.openingBalance,



            );



      },



    );







    return RefreshIndicator(



      onRefresh: _loadData,



      child: ListView(



        physics: const AlwaysScrollableScrollPhysics(),



        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),



        children: [



          Row(



            children: [



              Expanded(



                child: Column(



                  crossAxisAlignment: CrossAxisAlignment.start,



                  children: [



                    Text(



                      _getGreeting(),



                      style: TextStyle(



                        fontSize: 14,



                        fontWeight: FontWeight.w500,



                        color: Theme.of(context)



                            .colorScheme



                            .onSurfaceVariant,



                      ),



                    ),



                    const SizedBox(height: 4),



                    Text(



                      widget.userName,



                      maxLines: 1,



                      overflow: TextOverflow.ellipsis,



                      style: const TextStyle(



                        fontSize: 28,



                        fontWeight: FontWeight.w800,



                        letterSpacing: -0.6,



                      ),



                    ),



                  ],



                ),



              ),



              _ProfileAvatar(



                initials: _getInitials(widget.userName),



              ),



            ],



          ),







          const SizedBox(height: 22),







          // Today's collection card



          Container(



            width: double.infinity,



            padding: const EdgeInsets.all(22),



            decoration: BoxDecoration(



              gradient: LinearGradient(



                begin: Alignment.topLeft,



                end: Alignment.bottomRight,



                colors: [



                  Theme.of(context).colorScheme.primary,



                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.82),



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



                        size: 22,



                      ),



                    ),



                    const SizedBox(width: 12),



                    const Expanded(



                      child: Text(



                        "Today's Collection",



                        style: TextStyle(



                          color: Colors.white,



                          fontSize: 15,



                          fontWeight: FontWeight.w600,



                        ),



                      ),



                    ),



                    Container(



                      padding: const EdgeInsets.symmetric(



                        horizontal: 10,



                        vertical: 6,



                      ),



                      decoration: BoxDecoration(



                        color: Colors.white.withValues(alpha: 0.14),



                        borderRadius: BorderRadius.circular(20),



                      ),



                      child: Text(



                        '$paymentsToday ${paymentsToday == 1 ? 'payment' : 'payments'}',



                        style: const TextStyle(



                          color: Colors.white,



                          fontSize: 11,



                          fontWeight: FontWeight.w600,



                        ),



                      ),



                    ),



                  ],



                ),



                const SizedBox(height: 20),



                Text(



                  '₹${todayCollection.toStringAsFixed(2)}',



                  style: const TextStyle(



                    color: Colors.white,



                    fontSize: 34,



                    fontWeight: FontWeight.w800,



                    letterSpacing: -0.8,



                  ),



                ),



                const SizedBox(height: 6),



                Text(



                  'Payments received today',



                  style: TextStyle(



                    color: Colors.white.withValues(alpha: 0.78),



                    fontSize: 13,



                  ),



                ),



              ],



            ),



          ),







          const SizedBox(height: 14),







          Row(



            children: [



              Expanded(



                child: _StatCard(



                  icon: Icons.people_outline,



                  title: 'Customers',



                  value: customerCount.toString(),



                ),



              ),



              const SizedBox(width: 12),



              Expanded(



                child: _StatCard(



                  icon: Icons.account_balance_wallet_outlined,



                  title: 'Total Due',



                  value: _formatCompactAmount(totalDue),



                ),



              ),



            ],



          ),







          const SizedBox(height: 26),







          const Text(



            'Quick Actions',



            style: TextStyle(



              fontSize: 20,



              fontWeight: FontWeight.w800,



              letterSpacing: -0.3,



            ),



          ),







          const SizedBox(height: 12),







          Row(



            children: [



              Expanded(



                child: _QuickAction(



                  icon: Icons.person_search_outlined,



                  title: 'Customers',



                  subtitle: 'Find customer',



                  onTap: () {



                    setState(() {



                      selectedIndex = 1;



                    });



                  },



                ),



              ),



              const SizedBox(width: 12),



              Expanded(



                child: _QuickAction(



                  icon: Icons.receipt_long_outlined,



                  title: 'Payments',



                  subtitle: 'View received',



                  onTap: _openPayments,



                ),



              ),



            ],



          ),







          const SizedBox(height: 12),







          Row(



            children: [



              Expanded(



                child: _QuickAction(



                  icon: Icons.refresh_rounded,



                  title: 'Refresh',



                  subtitle: 'Update data',



                  onTap: _loadData,



                ),



              ),



              const SizedBox(width: 12),



              Expanded(



                child: _QuickAction(



                  icon: Icons.settings_outlined,



                  title: 'Settings',



                  subtitle: 'Preferences',



                  onTap: _openSettings,



                ),



              ),



            ],



          ),







          const SizedBox(height: 28),







          Row(



            mainAxisAlignment: MainAxisAlignment.spaceBetween,



            children: [



              const Text(



                'Recent Payments',



                style: TextStyle(



                  fontSize: 20,



                  fontWeight: FontWeight.w800,



                  letterSpacing: -0.3,



                ),



              ),



              TextButton(



                onPressed: _openPayments,



                child: const Text('View all'),



              ),



            ],



          ),







          const SizedBox(height: 8),







          if (TransactionService.transactions.isEmpty)



            _EmptyState(



              icon: Icons.receipt_long_outlined,



              title: 'No payments yet',



              subtitle: 'Payments you receive will appear here.',



            )



          else



            ...TransactionService.transactions.take(5).map(



              (transaction) {



                return _PaymentPreviewCard(



                  customerName: transaction.customerName,



                  amount: transaction.amount,



                  date: _formatDate(transaction.transactionDate),



                  onTap: _openPayments,



                );



              },



            ),



        ],



      ),



    );



  }







  Widget _buildCustomersTab() {



    return Column(



      children: [



        Padding(



          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),



          child: Column(



            crossAxisAlignment: CrossAxisAlignment.start,



            children: [



              const Text(



                'Customers',



                style: TextStyle(



                  fontSize: 28,



                  fontWeight: FontWeight.w800,



                  letterSpacing: -0.5,



                ),



              ),



              const SizedBox(height: 4),



              Text(



                '${CustomerService.customers.length} customers available',



                style: TextStyle(



                  color: Theme.of(context)



                      .colorScheme



                      .onSurfaceVariant,



                ),



              ),



              const SizedBox(height: 16),



              TextField(



                controller: searchController,



                onChanged: (_) {



                  setState(() {});



                },



                textInputAction: TextInputAction.search,



                decoration: InputDecoration(



                  hintText: 'Search business, location or phone',



                  prefixIcon: const Icon(Icons.search_rounded),



                  suffixIcon: searchController.text.isEmpty



                      ? null



                      : IconButton(



                          onPressed: () {



                            searchController.clear();



                            setState(() {});



                          },



                          icon: const Icon(Icons.close_rounded),



                        ),



                  filled: true,



                  fillColor: Theme.of(context)



                      .colorScheme



                      .surfaceContainerHighest



                      .withValues(alpha: 0.55),



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



                    borderSide: BorderSide(



                      color: Theme.of(context).colorScheme.primary,



                      width: 1.5,



                    ),



                  ),



                ),



              ),



            ],



          ),



        ),



        Expanded(



          child: filteredCustomers.isEmpty



              ? _EmptyState(



                  icon: Icons.search_off_rounded,



                  title: 'No customers found',



                  subtitle: searchController.text.trim().isEmpty



                      ? 'There are no customers available.'



                      : 'Try a different business name, location or phone number.',



                )



              : RefreshIndicator(



                  onRefresh: _loadData,



                  child: ListView.builder(



                    physics: const AlwaysScrollableScrollPhysics(),



                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),



                    itemCount: filteredCustomers.length,



                    itemBuilder: (context, index) {



                      final customer = filteredCustomers[index];







                      final balance =



                          TransactionService.getCurrentBalance(



                        customerId: customer.id,



                        openingBalance: customer.openingBalance,



                      );







                      return _CustomerCard(



                        customer: customer,



                        balance: balance,



                        onTap: () => _openCustomer(customer),



                        onPayment: balance > 0



                            ? () => _openPaymentScreen(customer)



                            : null,



                      );



                    },



                  ),



                ),



        ),



      ],



    );



  }







  Widget _buildPaymentsTab() {



    final todayCollection = TransactionService.getCollectedToday();



    final paymentCount = TransactionService.transactions.length;







    return ListView(



      physics: const AlwaysScrollableScrollPhysics(),



      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),



      children: [



        Row(



          children: [



            const Expanded(



              child: Column(



                crossAxisAlignment: CrossAxisAlignment.start,



                children: [



                  Text(



                    'Payments',



                    style: TextStyle(



                      fontSize: 28,



                      fontWeight: FontWeight.w800,



                      letterSpacing: -0.5,



                    ),



                  ),



                  SizedBox(height: 4),



                  Text(



                    'All payments received',



                  ),



                ],



              ),



            ),



            IconButton.filledTonal(



              tooltip: 'Refresh',



              onPressed: _loadData,



              icon: const Icon(Icons.refresh_rounded),



            ),



          ],



        ),







        const SizedBox(height: 22),







        Row(



          children: [



            Expanded(



              child: _MiniSummaryCard(



                icon: Icons.payments_outlined,



                title: 'Today',



                value: '₹${todayCollection.toStringAsFixed(2)}',



              ),



            ),



            const SizedBox(width: 12),



            Expanded(



              child: _MiniSummaryCard(



                icon: Icons.receipt_long_outlined,



                title: 'Transactions',



                value: paymentCount.toString(),



              ),



            ),



          ],



        ),







        const SizedBox(height: 24),







        Container(



          padding: const EdgeInsets.all(22),



          decoration: BoxDecoration(



            color: Theme.of(context)



                .colorScheme



                .surfaceContainerHighest



                .withValues(alpha: 0.45),



            borderRadius: BorderRadius.circular(22),



            border: Border.all(



              color: Theme.of(context)



                  .colorScheme



                  .outlineVariant



                  .withValues(alpha: 0.5),



            ),



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



                  Icons.receipt_long_rounded,



                  size: 38,



                  color: Theme.of(context)



                      .colorScheme



                      .onPrimaryContainer,



                ),



              ),



              const SizedBox(height: 18),



              const Text(



                'Payment History',



                style: TextStyle(



                  fontSize: 21,



                  fontWeight: FontWeight.w800,



                ),



              ),



              const SizedBox(height: 8),



              Text(



                'View payment amounts, customers, signatures and transaction details.',



                textAlign: TextAlign.center,



                style: TextStyle(



                  color: Theme.of(context)



                      .colorScheme



                      .onSurfaceVariant,



                  height: 1.45,



                ),



              ),



              const SizedBox(height: 20),



              SizedBox(



                width: double.infinity,



                child: FilledButton.icon(



                  onPressed: _openPayments,



                  icon: const Icon(Icons.open_in_new_rounded),



                  label: const Text('Open Payment History'),



                ),



              ),



            ],



          ),



        ),



      ],



    );



  }







  Widget _buildMoreTab() {



    return ListView(



      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),



      children: [



        const Text(



          'More',



          style: TextStyle(



            fontSize: 28,



            fontWeight: FontWeight.w800,



            letterSpacing: -0.5,



          ),



        ),



        const SizedBox(height: 4),



        Text(



          'Account and app settings',



          style: TextStyle(



            color: Theme.of(context)



                .colorScheme



                .onSurfaceVariant,



          ),



        ),







        const SizedBox(height: 22),







        Container(



          padding: const EdgeInsets.all(18),



          decoration: BoxDecoration(



            color: Theme.of(context)



                .colorScheme



                .surfaceContainerHighest



                .withValues(alpha: 0.55),



            borderRadius: BorderRadius.circular(20),



          ),



          child: Row(



            children: [



              _ProfileAvatar(



                initials: _getInitials(widget.userName),



                radius: 28,



              ),



              const SizedBox(width: 14),



              Expanded(



                child: Column(



                  crossAxisAlignment: CrossAxisAlignment.start,



                  children: [



                    Text(



                      widget.userName,



                      maxLines: 1,



                      overflow: TextOverflow.ellipsis,



                      style: const TextStyle(



                        fontWeight: FontWeight.w800,



                        fontSize: 17,



                      ),



                    ),



                    const SizedBox(height: 3),



                    Text(



                      'Salesman account',



                      style: TextStyle(



                        color: Theme.of(context)



                            .colorScheme



                            .onSurfaceVariant,



                      ),



                    ),



                  ],



                ),



              ),



            ],



          ),



        ),







        const SizedBox(height: 16),







        Container(



          decoration: BoxDecoration(



            color: Theme.of(context).colorScheme.surface,



            borderRadius: BorderRadius.circular(20),



            border: Border.all(



              color: Theme.of(context)



                  .colorScheme



                  .outlineVariant



                  .withValues(alpha: 0.55),



            ),



          ),



          child: Column(



            children: [



              _MoreTile(



                icon: Icons.settings_outlined,



                title: 'Settings',



                subtitle: 'Appearance and preferences',



                onTap: _openSettings,



              ),



              _MoreDivider(),



              _MoreTile(



                icon: Icons.refresh_rounded,



                title: 'Refresh Data',



                subtitle: 'Get the latest customers and payments',



                onTap: _loadData,



              ),



              _MoreDivider(),



              _MoreTile(



                icon: Icons.info_outline_rounded,



                title: 'About',



                subtitle: 'Business Payment App',



                onTap: () {



                  showAboutDialog(



                    context: context,



                    applicationName: 'Business Payment App',



                    applicationVersion: '1.0.0',



                    applicationIcon: const Icon(



                      Icons.account_balance_wallet_rounded,



                      size: 40,



                    ),



                    children: const [



                      Text(



                        'A business payment and customer ledger application.',



                      ),



                    ],



                  );



                },



              ),



            ],



          ),



        ),







        const SizedBox(height: 16),







        Container(



          decoration: BoxDecoration(



            color: Theme.of(context)



                .colorScheme



                .errorContainer



                .withValues(alpha: 0.35),



            borderRadius: BorderRadius.circular(20),



          ),



          child: ListTile(



            contentPadding: const EdgeInsets.symmetric(



              horizontal: 18,



              vertical: 5,



            ),



            leading: Icon(



              Icons.logout_rounded,



              color: Theme.of(context).colorScheme.error,



            ),



            title: Text(



              'Log out',



              style: TextStyle(



                color: Theme.of(context).colorScheme.error,



                fontWeight: FontWeight.w700,



              ),



            ),



            subtitle: const Text(



              'Sign out of this account',



            ),



            onTap: _logout,



          ),



        ),







        const SizedBox(height: 28),







        Center(



          child: Text(



            'Business Payment App',



            style: TextStyle(



              color: Theme.of(context)



                  .colorScheme



                  .onSurfaceVariant,



              fontSize: 12,



            ),



          ),



        ),



      ],



    );



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







  String _getInitials(String name) {



    final parts = name.trim().split(RegExp(r'\s+'));







    if (parts.isEmpty || parts.first.isEmpty) {



      return 'S';



    }







    if (parts.length == 1) {



      return parts.first[0].toUpperCase();



    }







    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();



  }







  String _formatDate(DateTime date) {



    return '${date.day.toString().padLeft(2, '0')}/'



        '${date.month.toString().padLeft(2, '0')}/'



        '${date.year}';



  }







  String _formatCompactAmount(double amount) {



    if (amount >= 100000) {



      return '₹${(amount / 100000).toStringAsFixed(1)}L';



    }







    if (amount >= 1000) {



      return '₹${(amount / 1000).toStringAsFixed(1)}K';



    }







    return '₹${amount.toStringAsFixed(0)}';



  }







  @override



  void dispose() {



    _presenceTimer?.cancel();

    _forceLogoutChannel?.unsubscribe();

    searchController.dispose();



    super.dispose();



  }







  @override



  Widget build(BuildContext context) {



    final pages = [



      _buildHomeTab(),



      _buildCustomersTab(),



      _buildPaymentsTab(),



      _buildMoreTab(),



    ];







    final titles = [



      'Salesman',



      'Customers',



      'Payments',



      'More',



    ];







    return Scaffold(



      appBar: AppBar(



        title: Text(



          titles[selectedIndex],



          style: const TextStyle(



            fontWeight: FontWeight.w700,



          ),



        ),



        actions: [



          if (selectedIndex == 0)



            IconButton(



              tooltip: 'Refresh',



              onPressed: _loadData,



              icon: const Icon(Icons.refresh_rounded),



            ),



          const SizedBox(width: 4),



        ],



      ),



      body: isLoading



          ? const Center(



              child: CircularProgressIndicator(),



            )



          : IndexedStack(



              index: selectedIndex,



              children: pages,



            ),



      bottomNavigationBar: NavigationBar(



        selectedIndex: selectedIndex,



        onDestinationSelected: (index) {



          setState(() {



            selectedIndex = index;



          });



        },



        destinations: const [



          NavigationDestination(



            icon: Icon(Icons.home_outlined),



            selectedIcon: Icon(Icons.home_rounded),



            label: 'Home',



          ),



          NavigationDestination(



            icon: Icon(Icons.people_outline_rounded),



            selectedIcon: Icon(Icons.people_rounded),



            label: 'Customers',



          ),



          NavigationDestination(



            icon: Icon(Icons.receipt_long_outlined),



            selectedIcon: Icon(Icons.receipt_long_rounded),



            label: 'Payments',



          ),



          NavigationDestination(



            icon: Icon(Icons.more_horiz_rounded),



            selectedIcon: Icon(Icons.more_horiz_rounded),



            label: 'More',



          ),



        ],



      ),



    );



  }



}







// ============================================================



// PROFILE AVATAR



// ============================================================







class _ProfileAvatar extends StatelessWidget {



  final String initials;



  final double radius;







  const _ProfileAvatar({



    required this.initials,



    this.radius = 24,



  });







  @override



  Widget build(BuildContext context) {



    return CircleAvatar(



      radius: radius,



      backgroundColor:



          Theme.of(context).colorScheme.primaryContainer,



      child: Text(



        initials,



        style: TextStyle(



          color: Theme.of(context)



              .colorScheme



              .onPrimaryContainer,



          fontSize: radius * 0.62,



          fontWeight: FontWeight.w800,



        ),



      ),



    );



  }



}







// ============================================================



// STAT CARD



// ============================================================







class _StatCard extends StatelessWidget {



  final IconData icon;



  final String title;



  final String value;







  const _StatCard({



    required this.icon,



    required this.title,



    required this.value,



  });







  @override



  Widget build(BuildContext context) {



    return Container(



      padding: const EdgeInsets.all(18),



      decoration: BoxDecoration(



        color: Theme.of(context)



            .colorScheme



            .surfaceContainerHighest



            .withValues(alpha: 0.65),



        borderRadius: BorderRadius.circular(18),



        border: Border.all(



          color: Theme.of(context)



              .colorScheme



              .outlineVariant



              .withValues(alpha: 0.4),



        ),



      ),



      child: Column(



        crossAxisAlignment: CrossAxisAlignment.start,



        children: [



          Icon(



            icon,



            size: 24,



            color: Theme.of(context).colorScheme.primary,



          ),



          const SizedBox(height: 14),



          Text(



            value,



            maxLines: 1,



            overflow: TextOverflow.ellipsis,



            style: const TextStyle(



              fontSize: 22,



              fontWeight: FontWeight.w800,



              letterSpacing: -0.4,



            ),



          ),



          const SizedBox(height: 3),



          Text(



            title,



            style: TextStyle(



              fontSize: 12,



              color: Theme.of(context)



                  .colorScheme



                  .onSurfaceVariant,



            ),



          ),



        ],



      ),



    );



  }



}







// ============================================================



// MINI SUMMARY CARD



// ============================================================







class _MiniSummaryCard extends StatelessWidget {



  final IconData icon;



  final String title;



  final String value;







  const _MiniSummaryCard({



    required this.icon,



    required this.title,



    required this.value,



  });







  @override



  Widget build(BuildContext context) {



    return Container(



      padding: const EdgeInsets.all(17),



      decoration: BoxDecoration(



        color: Theme.of(context)



            .colorScheme



            .surfaceContainerHighest



            .withValues(alpha: 0.65),



        borderRadius: BorderRadius.circular(18),



      ),



      child: Row(



        children: [



          Container(



            padding: const EdgeInsets.all(9),



            decoration: BoxDecoration(



              color: Theme.of(context)



                  .colorScheme



                  .primaryContainer,



              borderRadius: BorderRadius.circular(12),



            ),



            child: Icon(



              icon,



              size: 20,



              color: Theme.of(context)



                  .colorScheme



                  .onPrimaryContainer,



            ),



          ),



          const SizedBox(width: 10),



          Expanded(



            child: Column(



              crossAxisAlignment: CrossAxisAlignment.start,



              children: [



                Text(



                  title,



                  style: TextStyle(



                    fontSize: 12,



                    color: Theme.of(context)



                        .colorScheme



                        .onSurfaceVariant,



                  ),



                ),



                const SizedBox(height: 3),



                Text(



                  value,



                  maxLines: 1,



                  overflow: TextOverflow.ellipsis,



                  style: const TextStyle(



                    fontSize: 17,



                    fontWeight: FontWeight.w800,



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



// QUICK ACTION



// ============================================================







class _QuickAction extends StatelessWidget {



  final IconData icon;



  final String title;



  final String subtitle;



  final VoidCallback onTap;







  const _QuickAction({



    required this.icon,



    required this.title,



    required this.subtitle,



    required this.onTap,



  });







  @override



  Widget build(BuildContext context) {



    return Material(



      color: Theme.of(context).colorScheme.surface,



      borderRadius: BorderRadius.circular(18),



      child: InkWell(



        onTap: onTap,



        borderRadius: BorderRadius.circular(18),



        child: Container(



          padding: const EdgeInsets.all(15),



          decoration: BoxDecoration(



            borderRadius: BorderRadius.circular(18),



            border: Border.all(



              color: Theme.of(context)



                  .colorScheme



                  .outlineVariant



                  .withValues(alpha: 0.55),



            ),



          ),



          child: Row(



            children: [



              Container(



                padding: const EdgeInsets.all(10),



                decoration: BoxDecoration(



                  color: Theme.of(context)



                      .colorScheme



                      .primaryContainer,



                  borderRadius: BorderRadius.circular(12),



                ),



                child: Icon(



                  icon,



                  color: Theme.of(context)



                      .colorScheme



                      .onPrimaryContainer,



                  size: 21,



                ),



              ),



              const SizedBox(width: 10),



              Expanded(



                child: Column(



                  crossAxisAlignment: CrossAxisAlignment.start,



                  children: [



                    Text(



                      title,



                      maxLines: 1,



                      overflow: TextOverflow.ellipsis,



                      style: const TextStyle(



                        fontWeight: FontWeight.w700,



                        fontSize: 13,



                      ),



                    ),



                    const SizedBox(height: 3),



                    Text(



                      subtitle,



                      maxLines: 1,



                      overflow: TextOverflow.ellipsis,



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



            ],



          ),



        ),



      ),



    );



  }



}







// ============================================================



// CUSTOMER CARD



// ============================================================







class _CustomerCard extends StatelessWidget {



  final Customer customer;



  final double balance;



  final VoidCallback onTap;



  final VoidCallback? onPayment;







  const _CustomerCard({



    required this.customer,



    required this.balance,



    required this.onTap,



    this.onPayment,



  });







  @override



  Widget build(BuildContext context) {



    final hasBalance = balance > 0;







    return Container(



      margin: const EdgeInsets.only(bottom: 12),



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



      child: InkWell(



        onTap: onTap,



        borderRadius: BorderRadius.circular(20),



        child: Padding(



          padding: const EdgeInsets.all(16),



          child: Row(



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



                  Icons.storefront_outlined,



                  color: Theme.of(context)



                      .colorScheme



                      .onPrimaryContainer,



                ),



              ),



              const SizedBox(width: 13),



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



                      ),



                    ),



                    const SizedBox(height: 5),



                    Row(



                      children: [



                        Icon(



                          Icons.location_on_outlined,



                          size: 14,



                          color: Theme.of(context)



                              .colorScheme



                              .onSurfaceVariant,



                        ),



                        const SizedBox(width: 3),



                        Expanded(



                          child: Text(



                            customer.location,



                            maxLines: 1,



                            overflow: TextOverflow.ellipsis,



                            style: TextStyle(



                              fontSize: 12,



                              color: Theme.of(context)



                                  .colorScheme



                                  .onSurfaceVariant,



                            ),



                          ),



                        ),



                      ],



                    ),



                    const SizedBox(height: 8),



                    Row(



                      children: [



                        Text(



                          '₹${balance.toStringAsFixed(2)}',



                          style: TextStyle(



                            fontWeight: FontWeight.w800,



                            fontSize: 14,



                            color: hasBalance



                                ? Theme.of(context)



                                    .colorScheme



                                    .error



                                : Colors.green.shade700,



                          ),



                        ),



                        const SizedBox(width: 5),



                        Text(



                          hasBalance ? 'due' : 'paid',



                          style: TextStyle(



                            fontSize: 11,



                            color: hasBalance



                                ? Theme.of(context)



                                    .colorScheme



                                    .error



                                : Colors.green.shade700,



                            fontWeight: FontWeight.w600,



                          ),



                        ),



                      ],



                    ),



                  ],



                ),



              ),



              const SizedBox(width: 8),



              Column(



                children: [



                  const Icon(Icons.chevron_right_rounded),



                  if (onPayment != null)



                    IconButton(



                      tooltip: 'Receive payment',



                      visualDensity: VisualDensity.compact,



                      onPressed: onPayment,



                      icon: Icon(



                        Icons.payments_outlined,



                        color: Theme.of(context)



                            .colorScheme



                            .primary,



                      ),



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



// PAYMENT PREVIEW CARD



// ============================================================







class _PaymentPreviewCard extends StatelessWidget {



  final String customerName;



  final double amount;



  final String date;



  final VoidCallback onTap;







  const _PaymentPreviewCard({



    required this.customerName,



    required this.amount,



    required this.date,



    required this.onTap,



  });







  @override



  Widget build(BuildContext context) {



    return Container(



      margin: const EdgeInsets.only(bottom: 9),



      decoration: BoxDecoration(



        color: Theme.of(context).colorScheme.surface,



        borderRadius: BorderRadius.circular(16),



        border: Border.all(



          color: Theme.of(context)



              .colorScheme



              .outlineVariant



              .withValues(alpha: 0.45),



        ),



      ),



      child: ListTile(



        onTap: onTap,



        contentPadding: const EdgeInsets.symmetric(



          horizontal: 14,



          vertical: 4,



        ),



        leading: Container(



          padding: const EdgeInsets.all(10),



          decoration: BoxDecoration(



            color: Theme.of(context)



                .colorScheme



                .primaryContainer,



            borderRadius: BorderRadius.circular(12),



          ),



          child: Icon(



            Icons.payments_outlined,



            color: Theme.of(context)



                .colorScheme



                .onPrimaryContainer,



          ),



        ),



        title: Text(



          customerName,



          maxLines: 1,



          overflow: TextOverflow.ellipsis,



          style: const TextStyle(



            fontWeight: FontWeight.w700,



          ),



        ),



        subtitle: Padding(



          padding: const EdgeInsets.only(top: 3),



          child: Text(date),



        ),



        trailing: Text(



          '+ ₹${amount.toStringAsFixed(2)}',



          style: TextStyle(



            fontWeight: FontWeight.w800,



            color: Colors.green.shade700,



          ),



        ),



      ),



    );



  }



}







// ============================================================



// EMPTY STATE



// ============================================================







class _EmptyState extends StatelessWidget {



  final IconData icon;



  final String title;



  final String subtitle;







  const _EmptyState({



    required this.icon,



    required this.title,



    required this.subtitle,



  });







  @override



  Widget build(BuildContext context) {



    return Container(



      margin: const EdgeInsets.only(top: 12),



      padding: const EdgeInsets.all(28),



      decoration: BoxDecoration(



        color: Theme.of(context)



            .colorScheme



            .surfaceContainerHighest



            .withValues(alpha: 0.4),



        borderRadius: BorderRadius.circular(20),



      ),



      child: Column(



        children: [



          Container(



            padding: const EdgeInsets.all(16),



            decoration: BoxDecoration(



              color: Theme.of(context)



                  .colorScheme



                  .primaryContainer,



              shape: BoxShape.circle,



            ),



            child: Icon(



              icon,



              size: 30,



              color: Theme.of(context)



                  .colorScheme



                  .onPrimaryContainer,



            ),



          ),



          const SizedBox(height: 14),



          Text(



            title,



            textAlign: TextAlign.center,



            style: const TextStyle(



              fontSize: 16,



              fontWeight: FontWeight.w800,



            ),



          ),



          const SizedBox(height: 6),



          Text(



            subtitle,



            textAlign: TextAlign.center,



            style: TextStyle(



              color: Theme.of(context)



                  .colorScheme



                  .onSurfaceVariant,



              height: 1.4,



              fontSize: 13,



            ),



          ),



        ],



      ),



    );



  }



}







// ============================================================



// MORE TILE



// ============================================================







class _MoreTile extends StatelessWidget {



  final IconData icon;



  final String title;



  final String subtitle;



  final VoidCallback onTap;







  const _MoreTile({



    required this.icon,



    required this.title,



    required this.subtitle,



    required this.onTap,



  });







  @override



  Widget build(BuildContext context) {



    return ListTile(



      contentPadding: const EdgeInsets.symmetric(



        horizontal: 18,



        vertical: 5,



      ),



      leading: Container(



        padding: const EdgeInsets.all(9),



        decoration: BoxDecoration(



          color: Theme.of(context)



              .colorScheme



              .primaryContainer,



          borderRadius: BorderRadius.circular(11),



        ),



        child: Icon(



          icon,



          size: 20,



          color: Theme.of(context)



              .colorScheme



              .onPrimaryContainer,



        ),



      ),



      title: Text(



        title,



        style: const TextStyle(



          fontWeight: FontWeight.w700,



        ),



      ),



      subtitle: Text(subtitle),



      trailing: const Icon(Icons.chevron_right_rounded),



      onTap: onTap,



    );



  }



}







class _MoreDivider extends StatelessWidget {



  @override



  Widget build(BuildContext context) {



    return Divider(



      height: 1,



      indent: 18,



      endIndent: 18,



      color: Theme.of(context)



          .colorScheme



          .outlineVariant



          .withValues(alpha: 0.4),



    );



  }



}




