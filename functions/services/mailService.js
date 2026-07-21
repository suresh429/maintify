'use strict';

/**
 * mailService.js — Gmail SMTP transport via Nodemailer.
 *
 * Exports:
 *   sendEmail({ to, subject, html })  — sends one email; throws on failure
 *   GMAIL_EMAIL                       — Firebase Secret reference (for `secrets:` arrays)
 *   GMAIL_APP_PASSWORD                — Firebase Secret reference (for `secrets:` arrays)
 *
 * IMPORTANT: The Nodemailer transporter is created lazily inside sendEmail()
 * so that GMAIL_EMAIL.value() and GMAIL_APP_PASSWORD.value() are only called
 * at runtime inside a function handler — Firebase Secret Manager secrets are
 * not available at module initialisation time.
 *
 * Set secrets once with:
 *   firebase functions:secrets:set GMAIL_EMAIL
 *   firebase functions:secrets:set GMAIL_APP_PASSWORD
 */

const nodemailer = require('nodemailer');
const { defineSecret } = require('firebase-functions/params');

const GMAIL_EMAIL       = defineSecret('GMAIL_EMAIL');
const GMAIL_APP_PASSWORD = defineSecret('GMAIL_APP_PASSWORD');

/**
 * Sends one email via Gmail SMTP.
 *
 * Must be called from inside a Cloud Function handler that declares
 * `secrets: [GMAIL_EMAIL, GMAIL_APP_PASSWORD]` so the runtime injects
 * the secret values before this function executes.
 *
 * @param {object} opts
 * @param {string} opts.to       Recipient address.
 * @param {string} opts.subject  Subject line.
 * @param {string} opts.html     HTML body.
 * @returns {Promise<void>}  Resolves on success; throws on failure.
 */
async function sendEmail({ to, subject, html }) {
  console.log('[EMAIL] Sending email to:', to);

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: GMAIL_EMAIL.value(),
      pass: GMAIL_APP_PASSWORD.value(),
    },
  });

  await transporter.sendMail({
    from: `"Maintify" <${GMAIL_EMAIL.value()}>`,
    to,
    subject,
    html,
  });

  console.log('[EMAIL] Email sent successfully.');
}

module.exports = {
  sendEmail,
  GMAIL_EMAIL,
  GMAIL_APP_PASSWORD,
};
