/**
 * Maintify — Firebase Cloud Functions
 *
 * Handles all FCM push notifications and Firestore notification writes
 * triggered by Firestore document events.
 *
 * Trigger map:
 *   bills/{billId}                    onCreate  → FCM to all apartment users
 *   meetings/{meetingId}              onCreate  → FCM to all apartment users
 *   complaints/{complaintId}          onCreate  → FCM to apartment admin
 *   complaints/{id}/messages/{msgId}  onCreate  → FCM to the other party
 *   payments/{paymentId}              onUpdate  → FCM + Firestore notification
 */

'use strict';

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Returns FCM tokens for all users of [role] in [aptId].
 * Silently skips users that have no fcmToken stored.
 *
 * @param {string} aptId
 * @param {string} role  'user' | 'admin' | 'superAdmin'
 * @returns {Promise<string[]>}
 */
async function getTokensForApartment(aptId, role) {
  const snap = await db
    .collection('users')
    .where('apartmentId', '==', aptId)
    .where('role', '==', role)
    .get();

  const tokens = [];
  const missing = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const token = data.fcmToken;
    if (token && typeof token === 'string' && token.length > 0) {
      tokens.push(token);
      console.log(`[FCM] Token found for ${data.name ?? doc.id} (${role}): ${token.substring(0, 20)}…`);
    } else {
      missing.push(data.name ?? doc.id);
    }
  }
  if (missing.length > 0) {
    console.warn(`[FCM] No fcmToken for users: ${missing.join(', ')} — they may not have logged in yet or permission was denied.`);
  }
  console.log(`[FCM] getTokensForApartment(${aptId}, ${role}) → ${tokens.length} token(s)`);
  return tokens;
}

/**
 * Sends a multicast FCM message to a list of device tokens.
 * Silently returns if the token list is empty.
 *
 * @param {string[]} tokens
 * @param {string}   title
 * @param {string}   body
 * @param {Object}   data   Extra key-value pairs attached to the message payload.
 *                          Used by the Flutter app for click-action navigation.
 *                          Values must be strings.
 */
async function sendMulticast(tokens, title, body, data = {}) {
  if (tokens.length === 0) return;

  // Ensure all data values are strings (FCM requirement)
  const stringData = {};
  for (const [k, v] of Object.entries(data)) {
    stringData[k] = String(v ?? '');
  }

  const message = {
    notification: { title, body },
    data: stringData,
    tokens,
    android: {
      priority: 'high',
      notification: {
        // Use the channel declared in AndroidManifest via
        // com.google.firebase.messaging.default_notification_channel_id.
        // firebase_messaging auto-creates this channel (HIGH importance) on
        // first launch. Specifying a non-existent custom channel here causes
        // Android 8+ to silently drop the notification — that was the root
        // cause of users not receiving push notifications.
        channelId: 'fcm_fallback_notification_channel',
        sound: 'default',
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          contentAvailable: true,
        },
      },
    },
  };

  console.log(`[FCM] Sending "${title}" to ${tokens.length} device(s)…`);
  const response = await admin.messaging().sendEachForMulticast(message);
  console.log(`[FCM] Result: ${response.successCount} success / ${response.failureCount} failed`);

  if (response.failureCount > 0) {
    response.responses.forEach((resp, i) => {
      if (!resp.success) {
        const errCode = resp.error?.code ?? 'unknown';
        const errMsg  = resp.error?.message ?? '';
        console.error(`[FCM] Token[${i}] failed — ${errCode}: ${errMsg}`);
        // messaging/registration-token-not-registered means stale token;
        // log it so you can remove it from Firestore if needed.
        if (errCode === 'messaging/registration-token-not-registered') {
          console.warn(`[FCM] Stale token at index ${i}: ${tokens[i].substring(0, 20)}…`);
        }
      }
    });
  }
}

/**
 * Writes an in-app notification document to the `notifications` collection.
 * The NotificationProvider Firestore stream will pick this up automatically.
 *
 * @param {string} title
 * @param {string} body
 * @param {string} type   NotificationType constant (bill|payment|complaint|meeting|system)
 * @param {string} targetRole  'user' | 'admin' | 'superAdmin'
 */
async function writeNotification(title, body, type, targetRole) {
  await db.collection('notifications').add({
    title,
    body,
    type,
    targetRole,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Bill created  →  FCM to all residents in the apartment
// ─────────────────────────────────────────────────────────────────────────────

exports.onBillCreated = onDocumentCreated('bills/{billId}', async (event) => {
  const bill = event.data.data();
  const aptId = bill.apartmentId;
  if (!aptId) return;

  const perFlat = bill.totalFlats > 0
    ? (bill.totalAmount / bill.totalFlats).toFixed(0)
    : bill.totalAmount;

  const tokens = await getTokensForApartment(aptId, 'user');
  await sendMulticast(
    tokens,
    `New Bill: ${bill.title}`,
    `${bill.month} bill generated — ₹${perFlat} per flat due by ${_formatTimestamp(bill.dueDate)}.`,
    { type: 'bill', aptId }
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. Meeting created  →  FCM to all residents
// ─────────────────────────────────────────────────────────────────────────────

exports.onMeetingCreated = onDocumentCreated('meetings/{meetingId}', async (event) => {
  const meeting = event.data.data();
  const aptId = meeting.apartmentId;
  if (!aptId) return;

  const dateStr = _formatTimestamp(meeting.scheduledAt);
  const tokens = await getTokensForApartment(aptId, 'user');
  await sendMulticast(
    tokens,
    `Meeting Scheduled: ${meeting.title}`,
    `A meeting has been scheduled on ${dateStr}.`,
    { type: 'meeting', aptId }
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. Complaint created  →  FCM to admin
// ─────────────────────────────────────────────────────────────────────────────

exports.onComplaintCreated = onDocumentCreated('complaints/{complaintId}', async (event) => {
  const complaint = event.data.data();
  const aptId = complaint.apartmentId;
  if (!aptId) return;

  const tokens = await getTokensForApartment(aptId, 'admin');
  await sendMulticast(
    tokens,
    'New Complaint Received',
    `${complaint.userName} (Flat ${complaint.unit}): ${complaint.title}`,
    { type: 'complaint', complaintId: event.params.complaintId, aptId }
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. Complaint message  →  FCM to the other party
//    Admin reply  → push to the resident who raised the complaint
//    User message → push to the apartment admin
// ─────────────────────────────────────────────────────────────────────────────

exports.onComplaintMessage = onDocumentCreated(
  'complaints/{complaintId}/messages/{messageId}',
  async (event) => {
    const msg = event.data.data();
    const { complaintId } = event.params;

    const complaintDoc = await db.collection('complaints').doc(complaintId).get();
    if (!complaintDoc.exists) return;

    const complaint = complaintDoc.data();
    const aptId = complaint.apartmentId;

    if (msg.isFromAdmin) {
      // Admin replied → notify the specific resident who raised the complaint
      const userDoc = await db.collection('users').doc(complaint.userId).get();
      if (!userDoc.exists) return;
      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) return;

      await sendMulticast(
        [fcmToken],
        'Reply on Your Complaint',
        `Admin replied: "${_truncate(msg.content, 100)}"`,
        { type: 'complaint', complaintId, aptId }
      );
    } else {
      // Resident sent a message → notify admin
      const tokens = await getTokensForApartment(aptId, 'admin');
      await sendMulticast(
        tokens,
        'New Message on Complaint',
        `${msg.senderName}: ${_truncate(msg.content, 100)}`,
        { type: 'complaint', complaintId, aptId }
      );
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 5. Payment updated
//    Case A: resident reports/submits payment  → FCM + notification to admin
//    Case B: admin verifies payment            → FCM + notification to resident
// ─────────────────────────────────────────────────────────────────────────────

exports.onPaymentUpdated = onDocumentUpdated('payments/{paymentId}', async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();
  const aptId  = after.apartmentId;
  if (!aptId) return;

  // ── Case A: Resident initiated payment (new transactionId, not yet admin-verified)
  const paymentInitiated = !before.transactionId && after.transactionId && !after.adminVerified;
  if (paymentInitiated) {
    const tokens = await getTokensForApartment(aptId, 'admin');
    await Promise.all([
      sendMulticast(
        tokens,
        'Payment Reported',
        `Flat ${after.unitNumber} has reported a payment and is awaiting verification.`,
        { type: 'payment', aptId }
      ),
      writeNotification(
        'Payment Reported',
        `Flat ${after.unitNumber} has reported a payment and is awaiting verification.`,
        'payment',
        'admin'
      ),
    ]);
    return;
  }

  // ── Case B: Admin verified the payment
  const adminVerified = !before.adminVerified && after.adminVerified && after.status === 'paid';
  if (adminVerified) {
    const userDoc = await db.collection('users').doc(after.userId).get();
    if (!userDoc.exists) return;

    const fcmToken = userDoc.data().fcmToken;
    await Promise.all([
      fcmToken
        ? sendMulticast(
            [fcmToken],
            'Payment Verified ✓',
            'Your maintenance payment has been verified by the admin.',
            { type: 'payment', aptId }
          )
        : Promise.resolve(),
      writeNotification(
        'Payment Verified',
        'Your maintenance payment has been verified by the admin.',
        'payment',
        'user'
      ),
    ]);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────────────────────────────────────

/** Truncates a string to maxLen characters, appending '…' if needed. */
function _truncate(str, maxLen) {
  if (!str) return '';
  return str.length <= maxLen ? str : str.substring(0, maxLen) + '…';
}

/**
 * Formats a Firestore Timestamp (or anything with a toDate() method) into a
 * human-readable date string.  Falls back gracefully for null/undefined values.
 *
 * @param {admin.firestore.Timestamp | null | undefined} ts
 * @returns {string}
 */
function _formatTimestamp(ts) {
  if (!ts || typeof ts.toDate !== 'function') return '';
  const d = ts.toDate();
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}
