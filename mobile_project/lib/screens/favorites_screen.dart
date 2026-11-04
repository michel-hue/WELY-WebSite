import 'package:flutter/material.dart';
import '../services/favorites_store.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    final items = FavoritesStore.instance.items;
    if (items.isEmpty) return const Center(child: Text('Aucun favori'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return ListTile(
          title: Text(item['title']?.toString() ?? 'Bien'),
          subtitle: Text(item['city']?.toString() ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              FavoritesStore.instance.remove(item['id']?.toString() ?? '');
              setState(() {});
            },
          ),
        );
      },
    );
  }
}