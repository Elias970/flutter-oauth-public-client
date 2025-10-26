# PKCEAuthiOS (Flutter)

Manual implementation of the OAuth 2.0 Authorization Code Flow with PKCE (RFC 7636) for iOS — without external OAuth libraries.

## Requirements & architecture

- Target platform: iOS
- No external OAuth libraries (only: `http`, `crypto`, `url_launcher`, plus Dart standard packages)
- Authorization Server (local):
  - Authorize: `http://localhost:9001/authorize`
  - Token: `http://localhost:9001/token`
- Redirect URI (custom scheme): `com.pkceauth.ios:/callback`

### Components

- `lib/home_screen.dart` — UI with a "Login" button; shows the access token and an optional resource response
- `lib/auth_service.dart` — PKCE logic: generate `code_verifier` and `code_challenge`, open the browser, handle the redirect, exchange the token
- `lib/callback_handler.dart` — Bridges iOS AppDelegate with Flutter (MethodChannel) and exposes redirect URLs
- `ios/Runner/AppDelegate.swift` — Intercepts `application:openURL:` and sends the redirect URL to Flutter
- `ios/Runner/Info.plist` — Registers the `com.pkceauth.ios` scheme and allows HTTP to `localhost` (dev only)

## Configuration

1) Open `lib/auth_service.dart` and adjust:

- `clientId` — your client ID registered with the Authorization Server
- Optional: `scope` — if your AS requires scopes
- Confirm that `redirectUri` = `com.pkceauth.ios:/callback` is registered on the server

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
6. The UI shows the access token; optionally perform a GET to `http://localhost:9002/resource` with `Authorization: Bearer <token>`

## Troubleshooting

- No return to the app? Check that the `com.pkceauth.ios` scheme is registered as a redirect URI with your Authorization Server.
- `NSAppTransportSecurity`/HTTP errors: Ensure `Info.plist` has development exceptions for `localhost`.
- `invalid_client` etc.: The client ID does not match the server configuration.
- iOS Simulator and `localhost`: The iOS Simulator uses the host machine's `localhost` — that's usually correct. On real devices, use the host IP on the same network and adjust the endpoints.

## Security

- Sensitive data (access token) is not persisted (memory only).
- `state` is generated and verified (CSRF protection).

