import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'callback_handler.dart';

/// Represents the outcome of the OAuth 2.0 Authorization Code + PKCE exchange.
class AuthResult {
  final String accessToken;
  final String? idToken;
  final String? refreshToken;
  final Map<String, dynamic> raw;

  AuthResult({
    required this.accessToken,
    required this.raw,
    this.idToken,
    this.refreshToken,
  });
}

/// A lightweight, manual implementation of OAuth 2.0 Authorization Code Flow
/// with PKCE (RFC 7636), without external OAuth libraries.
class AuthService {
  // --- Configuration (adjust to match your Authorization Server) ---
  final Uri authorizationEndpoint = Uri.parse('http://localhost:9001/authorize');
  final Uri tokenEndpoint = Uri.parse('http://localhost:9001/token');

  // The client identifier registered with the Authorization Server.
  // TODO: Change this to your actual client id.
  // Aligned with demo server registry
  final String clientId = 'oauth-app-client-1';

  // The custom scheme redirect URI that brings the user back into the app.
  // Must be registered in iOS Info.plist under CFBundleURLTypes.
  final Uri redirectUri = Uri.parse('com.pkceauth.ios:/callback');

  // The requested scopes (adjust as needed or leave empty if your AS doesn't require scopes).
  // Aligned with demo server registry
  final String scope = 'profile read write';

  // In-memory state for the latest login attempt (not persisted).
  String? _lastState;

  /// Starts the Authorization Code flow with PKCE.
  /// Steps:
  /// 1) Generate code_verifier and code_challenge
  /// 2) Build the /authorize URL and open Safari
  /// 3) Wait for the app to be opened via the redirect URI with an authorization code
  /// 4) Exchange the code for an access token at /token, including the code_verifier
  Future<AuthResult> authorize() async {
    // 1) Generate PKCE values
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _codeChallengeFor(codeVerifier);
    final state = _randomUrlSafeString(32);
    _lastState = state;

    // 2) Build the authorization URL
    final authUrl = authorizationEndpoint.replace(queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri.toString(),
      'scope': scope,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    // Initialize callback listener and check for any pending initial URL
    await CallbackHandler.instance.initialize();
    final initial = await CallbackHandler.instance.getInitialRedirectUri();
    if (initial != null) {
      // Clear any stale pending initial URL by ignoring it here; flow will await a fresh one.
    }

    // 3) Open the browser (Safari) to begin authentication - LaunchMode has more options
    final launched = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('Could not open the authorization link.');
    }

    // 4) Wait for redirect back to the app
    final redirect = await CallbackHandler.instance.waitForNextRedirect();

    // Parse query parameters from the redirect URL
    final qp = redirect.queryParameters;
    if (qp.containsKey('error')) {
      final err = qp['error'];
      final desc = qp['error_description'];
      throw Exception('Authorization error: $err ${desc ?? ''}'.trim());
    }

    final code = qp['code'];
    final returnedState = qp['state'];
    if (code == null || code.isEmpty) {
      throw Exception('No authorization code found in the redirect URL.');
    }
    if (returnedState == null || returnedState != _lastState) {
      throw Exception('Invalid or missing state — abort (CSRF protection).');
    }

    // 5) Exchange code for tokens at /token
    final token = await _exchangeCodeForToken(code, codeVerifier);
    return token;
  }

  /// Optional: Call a protected resource endpoint using the obtained access token.
  Future<http.Response> fetchResource(String accessToken) async {
    // Backwards-compatible: maps to res1
    return fetchResourceByKey(accessToken, 'res1');
  }

  /// Fetch a specific resource by key: 'res1', 'res2', or 'res3'.
  /// Mapping:
  ///  - res1 -> http://localhost:9002/resource (existing demo endpoint)
  ///  - res2 -> http://localhost:9002/resource2
  ///  - res3 -> http://localhost:9002/resource3
  Future<http.Response> fetchResourceByKey(String accessToken, String key) async {
    final pathMap = {
      'res1': '/resource/profile',
      'res2': '/resource/read',
      'res3': '/resource/write',
    };
    final path = pathMap[key] ?? '/resource';
    final uri = Uri.parse('http://localhost:9002$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    };

    if (key == 'res3') {
      // res3 requires POST
      return http.post(uri, headers: headers);
    }
    return http.get(uri, headers: headers);
  }

  // --- Internals ---

  Future<AuthResult> _exchangeCodeForToken(String code, String codeVerifier) async {
    final body = {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri.toString(),
      'client_id': clientId,
      'code_verifier': codeVerifier,
    };

    final resp = await http.post(
      tokenEndpoint,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: body,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Token endpoint error (${resp.statusCode}): ${resp.body}');
    }

    final Map<String, dynamic> jsonMap = json.decode(resp.body) as Map<String, dynamic>;
    final accessToken = jsonMap['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Response without access_token: ${resp.body}');
    }

    return AuthResult(
      accessToken: accessToken,
      idToken: jsonMap['id_token'] as String?,
      refreshToken: jsonMap['refresh_token'] as String?,
      raw: jsonMap,
    );
  }

  String _generateCodeVerifier({int length = 64}) {
    // RFC 7636: code_verifier must be between 43 and 128 chars from charset [A-Z a-z 0-9 - . _ ~]
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    final buff = StringBuffer();
    for (var i = 0; i < length; i++) {
      buff.write(charset[rand.nextInt(charset.length)]);
    }
    return buff.toString();
  }

  String _codeChallengeFor(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = crypto.sha256.convert(bytes);
    return _base64UrlNoPadding(digest.bytes);
  }

  String _randomUrlSafeString(int length) {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    final buff = StringBuffer();
    for (var i = 0; i < length; i++) {
      buff.write(charset[rand.nextInt(charset.length)]);
    }
    return buff.toString();
  }

  String _base64UrlNoPadding(List<int> bytes) {
    // base64Url.encode already uses - and _; just strip padding
    return base64Url.encode(Uint8List.fromList(bytes)).replaceAll('=', '');
  }
}
