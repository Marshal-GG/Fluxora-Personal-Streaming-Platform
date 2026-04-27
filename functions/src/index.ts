import { onRequest } from 'firebase-functions/v2/https'
import { logger } from 'firebase-functions'

// Phase 3 — WebRTC signaling relay
// Allows two Fluxora clients to negotiate a peer-to-peer connection
// when both are outside the home LAN.
// export const signalingRelay = onRequest(...)

// Phase 3 — FCM push notifications
// Notifies mobile clients when a stream session starts or a new
// device requests pairing.
// export const notifyPairingRequest = onDocumentCreated(...)

// Phase 3 — Subscription webhook
// Handles incoming webhooks from the payment provider and updates
// the user's subscription status in Firestore.
// export const subscriptionWebhook = onRequest(...)

export const health = onRequest((req, res) => {
  logger.info('health check', { structuredData: true })
  res.json({ status: 'ok', version: '0.1.0' })
})
