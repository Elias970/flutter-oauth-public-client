import 'package:flutter/material.dart';

class AuthConfig {
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final String clientId;
  final Uri redirectUri;
  final String scope;
  final Uri resourceProfile;
  final Uri resourceRead;
  final Uri resourceWrite;

  const AuthConfig({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.clientId,
    required this.redirectUri,
    required this.scope,
    required this.resourceProfile,
    required this.resourceRead,
    required this.resourceWrite,
  });

  factory AuthConfig.defaults() => AuthConfig(
        authorizationEndpoint: Uri.parse('http://localhost:9001/authorize'),
        tokenEndpoint: Uri.parse('http://localhost:9001/token'),
        clientId: 'oauth-app-client-1',
        redirectUri: Uri.parse('com.pkceauth.ios:/callback'),
        scope: 'profile read write',
        resourceProfile: Uri.parse('http://localhost:9002/resource/profile'),
        resourceRead: Uri.parse('http://localhost:9002/resource/read'),
        resourceWrite: Uri.parse('http://localhost:9002/resource/write'),
      );
}

class SettingsSheet extends StatefulWidget {
  final AuthConfig initial;
  const SettingsSheet({super.key, required this.initial});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _clientId;
  late final TextEditingController _scope;
  late final TextEditingController _authEndpoint;
  late final TextEditingController _tokenEndpoint;
  late final TextEditingController _redirectUri;
  late final TextEditingController _resProfile;
  late final TextEditingController _resRead;
  late final TextEditingController _resWrite;

  @override
  void initState() {
    super.initState();
    _clientId = TextEditingController(text: widget.initial.clientId);
    _scope = TextEditingController(text: widget.initial.scope);
    _authEndpoint = TextEditingController(text: widget.initial.authorizationEndpoint.toString());
    _tokenEndpoint = TextEditingController(text: widget.initial.tokenEndpoint.toString());
    _redirectUri = TextEditingController(text: widget.initial.redirectUri.toString());
    _resProfile = TextEditingController(text: widget.initial.resourceProfile.toString());
    _resRead = TextEditingController(text: widget.initial.resourceRead.toString());
    _resWrite = TextEditingController(text: widget.initial.resourceWrite.toString());
  }

  @override
  void dispose() {
    _clientId.dispose();
    _scope.dispose();
    _authEndpoint.dispose();
    _tokenEndpoint.dispose();
    _redirectUri.dispose();
    _resProfile.dispose();
    _resRead.dispose();
    _resWrite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets + const EdgeInsets.all(16);
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Einstellungen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  tooltip: 'Schließen',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            _field('Client ID', _clientId),
            _field('Scope', _scope),
            _field('Authorization Endpoint', _authEndpoint),
            _field('Token Endpoint', _tokenEndpoint),
            _field('Redirect URI', _redirectUri),
            _field('Resource Profile', _resProfile),
            _field('Resource Read', _resRead),
            _field('Resource Write (POST)', _resWrite),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        minLines: 1,
        maxLines: 2,
      ),
    );
  }

  void _save() {
    try {
      final cfg = AuthConfig(
        authorizationEndpoint: Uri.parse(_authEndpoint.text.trim()),
        tokenEndpoint: Uri.parse(_tokenEndpoint.text.trim()),
        clientId: _clientId.text.trim(),
        redirectUri: Uri.parse(_redirectUri.text.trim()),
        scope: _scope.text.trim(),
        resourceProfile: Uri.parse(_resProfile.text.trim()),
        resourceRead: Uri.parse(_resRead.text.trim()),
        resourceWrite: Uri.parse(_resWrite.text.trim()),
      );
      Navigator.of(context).pop(cfg);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ungültige Eingabe: $e')),
      );
    }
  }
}
