import 'package:flutter/material.dart';
import '../services/reservations_service.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});
  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final _service = ReservationsService();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.fetchReservations();
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!), ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
      ]));
    }
    if (_items.isEmpty) return const Center(child: Text('Aucune réservation'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i] as Map<String, dynamic>;
          return ListTile(
            title: Text(item['listingTitle']?.toString() ?? 'Réservation'),
            subtitle: Text('${item['startDate'] ?? ''} → ${item['endDate'] ?? ''}'),
            trailing: Text(item['status']?.toString() ?? ''),
          );
        },
      ),
    );
  }
}