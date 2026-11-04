import 'package:flutter/material.dart';
import '../services/listings_service.dart';
import '../services/favorites_store.dart';
import 'listing_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _service = ListingsService();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchListings();
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Aucun bien trouvé'));
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final item = _items[i] as Map<String, dynamic>;
        return ListTile(
          title: Text(item['title']?.toString() ?? 'Bien'),
          subtitle: Text(item['city']?.toString() ?? ''),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item['price']?.toString() ?? ''),
              IconButton(
                icon: Icon(FavoritesStore.instance.isFavorite(item['id']?.toString() ?? '') ? Icons.favorite : Icons.favorite_border),
                onPressed: () { FavoritesStore.instance.toggle(item); setState(() {}); },
              ),
            ],
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: item))),
        );
      },
    );
  }
}