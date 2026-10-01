'use strict';

/**
 * Maintify Notification Server — FCM delivery module
 *
 * Responsibilities:
 *   - Initialize Firebase Admin SDK from environment variables
 *   - Fetch FCM tokens from Firestore users/{uid}.fcmToken
 *   - Send FCM via HTTP v1 (sendEachForMulticast)
 *   - Clean up stale/invalid tokens automatically
 *   - Verify Firebase Auth ID tokens
 *
 * Does NOT write to the notifications Firestore collection.
 * That is handled by the existing Cloud Functions triggered by Firestore writes.
 */

const admin = require('firebase-admin');

// ─────────────────────────────────────────────────────────────────────────────
// Firebase Admin SDK initialization (runs once at startup)
// ─────────────────────────────────────────────────────────────────────────────

let _initialized = false;

function _initFirebase() {
  if (_initialized) return;

  const projectId    = process.env.FIREBASE_PROJECT_ID;
  const clientEmail  = process.env.FIREBASE_CLIENT_EMAIL;
  // Render stores multi-line values with literal \n — replace them with real newlines
  const privateKey   = process.env.FIREBASE_PRIVATE_KEY
    ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
    : undefined;

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error(
      'Missing Firebase credentials. Set FIREBASE_PROJECT_ID, ' +
      'FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY environment variables.'
    );
  }

  admin.initializeApp({
    credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
  });

  _initialized = true;
  console.log('[FIREBASE] Admin SDK initialized — project:', projectId);
}

// Initialize immediately so startup failures are visible before the first request
try {
  _initFirebase();
} catch (e) {
  console.error('[FIREBASE] Initialization failed:', e.message);
  // Server will still start; requests will fail gracefully at the send step
}

const _db = () => admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Internal: token resolution
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fetches fcmToken for each userId from Firestore users collection.
 * Processes in chunks of 10 to respect Firestore parallelism limits.
 *
 * @param {string[]} userIds
 * @returns {{ tokens: string[], tokenToUserId: Map<string, string> }}
 */
async function _tokensForUserIds(userIds) {
  const tokens       = [];
  const tokenToUserId = new Map();

  const chunks = [];
  for (let i = 0; i < userIds.length; i += 10) {
    chunks.push(userIds.slice(i, i + 10));
  }

  for (const chunk of chunks) {
    await Promise.all(chunk.map(async (userId) => {
      try {
        const doc = await _db().collection('users').doc(userId).get();
        if (!doc.exists) {
          console.warn(`[FCM] User not found in Firestore: ${userId}`);
          return;
        }
        const token = doc.data().fcmToken;
        if (token && typeof token === 'string' && token.length > 10) {
          tokens.push(token);
          tokenToUserId.set(token, userId);
        } else {
          console.warn(`[FCM] No valid FCM token for user: ${userId}`);
        }
      } catch (e) {
        console.warn(`[FCM] Could not fetch token for ${userId}: ${e.message}`);
      }
    }));
  }

  return { tokens, tokenToUserId };
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal: stale token cleanup
// ─────────────────────────────────────────────────────────────────────────────

async function _removeStaleTokens(staleTokens, tokenToUserId) {
  for (const token of staleTokens) {
    const userId = tokenToUserId.get(token);
    if (!userId) continue;
    try {
      await _db().collection('users').doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });
      console.warn(`[FCM] Removed stale token for user: ${userId}`);
    } catch (e) {
      console.error(`[FCM] Failed to remove stale token for ${userId}: ${e.message}`);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal: FCM multicast
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Builds and sends FCM MulticastMessage.
 * Message format matches the existing Cloud Functions exactly
 * (same channel ID, Android priority, APNS config) so all device states work.
 *
 * @param {string[]}             tokens
 * @param {string}               title
 * @param {string}               body
 * @param {Record<string,string>} data   — extra payload (all values must be strings)
 * @param {Map<string,string>}   tokenToUserId
 */
async function _multicast(tokens, title, body, data, tokenToUserId) {
  if (!tokens || tokens.length === 0) {
    return { successCount: 0, failureCount: 0 };
  }

  // FCM requires all data values to be strings
  const fcmData = {
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
    timestamp:    Date.now().toString(),
  };
  for (const [k, v] of Object.entries(data)) {
    fcmData[k] = String(v ?? '');
  }

  const message = {
    notification: { title, body },
    data:         fcmData,
    tokens,
    android: {
      priority: 'high',
      notification: {
        channelId:             'maintify_notifications',
        sound:                 'default',
        defaultSound:          true,
        defaultVibrateTimings: true,
        priority:              'high',
        visibility:            'public',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: {
        aps: {
          sound:            'default',
          badge:            1,
          contentAvailable: true,
          alert:            { title, body },
        },
      },
    },
  };

  console.log(`[FCM] Sending "${title}" to ${tokens.length} device(s)…`);
  const response = await admin.messaging().sendEachForMulticast(message);
  console.log(`[FCM] Result: ${response.successCount}✓ / ${response.failureCount}✗`);

  // Identify stale / invalid tokens for cleanup
  const staleTokens = [];
  if (response.failureCount > 0) {
    response.responses.forEach((resp, i) => {
      if (!resp.success) {
        const code = resp.error?.code ?? 'unknown';
        console.error(`[FCM] Token[${i}] failed — ${code}: ${resp.error?.message ?? ''}`);
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/invalid-argument'
        ) {
          staleTokens.push(tokens[i]);
        }
      }
    });
  }

  if (staleTokens.length > 0) {
    await _removeStaleTokens(staleTokens, tokenToUserId);
  }

  return { successCount: response.successCount, failureCount: response.failureCount };
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Verifies a Firebase Auth ID token.
 * @param {string} idToken
 * @returns {Promise<admin.auth.DecodedIdToken>}
 */
async function verifyIdToken(idToken) {
  return admin.auth().verifyIdToken(idToken);
}

/**
 * Fetches a user document from Firestore.
 * @param {string} uid
 * @returns {Promise<{id: string, [key: string]: any} | null>}
 */
async function getUserDoc(uid) {
  const doc = await _db().collection('users').doc(uid).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

/**
 * Sends FCM push notification to one or more specific user UIDs.
 * Fetches FCM tokens from Firestore — never exposes tokens to callers.
 *
 * @param {{ recipientUids: string[], title: string, body: string, type: string, referenceId: string, referenceType?: string }} params
 * @returns {Promise<{ successCount: number, failureCount: number }>}
 */
async function sendToUids({ recipientUids, title, body, type, referenceId, referenceType }) {
  console.log(`[FCM-SERVER] recipient count: ${recipientUids.length}`);
  console.log(`[FCM-SERVER] type: ${type}`);
  console.log(`[FCM-SERVER] referenceId: ${referenceId || '(none)'}`);
  console.log(`[FCM-SERVER] referenceType: ${referenceType || '(none)'}`);

  const { tokens, tokenToUserId } = await _tokensForUserIds(recipientUids);

  console.log(`[FCM-SERVER] tokens found: ${tokens.length}`);

  if (tokens.length === 0) {
    console.warn('[FCM-SERVER] no valid tokens found for any recipient');
    return { successCount: 0, failureCount: 0 };
  }

  return _multicast(tokens, title, body, {
    type:          type          ?? '',
    referenceId:   referenceId   ?? '',
    referenceType: referenceType ?? '',
  }, tokenToUserId);
}

module.exports = { verifyIdToken, getUserDoc, sendToUids };
