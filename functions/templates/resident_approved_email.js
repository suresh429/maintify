'use strict';

/**
 * Builds the HTML body for the resident-approval email sent when an admin
 * approves a resident's join request.
 *
 * All CSS is inlined for Gmail / Outlook compatibility.
 *
 * @param {string} name  Resident's display name.
 * @returns {string}     Complete HTML string ready for the email `html` field.
 */
function buildResidentApprovedEmail(name) {
  const year = new Date().getFullYear();
  const n    = escapeHtml(name);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <title>Registration Approved — Maintify</title>
</head>
<body style="margin:0;padding:0;background-color:#F1F5F9;font-family:'Segoe UI',Arial,sans-serif;">

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background-color:#F1F5F9;padding:40px 0;">
    <tr>
      <td align="center">

        <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
               style="max-width:600px;background-color:#FFFFFF;border-radius:16px;
                      overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#2F3147 0%,#6366F1 100%);
                       padding:32px 40px;text-align:center;">
              <div style="display:inline-block;background:rgba(255,255,255,0.15);
                          border-radius:12px;padding:8px 16px;margin-bottom:10px;">
                <span style="font-size:20px;font-weight:700;color:#FFFFFF;
                             letter-spacing:3px;font-family:'Segoe UI',Arial,sans-serif;">
                  MAINTIFY
                </span>
              </div><br/>
              <span style="font-size:12px;color:rgba(255,255,255,0.75);letter-spacing:1.2px;">
                MANAGE &bull; MAINTAIN &bull; SIMPLIFY
              </span>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:36px 40px 28px;">
              <p style="margin:0 0 10px;font-size:22px;font-weight:700;color:#2F3147;">
                Registration Approved &#10003;
              </p>
              <p style="margin:0 0 20px;font-size:15px;color:#64748B;line-height:1.7;">
                Hello <strong>${n}</strong>,<br/>
                Great news! Your registration request has been approved by the apartment president.
              </p>
              <div style="background:#F0FDF4;border:1px solid #86EFAC;border-radius:10px;
                          padding:16px 20px;margin-bottom:20px;">
                <p style="margin:0;font-size:14px;font-weight:600;color:#166534;">
                  &#10003; You can now log in to Maintify using your registered email and password.
                </p>
              </div>
              <p style="margin:0;font-size:14px;color:#475569;line-height:1.7;">
                Open the Maintify app and sign in to access your apartment dashboard,
                view bills, raise complaints, and more.
              </p>
              <p style="margin:24px 0 0;font-size:14px;color:#475569;">
                Welcome aboard,<br/>
                <strong style="color:#2F3147;">The Maintify Team</strong>
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#F8FAFC;border-top:1px solid #E2E8F0;
                       padding:16px 40px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#94A3B8;">
                &copy; ${year} Maintify &bull; Manage &bull; Maintain &bull; Simplify
              </p>
              <p style="margin:4px 0 0;font-size:11px;color:#CBD5E1;">
                You received this email because of activity on your Maintify account.
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

/**
 * Escapes HTML special characters to prevent XSS in email bodies.
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

module.exports = { buildResidentApprovedEmail };
