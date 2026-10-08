import 'package:flutter/material.dart';



import 'add_customer_screen.dart';

import 'customer_details_screen.dart';

import '../../models/customer.dart';

import '../../services/customer_service.dart';

import '../../services/transaction_service.dart';



class CustomersScreen extends StatefulWidget {

  const CustomersScreen({

    super.key,

  });



  @override

  State<CustomersScreen> createState() =>

      _CustomersScreenState();

}



class _CustomersScreenState

    extends State<CustomersScreen> {

  final TextEditingController _searchController =

      TextEditingController();



  String _searchQuery = '';



  @override

  void initState() {

    super.initState();



    _loadData();



    _searchController.addListener(() {

      setState(() {

        _searchQuery =

            _searchController.text.trim().toLowerCase();

      });

    });

  }



  Future<void> _loadData() async {

    await CustomerService.loadCustomers();

    await TransactionService.loadCustomerBalances();



    if (mounted) {

      setState(() {});

    }

  }



  @override

  void dispose() {

    _searchController.dispose();

    super.dispose();

  }



  List<Customer> get _filteredCustomers {

    if (_searchQuery.isEmpty) {

      return CustomerService.customers;

    }



    return CustomerService.customers.where((customer) {

      return customer.businessName

              .toLowerCase()

              .contains(_searchQuery) ||

          customer.location

              .toLowerCase()

              .contains(_searchQuery) ||

          customer.phone

              .toLowerCase()

              .contains(_searchQuery);

    }).toList();

  }



  Future<void> _addCustomer() async {

    final result =

        await Navigator.push<bool>(

      context,

      MaterialPageRoute(

        builder: (context) =>

            const AddCustomerScreen(),

      ),

    );



    if (result == true) {

      await _loadData();

    }

  }



  Future<void> _openCustomer(

    Customer customer,

  ) async {

    await Navigator.push(

      context,

      MaterialPageRoute(

        builder: (context) =>

            CustomerDetailsScreen(

          customer: customer,

        ),

      ),

    );



    await _loadData();

  }



  Future<void> _deleteCustomer(

    Customer customer,

  ) async {

    final shouldDelete =

        await showDialog<bool>(

      context: context,

      builder: (dialogContext) {

        return AlertDialog(

          title: const Text(

            'Remove Customer?',

          ),

          content: Text(

            'Are you sure you want to remove '

            '"${customer.businessName}"?\n\n'

            'The customer will be removed from the '

            'active customer list, but their purchase '

            'and payment history will be preserved.',

          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(

                  dialogContext,

                  false,

                );

              },

              child: const Text(

                'Cancel',

              ),

            ),

            FilledButton(

              onPressed: () {

                Navigator.pop(

                  dialogContext,

                  true,

                );

              },

              child: const Text(

                'Remove',

              ),

            ),

          ],

        );

      },

    );



    if (shouldDelete != true) {

      return;

    }



    final success =

        await CustomerService.deleteCustomer(

      customer.id,

    );



    if (!mounted) {

      return;

    }



    if (success) {

      ScaffoldMessenger.of(context)

          .showSnackBar(

        SnackBar(

          content: Text(

            '${customer.businessName} was removed.',

          ),

        ),

      );



      await _loadData();

    } else {

      ScaffoldMessenger.of(context)

          .showSnackBar(

        SnackBar(

          content: Text(

            CustomerService.errorMessage ??

                'Could not remove customer.',

          ),

        ),

      );

    }

  }



  @override

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF0F766E);
    final accentLight = isDark ? const Color(0xFF2A9D8F) : accent;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Customers',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        backgroundColor: accentLight,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Add Customer',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: accentLight,
        backgroundColor: theme.colorScheme.surface,
        onRefresh: _loadData,
        child: ValueListenableBuilder<int>(
          valueListenable: CustomerService.dataVersion,
          builder: (context, customerVersion, child) {
            return ValueListenableBuilder<int>(
              valueListenable: TransactionService.dataVersion,
              builder: (context, transactionVersion, child) {
                final customers = _filteredCustomers;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search customers...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () => _searchController.clear(),
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF121918)
                              : const Color(0xFFF3F6F5),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 18,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF26302E)
                                  : const Color(0xFFE2E9E7),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: customers.isEmpty
                          ? _EmptyCustomers(
                              hasSearch: _searchQuery.isNotEmpty,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                              itemCount: customers.length,
                              itemBuilder: (context, index) {
                                final customer = customers[index];
                                final balance =
                                    TransactionService.getCustomerBalance(customer.id);
                                return _CustomerCard(
                                  customer: customer,
                                  balance: balance,
                                  onTap: () => _openCustomer(customer),
                                  onDelete: () => _deleteCustomer(customer),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

}

// CUSTOMER CARD

// -----------------------------------------------------------------------------



class _CustomerCard

    extends StatelessWidget {

  final Customer customer;

  final double balance;

  final VoidCallback onTap;

  final VoidCallback onDelete;



  const _CustomerCard({

    required this.customer,

    required this.balance,

    required this.onTap,

    required this.onDelete,

  });



  @override

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF0F766E);
    final accentLight = isDark ? const Color(0xFF2A9D8F) : accent;
    final hasDue = balance > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121918) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF26302E) : const Color(0xFFE5EBE9),
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentLight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    customer.businessName.isNotEmpty
                        ? customer.businessName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: accentLight,
                      fontSize: 19,
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
                        customer.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 15,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              customer.location,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 15,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Text(
                            customer.phone,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasDue ? 'Amount Due' : 'Paid',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₹${balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: hasDue ? theme.colorScheme.error : accentLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_right_rounded,
                            size: 19,
                            color: theme.colorScheme.onSurfaceVariant),
                        PopupMenuButton<String>(
                          tooltip: 'Customer options',
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_horiz_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant),
                          onSelected: (value) {
                            if (value == 'delete') onDelete();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline),
                                  SizedBox(width: 10),
                                  Text('Remove Customer'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// EMPTY STATE

// -----------------------------------------------------------------------------



class _EmptyCustomers

    extends StatelessWidget {

  final bool hasSearch;



  const _EmptyCustomers({

    required this.hasSearch,

  });



  @override

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF0F766E);
    final isDark = theme.brightness == Brightness.dark;
    final accentLight = isDark ? const Color(0xFF2A9D8F) : accent;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: accentLight.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.people_outline_rounded,
                size: 38,
                color: accentLight,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch ? 'No customers found' : 'No customers yet',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try a different search.'
                  : 'Add your first customer using the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
