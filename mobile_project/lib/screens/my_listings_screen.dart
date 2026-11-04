import 'package:flutter/material.dart';
import '../services/listings_service.dart';
import 'listing_form_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});
  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _service = ListingsService();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.fetchListings();
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _service.deleteListing(id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), ElevatedButton(onPressed: _load, child: const Text('Réessayer'))]));
    return Scaffold(
      appBar: AppBar(title: const Text('Mes annonces')),
      body: _items.isEmpty
          ? const Center(child: Text('Aucune annonce'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i] as Map<String, dynamic>;
                final id = item['id']?.toString() ?? '';
                return ListTile(
                  title: Text(item['title']?.toString() ?? 'Bien'),
                  subtitle: Text(item['city']?.toString() ?? ''),
                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(id)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditListingScreen(listing: item))),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateListingScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}