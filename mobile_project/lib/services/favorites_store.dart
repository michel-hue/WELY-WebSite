class FavoritesStore {
  static final FavoritesStore instance = FavoritesStore._();
  FavoritesStore._();
  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  bool isFavorite(String id) => _items.any((e) => e['id']?.toString() == id);
  void toggle(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null) return;
    final idx = _items.indexWhere((e) => e['id']?.toString() == id);
    if (idx >= 0) {
      _items.removeAt(idx);
    } else {
      _items.add(Map<String, dynamic>.from(item));
    }
  }
  void remove(String id) => _items.removeWhere((e) => e['id']?.toString() == id);
}