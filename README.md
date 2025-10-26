# PKCEAuthiOS (Flutter)

Manual implementation of the OAuth 2.0 Authorization Code Flow with PKCE (RFC 7636) for iOS — without external OAuth libraries.

## Overview

This app is a public client for the OAuth 2.0 Authorization Code Flow with PKCE (no client secret embedded). The default redirect URI is:

- `com.pkceauth.ios:/callback`

Learn more here:
- PKCE (RFC 7636): https://datatracker.ietf.org/doc/html/rfc7636
- OAuth 2.0 for Native Apps (RFC 8252/BCP): https://datatracker.ietf.org/doc/html/rfc8252

## Requirements & architecture

- Target platform: iOS
- No external OAuth libraries (only: `http`, `crypto`, `url_launcher`, plus Dart standard packages)
- Authorization Server (local):
  - Authorize: `http://localhost:9001/authorize`
  - Token: `http://localhost:9001/token`
- Redirect URI (custom scheme): `com.pkceauth.ios:/callback`

### Components

- `lib/home_screen.dart` — UI with a "Login" button; shows the access token. Buttons to call resources (Profile/Read/Write) with SnackBar output.
- `lib/auth_service.dart` — PKCE logic: generate `code_verifier` and `code_challenge`, open the browser, handle the redirect, exchange the token. Uses `AuthConfig` for endpoints.
- `lib/settings.dart` — `AuthConfig` (defaults) and `SettingsSheet` (top-right gear) to edit Redirect URI, endpoints, Client ID, and scope at runtime.
- `lib/callback_handler.dart` — Bridges iOS AppDelegate with Flutter (MethodChannel) and exposes redirect URLs
- `ios/Runner/AppDelegate.swift` — Intercepts `application:openURL:` and sends the redirect URL to Flutter
- `ios/Runner/Info.plist` — Registers the `com.pkceauth.ios` scheme and allows HTTP to `localhost` (dev only)

## Configuration

1) App configuration

- Runtime: Open the gear icon (Settings) on the Home screen to adjust Redirect URI, Authorization/Token endpoints, Resource endpoints, Client ID, and scope.
- Defaults: See `lib/settings.dart` → `AuthConfig.defaults()` (e.g., `http://localhost:9001` for AS and `http://localhost:9002/resource/...` for RS, redirect URI `com.pkceauth.ios:/callback`).
- Ensure the same redirect URI is registered with your Authorization Server.

2) iOS redirect & ATS

- `ios/Runner/Info.plist` already contains:
  - `CFBundleURLTypes` with `com.pkceauth.ios`
  - `NSAppTransportSecurity` allowing `http://localhost` (development)

## Run

```bash
flutter pub get
flutter run -d ios
```

Make sure the Authorization Server is running on port 9001 (and optionally the resource on 9002) before starting the login.

## Flow (short)

1. Create a `code_verifier` (random string) and `code_challenge` (SHA-256 + base64url without padding)
2. Open Safari with `/authorize?response_type=code&client_id=...&redirect_uri=...&code_challenge=...&code_challenge_method=S256&state=...`
3. After successful authentication, iOS returns to `com.pkceauth.ios:/callback?code=...&state=...`
4. AppDelegate delivers the redirect URL to Flutter via a MethodChannel
5. Flutter extracts the `code` and exchanges it at `/token` for an access token (including the `code_verifier`)
6. The UI shows the access token. You can call protected resources via the buttons (Profile/Read via GET, Write via POST):
  - `http://localhost:9002/resource/profile`
  - `http://localhost:9002/resource/read`
  - `http://localhost:9002/resource/write` (POST)
  Each request sends `Authorization: Bearer <token>` and shows the JSON in a SnackBar.

## Troubleshooting

- No return to the app? Check that the `com.pkceauth.ios` scheme is registered as a redirect URI with your Authorization Server.
- `NSAppTransportSecurity`/HTTP errors: Ensure `Info.plist` has development exceptions for `localhost`.
- `invalid_client` etc.: The client ID does not match the server configuration.
- iOS Simulator and `localhost`: The iOS Simulator uses the host machine's `localhost` — that's usually correct. On real devices, use the host IP on the same network and adjust the endpoints.

## Security

- Sensitive data (access token) is not persisted (memory only).
- `state` is generated and verified (CSRF protection).

