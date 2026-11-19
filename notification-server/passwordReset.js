'use strict';

/**
 * Maintify — OTP-based Password Reset
 *
 * Sends a 6-digit OTP to a user's registered email and resets the password
 * once the OTP is verified. Works across both Firebase projects (primary + secondary).
 *
 * Collections used:
 *   password_reset_otps/{email}  — temporary OTP doc; deleted after use or expiry
 *
 * Env vars required for email sending:
 *   GMAIL_EMAIL          — Gmail address used as sender
 *   GMAIL_APP_PASSWORD   — Gmail App Password (not the account password)
 */

const admin  = require('firebase-admin');
const crypto = require('crypto');

// Lazy nodemailer transporter — created on first use so secrets are available
let _transporter = null;

function _getTransporter() {
  if (_transporter) return _transporter;

  const nodemailer = require('nodemailer');
  const email    = process.env.GMAIL_EMAIL;
  const password = process.env.GMAIL_APP_PASSWORD;

  if (!email || !password) {
    throw new Error('Missing GMAIL_EMAIL or GMAIL_APP_PASSWORD environment variables.');
  }

  _transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: email, pass: password },
  });

  return _transporter;
}

// ─────────────────────────────────────────────────────────────────────────────
// Firebase context helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Returns the secondary Firebase app, trying to reuse an existing one first
 * (may already have been initialized by overdueChecker.js).
 */
function _getSecondaryApp() {
  const projectId   = process.env.FIREBASE_PROJECT_ID_2;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL_2;
  const privateKey  = process.env.FIREBASE_PRIVATE_KEY_2
    ? process.env.FIREBASE_PRIVATE_KEY_2.replace(/\\n/g, '\n')
    : undefined;

  if (!projectId || !clientEmail || !privateKey) return null;

  // Try reusing an already-initialized app
  try {
    return admin.app('secondary');
  } catch (_) {
    // Not initialized yet — create it
  }

  try {
    return admin.initializeApp(
      { credential: admin.credential.cert({ projectId, clientEmail, privateKey }) },
      'secondary'
    );
  } catch (e) {
    console.error('[PASSWORD_RESET] Failed to initialize secondary Firebase app:', e.message);
    return null;
  }
}

/**
 * Returns an array of { auth, db, label } for every configured Firebase project.
 */
function _getFirebaseContexts() {
  const contexts = [
    {
      auth:  admin.auth(),
      db:    admin.firestore(),
      label: process.env.FIREBASE_PROJECT_ID || 'primary',
    },
  ];

  const secondaryApp = _getSecondaryApp();
  if (secondaryApp) {
    contexts.push({
      auth:  secondaryApp.auth(),
      db:    secondaryApp.firestore(),
      label: process.env.FIREBASE_PROJECT_ID_2 || 'secondary',
    });
  }

  return contexts;
}

// ─────────────────────────────────────────────────────────────────────────────
// Email template
// ─────────────────────────────────────────────────────────────────────────────

function _buildOtpEmailHtml(otp) {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Maintify — Password Reset OTP</title>
</head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#1e3a8a,#06b6d4);padding:32px 32px 24px;text-align:center;">
              <p style="margin:0;font-size:28px;font-weight:700;color:#ffffff;letter-spacing:-0.5px;">Maintify</p>
              <p style="margin:6px 0 0;font-size:13px;color:rgba(255,255,255,0.8);">Apartment Management</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:32px 32px 24px;">
              <p style="margin:0 0 8px;font-size:20px;font-weight:600;color:#0f172a;">Password Reset OTP</p>
              <p style="margin:0 0 24px;font-size:14px;color:#64748b;line-height:1.6;">
                We received a request to reset your Maintify password. Use the OTP below to continue.
                This code expires in <strong>10 minutes</strong>.
              </p>
              <!-- OTP box -->
              <div style="background:#f0f9ff;border:2px dashed #06b6d4;border-radius:12px;padding:24px;text-align:center;margin:0 0 24px;">
                <p style="margin:0 0 4px;font-size:12px;font-weight:600;color:#0891b2;letter-spacing:1px;text-transform:uppercase;">Your OTP Code</p>
                <p style="margin:0;font-size:40px;font-weight:700;color:#1e3a8a;letter-spacing:12px;">${otp}</p>
              </div>
              <p style="margin:0 0 8px;font-size:13px;color:#64748b;line-height:1.6;">
                If you did not request a password reset, please ignore this email. Your password will remain unchanged.
              </p>
              <p style="margin:0;font-size:13px;color:#94a3b8;">
                <strong>Note:</strong> Never share this OTP with anyone.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background:#f8fafc;padding:20px 32px;text-align:center;border-top:1px solid #e2e8f0;">
              <p style="margin:0;font-size:12px;color:#94a3b8;">
                &copy; 2026 Maintify &middot; All rights reserved
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Public: sendResetOtp
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Generates and emails a 6-digit OTP for password reset.
 *
 * Rate-limited to one OTP per 60 seconds per email address.
 * Silently succeeds if the email is not registered (don't reveal existence).
 *
 * @param {string} email
 * @returns {Promise<{ sent: boolean }>}
 * @throws Error('RATE_LIMITED') if called too soon after a previous OTP
 */
async function sendResetOtp(email) {
  const normalizedEmail = email.trim().toLowerCase();

  const contexts = _getFirebaseContexts();

  // Find which Firebase project this email belongs to
  let foundCtx = null;
  for (const ctx of contexts) {
    try {
      await ctx.auth.getUserByEmail(normalizedEmail);
      foundCtx = ctx;
      console.log(`[PASSWORD_RESET] Email found in project: ${ctx.label}`);
      break;
    } catch (e) {
      // auth/user-not-found is expected — try next context
      if (e.code !== 'auth/user-not-found') {
        console.warn(`[PASSWORD_RESET] Unexpected error looking up email in ${ctx.label}:`, e.message);
      }
    }
  }

  // Don't reveal whether the email exists
  if (!foundCtx) {
    console.log('[PASSWORD_RESET] Email not found in any project — returning silently');
    return { sent: true };
  }

  // Rate limit: one OTP per 60 seconds
  const otpRef = foundCtx.db.collection('password_reset_otps').doc(normalizedEmail);
  const existing = await otpRef.get();
  if (existing.exists) {
    const sentAt = existing.data().sentAt;
    if (sentAt && Date.now() - sentAt.toMillis() < 60_000) {
      throw new Error('RATE_LIMITED');
    }
  }

  // Generate OTP and hash
  const otp     = Math.floor(100000 + Math.random() * 900000).toString();
  const otpHash = crypto.createHash('sha256').update(otp).digest('hex');
  const now     = admin.firestore.FieldValue.serverTimestamp();

  // Store OTP doc (10-minute expiry)
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
  await otpRef.set({
    email:    normalizedEmail,
    otpHash,
    expiresAt,
    sentAt:   now,
    attempts: 0,
  });

  // Send email
  const transporter = _getTransporter();
  await transporter.sendMail({
    from:    `"Maintify" <${process.env.GMAIL_EMAIL}>`,
    to:      normalizedEmail,
    subject: 'Your Maintify Password Reset OTP',
    html:    _buildOtpEmailHtml(otp),
  });

  console.log(`[PASSWORD_RESET] OTP sent to: ${normalizedEmail}`);
  return { sent: true };
}

// ─────────────────────────────────────────────────────────────────────────────
// Public: resetPasswordWithOtp
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Verifies the OTP and resets the user's Firebase Auth password.
 *
 * Checks all configured Firebase projects for the OTP doc.
 *
 * @param {string} email
 * @param {string} otp
 * @param {string} newPassword
 * @returns {Promise<{ success: boolean }>}
 * @throws Error with code: 'NO_OTP_FOUND' | 'OTP_EXPIRED' | 'TOO_MANY_ATTEMPTS' | 'INVALID_OTP'
 */
async function resetPasswordWithOtp(email, otp, newPassword) {
  const normalizedEmail = email.trim().toLowerCase();
  const contexts = _getFirebaseContexts();

  // Find the OTP doc across all projects
  let targetCtx    = null;
  let otpDoc       = null;
  let otpRef       = null;

  for (const ctx of contexts) {
    const ref = ctx.db.collection('password_reset_otps').doc(normalizedEmail);
    const doc = await ref.get();
    if (doc.exists) {
      targetCtx = ctx;
      otpDoc    = doc;
      otpRef    = ref;
      console.log(`[PASSWORD_RESET] OTP doc found in project: ${ctx.label}`);
      break;
    }
  }

  if (!targetCtx || !otpDoc) {
    throw new Error('NO_OTP_FOUND');
  }

  const data = otpDoc.data();

  // Check expiry
  if (data.expiresAt.toMillis() < Date.now()) {
    await otpRef.delete();
    throw new Error('OTP_EXPIRED');
  }

  // Check attempts
  if (data.attempts >= 3) {
    await otpRef.delete();
    throw new Error('TOO_MANY_ATTEMPTS');
  }

  // Verify OTP hash
  const inputHash = crypto.createHash('sha256').update(otp.trim()).digest('hex');
  if (inputHash !== data.otpHash) {
    await otpRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
    throw new Error('INVALID_OTP');
  }

  // OTP valid — reset password
  const userRecord = await targetCtx.auth.getUserByEmail(normalizedEmail);
  await targetCtx.auth.updateUser(userRecord.uid, { password: newPassword });
  await otpRef.delete();

  console.log(`[PASSWORD_RESET] Password reset successful for: ${normalizedEmail}`);
  return { success: true };
}

module.exports = { sendResetOtp, resetPasswordWithOtp };
