import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'my_listings_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _message;

  Future<void> _login() async {
    try {
      await _auth.login(_email.text, _password.text);
      setState(() => _message = 'Connecté');
    } catch (e) {
      setState(() => _message = e.toString());
    }
  }

  Future<void> _register() async {
    try {
      await _auth.register(_email.text, _password.text, 'buyer');
      setState(() => _message = 'Compte créé');
    } catch (e) {
      setState(() => _message = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: _password, decoration: const InputDecoration(labelText: 'Mot de passe'), obscureText: true),
          Row(
            children: [
              ElevatedButton(onPressed: _login, child: const Text('Connexion')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _register, child: const Text('Inscription')),
            ],
          ),
          if (_message != null) Text(_message!),
          const Divider(),
          ListTile(title: const Text('Mes annonces (vendeur)'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyListingsScreen()))),
          ListTile(title: const Text('Créer un bien (vendeur)'), onTap: () {}),
          ListTile(title: const Text('Demandes de réservation'), onTap: () {}),
        ],
      ),
    );
  }
}