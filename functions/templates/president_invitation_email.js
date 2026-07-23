'use strict';

/**
 * Builds the HTML invitation email sent to a president when a Super Admin
 * creates their apartment.
 *
 * Uses the same branding/colors as welcome_email.js.
 * Includes a prominent "Activate My Apartment" button and a plaintext token
 * the president can copy into the app.
 *
 * @param {object} params
 * @param {string}      params.presidentName
 * @param {string}      params.apartmentName
 * @param {string}      params.apartmentCode
 * @param {string}      params.invitationToken  12-char alphanumeric token
 * @param {string|null} params.apartmentType
 * @param {string|null} params.apartmentAddress
 * @param {string|null} params.towerInfo         e.g. "2 Towers (A, B)"
 * @param {string|null} params.presidentFlat
 * @returns {string}
 */

const LOGO_URL = 'https://firebasestorage.googleapis.com/v0/b/tivastraapp.firebasestorage.app/o/app_logo.png?alt=media&token=4ed86685-f0ac-4da5-a5b6-69771dbbf520';

function buildPresidentInvitationEmail({
  presidentName,
  apartmentName,
  apartmentCode,
  invitationToken,
  apartmentType    = null,
  apartmentAddress = null,
  towerInfo        = null,
  presidentFlat    = null,
}) {
  const year = new Date().getFullYear();

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Activate Your Apartment on Maintify</title>
</head>
<body style="margin:0;padding:0;background-color:#F1F5F9;
             font-family:'Segoe UI',Arial,sans-serif;">

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background-color:#F1F5F9;padding:40px 16px;">
    <tr>
      <td align="center">

        <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
               style="max-width:600px;background-color:#FFFFFF;border-radius:20px;
                      overflow:hidden;
                      box-shadow:0 2px 8px rgba(0,0,0,0.06),
                                 0 8px 32px rgba(0,0,0,0.06);">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#2F3147 0%,#6366F1 100%);
                       padding:32px 40px 30px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="vertical-align:middle;padding-right:18px;">
                    <div style="display:inline-block;width:64px;height:64px;
                                background:rgba(255,255,255,0.14);
                                border:1px solid rgba(255,255,255,0.10);
                                border-radius:16px;overflow:hidden;">
                      <div style="padding:8px;">
                        <img src="${LOGO_URL}" alt="Maintify Logo"
                             width="48" height="48"
                             style="display:block;width:48px;height:48px;
                                    object-fit:contain;border:none;outline:none;" />
                      </div>
                    </div>
                  </td>
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

          <!-- Body -->
          <tr>
            <td style="padding:40px 40px 8px;">

              <p style="margin:0 0 10px;font-size:22px;font-weight:700;
                        color:#2F3147;line-height:1.3;
                        font-family:'Segoe UI',Arial,sans-serif;">
                You're Invited, ${escapeHtml(presidentName)}! &#127881;
              </p>
              <p style="margin:0 0 6px;font-size:15px;font-weight:500;
                        color:#475569;line-height:1.6;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Your apartment has been set up on Maintify.
                You have been designated as the <strong>President</strong> of
                <strong style="color:#2F3147;">${escapeHtml(apartmentName)}</strong>.
              </p>
              <p style="margin:0 0 28px;font-size:14px;color:#64748B;line-height:1.7;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Activate your account to start managing your community.
              </p>

              <!-- Apartment Details card -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                     style="background:#F8FAFC;border-radius:14px;
                            border:1px solid #E2E8F0;margin-bottom:28px;">
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
                <tr><td style="padding:10px 24px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
                    <td style="font-size:13px;color:#94A3B8;width:150px;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">Apartment Name</td>
                    <td style="font-size:15px;font-weight:600;color:#2F3147;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">${escapeHtml(apartmentName)}</td>
                  </tr></table>
                </td></tr>

                <tr><td style="padding:0 24px;"><div style="height:1px;background:#E2E8F0;"></div></td></tr>

                <!-- Apartment Code -->
                <tr><td style="padding:10px 24px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
                    <td style="font-size:13px;color:#94A3B8;width:150px;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">Apartment Code</td>
                    <td style="vertical-align:middle;">
                      <span style="display:inline-block;background:#EEF2FF;color:#4F46E5;
                                   font-size:20px;font-weight:700;letter-spacing:4px;
                                   padding:7px 16px;border-radius:10px;
                                   font-family:'Courier New',monospace;">
                        ${escapeHtml(apartmentCode)}
                      </span>
                    </td>
                  </tr></table>
                </td></tr>

                ${apartmentType ? `<tr><td style="padding:0 24px;"><div style="height:1px;background:#E2E8F0;"></div></td></tr>
                <tr><td style="padding:10px 24px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
                    <td style="font-size:13px;color:#94A3B8;width:150px;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">Type</td>
                    <td style="font-size:15px;font-weight:600;color:#2F3147;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">${escapeHtml(apartmentType)}</td>
                  </tr></table>
                </td></tr>` : ''}

                ${apartmentAddress ? `<tr><td style="padding:0 24px;"><div style="height:1px;background:#E2E8F0;"></div></td></tr>
                <tr><td style="padding:10px 24px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
                    <td style="font-size:13px;color:#94A3B8;width:150px;vertical-align:top;font-family:'Segoe UI',Arial,sans-serif;">Address</td>
                    <td style="font-size:14px;color:#2F3147;line-height:1.5;vertical-align:top;font-family:'Segoe UI',Arial,sans-serif;">${escapeHtml(apartmentAddress)}</td>
                  </tr></table>
                </td></tr>` : ''}

                ${towerInfo ? `<tr><td style="padding:0 24px;"><div style="height:1px;background:#E2E8F0;"></div></td></tr>
                <tr><td style="padding:10px 24px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
                    <td style="font-size:13px;color:#94A3B8;width:150px;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">Towers</td>
                    <td style="font-size:14px;font-weight:500;color:#2F3147;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">${escapeHtml(towerInfo)}</td>
                  </tr></table>
                </td></tr>` : ''}

                ${presidentFlat ? `<tr><td style="padding:0 24px;"><div style="height:1px;background:#E2E8F0;"></div></td></tr>
                <tr><td style="padding:10px 24px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
                    <td style="font-size:13px;color:#94A3B8;width:150px;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">Your Flat</td>
                    <td style="font-size:15px;font-weight:600;color:#2F3147;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">${escapeHtml(presidentFlat)}</td>
                  </tr></table>
                </td></tr>` : ''}

                <!-- Role badge -->
                <tr><td style="padding:10px 24px 20px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
                    <td style="font-size:13px;color:#94A3B8;width:150px;vertical-align:middle;font-family:'Segoe UI',Arial,sans-serif;">Role</td>
                    <td style="vertical-align:middle;">
                      <span style="display:inline-block;background:#DCFCE7;color:#166534;
                                   font-size:12px;font-weight:700;padding:4px 12px;
                                   border-radius:20px;letter-spacing:0.4px;
                                   font-family:'Segoe UI',Arial,sans-serif;">
                        &#10003;&nbsp;President
                      </span>
                    </td>
                  </tr></table>
                </td></tr>
              </table>

              <!-- Activation Token card -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                     style="background:#EEF2FF;border-radius:14px;
                            border:1px solid #C7D2FE;margin-bottom:24px;">
                <tr>
                  <td style="padding:20px 24px;">
                    <p style="margin:0 0 6px;font-size:11px;font-weight:700;
                              color:#6366F1;letter-spacing:1.4px;text-transform:uppercase;
                              font-family:'Segoe UI',Arial,sans-serif;">
                      Your Activation Token
                    </p>
                    <p style="margin:0 0 12px;font-size:13px;color:#475569;
                              font-family:'Segoe UI',Arial,sans-serif;">
                      Open Maintify &rarr; tap <strong>Activate Existing Apartment</strong> &rarr; enter this token:
                    </p>
                    <div style="text-align:center;padding:14px;
                                background:#FFFFFF;border-radius:10px;
                                border:1px dashed #A5B4FC;">
                      <span style="font-family:'Courier New',monospace;
                                   font-size:26px;font-weight:700;
                                   color:#4F46E5;letter-spacing:5px;">
                        ${escapeHtml(invitationToken)}
                      </span>
                    </div>
                    <p style="margin:10px 0 0;font-size:12px;color:#64748B;
                              font-family:'Segoe UI',Arial,sans-serif;">
                      &#9888;&nbsp;This token expires in <strong>7 days</strong>.
                      Do not share it with anyone.
                    </p>
                  </td>
                </tr>
              </table>

              <!-- How to activate -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                     style="background:#F8FAFC;border-radius:12px;
                            border:1px solid #E2E8F0;margin-bottom:28px;">
                <tr>
                  <td style="padding:18px 24px;">
                    <p style="margin:0 0 10px;font-size:13px;font-weight:700;
                              color:#2F3147;font-family:'Segoe UI',Arial,sans-serif;">
                      How to Activate
                    </p>
                    <ol style="margin:0;padding-left:18px;font-size:13px;color:#475569;
                               line-height:1.9;font-family:'Segoe UI',Arial,sans-serif;">
                      <li>Download &amp; open the <strong>Maintify</strong> app.</li>
                      <li>Tap <strong>Activate Existing Apartment</strong> on the login screen.</li>
                      <li>Enter your <strong>Activation Token</strong> shown above.</li>
                      <li>Create your password and verify your email.</li>
                      <li>Your apartment will be live immediately after verification.</li>
                    </ol>
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- Signature -->
          <tr>
            <td style="padding:4px 40px 36px;">
              <p style="margin:0;font-size:14px;color:#475569;line-height:1.8;
                        font-family:'Segoe UI',Arial,sans-serif;">
                Best regards,<br/>
                <strong style="color:#2F3147;">The Maintify Team</strong>
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#F8FAFC;border-top:1px solid #E2E8F0;
                       padding:28px 40px 24px;text-align:center;">
              <p style="margin:0 0 4px;font-size:13px;font-weight:600;
                        color:#475569;font-family:'Segoe UI',Arial,sans-serif;">
                Need help?
              </p>
              <p style="margin:0 0 18px;font-size:13px;font-family:'Segoe UI',Arial,sans-serif;">
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
                This email was sent because your Super Admin created an apartment
                on Maintify for you. If this was not expected, please contact
                support.maintify@gmail.com.
              </p>
            </td>
          </tr>

        </table>

      </td>
    </tr>
  </table>

</body>
</html>`;
}

function escapeHtml(str) {
  if (str == null) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

module.exports = { buildPresidentInvitationEmail };
