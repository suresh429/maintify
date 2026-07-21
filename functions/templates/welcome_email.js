'use strict';

/**
 * Builds the HTML body for the apartment-creation welcome email sent to the
 * newly assigned president.
 *
 * Design tokens:
 *   Primary  →  #2F3147  (deep navy)
 *   Accent   →  #6366F1  (indigo)
 *   Success  →  #22C55E  (green badge)
 *
 * All CSS is inlined so the email renders correctly in Gmail AND Outlook.
 * Single-column table layout (max-width 600 px) — the most compatible
 * responsive pattern for email clients.
 *
 * @param {object} params
 * @param {string} params.presidentName   Full name of the apartment president.
 * @param {string} params.apartmentName   Human-readable apartment name.
 * @param {string} params.apartmentCode   Unique registration code (e.g. SAMH5195).
 * @returns {string}  Complete HTML string ready for the email `html` field.
 */

// ─── Configurable branding constants ─────────────────────────────────────────

/** Maintify logo hosted on Firebase Storage. Loaded remotely by the email client. */
const LOGO_URL = 'https://firebasestorage.googleapis.com/v0/b/tivastraapp.firebasestorage.app/o/app_logo.png?alt=media&token=4ed86685-f0ac-4da5-a5b6-69771dbbf520';

/**
 * Destination URL for the "Open Maintify" CTA button (App Store / Play Store).
 * Set to null to hide the button entirely until the link is ready.
 *
 * @type {string|null}
 */
const CTA_URL = null;
// TODO: const CTA_URL = 'https://play.google.com/store/apps/details?id=com.maintify';

// ─────────────────────────────────────────────────────────────────────────────

function buildWelcomeEmail({ presidentName, apartmentName, apartmentCode }) {
  const year = new Date().getFullYear();

  // ── CTA button: rendered only when CTA_URL is provided ────────────────────
  const ctaHtml = CTA_URL
    ? `<table role="presentation" cellpadding="0" cellspacing="0"
              style="margin:0 auto 32px;">
         <tr>
           <td align="center"
               style="border-radius:12px;
                      background:linear-gradient(135deg,#6366F1 0%,#4F46E5 100%);
                      box-shadow:0 4px 16px rgba(99,102,241,0.38);">
             <a href="${CTA_URL}" target="_blank"
                style="display:inline-block;padding:14px 44px;
                       font-size:15px;font-weight:700;color:#FFFFFF;
                       text-decoration:none;letter-spacing:0.4px;
                       font-family:'Segoe UI',Arial,sans-serif;
                       border-radius:12px;">
               Open Maintify
             </a>
           </td>
         </tr>
       </table>`
    : '';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <title>Welcome to Maintify</title>
</head>
<body style="margin:0;padding:0;background-color:#F1F5F9;
             font-family:'Segoe UI',Arial,sans-serif;">

  <!-- ═══════════════════  Outer wrapper  ═══════════════════ -->
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background-color:#F1F5F9;padding:40px 16px;">
    <tr>
      <td align="center">

        <!-- ═══════════════════  Card  ═══════════════════ -->
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
               style="max-width:600px;background-color:#FFFFFF;border-radius:20px;
                      overflow:hidden;
                      box-shadow:0 2px 8px rgba(0,0,0,0.06),
                                 0 8px 32px rgba(0,0,0,0.06);">

          <!-- ─── Header ──────────────────────────────────────────── -->
          <tr>
            <td style="background:linear-gradient(135deg,#2F3147 0%,#6366F1 100%);
                       padding:32px 40px 30px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <!-- Logo — glass badge matching the app design system.
                       Outer div: 64×64, rgba bg + border + 16 px radius.
                       Inner div: 8 px padding to centre the 48×48 image.
                       Degrades gracefully in Outlook (container transparent,
                       logo still visible directly on the gradient). -->
                  <td style="vertical-align:middle;padding-right:18px;">
                    <div style="display:inline-block;width:64px;height:64px;
                                background:rgba(255,255,255,0.14);
                                border:1px solid rgba(255,255,255,0.10);
                                border-radius:16px;overflow:hidden;">
                      <div style="padding:8px;">
                        <img src="${LOGO_URL}" alt="Maintify Logo"
                             width="48" height="48"
                             style="display:block;width:48px;height:48px;
                                    object-fit:contain;
                                    border:none;outline:none;" />
                      </div>
                    </div>
                  </td>
                  <!-- Brand text -->
                  <td style="vertical-align:middle;">
                    <div style="font-size:24px;font-weight:800;color:#FFFFFF;
                                letter-spacing:3.5px;line-height:1.15;
                                font-family:'Segoe UI',Arial,sans-serif;">
                      MAINTIFY
                    </div>
                    <div style="font-size:11px;color:rgba(255,255,255,0.68);
                                letter-spacing:2px;margin-top:5px;
                                font-family:'Segoe UI',Arial,sans-serif;">
                      Manage &bull; Maintain &bull; Simplify
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- ─── Body ────────────────────────────────────────────── -->
          <tr>
            <td style="padding:40px 40px 8px;">

              <!-- Greeting -->
              <p style="margin:0 0 10px;font-size:22px;font-weight:700;
                        color:#2F3147;line-height:1.3;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Welcome to Maintify, ${escapeHtml(presidentName)}! &#127881;
              </p>
              <p style="margin:0 0 6px;font-size:15px;font-weight:500;
                        color:#475569;line-height:1.6;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Your apartment account has been successfully created and is ready to use.
              </p>
              <p style="margin:0 0 28px;font-size:14px;color:#64748B;line-height:1.7;
                        font-family:'Segoe UI',Arial,sans-serif;">
                You are now the Apartment President of
                <strong style="color:#2F3147;">${escapeHtml(apartmentName)}</strong>
                and can start managing your community right away.
              </p>

              <!-- ── Apartment Details card ──────────────────────── -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                     style="background:#F8FAFC;border-radius:14px;
                            border:1px solid #E2E8F0;margin-bottom:28px;">

                <!-- Section label -->
                <tr>
                  <td style="padding:18px 24px 4px;">
                    <p style="margin:0;font-size:11px;font-weight:700;
                              color:#6366F1;letter-spacing:1.4px;
                              text-transform:uppercase;
                              font-family:'Segoe UI',Arial,sans-serif;">
                      Apartment Details
                    </p>
                  </td>
                </tr>

                <!-- Apartment Name -->
                <tr>
                  <td style="padding:10px 24px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="font-size:13px;color:#94A3B8;width:150px;
                                   vertical-align:middle;
                                   font-family:'Segoe UI',Arial,sans-serif;">
                          Apartment Name
                        </td>
                        <td style="font-size:15px;font-weight:600;color:#2F3147;
                                   vertical-align:middle;
                                   font-family:'Segoe UI',Arial,sans-serif;">
                          ${escapeHtml(apartmentName)}
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <tr>
                  <td style="padding:0 24px;">
                    <div style="height:1px;background:#E2E8F0;"></div>
                  </td>
                </tr>

                <!-- Apartment Code — highlighted badge -->
                <tr>
                  <td style="padding:10px 24px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="font-size:13px;color:#94A3B8;width:150px;
                                   vertical-align:middle;
                                   font-family:'Segoe UI',Arial,sans-serif;">
                          Apartment Code
                        </td>
                        <td style="vertical-align:middle;">
                          <span style="display:inline-block;background:#EEF2FF;
                                       color:#4F46E5;font-size:20px;font-weight:700;
                                       letter-spacing:4px;padding:7px 16px;
                                       border-radius:10px;
                                       font-family:'Courier New',monospace;">
                            ${escapeHtml(apartmentCode)}
                          </span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <tr>
                  <td style="padding:0 24px;">
                    <div style="height:1px;background:#E2E8F0;"></div>
                  </td>
                </tr>

                <!-- Role badge -->
                <tr>
                  <td style="padding:10px 24px 20px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="font-size:13px;color:#94A3B8;width:150px;
                                   vertical-align:middle;
                                   font-family:'Segoe UI',Arial,sans-serif;">
                          Role
                        </td>
                        <td style="vertical-align:middle;">
                          <span style="display:inline-block;background:#DCFCE7;
                                       color:#166534;font-size:12px;font-weight:700;
                                       padding:4px 12px;border-radius:20px;
                                       letter-spacing:0.4px;
                                       font-family:'Segoe UI',Arial,sans-serif;">
                            &#10003;&nbsp;President
                          </span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
              <!-- /Apartment Details card -->

              <!-- Instructions -->
              <p style="margin:0 0 10px;font-size:14px;color:#475569;line-height:1.7;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Sign in to the <strong style="color:#2F3147;">Maintify</strong> app
                using your registered email address to begin managing your apartment community.
              </p>
              <p style="margin:0 0 32px;font-size:13px;color:#94A3B8;line-height:1.6;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Share the <strong style="color:#4F46E5;">Apartment Code</strong> above
                with your residents so they can register and join your community.
              </p>

              <!-- CTA button (hidden when CTA_URL is null) -->
              ${ctaHtml}

            </td>
          </tr>

          <!-- ─── Signature ────────────────────────────────────────── -->
          <tr>
            <td style="padding:4px 40px 36px;">
              <p style="margin:0;font-size:14px;color:#475569;line-height:1.8;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Best regards,<br/>
                <strong style="color:#2F3147;">The Maintify Team</strong>
              </p>
            </td>
          </tr>

          <!-- ─── Footer ──────────────────────────────────────────── -->
          <tr>
            <td style="background:#F8FAFC;border-top:1px solid #E2E8F0;
                       padding:28px 40px 24px;text-align:center;">
              <p style="margin:0 0 4px;font-size:13px;font-weight:600;
                        color:#475569;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Need help?
              </p>
              <p style="margin:0 0 18px;font-size:13px;
                        font-family:'Segoe UI',Arial,sans-serif;">
                &#128231;&nbsp;<a href="mailto:support.maintify@gmail.com"
                   style="color:#6366F1;text-decoration:none;font-weight:500;">
                  support.maintify@gmail.com
                </a>
              </p>
              <p style="margin:0 0 8px;font-size:12px;color:#64748B;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Thank you for choosing Maintify &#10084;&#65039;
              </p>
              <p style="margin:0;font-size:11px;color:#94A3B8;letter-spacing:0.3px;
                        font-family:'Segoe UI',Arial,sans-serif;">
                &copy; ${year} Maintify. All rights reserved.
              </p>
              <p style="margin:6px 0 0;font-size:11px;color:#CBD5E1;
                        font-family:'Segoe UI',Arial,sans-serif;">
                This email was sent because a new apartment was registered in Maintify.
                If this was not you, please ignore this email.
              </p>
            </td>
          </tr>

        </table>
        <!-- /Card -->

      </td>
    </tr>
  </table>

</body>
</html>`;
}

/**
 * Escapes the five HTML-special characters to prevent XSS in the email body.
 * Must be applied to every user-supplied value interpolated into the template.
 *
 * @param {string | null | undefined} str
 * @returns {string}
 */
function escapeHtml(str) {
  if (str == null) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

module.exports = { buildWelcomeEmail };
