import 'package:flutter/material.dart';
import '../services/listings_service.dart';

class CreateListingScreen extends StatelessWidget {
  const CreateListingScreen({super.key});
  @override
  Widget build(BuildContext context) => const _ListingForm(isEdit: false);
}

class EditListingScreen extends StatelessWidget {
  final Map<String, dynamic> listing;
  const EditListingScreen({super.key, required this.listing});
  @override
  Widget build(BuildContext context) => _ListingForm(isEdit: true, listing: listing);
}

class _ListingForm extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? listing;
  const _ListingForm({required this.isEdit, this.listing});
  @override
  State<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<_ListingForm> {
  final _service = ListingsService();
  final _title = TextEditingController();
  final _city = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  final _imagePath = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final l = widget.listing;
    if (l != null) {
      _title.text = l['title']?.toString() ?? '';
      _city.text = l['city']?.toString() ?? '';
      _price.text = l['price']?.toString() ?? '';
      _desc.text = l['description']?.toString() ?? '';
    }
  }



  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final payload = {
        'title': _title.text,
        'city': _city.text,
        'price': _price.text,
        'description': _desc.text,
      };
      String id;
      if (widget.isEdit) {
        final res = await _service.updateListing(widget.listing!['id'].toString(), payload);
        id = res['id']?.toString() ?? widget.listing!['id'].toString();
      } else {
        final res = await _service.createListing(payload);
        id = res['id']?.toString() ?? '';
      }
      if (_imagePath.text.isNotEmpty && id.isNotEmpty) {
        await _service.uploadImage(id, _imagePath.text);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Modifier' : 'Créer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Titre')),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'Ville')),
            TextField(controller: _price, decoration: const InputDecoration(labelText: 'Prix')),
            TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 8),
            TextField(controller: _imagePath, decoration: const InputDecoration(labelText: 'Chemin image (optionnel)')),
            const Spacer(),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _busy ? null : _submit, child: _busy ? const CircularProgressIndicator() : const Text('Enregistrer'))),
          ],
        ),
      ),
    );
  }
}