import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed route selection and daily customer visit status service.
class SalesmanVisitService {
  SalesmanVisitService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String _todayKey() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to record a route or visit.');
    }
    return userId;
  }

  static Future<List<String>> loadTodayRoute() async {
    final userId = _requireUserId();
    final row = await _client
        .from('salesman_daily_route_selections')
        .select('locations')
        .eq('salesman_id', userId)
        .eq('route_date', _todayKey())
        .maybeSingle();

    if (row == null) return <String>[];
    final value = row['locations'];
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return <String>[];
  }

  static Future<void> saveTodayRoute(List<String> locations) async {
    final userId = _requireUserId();
    final cleaned =
        locations
            .map((location) => location.trim())
            .where((location) => location.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Delete today's previous selection before inserting the replacement.
    // This does not affect historical route dates.
    await _client
        .from('salesman_daily_route_selections')
        .delete()
        .eq('salesman_id', userId)
        .eq('route_date', _todayKey());

    if (cleaned.isNotEmpty) {
      await _client.from('salesman_daily_route_selections').insert({
        'salesman_id': userId,
        'route_date': _todayKey(),
        'locations': cleaned,
      });
    }
  }

  static Future<Map<String, String>> loadTodayStatuses() async {
    final rows = await _client
        .from('salesman_customer_daily_status')
        .select('customer_id, status')
        .eq('status_date', _todayKey());

    final result = <String, String>{};
    for (final row in rows) {
      final customerId = row['customer_id']?.toString();
      final status = row['status']?.toString();
      if (customerId != null && status != null) {
        result[customerId] = status;
      }
    }
    return result;
  }

  static Future<Position> captureLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Turn on location services and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is permanently denied. Enable it in system settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  static Future<void> recordStatus({
    required String customerId,
    required String status,
    Position? capturedPosition,
    String? note,
  }) async {
    if (status != 'paid' && status != 'rejected') {
      throw ArgumentError.value(status, 'status', 'Expected paid or rejected.');
    }

    final position = capturedPosition ?? await captureLocation();
    await _client.rpc(
      'record_salesman_customer_status',
      params: {
        'p_customer_id': customerId,
        'p_status': status,
        'p_latitude': position.latitude,
        'p_longitude': position.longitude,
        'p_accuracy_meters': position.accuracy,
        'p_note': note,
      },
    );
  }
}
