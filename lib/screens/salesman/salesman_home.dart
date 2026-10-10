import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/customer.dart';

import 'salesman_customer_screen.dart';

import 'salesman_payments_screen.dart';

import '../../services/customer_service.dart';

import '../../services/transaction_service.dart';

import '../../services/salesman_visit_service.dart';

import '../settings/settings_screen.dart';

class SalesmanHome extends StatefulWidget {
  final String userName;

  const SalesmanHome({super.key, required this.userName});

  @override
  State<SalesmanHome> createState() => _SalesmanHomeState();
}

class _SalesmanHomeState extends State<SalesmanHome> {
  final TextEditingController searchController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;

  int selectedIndex = 0;

  String customerStatusFilter = 'All';

  bool isLoading = true;

  List<String> selectedRouteLocations = <String>[];

  Position? _currentPosition;
  bool _locationUnavailable = false;

  Map<String, String> todaysCustomerStatuses = <String, String>{};

  Timer? _presenceTimer;

  RealtimeChannel? _forceLogoutChannel;

  bool _presenceCheckRunning = false;

  bool _forcedLogoutInProgress = false;

  @override
  void initState() {
    super.initState();

    _loadData();
    _loadCurrentLocation();

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
            final forceLogoutAt = payload.newRecord['force_logout_at'];

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

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationUnavailable = true);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationUnavailable = true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locationUnavailable = false;
      });
    } catch (error) {
      debugPrint('Could not get current map location: $error');
      if (mounted) setState(() => _locationUnavailable = true);
    }
  }

  Future<void> _openDirections(Customer customer) async {
    final destination =
        '${customer.businessName}, ${customer.location}, Kerala, India';
    final origin = _currentPosition == null
        ? ''
        : '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1$origin&destination=${Uri.encodeComponent(destination)}&travelmode=driving',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open directions. Please check your browser or maps app.',
          ),
        ),
      );
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

    try {
      selectedRouteLocations = await SalesmanVisitService.loadTodayRoute();

      todaysCustomerStatuses = await SalesmanVisitService.loadTodayStatuses();
    } catch (error) {
      debugPrint('Could not load route/status data: $error');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  List<Customer> get routeCustomers {
    return CustomerService.customers.where((customer) {
      return selectedRouteLocations.contains(customer.location.trim());
    }).toList();
  }

  List<Customer> get filteredCustomers {
    final query = searchController.text.trim().toLowerCase();

    return routeCustomers.where((customer) {
      final matchesSearch =
          query.isEmpty ||
          customer.businessName.toLowerCase().contains(query) ||
          customer.location.toLowerCase().contains(query) ||
          customer.phone.contains(query);
      final status = todaysCustomerStatuses[customer.id];
      final matchesStatus = switch (customerStatusFilter) {
        'Pending' => status == null,
        'Visited' => status != null,
        _ => true,
      };
      return matchesSearch && matchesStatus;
    }).toList();
  }

  int _statusCount(String filter) {
    return routeCustomers.where((customer) {
      final status = todaysCustomerStatuses[customer.id];
      return switch (filter) {
        'Pending' => status == null,
        'Visited' => status != null,
        _ => true,
      };
    }).length;
  }

  String _statusLabel(Customer customer) {
    final status = todaysCustomerStatuses[customer.id];
    if (status == 'paid') return 'Visited';
    if (status == 'rejected') return 'No Payment';
    return 'Pending';
  }

  Future<void> _chooseTodayRoute() async {
    final locations =
        CustomerService.customers
            .map((customer) => customer.location.trim())
            .where((location) => location.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final draft = selectedRouteLocations.toSet();

    final saved = await showDialog<bool>(
      context: context,

      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Today's route"),

          content: SizedBox(
            width: 420,

            child: locations.isEmpty
                ? const Text('No customer locations are available yet.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: locations
                          .map(
                            (location) => CheckboxListTile(
                              value: draft.contains(location),

                              title: Text(location),

                              dense: true,

                              contentPadding: EdgeInsets.zero,

                              controlAffinity: ListTileControlAffinity.leading,

                              onChanged: (checked) => setDialogState(() {
                                if (checked == true) {
                                  draft.add(location);
                                } else {
                                  draft.remove(location);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save route'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      await SalesmanVisitService.saveTodayRoute(draft.toList());

      if (!mounted) return;

      setState(() => selectedRouteLocations = draft.toList());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.isEmpty
                ? 'No locations selected. Customer list is empty until you choose a route.'
                : 'Route saved for today.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save route: $error')));
    }
  }

  Future<void> _openCustomer(Customer customer) async {
    try {
      todaysCustomerStatuses = await SalesmanVisitService.loadTodayStatuses();
      if (!mounted) return;

      if (todaysCustomerStatuses.containsKey(customer.id)) {
        if (mounted) {
          setState(() {});

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This customer already has a recorded outcome today.',
              ),
            ),
          );
        }

        return;
      }
    } catch (error) {
      debugPrint('Could not refresh customer visit status: $error');
    }

    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => SalesmanCustomerDetailsScreen(customer: customer),
      ),
    );

    await _loadData();
  }

  void _openPayments() {
    Navigator.push(
      context,

      MaterialPageRoute(builder: (_) => const SalesmanPaymentsScreen()),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) =>
            SettingsScreen(role: 'salesman', userName: widget.userName),
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

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Widget _buildHomeTab() {
    final route = routeCustomers;
    final visited = route
        .where((c) => todaysCustomerStatuses[c.id] == 'paid')
        .length;
    final noPayment = route
        .where((c) => todaysCustomerStatuses[c.id] == 'rejected')
        .length;
    final pending = route
        .where((c) => !todaysCustomerStatuses.containsKey(c.id))
        .length;
    final remaining = pending;
    final nextLocation = selectedRouteLocations.isEmpty
        ? 'Choose a location'
        : selectedRouteLocations.first;
    const purple = Color(0xFF5B3FE4);
    const ink = Color(0xFF25233A);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Good morning,',
                      style: TextStyle(fontSize: 12, color: Color(0xFF77768A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: _loadData,
                icon: const Icon(Icons.notifications_none_rounded, color: ink),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFAFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E2F1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: purple,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Route",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6E6B7D),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        nextLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${route.length} customers',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF77768A),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _chooseTodayRoute,
                  style: TextButton.styleFrom(
                    foregroundColor: purple,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SalesmanStatusCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Visited',
                  value: '$visited',
                  color: const Color(0xFF159B68),
                  background: const Color(0xFFEAF8F2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SalesmanStatusCard(
                  icon: Icons.schedule_rounded,
                  label: 'Pending',
                  value: '$pending',
                  color: const Color(0xFFE5A12B),
                  background: const Color(0xFFFFF5E6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SalesmanStatusCard(
                  icon: Icons.cancel_rounded,
                  label: 'No Payment',
                  value: '$noPayment',
                  color: const Color(0xFFE55362),
                  background: const Color(0xFFFFEFF0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SalesmanStatusCard(
                  icon: Icons.pending_actions_rounded,
                  label: 'Remaining',
                  value: '$remaining',
                  color: purple,
                  background: const Color(0xFFF0EDFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (selectedRouteLocations.isEmpty) {
                  _chooseTodayRoute();
                } else {
                  setState(() => selectedIndex = 2);
                }
              },
              child: const Text(
                'Start Route',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Payments',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openPayments,
                child: const Text(
                  'View all',
                  style: TextStyle(color: purple, fontSize: 12),
                ),
              ),
            ],
          ),
          if (TransactionService.transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No payments received yet',
                  style: TextStyle(color: Color(0xFF77768A), fontSize: 12),
                ),
              ),
            )
          else
            ...TransactionService.transactions
                .take(4)
                .map(
                  (transaction) => _PaymentPreviewCard(
                    customerName: transaction.customerName,
                    amount: transaction.amount,
                    date: _formatDate(transaction.transactionDate),
                    onTap: _openPayments,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCustomersTab() {
    const purple = Color(0xFF5B3FE4);
    const ink = Color(0xFF202033);
    final filters = ['All', 'Pending', 'Visited'];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to home',
                  onPressed: () => setState(() => selectedIndex = 0),
                  icon: const Icon(Icons.arrow_back_rounded, size: 21),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    "Today's Customers",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.45,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search customer...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8B8DA0),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                filled: true,
                fillColor: const Color(0xFFF7F7FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xFFE8E8F1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xFFE8E8F1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: purple, width: 1.2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
            child: Row(
              children: filters.map((filter) {
                final selected = customerStatusFilter == filter;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: filter == filters.last ? 0 : 7,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          setState(() => customerStatusFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? purple : const Color(0xFFF6F6FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? purple : const Color(0xFFE7E7F0),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$filter (${_statusCount(filter)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF45465B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filteredCustomers.isEmpty
                ? RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 65),
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 42,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            searchController.text.trim().isNotEmpty
                                ? 'No matching customers'
                                : 'No customers in this filter',
                            style: const TextStyle(
                              color: Color(0xFF77798B),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 3, 20, 18),
                      itemCount: filteredCustomers.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        thickness: 0.6,
                        indent: 47,
                        color: Color(0xFFEDEDF3),
                      ),
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        final status = _statusLabel(customer);
                        final statusColor = switch (status) {
                          'Visited' => const Color(0xFF27845B),
                          'No Payment' => const Color(0xFFD64A55),
                          _ => const Color(0xFFD58B28),
                        };
                        final initials = customer.businessName
                            .trim()
                            .split(RegExp(r'\s+'))
                            .where((part) => part.isNotEmpty)
                            .take(2)
                            .map((part) => part[0].toUpperCase())
                            .join();
                        final avatarColors = const [
                          Color(0xFFE0D9FF),
                          Color(0xFFDCE9FF),
                          Color(0xFFE9DFFF),
                          Color(0xFFD9F0EB),
                        ];
                        return InkWell(
                          onTap: () => _openCustomer(customer),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 1,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 35,
                                  height: 35,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        avatarColors[index %
                                            avatarColors.length],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials.isEmpty ? '?' : initials,
                                    style: const TextStyle(
                                      color: Color(0xFF5142A5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.businessName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: ink,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 11,
                                            color: Color(0xFF85879A),
                                          ),
                                          const SizedBox(width: 2),
                                          Expanded(
                                            child: Text(
                                              customer.location,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF85879A),
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 17,
                                  color: Color(0xFF85879A),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTab() {
    const ink = Color(0xFF25233A);
    final customers = routeCustomers;
    final unvisitedCustomers = customers
        .where((customer) => !todaysCustomerStatuses.containsKey(customer.id))
        .toList();
    final Customer? nextCustomer = unvisitedCustomers.isEmpty
        ? null
        : unvisitedCustomers.first;
    final currentPoint = _currentPosition == null
        ? null
        : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    // The Customer model currently stores a business name, location text and phone,
    // but not latitude/longitude. The real map therefore shows the actual current
    // GPS location; customer pins/route geometry require coordinates saved per customer.
    const fallbackCenter = LatLng(
      9.755,
      77.115,
    ); // Kattappana town fallback only.

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => selectedIndex = 0),
                  icon: const Icon(Icons.arrow_back_rounded),
                  visualDensity: VisualDensity.compact,
                ),
                const Expanded(
                  child: Text(
                    "Today's Route (Map)",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await _loadCurrentLocation();
                    await _loadData();
                  },
                  icon: const Icon(Icons.my_location_rounded),
                  tooltip: 'Refresh my location and route',
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    key: ValueKey(
                      currentPoint?.toString() ?? 'route-map-fallback',
                    ),
                    options: MapOptions(
                      initialCenter: currentPoint ?? fallbackCenter,
                      initialZoom: currentPoint == null ? 13.0 : 15.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.example.business_payment_app',
                      ),
                      if (currentPoint != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: currentPoint,
                              width: 48,
                              height: 48,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2587F7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 7,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.my_location_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      RichAttributionWidget(
                        alignment: AttributionAlignment.bottomRight,
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_locationUnavailable)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 3,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'Showing the route area. Enable location permission to show your live position.',
                          style: TextStyle(fontSize: 12, color: ink),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 15,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nextCustomer?.businessName ??
                              (customers.isEmpty
                                  ? 'No route selected'
                                  : 'Route completed'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          nextCustomer == null
                              ? 'Choose customers for today or review your visits'
                              : 'Next stop · ${nextCustomer.location}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF77768A),
                          ),
                        ),
                        if (currentPoint == null) ...[
                          const SizedBox(height: 5),
                          const Text(
                            'Live location is unavailable. The map is centred on the selected route area.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF77768A),
                            ),
                          ),
                        ],
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: nextCustomer == null
                                    ? _chooseTodayRoute
                                    : () => _openDirections(nextCustomer),
                                icon: const Icon(
                                  Icons.directions_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Get Directions',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _chooseTodayRoute,
                              icon: const Icon(Icons.tune_rounded),
                              tooltip: 'Edit route',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 22),

        Container(
          padding: const EdgeInsets.all(18),

          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),

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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),

          child: Column(
            children: [
              _MoreTile(
                icon: Icons.receipt_long_outlined,
                title: 'Payments received',
                subtitle: 'View payment history and totals',
                onTap: _openPayments,
              ),
              _MoreDivider(),
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
            color: Theme.of(
              context,
            ).colorScheme.errorContainer.withValues(alpha: 0.35),

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

            subtitle: const Text('Sign out of this account'),

            onTap: _logout,
          ),
        ),

        const SizedBox(height: 28),

        Center(
          child: Text(
            'Business Payment App',

            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,

              fontSize: 12,
            ),
          ),
        ),
      ],
    );
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
      _buildMapTab(),
      _buildMoreTab(),
    ];

    final titles = [
      'LedgerPro',
      "Today's Customers",
      "Today's Route (Map)",
      'Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: selectedIndex == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B3FE4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LedgerPro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Business Ledger',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Text(
                titles[selectedIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
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
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: selectedIndex, children: pages),

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
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================================

class _SalesmanStatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;
  const _SalesmanStatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF555368),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  height: 1,
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Icon(icon, color: color, size: 21),
      ],
    ),
  );
}

// PROFILE AVATAR

// ============================================================

class _ProfileAvatar extends StatelessWidget {
  final String initials;

  final double radius;

  const _ProfileAvatar({required this.initials, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,

      backgroundColor: Theme.of(context).colorScheme.primaryContainer,

      child: Text(
        initials,

        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,

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

// ============================================================

// MINI SUMMARY CARD

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
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),

      child: ListTile(
        onTap: onTap,

        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),

        leading: Container(
          padding: const EdgeInsets.all(10),

          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,

            borderRadius: BorderRadius.circular(12),
          ),

          child: Icon(
            Icons.payments_outlined,

            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),

        title: Text(
          customerName,

          maxLines: 1,

          overflow: TextOverflow.ellipsis,

          style: const TextStyle(fontWeight: FontWeight.w700),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),

      leading: Container(
        padding: const EdgeInsets.all(9),

        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,

          borderRadius: BorderRadius.circular(11),
        ),

        child: Icon(
          icon,

          size: 20,

          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),

      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),

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

      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}
