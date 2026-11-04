import 'package:flutter/material.dart';
import '../services/favorites_store.dart';
import '../services/reservations_service.dart';

class ListingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> listing;
  const ListingDetailScreen({super.key, required this.listing});
  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _reservations = ReservationsService();
  bool _busy = false;

  Future<void> _reserve() async {
    setState(() => _busy = true);
    try {
      await _reservations.createReservation({'listingId': widget.listing['id']});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réservation créée')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final fav = FavoritesStore.instance.isFavorite(l['id']?.toString() ?? '');
    return Scaffold(
      appBar: AppBar(title: Text(l['title']?.toString() ?? 'Bien')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l['city']?.toString() ?? ''),
            const SizedBox(height: 8),
            Text(l['price']?.toString() ?? ''),
            const SizedBox(height: 8),
            Text(l['description']?.toString() ?? ''),
            const Spacer(),
            Row(
              children: [
                IconButton(
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
                  onPressed: () {
                    FavoritesStore.instance.toggle(l);
                    setState(() {});
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _reserve,
                    child: _busy ? const CircularProgressIndicator() : const Text('Réserver'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}