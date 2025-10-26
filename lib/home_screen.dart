import 'dart:convert';
import 'package:flutter/material.dart';
import 'callback_handler.dart';

import 'auth_service.dart';
import 'settings.dart';

/// Simple UI:
/// - Shows a "Login" button to start the PKCE flow
/// - Displays the access token or an error message once the flow completes
/// - Bonus: fetches a protected resource with the access token and shows the response
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AuthService _auth;
  AuthConfig _config = AuthConfig.defaults();
  bool _loading = false;
  String? _accessToken;
  String? _lastRedirectUrl;

  @override
  void initState() {
    super.initState();
    _auth = AuthService(config: _config);
    // Listen for any redirect arriving at any time (useful for testing the scheme first).
    CallbackHandler.instance.initialize();
    CallbackHandler.instance.onRedirect.listen((uri) {
      setState(() {
        _lastRedirectUrl = uri.toString();
      });
    });
    // Also fetch any initial redirect that might have launched the app.
    CallbackHandler.instance.getInitialRedirectUri().then((uri) {
      if (uri != null) {
        setState(() {
          _lastRedirectUrl = uri.toString();
        });
      }
    });
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _accessToken = null;
    });
    try {
      final result = await _auth.authorize();
      setState(() {
        _accessToken = result.accessToken;
      });
    } catch (e) {
      // Show error via snackbar for better visibility
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login fehlgeschlagen: $e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchResource(String key) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (_accessToken == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Bitte zuerst einloggen.'),
      ));
      return;
    }
    try {
      final resp = await _auth.fetchResourceByKey(_accessToken!, key);
      String body = resp.body;
      try {
        final decoded = jsonDecode(body);
        body = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        // leave body as-is if not JSON
      }
      messenger.showSnackBar(SnackBar(
        content: Text(body),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Fehler beim Laden (${key}): $e'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PKCEAuthiOS'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OAuth 2.0 Authorization Code Flow with PKCE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Redirect monitor',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    _lastRedirectUrl == null
                        ? 'No redirect URL received yet.'
                        : _lastRedirectUrl!,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Access Token (letzte 10 Zeichen)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText(
                    _accessToken == null
                        ? 'Kein Access Token vorhanden.'
                        : (_accessToken!.length <= 10
                            ? _accessToken!
                            : _accessToken!.substring(_accessToken!.length - 10)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _login,
              icon: const Icon(Icons.login),
              label: const Text('Login'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: (_loading || _accessToken == null)
                      ? null
                      : () => _fetchResource('res1'),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Res 1'),
                ),
                ElevatedButton.icon(
                  onPressed: (_loading || _accessToken == null)
                      ? null
                      : () => _fetchResource('res2'),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Res 2'),
                ),
                ElevatedButton.icon(
                  onPressed: (_loading || _accessToken == null)
                      ? null
                      : () => _fetchResource('res3'),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Res 3'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final result = await showModalBottomSheet<AuthConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SettingsSheet(initial: _config),
    );
    if (result != null) {
      setState(() {
        _config = result;
        _auth = AuthService(config: _config);
        _accessToken = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Einstellungen gespeichert.')),
        );
      }
    }
  }
}

// SettingsSheet moved to settings.dart
