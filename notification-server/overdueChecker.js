'use strict';

/**
 * Maintify — Daily Overdue Payment Reminder
 *
 * Runs on a cron schedule (09:00 AM IST) from server.js.
 * Supports two Firebase projects (dev + prod) from one Render service.
 *
 * Primary project: FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY
 * Secondary project (optional): FIREBASE_PROJECT_ID_2 / FIREBASE_CLIENT_EMAIL_2 / FIREBASE_PRIVATE_KEY_2
 *
 * Skips residents who already submitted payment ('Pending Approval') or paid ('Paid').
 * Groups overdue bills per resident — one notification even if multiple bills overdue.
 */

const admin = require('firebase-admin');

// Firebase Admin default app is already initialized by notification.js.
// We lazily initialize a named 'secondary' app for the second project if credentials exist.
let _secondaryApp = null;

function _getSecondaryApp() {
  if (_secondaryApp) return _secondaryApp;

  const projectId   = process.env.FIREBASE_PROJECT_ID_2;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL_2;
  const privateKey  = process.env.FIREBASE_PRIVATE_KEY_2
    ? process.env.FIREBASE_PRIVATE_KEY_2.replace(/\\n/g, '\n')
    : undefined;

  if (!projectId || !clientEmail || !privateKey) return null;

  try {
    _secondaryApp = admin.initializeApp(
      { credential: admin.credential.cert({ projectId, clientEmail, privateKey }) },
      'secondary'
    );
    console.log('[OVERDUE] Secondary Firebase app initialized — project:', projectId);
  } catch (e) {
    console.error('[OVERDUE] Failed to initialize secondary Firebase app:', e.message);
  }
  return _secondaryApp;
}

// Returns list of { db, messaging, label } for every configured Firebase project.
function _getFirebaseContexts() {
  const contexts = [
    {
      db:        admin.firestore(),
      messaging: admin.messaging(),
      label:     process.env.FIREBASE_PROJECT_ID || 'primary',
    },
  ];

  const secondaryApp = _getSecondaryApp();
  if (secondaryApp) {
    contexts.push({
      db:        secondaryApp.firestore(),
      messaging: secondaryApp.messaging(),
      label:     process.env.FIREBASE_PROJECT_ID_2,
    });
  }

  return contexts;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function _formatDate(ts) {
  if (!ts || typeof ts.toDate !== 'function') return '';
  return ts.toDate().toLocaleDateString('en-IN', {
    day: 'numeric', month: 'short', year: 'numeric',
  });
}

async function _sendFcm(db, messaging, userId, title, body, extraData) {
  try {
    const doc = await db.collection('users').doc(userId).get();
    if (!doc.exists) return;

    const token = doc.data().fcmToken;
    if (!token || typeof token !== 'string' || token.length <= 10) {
      console.warn(`[OVERDUE] No FCM token for user: ${userId}`);
      return;
    }

    const fcmData = {
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      timestamp:    Date.now().toString(),
    };
    for (const [k, v] of Object.entries(extraData)) {
      fcmData[k] = String(v ?? '');
    }

    const message = {
      notification: { title, body },
      data:         fcmData,
      tokens:       [token],
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

    const response = await messaging.sendEachForMulticast(message);
    console.log(`[OVERDUE] FCM for ${userId}: ${response.successCount}✓ / ${response.failureCount}✗`);

    if (response.failureCount > 0) {
      const code = response.responses[0]?.error?.code ?? '';
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/invalid-argument'
      ) {
        await db.collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        console.warn(`[OVERDUE] Removed stale token for user: ${userId}`);
      }
    }
  } catch (e) {
    console.error(`[OVERDUE] FCM send failed for ${userId}: ${e.message}`);
  }
}

async function _saveNotification(db, { receiverId, apartmentId, type, title, body, referenceId }) {
  try {
    await db.collection('notifications').add({
      receiverId,
      userId:        receiverId,
      senderId:      null,
      apartmentId,
      type,
      title,
      body,
      route:         'bill_detail',
      referenceId,
      referenceType: 'bill',
      isRead:        false,
      createdAt:     admin.firestore.FieldValue.serverTimestamp(),
      payload:       {},
    });
  } catch (e) {
    console.error(`[OVERDUE] Firestore notification save failed for ${receiverId}: ${e.message}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-project check
// ─────────────────────────────────────────────────────────────────────────────

async function _checkProject({ db, messaging, label }) {
  console.log(`[OVERDUE] Checking project: ${label}`);
  const now = admin.firestore.Timestamp.now();

  let billsSnap;
  try {
    billsSnap = await db.collection('bills').where('dueDate', '<', now).get();
  } catch (e) {
    console.error(`[OVERDUE] [${label}] Failed to query bills: ${e.message}`);
    return;
  }

  if (billsSnap.empty) {
    console.log(`[OVERDUE] [${label}] No overdue bills.`);
    return;
  }

  console.log(`[OVERDUE] [${label}] ${billsSnap.size} overdue bill(s) found.`);

  // Map: userId → { aptId, count, firstBillId, firstBillTitle, dueDate }
  const userMap = new Map();

  for (const billDoc of billsSnap.docs) {
    const bill   = billDoc.data();
    const billId = billDoc.id;
    const aptId  = bill.apartmentId;
    if (!aptId) continue;

    let paymentsSnap;
    try {
      paymentsSnap = await db.collection('payments').where('billId', '==', billId).get();
    } catch (e) {
      console.error(`[OVERDUE] [${label}] Failed to query payments for bill ${billId}: ${e.message}`);
      continue;
    }

    for (const payDoc of paymentsSnap.docs) {
      const status = payDoc.data().status ?? 'Pending';
      if (status === 'Paid' || status === 'Pending Approval') continue;

      const userId = payDoc.data().userId;
      if (!userId) continue;

      if (!userMap.has(userId)) {
        userMap.set(userId, {
          aptId,
          count:          0,
          firstBillId:    billId,
          firstBillTitle: bill.title ?? bill.month ?? 'Maintenance',
          dueDate:        _formatDate(bill.dueDate),
        });
      }
      userMap.get(userId).count++;
    }
  }

  if (userMap.size === 0) {
    console.log(`[OVERDUE] [${label}] All payments settled.`);
    return;
  }

  console.log(`[OVERDUE] [${label}] Sending reminders to ${userMap.size} resident(s)…`);

  for (const [userId, info] of userMap.entries()) {
    const { aptId, count, firstBillId, firstBillTitle, dueDate } = info;

    const title = 'Payment Overdue';
    const body  = count === 1
      ? `Your ${firstBillTitle} payment was due on ${dueDate}. Please pay at the earliest.`
      : `You have ${count} overdue maintenance bills. Please clear them at the earliest.`;

    await _sendFcm(db, messaging, userId, title, body, {
      type:          'payment_overdue_reminder',
      referenceId:   firstBillId,
      referenceType: 'bill',
      apartmentId:   aptId,
    });

    await _saveNotification(db, {
      receiverId:  userId,
      apartmentId: aptId,
      type:        'payment_overdue_reminder',
      title,
      body,
      referenceId: firstBillId,
    });
  }

  console.log(`[OVERDUE] [${label}] Done — ${userMap.size} reminder(s) sent.`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main export
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Runs the daily overdue payment check across all configured Firebase projects.
 * Called by node-cron at 09:00 AM IST every day.
 */
async function runOverdueCheck() {
  console.log('[OVERDUE] ══════════════════════════════════════');
  console.log('[OVERDUE] Starting daily overdue payment check…');

  const contexts = _getFirebaseContexts();
  console.log(`[OVERDUE] Running for ${contexts.length} project(s): ${contexts.map(c => c.label).join(', ')}`);

  for (const ctx of contexts) {
    await _checkProject(ctx);
  }

  console.log('[OVERDUE] All projects checked.');
  console.log('[OVERDUE] ══════════════════════════════════════');
}

module.exports = { runOverdueCheck };
