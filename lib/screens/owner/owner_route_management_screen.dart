import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/customer.dart';
import '../../services/customer_service.dart';

/// Owner tools for reusable named routes and per-day location assignments.
/// Requires the SQL migration in owner_route_management_schema.sql.
enum OwnerRoutePage { places, salesmen, map }

class OwnerRouteManagementScreen extends StatefulWidget {
  final OwnerRoutePage page;
  const OwnerRouteManagementScreen({
    super.key,
    this.page = OwnerRoutePage.places,
  });

  @override
  State<OwnerRouteManagementScreen> createState() =>
      _OwnerRouteManagementScreenState();
}

class _OwnerRouteManagementScreenState
    extends State<OwnerRouteManagementScreen> {
  final _client = Supabase.instance.client;
  final _routeNameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _salesmen = [];
  final Map<String, List<String>> _todayAssignments = {};
  String? _selectedRouteId;
  String? _selectedSalesmanId;
  Set<String> _selectedLocations = {};

  List<String> get _availableLocations =>
      CustomerService.customers
          .map((Customer c) => c.location.trim())
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  Map<String, dynamic>? get _selectedRoute {
    for (final route in _routes) {
      if (route['id'].toString() == _selectedRouteId) return route;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CustomerService.loadCustomers();
      final now = DateTime.now();
      final todayKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final results = await Future.wait([
        _client
            .from('salesman_route_templates')
            .select('id, route_name, locations, updated_at')
            .order('route_name'),
        _client.from('profiles').select('id, name, role').order('name'),
        _client
            .from('salesman_daily_route_selections')
            .select('salesman_id, locations')
            .eq('route_date', todayKey),
      ]);
      final allProfiles = List<Map<String, dynamic>>.from(results[1] as List);
      final assignmentRows = List<Map<String, dynamic>>.from(
        results[2] as List,
      );
      final assignments = <String, List<String>>{};
      for (final row in assignmentRows) {
        final id = (row['salesman_id'] ?? '').toString();
        final rawLocations = row['locations'];
        if (id.isNotEmpty && rawLocations is List) {
          assignments[id] = rawLocations.map((e) => e.toString()).toList();
        }
      }
      final salesmen = allProfiles
          .where(
            (p) => (p['role'] ?? '').toString().toLowerCase() == 'salesman',
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _routes = List<Map<String, dynamic>>.from(results[0] as List);
        _salesmen = salesmen;
        _todayAssignments
          ..clear()
          ..addAll(assignments);
        _selectedRouteId ??= _routes.isEmpty
            ? null
            : _routes.first['id'].toString();
        _selectedSalesmanId ??= _salesmen.isEmpty
            ? null
            : _salesmen.first['id'].toString();
        _selectedLocations = _selectedRoute == null
            ? <String>{}
            : Set<String>.from(
                (_selectedRoute!['locations'] as List? ?? const []).map(
                  (e) => e.toString(),
                ),
              );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load routes. Check your connection and route setup.';
      });
      debugPrint('Owner route management load failed: $error');
    }
  }

  Future<void> _createRoute() async {
    final name = _routeNameController.text.trim();
    if (name.isEmpty) {
      _message('Enter a route name first.');
      return;
    }
    setState(() => _saving = true);
    try {
      final row = await _client
          .from('salesman_route_templates')
          .insert({'route_name': name, 'locations': <String>[]})
          .select('id, route_name, locations, updated_at')
          .single();
      if (!mounted) return;
      setState(() {
        _routes.add(Map<String, dynamic>.from(row));
        _routes.sort(
          (a, b) => a['route_name'].toString().toLowerCase().compareTo(
            b['route_name'].toString().toLowerCase(),
          ),
        );
        _selectedRouteId = row['id'].toString();
        _selectedLocations = <String>{};
        _routeNameController.clear();
      });
      _message('Route created. Select its locations below.');
    } catch (error) {
      debugPrint('Create route failed: $error');
      _message(
        'Could not create that route. Check whether the name already exists.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _renameRoute() async {
    final route = _selectedRoute;
    if (route == null) return;
    final controller = TextEditingController(
      text: route['route_name'].toString(),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename route'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Route name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save name'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null ||
        name.trim().isEmpty ||
        name.trim() == route['route_name'])
      return;
    setState(() => _saving = true);
    try {
      await _client
          .from('salesman_route_templates')
          .update({
            'route_name': name.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', route['id'].toString());
      if (!mounted) return;
      setState(() {
        final index = _routes.indexWhere(
          (r) => r['id'].toString() == route['id'].toString(),
        );
        if (index >= 0) {
          _routes[index] = {..._routes[index], 'route_name': name.trim()};
          _routes.sort(
            (a, b) => a['route_name'].toString().toLowerCase().compareTo(
              b['route_name'].toString().toLowerCase(),
            ),
          );
        }
      });
      _message('Route renamed to ${name.trim()}.');
    } catch (error) {
      debugPrint('Rename route failed: $error');
      _message(
        'Could not rename route. Make sure the name is not already in use.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveTemplateLocations() async {
    final route = _selectedRoute;
    if (route == null) return;
    setState(() => _saving = true);
    try {
      final locations = _selectedLocations.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await _client
          .from('salesman_route_templates')
          .update({
            'locations': locations,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', route['id'].toString());
      if (!mounted) return;
      setState(() {
        final index = _routes.indexWhere(
          (r) => r['id'].toString() == route['id'].toString(),
        );
        if (index >= 0)
          _routes[index] = {..._routes[index], 'locations': locations};
      });
      _message('Default locations saved for ${route['route_name']}.');
    } catch (error) {
      debugPrint('Save route locations failed: $error');
      _message('Could not save these locations. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _assignForToday() async {
    final route = _selectedRoute;
    final salesmanId = _selectedSalesmanId;
    if (route == null || salesmanId == null) {
      _message('Create a route and select a salesman first.');
      return;
    }
    setState(() => _saving = true);
    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final locations = _selectedLocations.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      // Replaces only this salesman's assignment for today; previous dates remain unchanged.
      await _client.from('salesman_daily_route_selections').upsert({
        'salesman_id': salesmanId,
        'route_date': dateKey,
        'locations': locations,
      }, onConflict: 'salesman_id,route_date');
      if (!mounted) return;
      _message('Today’s locations assigned to the selected salesman.');
    } catch (error) {
      debugPrint('Assign daily route failed: $error');
      _message(
        'Could not assign today’s route. Please check the route database setup.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRoute() async {
    final route = _selectedRoute;
    if (route == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete route?'),
        content: Text(
          'Delete the saved route “${route['route_name']}”? Past daily assignments will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _client
          .from('salesman_route_templates')
          .delete()
          .eq('id', route['id'].toString());
      if (!mounted) return;
      setState(() {
        _routes.removeWhere(
          (r) => r['id'].toString() == route['id'].toString(),
        );
        _selectedRouteId = _routes.isEmpty
            ? null
            : _routes.first['id'].toString();
        _selectedLocations = _selectedRoute == null
            ? <String>{}
            : Set<String>.from(
                (_selectedRoute!['locations'] as List? ?? const []).map(
                  (e) => e.toString(),
                ),
              );
      });
      _message('Route deleted.');
    } catch (error) {
      debugPrint('Delete route failed: $error');
      _message('Could not delete this route. Please try again.');
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(switch (widget.page) {
          OwnerRoutePage.places => 'Places & Routes',
          OwnerRoutePage.salesmen => 'Salesmen & Assigned Routes',
          OwnerRoutePage.map => 'Route Map View',
        }),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : widget.page == OwnerRoutePage.places
          ? ListView(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 12 : 20,
              ),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create a reusable route',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 420;
                            final routeNameField = TextField(
                              controller: _routeNameController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (!_saving) _createRoute();
                              },
                              decoration: const InputDecoration(
                                labelText: 'Route name',
                                hintText: 'e.g. ABC Route',
                              ),
                            );
                            final createButton = FilledButton.icon(
                              onPressed: _saving ? null : _createRoute,
                              icon: const Icon(Icons.add_road_rounded),
                              label: const Text('Create route'),
                            );
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  routeNameField,
                                  const SizedBox(height: 10),
                                  createButton,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: routeNameField),
                                const SizedBox(width: 10),
                                createButton,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configure locations for this route',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        if (_routes.isEmpty)
                          const Text('Create your first route to get started.')
                        else
                          DropdownButtonFormField<String>(
                            value: _selectedRouteId,
                            decoration: const InputDecoration(
                              labelText: 'Saved route',
                            ),
                            items: _routes
                                .map(
                                  (route) => DropdownMenuItem<String>(
                                    value: route['id'].toString(),
                                    child: Text(
                                      route['route_name'].toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (id) {
                              setState(() {
                                _selectedRouteId = id;
                                _selectedLocations = _selectedRoute == null
                                    ? <String>{}
                                    : Set<String>.from(
                                        (_selectedRoute!['locations']
                                                    as List? ??
                                                const [])
                                            .map((value) => value.toString()),
                                      );
                              });
                            },
                          ),
                        const SizedBox(height: 12),
                        if (_availableLocations.isEmpty)
                          const Text(
                            'Add customer locations before configuring a route.',
                          )
                        else
                          ..._availableLocations.map(
                            (location) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _selectedLocations.contains(location),
                              title: Text(location),
                              onChanged: _selectedRoute == null
                                  ? null
                                  : (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedLocations.add(location);
                                        } else {
                                          _selectedLocations.remove(location);
                                        }
                                      });
                                    },
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _saving || _selectedRoute == null
                                  ? null
                                  : _saveTemplateLocations,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save default locations'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saving || _selectedRoute == null
                                  ? null
                                  : _renameRoute,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Rename route'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saving || _selectedRoute == null
                                  ? null
                                  : _deleteRoute,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete route'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign locations for today',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Change the selected locations each day. '
                          'Yesterday’s assignment stays in history.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedSalesmanId,
                          decoration: const InputDecoration(
                            labelText: 'Salesman',
                          ),
                          items: _salesmen
                              .map(
                                (user) => DropdownMenuItem<String>(
                                  value: user['id'].toString(),
                                  child: Text(
                                    (user['name'] ?? 'Salesman').toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (id) =>
                              setState(() => _selectedSalesmanId = id),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              _saving ||
                                  _selectedRoute == null ||
                                  _selectedSalesmanId == null
                              ? null
                              : _assignForToday,
                          icon: const Icon(Icons.route_outlined),
                          label: const Text(
                            'Assign selected locations for today',
                          ),
                        ),
                        if (_salesmen.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'No salesman accounts were found. Add a user '
                              'with the Salesman role first.',
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : widget.page == OwnerRoutePage.salesmen
          ? _buildSalesmenPage()
          : _buildMapPage(),
    );
  }

  Widget _buildSalesmenPage() {
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 20),
      children: [
        const Text(
          'Salesmen and their assigned routes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Assignments are stored for today. Open Places & Routes to create or edit a named route and assign it.',
        ),
        const SizedBox(height: 12),
        if (_salesmen.isEmpty)
          const Text('No salesman accounts were found.')
        else
          ..._salesmen.map((salesman) {
            final salesmanId = (salesman['id'] ?? '').toString();
            final assignedLocations =
                _todayAssignments[salesmanId] ?? const <String>[];
            final normalizedAssigned = [...assignedLocations]
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            String? assignedRouteName;
            for (final route in _routes) {
              final templateLocations =
                  (route['locations'] as List? ?? const [])
                      .map((e) => e.toString())
                      .toList()
                    ..sort(
                      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                    );
              if (templateLocations.length == normalizedAssigned.length &&
                  List.generate(
                    templateLocations.length,
                    (i) => templateLocations[i] == normalizedAssigned[i],
                  ).every((same) => same)) {
                assignedRouteName = route['route_name'].toString();
                break;
              }
            }
            final subtitle = assignedLocations.isEmpty
                ? 'No route assigned for today'
                : '${assignedRouteName == null ? 'Assigned locations' : 'Route: $assignedRouteName'}\n${assignedLocations.join(' → ')}';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text((salesman['name'] ?? 'Salesman').toString()),
                subtitle: Text(subtitle),
                isThreeLine: assignedLocations.isNotEmpty,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMapPage() {
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 20),
      children: [
        const Text(
          'Saved route locations',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Review the locations saved under each route. Places & Routes is where you can edit them.',
        ),
        const SizedBox(height: 12),
        if (_routes.isEmpty)
          const Text('No routes created yet.')
        else
          ..._routes.map((route) {
            final locations = (route['locations'] as List? ?? const [])
                .map((e) => e.toString())
                .toList();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(route['route_name'].toString()),
                subtitle: Text(
                  locations.isEmpty
                      ? 'No locations added'
                      : locations.join(' → '),
                ),
              ),
            );
          }),
      ],
    );
  }
}
