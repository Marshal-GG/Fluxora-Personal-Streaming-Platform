# Polar.sh Webhook Integration

## Overview
Fluxora integrates with [Polar.sh](https://polar.sh/) to process payments and issue license keys to users automatically. The server listens for specific webhook events (like `order.paid`) from Polar to verify purchases and allocate license keys.

## Architecture & Flow
1. **Endpoint**: `POST /api/v1/webhook/polar`
2. **Signature Verification**: Every request is verified using the `webhook-signature`, `webhook-id`, and `webhook-timestamp` headers against the `POLAR_WEBHOOK_SECRET` defined in the `.env` file.
3. **Event Processing**: The server parses the payload. If the event is `order.paid`, it extracts the tier and order ID.
4. **Key Generation**: A license key is generated via `services.webhook_service` (e.g., `FLUXORA-PLUS-20270429-77CCAC88`).
5. **Database Storage**: The order details and license key are stored in the local SQLite database (`fluxora.db`) under the `polar_orders` table.

## Database Schema
The `polar_orders` table ensures idempotent processing of webhooks:
```sql
CREATE TABLE IF NOT EXISTS polar_orders (
    order_id       TEXT PRIMARY KEY,          -- Polar order ID
    tier           TEXT NOT NULL,             -- plus | pro | ultimate
    license_key    TEXT NOT NULL,             -- the generated FLUXORA-... key
    processed_at   TEXT NOT NULL              -- ISO-8601 UTC datetime
);
```

## Local Development & Testing Guide
Because webhooks require a publicly accessible URL, local development requires a tunneling service. We use **smee.io** because it is a reliable polling client that avoids common NAT/firewall disconnection issues (unlike localtunnel or free SSH proxies).

### 1. Prerequisites
Ensure you have Node.js installed, then you can run the smee-client via `npx`.
Ensure your local Fluxora server is running on `127.0.0.1:8080`.

### 2. Start the Smee Client
Run the following command to forward payloads from smee.io to your local server:
```bash
npx smee-client --url https://smee.io/WkO5Z0u3uE5cM0d --target http://127.0.0.1:8080/api/v1/webhook/polar
```
*Note: We explicitly use `127.0.0.1` instead of `localhost` to avoid Node.js IPv6 `::1` resolution issues when Uvicorn is bound to IPv4 `0.0.0.0`.*

### 3. Configure Polar Dashboard
1. Go to Polar Dashboard -> Settings -> Webhooks.
2. Add a new endpoint with the exact URL: `https://smee.io/WkO5Z0u3uE5cM0d`
3. Check the events you want to subscribe to (e.g., `order.paid`).
4. Copy the generated **Webhook Secret**.

### 4. Configure Local Environment
1. Open `C:\Users\marsh\AppData\Roaming\Fluxora\.env`
2. Update the secret:
   ```env
   POLAR_WEBHOOK_SECRET=your_new_secret_here
   FLUXORA_LICENSE_SECRET=your_32_byte_hex_secret_here
   ```
3. Restart the Fluxora server so it loads the new configuration.

### 5. Triggering a Test Event
1. In Polar Sandbox, simulate an order or use a 100% discount code at checkout.
2. If an event fails initially, you can navigate to the **Deliveries** tab under Webhooks in Polar and click **Retry**.
3. Check your server console for `200 OK` and license generation logs.

## Security Considerations & Trade-offs
- **Webhook Secrets**: The `POLAR_WEBHOOK_SECRET` must never be committed to source control.
- **Signature Verification**: Ensure the server validates signatures before parsing the body. Unsigned or invalid requests are rejected with `403 Forbidden`.

### License Key Security Model
Fluxora is a self-hosted desktop application, which inherently means the user has full control over their local environment and the `fluxora.db` SQLite database.

1. **No Hardware Node-Locking (Currently)**: License keys encode the tier and expiry date (e.g., `FLUXORA-PLUS-20270429-77CCAC88`) and are signed cryptographically via HMAC-SHA256, but they **do not** contain a hardware ID or machine fingerprint. 
2. **Key Sharing**: Because there is no hardware binding or central activation check ("phoning home") upon startup, a valid key can technically be shared and injected into another user's local database.
3. **Cryptographic vs DRM Security**: The system relies on an **honor system backed by cryptography**. The cryptographic signature prevents users from using a keygen to create fake keys. However, it does not use strict DRM (Digital Rights Management) to prevent a valid key from being copied. Strict DRM in self-hosted apps is easily bypassed by users who can modify their local database to simply update the tier column.

### Future Security Enhancements
If key sharing becomes an issue, future phases (Phase 5/6) may implement:
- **Online Activation**: Requiring the app to register a Hardware ID with a central server (`api.fluxora.com/activate`) to receive an activation token.
- **Key Revocation**: Monitoring Polar.sh / activation servers for abnormally high IP counts per key and revoking them via a blocklist synced to the desktop app.
