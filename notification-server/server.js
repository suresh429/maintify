'use strict';

/**
 * Maintify Notification Server
 *
 * A lightweight Express server that delivers FCM push notifications
 * to Maintify residents and presidents.
 *
 * Routes:
 *   GET  /                    — Health check
 *   POST /send-notification   — Authenticated FCM delivery
 *
 * Security:
 *   - Every POST request must carry a valid Firebase Auth ID token
 *     in the Authorization: Bearer <token> header.
 *   - The caller must be a registered Maintify user (president, resident, or admin).
 *   - FCM tokens are never returned to the client.
 *   - Private keys and credentials are never logged.
 */

const express = require('express');
const cors    = require('cors');
const { verifyIdToken, getUserDoc, sendToUids } = require('./notification');

const app  = express();
const PORT = process.env.PORT || 3000;

// ─────────────────────────────────────────────────────────────────────────────
// Middleware
// ─────────────────────────────────────────────────────────────────────────────

app.use(cors());
app.use(express.json());

// ─────────────────────────────────────────────────────────────────────────────
// GET / — Health check
// ─────────────────────────────────────────────────────────────────────────────

app.get('/', (req, res) => {
  res.json({ success: true, service: 'Maintify Notification Server' });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /send-notification
// ─────────────────────────────────────────────────────────────────────────────

app.post('/send-notification', async (req, res) => {
  console.log('[NOTIFICATION] Request received');

  // ── Step 1: Extract Bearer token ──────────────────────────────────────────
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Missing or malformed authorization header' });
  }
  const idToken = authHeader.slice(7).trim();
  if (!idToken) {
    return res.status(401).json({ success: false, error: 'Empty authorization token' });
  }

  // ── Step 2: Verify Firebase Auth ID token ─────────────────────────────────
  let caller;
  try {
    caller = await verifyIdToken(idToken);
  } catch (e) {
    // Log only the error code — never log the token
    const code = e.code ?? e.errorInfo?.code ?? 'unknown';
    console.warn(`[AUTH] Token verification failed: ${code}`);
    return res.status(401).json({ success: false, error: 'Invalid or expired authentication token' });
  }

  // ── Step 3: Validate request body ─────────────────────────────────────────
  const { recipientUids, title, body, type, referenceId } = req.body ?? {};

  if (!Array.isArray(recipientUids) || recipientUids.length === 0) {
    return res.status(400).json({ success: false, error: 'recipientUids must be a non-empty array' });
  }
  if (recipientUids.length > 50) {
    return res.status(400).json({ success: false, error: 'Too many recipients (max 50 per request)' });
  }
  if (!title || typeof title !== 'string' || !title.trim()) {
    return res.status(400).json({ success: false, error: 'title is required' });
  }
  if (!body || typeof body !== 'string' || !body.trim()) {
    return res.status(400).json({ success: false, error: 'body is required' });
  }
  if (!type || typeof type !== 'string' || !type.trim()) {
    return res.status(400).json({ success: false, error: 'type is required' });
  }
  if (type === 'complaint' && (!referenceId || typeof referenceId !== 'string' || !referenceId.trim())) {
    return res.status(400).json({ success: false, error: 'referenceId is required for type "complaint"' });
  }

  // Sanitize: remove any non-string or blank UIDs
  const validUids = recipientUids.filter(uid => typeof uid === 'string' && uid.trim().length > 0);
  if (validUids.length === 0) {
    return res.status(400).json({ success: false, error: 'No valid recipient UIDs in request' });
  }

  // ── Step 4: Verify caller is a registered Maintify user ───────────────────
  let callerDoc;
  try {
    callerDoc = await getUserDoc(caller.uid);
  } catch (e) {
    console.error('[AUTH] Failed to fetch caller user doc:', e.message);
    return res.status(500).json({ success: false, error: 'Server error during authorization' });
  }

  if (!callerDoc) {
    console.warn(`[AUTH] Caller ${caller.uid} is not registered in Maintify`);
    return res.status(403).json({ success: false, error: 'Caller is not a registered Maintify user' });
  }

  const callerRole        = callerDoc.role;
  const callerApartmentId = callerDoc.apartmentId;

  const allowedRoles = ['president', 'resident', 'admin'];
  if (!allowedRoles.includes(callerRole)) {
    console.warn(`[AUTH] Caller ${caller.uid} has unauthorized role: ${callerRole}`);
    return res.status(403).json({ success: false, error: 'Caller role is not authorized to send notifications' });
  }

  if (callerRole !== 'admin' && !callerApartmentId) {
    console.warn(`[AUTH] Caller ${caller.uid} has no associated apartment`);
    return res.status(403).json({ success: false, error: 'Caller has no associated apartment' });
  }

  console.log(`[NOTIFICATION] Caller: uid=${caller.uid}, role=${callerRole}, apt=${callerApartmentId ?? 'admin'}`);
  console.log(`[NOTIFICATION] Recipient count: ${validUids.length}`);

  // ── Step 5: Send FCM ───────────────────────────────────────────────────────
  let result;
  try {
    result = await sendToUids({
      recipientUids: validUids,
      title:         title.trim(),
      body:          body.trim(),
      type:          type.trim(),
      referenceId:   typeof referenceId === 'string' ? referenceId.trim() : '',
    });
  } catch (e) {
    console.error('[FCM] Unexpected send error:', e.message);
    return res.status(500).json({ success: false, error: 'Failed to deliver notification' });
  }

  console.log(`[FCM] Success: ${result.successCount}, Failed: ${result.failureCount}`);

  return res.json({
    success:      true,
    successCount: result.successCount,
    failureCount: result.failureCount,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 404 handler
// ─────────────────────────────────────────────────────────────────────────────

app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Not found' });
});

// ─────────────────────────────────────────────────────────────────────────────
// Global error handler — ensures no stack traces reach the client
// ─────────────────────────────────────────────────────────────────────────────

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[SERVER] Unhandled error:', err.message);
  res.status(500).json({ success: false, error: 'Internal server error' });
});

// ─────────────────────────────────────────────────────────────────────────────
// Startup
// ─────────────────────────────────────────────────────────────────────────────

process.on('unhandledRejection', (reason) => {
  console.error('[SERVER] Unhandled promise rejection:', reason?.message ?? reason);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[SERVER] Maintify Notification Server running on port ${PORT}`);
});
