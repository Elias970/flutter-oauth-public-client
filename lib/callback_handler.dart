import 'dart:async';

import 'package:flutter/services.dart';

/// Handles the incoming OAuth redirect on iOS via a MethodChannel.
///
/// iOS sends the redirect URL (com.pkceauth.ios:/callback?code=...) from
/// AppDelegate to Flutter over the channel named 'com.pkceauth.ios/auth'.
/// This class exposes a broadcast stream of [Uri]s and a helper to read any
/// initial/pending URL that may have arrived before Dart was ready.
class CallbackHandler {
  CallbackHandler._internal();
  static final CallbackHandler instance = CallbackHandler._internal();

  static const MethodChannel _channel = MethodChannel('com.pkceauth.ios/auth');

  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  /// Stream of incoming redirect URIs.
  Stream<Uri> get onRedirect => _controller.stream;

  bool _initialized = false;

  /// Initialize the method call handler once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAuthRedirect') {
        final String? url = call.arguments as String?;
        if (url != null && url.isNotEmpty) {
          _controller.add(Uri.parse(url));
        }
      }
    });
  }

  /// Retrieve an initial/pending redirect URL if the app was launched by one.
  Future<Uri?> getInitialRedirectUri() async {
    try {
      final String? url = await _channel.invokeMethod<String>('getInitialUrl');
      if (url == null || url.isEmpty) return null;
      return Uri.parse(url);
    } on PlatformException {
      return null;
    }
  }

  /// Wait for the next redirect URI, with an optional timeout.
  Future<Uri> waitForNextRedirect({Duration timeout = const Duration(minutes: 3)}) async {
    return onRedirect.first.timeout(timeout);
  }
}
