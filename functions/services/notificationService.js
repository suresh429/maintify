'use strict';

/**
 * Maintify — Centralized Notification Service
 *
 * All FCM sends and Firestore notification writes go through this module.
 * No Cloud Function should duplicate token fetching, multicast logic,
 * or Firestore notification writes.
 *
 * Public API:
 *   sendToUser(userId, notification)
 *   sendToUsers(userIds, notification)
 *   sendToApartment(aptId, role, notification, opts)
 *   sendToRole(role, notification)
 *   saveNotification(data)
 */

const admin = require('firebase-admin');

// Lazy getter — admin.firestore() must not be called at module load time
// because admin.initializeApp() runs in index.js AFTER this module is required.
const getDb = () => admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Internal: token resolution
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fetches fcmToken from each userId doc.
 * @returns {{ tokens: string[], tokenToUserId: Map<string,string> }}
 */
async function _tokensForUserIds(userIds) {
  const tokens = [];
  const tokenToUserId = new Map();

  // Fetch in parallel, max 10 at a time to stay inside Firestore limits
  const chunks = [];
  for (let i = 0; i < userIds.length; i += 10) {
    chunks.push(userIds.slice(i, i + 10));
  }

  for (const chunk of chunks) {
    await Promise.all(chunk.map(async (userId) => {
      try {
        const doc = await getDb().collection('users').doc(userId).get();
        if (!doc.exists) return;
        const token = doc.data().fcmToken;
        if (token && typeof token === 'string' && token.length > 10) {
          tokens.push(token);
          tokenToUserId.set(token, userId);
        }
      } catch (e) {
        console.warn(`[FCM] Could not fetch token for ${userId}: ${e.message}`);
      }
    }));
  }

  return { tokens, tokenToUserId };
}

/**
 * Queries users by apartment + role. Skips excludeIds.
 * @returns {{ tokens: string[], userIds: string[], tokenToUserId: Map<string,string> }}
 */
async function _tokensForApartment(aptId, role, excludeIds = []) {
  const snap = await getDb().collection('users')
    .where('apartmentId', '==', aptId)
    .where('role', '==', role)
    .get();

  const tokens = [];
  const userIds = [];
  const tokenToUserId = new Map();

  for (const doc of snap.docs) {
    if (excludeIds.includes(doc.id)) continue;
    const token = doc.data().fcmToken;
    if (token && typeof token === 'string' && token.length > 10) {
      tokens.push(token);
      userIds.push(doc.id);
      tokenToUserId.set(token, doc.id);
    } else {
      userIds.push(doc.id); // still save notification even without FCM token
    }
  }

  console.log(`[FCM] _tokensForApartment(${aptId}, ${role}) → ${tokens.length} token(s), ${userIds.length} user(s)`);
  return { tokens, userIds, tokenToUserId };
}

/**
 * Queries all users of a role across all apartments.
 */
async function _tokensForRole(role) {
  const snap = await getDb().collection('users').where('role', '==', role).get();

  const tokens = [];
  const userIds = [];
  const tokenToUserId = new Map();

  for (const doc of snap.docs) {
    const token = doc.data().fcmToken;
    if (token && typeof token === 'string' && token.length > 10) {
      tokens.push(token);
      tokenToUserId.set(token, doc.id);
    }
    userIds.push(doc.id);
  }

  console.log(`[FCM] _tokensForRole(${role}) → ${tokens.length} token(s), ${userIds.length} user(s)`);
  return { tokens, userIds, tokenToUserId };
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal: multicast + stale token cleanup
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Builds the FCM MulticastMessage and sends it.
 * Cleans up stale/invalid tokens automatically.
 */
async function _multicast(tokens, title, body, extraData, tokenToUserId) {
  if (!tokens || tokens.length === 0) {
    return { successCount: 0, failureCount: 0 };
  }

  // FCM requires all data values to be strings
  const data = {
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
    timestamp: Date.now().toString(),
  };
  for (const [k, v] of Object.entries(extraData)) {
    data[k] = String(v ?? '');
  }

  const message = {
    notification: { title, body },
    data,
    tokens,
    android: {
      priority: 'high',
      notification: {
        channelId: 'maintify_notifications',
        sound: 'default',
        defaultSound: true,
        defaultVibrateTimings: true,
        priority: 'high',
        visibility: 'public',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          contentAvailable: true,
          alert: { title, body },
        },
      },
    },
  };

  console.log(`[FCM] Sending "${title}" to ${tokens.length} device(s)…`);
  const response = await admin.messaging().sendEachForMulticast(message);
  console.log(`[FCM] Result: ${response.successCount}✓ / ${response.failureCount}✗`);

  // Identify and remove stale tokens
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

  if (staleTokens.length > 0 && tokenToUserId) {
    await _removeStaleTokens(staleTokens, tokenToUserId);
  }

  return { successCount: response.successCount, failureCount: response.failureCount };
}

/**
 * Deletes fcmToken field from Firestore for stale/invalid tokens.
 */
async function _removeStaleTokens(staleTokens, tokenToUserId) {
  for (const token of staleTokens) {
    const userId = tokenToUserId.get(token);
    if (!userId) continue;
    try {
      await getDb().collection('users').doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });
      console.warn(`[FCM] Removed stale token for user: ${userId}`);
    } catch (e) {
      console.error(`[FCM] Failed to remove stale token for ${userId}: ${e.message}`);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal: Firestore notification persistence
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Saves notification documents to Firestore — one per receiverId.
 * Uses a batched write for efficiency (max 500 per batch, chunked).
 */
async function saveNotification({
  receiverIds,
  senderId     = null,
  apartmentId  = null,
  type,
  title,
  body,
  route        = null,
  referenceId  = null,
  referenceType = null,
  payload      = {},
}) {
  if (!receiverIds || receiverIds.length === 0) return;

  const now = admin.firestore.FieldValue.serverTimestamp();
  const chunkSize = 400;

  for (let i = 0; i < receiverIds.length; i += chunkSize) {
    const chunk = receiverIds.slice(i, i + chunkSize);
    const batch = getDb().batch();
    for (const receiverId of chunk) {
      const ref = getDb().collection('notifications').doc();
      batch.set(ref, {
        receiverId,
        userId:       receiverId,  // kept for backward compat with stream query
        senderId,
        apartmentId,
        type,
        title,
        body,
        route,
        referenceId,
        referenceType,
        isRead:       false,
        createdAt:    now,
        payload,
      });
    }
    await batch.commit();
  }

  console.log(`[NOTIFICATION] Saved ${receiverIds.length} doc(s) — type: ${type}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Sends FCM push + saves Firestore notification to ONE user.
 *
 * @param {string} userId
 * @param {{ title, body, type, route?, referenceId?, referenceType?, aptId?, senderId?, saveToFirestore? }} opts
 */
async function sendToUser(userId, {
  title, body, type,
  route         = null,
  referenceId   = null,
  referenceType = null,
  aptId         = null,
  senderId      = null,
  saveToFirestore = true,
}) {
  try {
    const { tokens, tokenToUserId } = await _tokensForUserIds([userId]);

    if (tokens.length > 0) {
      await _multicast(tokens, title, body, {
        type, route: route ?? '', referenceId: referenceId ?? '',
        referenceType: referenceType ?? '', apartmentId: aptId ?? '',
        senderId: senderId ?? '',
      }, tokenToUserId);
    } else {
      console.warn(`[FCM] sendToUser(${userId}) — no FCM token found`);
    }

    if (saveToFirestore) {
      await saveNotification({
        receiverIds: [userId], senderId, apartmentId: aptId,
        type, title, body, route, referenceId, referenceType,
      });
    }

    console.log(`[Notification] sendToUser — type: ${type}, userId: ${userId}`);
  } catch (e) {
    console.error(`[Notification] sendToUser error (${userId}): ${e.message}`);
  }
}

/**
 * Sends FCM push + saves Firestore notification to MULTIPLE specific users.
 *
 * @param {string[]} userIds
 * @param {{ title, body, type, route?, referenceId?, referenceType?, aptId?, senderId?, saveToFirestore? }} opts
 */
async function sendToUsers(userIds, {
  title, body, type,
  route         = null,
  referenceId   = null,
  referenceType = null,
  aptId         = null,
  senderId      = null,
  saveToFirestore = true,
}) {
  if (!userIds || userIds.length === 0) return;

  try {
    const { tokens, tokenToUserId } = await _tokensForUserIds(userIds);

    if (tokens.length > 0) {
      await _multicast(tokens, title, body, {
        type, route: route ?? '', referenceId: referenceId ?? '',
        referenceType: referenceType ?? '', apartmentId: aptId ?? '',
        senderId: senderId ?? '',
      }, tokenToUserId);
    }

    if (saveToFirestore) {
      await saveNotification({
        receiverIds: userIds, senderId, apartmentId: aptId,
        type, title, body, route, referenceId, referenceType,
      });
    }

    console.log(`[Notification] sendToUsers — type: ${type}, recipients: ${userIds.length}`);
  } catch (e) {
    console.error(`[Notification] sendToUsers error: ${e.message}`);
  }
}

/**
 * Sends FCM push + saves Firestore notification to all users of a ROLE in an APARTMENT.
 *
 * @param {string} aptId
 * @param {string} role  'user' | 'admin' | 'superAdmin'
 * @param {{ title, body, type, route?, referenceId?, referenceType?, senderId?, excludeIds?, saveToFirestore? }} opts
 */
async function sendToApartment(aptId, role, {
  title, body, type,
  route         = null,
  referenceId   = null,
  referenceType = null,
  senderId      = null,
  excludeIds    = [],
  saveToFirestore = true,
}) {
  try {
    const { tokens, userIds, tokenToUserId } =
      await _tokensForApartment(aptId, role, excludeIds);

    if (tokens.length > 0) {
      await _multicast(tokens, title, body, {
        type, route: route ?? '', referenceId: referenceId ?? '',
        referenceType: referenceType ?? '', apartmentId: aptId,
        senderId: senderId ?? '',
      }, tokenToUserId);
    }

    if (saveToFirestore && userIds.length > 0) {
      await saveNotification({
        receiverIds: userIds, senderId, apartmentId: aptId,
        type, title, body, route, referenceId, referenceType,
      });
    }

    console.log(`[Notification] sendToApartment(${aptId}, ${role}) — type: ${type}, recipients: ${userIds.length}`);
  } catch (e) {
    console.error(`[Notification] sendToApartment(${aptId}, ${role}) error: ${e.message}`);
  }
}

/**
 * Sends FCM push + saves Firestore notification to all users of a ROLE
 * across ALL apartments. Typically used for superAdmin notifications.
 *
 * @param {string} role
 * @param {{ title, body, type, route?, referenceId?, referenceType?, senderId?, aptId?, saveToFirestore? }} opts
 */
async function sendToRole(role, {
  title, body, type,
  route         = null,
  referenceId   = null,
  referenceType = null,
  senderId      = null,
  aptId         = null,
  saveToFirestore = true,
}) {
  try {
    const { tokens, userIds, tokenToUserId } = await _tokensForRole(role);

    if (tokens.length > 0) {
      await _multicast(tokens, title, body, {
        type, route: route ?? '', referenceId: referenceId ?? '',
        referenceType: referenceType ?? '', apartmentId: aptId ?? '',
        senderId: senderId ?? '',
      }, tokenToUserId);
    }

    if (saveToFirestore && userIds.length > 0) {
      await saveNotification({
        receiverIds: userIds, senderId, apartmentId: aptId,
        type, title, body, route, referenceId, referenceType,
      });
    }

    console.log(`[Notification] sendToRole(${role}) — type: ${type}, recipients: ${userIds.length}`);
  } catch (e) {
    console.error(`[Notification] sendToRole(${role}) error: ${e.message}`);
  }
}

module.exports = {
  sendToUser,
  sendToUsers,
  sendToApartment,
  sendToRole,
  saveNotification,
};
