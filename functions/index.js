/**
 * Maintify — Firebase Cloud Functions (2nd Gen)
 *
 * All FCM + Firestore notification logic delegates to notificationService.js.
 * Email (SMTP) functions keep their own logic (they use Firebase Secrets).
 *
 * Trigger map:
 *   president_invitations/{invId}         onCreate  → Invitation email  (SMTP)
 *   users/{userId}                        onUpdate  → Welcome email when welcomeEmailReady=true (SMTP)
 *   apartments/{aptId}                    onUpdate  → FCM: president registered / role transferred
 *   users/{userId}                        onCreate  → FCM: new resident joined → notify admin
 *   bills/{billId}                        onCreate  → FCM: new bill → notify residents
 *   bills/{billId}                        onUpdate  → FCM: bill edited → notify residents
 *   bills/{billId}                        onDelete  → FCM: bill deleted → notify residents
 *   meetings/{meetingId}                  onCreate  → FCM: new meeting → notify residents
 *   meetings/{meetingId}                  onUpdate  → FCM: meeting edited / cancelled
 *   complaints/{complaintId}              onCreate  → FCM: new complaint → notify admin
 *   complaints/{complaintId}              onUpdate  → FCM: complaint closed → notify creator
 *   complaints/{id}/messages/{msgId}      onCreate  → FCM: new message → notify other party
 *   payments/{paymentId}                  onUpdate  → FCM: payment submitted / verified / rejected
 */

'use strict';

const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

const { sendEmail, GMAIL_EMAIL, GMAIL_APP_PASSWORD } = require('./services/mailService');
const { buildWelcomeEmail }             = require('./templates/welcome_email');
const { buildResidentApprovedEmail }    = require('./templates/resident_approved_email');
const { buildPresidentInvitationEmail } = require('./templates/president_invitation_email');
const {
  sendToUser,
  sendToUsers,
  sendToApartment,
  sendToRole,
} = require('./services/notificationService');

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Utility
// ─────────────────────────────────────────────────────────────────────────────

function _truncate(str, maxLen) {
  if (!str) return '';
  return str.length <= maxLen ? str : str.substring(0, maxLen) + '…';
}

function _formatTimestamp(ts) {
  if (!ts || typeof ts.toDate !== 'function') return '';
  return ts.toDate().toLocaleDateString('en-IN', {
    day: 'numeric', month: 'short', year: 'numeric',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// EMAIL — President invitation created
// ─────────────────────────────────────────────────────────────────────────────

exports.onPresidentInvitationCreated = onDocumentCreated(
  { document: 'president_invitations/{invId}', secrets: [GMAIL_EMAIL, GMAIL_APP_PASSWORD] },
  async (event) => {
    const inv = event.data.data();

    if (inv.invitationEmailSentAt) {
      console.log('[EMAIL] onPresidentInvitationCreated: already sent — skipping');
      return;
    }

    const { presidentEmail, presidentName, apartmentName, apartmentCode, invitationToken } = inv;
    if (!presidentEmail || !invitationToken) {
      console.warn('[EMAIL] onPresidentInvitationCreated: missing email or token — skipping');
      return;
    }

    const towerCount = inv.towerCount || 0;
    const towerNames = inv.towerNames || [];
    const towerInfo  = towerCount > 0 && towerNames.length > 0
      ? `${towerCount} ${towerCount === 1 ? 'Tower' : 'Towers'} (${towerNames.join(', ')})`
      : null;

    try {
      await sendEmail({
        to:      presidentEmail,
        subject: `You're Invited to Activate ${apartmentName} on Maintify`,
        html:    buildPresidentInvitationEmail({
          presidentName:    presidentName  || 'President',
          apartmentName:    apartmentName  || '',
          apartmentCode:    apartmentCode  || '',
          invitationToken,
          apartmentType:    inv.apartmentType    || null,
          apartmentAddress: inv.apartmentAddress || null,
          towerInfo,
          presidentFlat:    inv.presidentFlatNumber || null,
        }),
      });
      console.log('[EMAIL] Invitation sent to', presidentEmail);
      await event.data.ref.update({
        invitationEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error('[EMAIL] Invitation send failed:', e?.message ?? e);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// EMAIL — Welcome email after email verification
// ─────────────────────────────────────────────────────────────────────────────

exports.onWelcomeEmailReady = onDocumentUpdated(
  { document: 'users/{userId}', secrets: [GMAIL_EMAIL, GMAIL_APP_PASSWORD] },
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();

    if (!after.welcomeEmailReady || before.welcomeEmailReady) return;
    if (after.welcomeEmailSentAt) {
      console.log('[EMAIL] onWelcomeEmailReady: already sent — skipping');
      return;
    }

    const { email, name, role } = after;
    if (!email) { console.warn('[EMAIL] onWelcomeEmailReady: no email — skipping'); return; }
    if (role !== 'admin' && role !== 'user') {
      console.log(`[EMAIL] onWelcomeEmailReady: role=${role} — skipping`);
      return;
    }

    try {
      let subject, html;

      if (role === 'admin') {
        const aptId = after.apartmentId;
        let aptName = after.apartmentName || '';
        let aptCode = after.apartmentCode || '';
        let aptType = after.apartmentType || null;
        let aptAddr = after.apartmentAddress || null;
        let presFlat = after.flatNumber || null;
        let towerInfo = null;

        if (aptId && (!aptName || !aptCode)) {
          const aptDoc = await db.collection('apartments').doc(aptId).get();
          if (aptDoc.exists) {
            const apt  = aptDoc.data();
            aptName    = aptName  || apt.name    || '';
            aptCode    = aptCode  || apt.code    || apt.apartmentCode || '';
            aptType    = aptType  || apt.type    || null;
            aptAddr    = aptAddr  || apt.address || null;
            const tc   = apt.towerCount || 0;
            const tn   = apt.towerNames || [];
            if (tc > 0 && tn.length > 0) {
              towerInfo = `${tc} ${tc === 1 ? 'Tower' : 'Towers'} (${tn.join(', ')})`;
            }
          }
        }

        subject = `Welcome to Maintify — ${aptName} is Live!`;
        html    = buildWelcomeEmail({
          presidentName: name ?? 'President',
          apartmentName: aptName,
          apartmentCode: aptCode,
          apartmentType: aptType,
          apartmentAddress: aptAddr,
          towerInfo,
          presidentFlat: presFlat,
          registrationDate: new Date().toLocaleDateString('en-IN', {
            day: 'numeric', month: 'short', year: 'numeric',
          }),
        });
      } else {
        subject = 'Welcome to Maintify — Your Account is Ready!';
        html    = buildResidentApprovedEmail(name ?? 'Resident');
      }

      console.log(`[EMAIL] Sending welcome (role=${role}) to`, email);
      await sendEmail({ to: email, subject, html });
      await event.data.after.ref.update({
        welcomeEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error('[EMAIL] Welcome email failed:', e?.message ?? e);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FCM — President registered → notify super admins
// ─────────────────────────────────────────────────────────────────────────────

exports.onPresidentRegistered = onDocumentUpdated('apartments/{aptId}', async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();

  if (before.status !== 'waiting_for_president' || after.status !== 'active') return;

  const aptId = event.params.aptId;
  await sendToRole('superAdmin', {
    title:        'New President Registered',
    body:         `${after.presidentName ?? 'A president'} has registered for ${after.name ?? 'an apartment'}.`,
    type:         'president_registered',
    referenceId:  aptId,
    referenceType: 'apartment',
    aptId,
    saveToFirestore: true,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — President transferred → notify old + new president
// ─────────────────────────────────────────────────────────────────────────────

exports.onPresidentTransferred = onDocumentUpdated('apartments/{aptId}', async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();

  if (!before.presidentId || !after.presidentId) return;
  if (before.presidentId === after.presidentId) return;

  const aptId   = event.params.aptId;
  const aptName = after.name ?? 'your apartment';

  await Promise.all([
    sendToUser(after.presidentId, {
      title:        'You Are Now the Apartment President',
      body:         `You have been assigned as president of ${aptName}.`,
      type:         'president_transfer',
      referenceId:  aptId,
      referenceType: 'apartment',
      aptId,
      saveToFirestore: true,
    }),
    sendToUser(before.presidentId, {
      title:        'President Role Transferred',
      body:         `Your president role for ${aptName} has been transferred to ${after.presidentName ?? 'another member'}.`,
      type:         'president_transfer',
      referenceId:  aptId,
      referenceType: 'apartment',
      aptId,
      saveToFirestore: true,
    }),
  ]);
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — New resident joined → notify admin
// ─────────────────────────────────────────────────────────────────────────────

exports.onResidentRegistered = onDocumentCreated('users/{userId}', async (event) => {
  const user = event.data.data();
  if (user.role !== 'user') return;

  const aptId = user.apartmentId;
  if (!aptId) return;

  const name = user.name ?? 'A resident';
  const unit = user.flatNumber ?? user.unit ?? '?';

  await sendToApartment(aptId, 'admin', {
    title:        'New Resident Joined',
    body:         `${name} from Flat ${unit} has joined your apartment.`,
    type:         'resident_registered',
    referenceId:  event.params.userId,
    referenceType: 'user',
    aptId,
    saveToFirestore: true,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — Bill created → notify all residents
// ─────────────────────────────────────────────────────────────────────────────

exports.onBillCreated = onDocumentCreated('bills/{billId}', async (event) => {
  const bill  = event.data.data();
  const aptId = bill.apartmentId;
  if (!aptId) return;

  const billId = event.params.billId;
  const perFlat = bill.totalFlats > 0
    ? Math.round(bill.totalAmount / bill.totalFlats)
    : bill.totalAmount;

  await sendToApartment(aptId, 'user', {
    title:        `New Bill: ${bill.title ?? bill.month ?? 'Maintenance'}`,
    body:         `A new maintenance bill has been generated — ₹${perFlat} per flat due by ${_formatTimestamp(bill.dueDate)}.`,
    type:         'bill',
    referenceId:  billId,
    referenceType: 'bill',
    route:        'bill_detail',
    aptId,
    saveToFirestore: true,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — Bill updated (admin edited) → notify all residents
//   Only fires when totalAmount or dueDate or title changes — not for payment ops.
// ─────────────────────────────────────────────────────────────────────────────

exports.onBillUpdated = onDocumentUpdated('bills/{billId}', async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();
  const aptId  = after.apartmentId;
  if (!aptId) return;

  const amountChanged = before.totalAmount !== after.totalAmount;
  const dueDateChanged = JSON.stringify(before.dueDate) !== JSON.stringify(after.dueDate);
  const titleChanged  = before.title !== after.title;
  const categoriesChanged = JSON.stringify(before.categories) !== JSON.stringify(after.categories);

  if (!amountChanged && !dueDateChanged && !titleChanged && !categoriesChanged) return;

  const billId = event.params.billId;
  await sendToApartment(aptId, 'user', {
    title:        'Maintenance Bill Updated',
    body:         `A maintenance bill has been updated. Please review the latest changes.`,
    type:         'bill_updated',
    referenceId:  billId,
    referenceType: 'bill',
    route:        'bill_detail',
    aptId,
    saveToFirestore: true,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — Bill deleted → notify all residents
// ─────────────────────────────────────────────────────────────────────────────

exports.onBillDeleted = onDocumentDeleted('bills/{billId}', async (event) => {
  const bill  = event.data.data();
  const aptId = bill?.apartmentId;
  if (!aptId) return;

  await sendToApartment(aptId, 'user', {
    title:        'Maintenance Bill Removed',
    body:         `A maintenance bill has been removed by the president.`,
    type:         'bill_deleted',
    referenceId:  event.params.billId,
    referenceType: 'bill',
    aptId,
    saveToFirestore: true,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — Meeting created → notify all residents
// ─────────────────────────────────────────────────────────────────────────────

exports.onMeetingCreated = onDocumentCreated('meetings/{meetingId}', async (event) => {
  const meeting  = event.data.data();
  const aptId    = meeting.apartmentId;
  if (!aptId) return;

  const meetingId = event.params.meetingId;
  const dateStr   = _formatTimestamp(meeting.scheduledAt);

  await sendToApartment(aptId, 'user', {
    title:        `New Meeting: ${meeting.title ?? 'Apartment Meeting'}`,
    body:         `A new apartment meeting has been scheduled on ${dateStr}.`,
    type:         'meeting',
    referenceId:  meetingId,
    referenceType: 'meeting',
    route:        'meeting_detail',
    aptId,
    saveToFirestore: true,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — Meeting updated or cancelled → notify all residents
// ─────────────────────────────────────────────────────────────────────────────

exports.onMeetingUpdated = onDocumentUpdated('meetings/{meetingId}', async (event) => {
  const before    = event.data.before.data();
  const after     = event.data.after.data();
  const aptId     = after.apartmentId;
  if (!aptId) return;

  const meetingId = event.params.meetingId;

  // Detect cancellation (status changed to cancelled/canceled)
  const wasCancelled =
    after.status === 'cancelled' || after.status === 'canceled';
  const justCancelled = wasCancelled &&
    before.status !== 'cancelled' && before.status !== 'canceled';

  if (justCancelled) {
    await sendToApartment(aptId, 'user', {
      title:        'Meeting Cancelled',
      body:         `The scheduled meeting "${after.title ?? 'Apartment Meeting'}" has been cancelled.`,
      type:         'meeting_cancelled',
      referenceId:  meetingId,
      referenceType: 'meeting',
      aptId,
      saveToFirestore: true,
    });
    return;
  }

  // Detect meaningful edit (title, agenda, scheduledAt changed)
  const titleChanged     = before.title !== after.title;
  const agendaChanged    = before.agenda !== after.agenda;
  const scheduleChanged  = JSON.stringify(before.scheduledAt) !== JSON.stringify(after.scheduledAt);
  const venueChanged     = before.venue !== after.venue;

  if (!titleChanged && !agendaChanged && !scheduleChanged && !venueChanged) return;

  await sendToApartment(aptId, 'user', {
    title:        'Meeting Updated',
    body:         `Meeting information for "${after.title ?? 'Apartment Meeting'}" has been updated.`,
    type:         'meeting_updated',
    referenceId:  meetingId,
    referenceType: 'meeting',
    route:        'meeting_detail',
    aptId,
    saveToFirestore: true,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — Complaint created → notify admin
// ─────────────────────────────────────────────────────────────────────────────

exports.onComplaintCreated = onDocumentCreated('complaints/{complaintId}', async (event) => {
  const complaint    = event.data.data();
  const aptId        = complaint.apartmentId;
  if (!aptId) return;

  const complaintId  = event.params.complaintId;

  await sendToApartment(aptId, 'admin', {
    title:        'New Complaint',
    body:         `${complaint.userName ?? 'A resident'} (Flat ${complaint.unit ?? '?'}): ${_truncate(complaint.title, 80)}`,
    type:         'complaint',
    referenceId:  complaintId,
    referenceType: 'complaint',
    route:        'complaint_detail',
    aptId,
    saveToFirestore: true,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — Complaint updated (closed/resolved) → notify complaint creator
// ─────────────────────────────────────────────────────────────────────────────

exports.onComplaintUpdated = onDocumentUpdated('complaints/{complaintId}', async (event) => {
  const before      = event.data.before.data();
  const after       = event.data.after.data();
  const aptId       = after.apartmentId;
  if (!aptId) return;

  const complaintId = event.params.complaintId;
  const userId      = after.userId;
  if (!userId) return;

  const closedStatuses  = ['closed', 'resolved', 'completed'];
  const justClosed =
    closedStatuses.includes(after.status) &&
    !closedStatuses.includes(before.status);

  if (!justClosed) return;

  await sendToUser(userId, {
    title:        'Complaint Closed',
    body:         `Your complaint "${_truncate(after.title, 60)}" has been resolved.`,
    type:         'complaint_closed',
    referenceId:  complaintId,
    referenceType: 'complaint',
    route:        'complaint_detail',
    aptId,
    saveToFirestore: true,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM — Complaint message → notify the other party
// ─────────────────────────────────────────────────────────────────────────────

exports.onComplaintMessage = onDocumentCreated(
  'complaints/{complaintId}/messages/{messageId}',
  async (event) => {
    const msg         = event.data.data();
    const { complaintId } = event.params;

    const complaintDoc = await db.collection('complaints').doc(complaintId).get();
    if (!complaintDoc.exists) return;

    const complaint = complaintDoc.data();
    const aptId     = complaint.apartmentId;

    if (msg.isFromAdmin) {
      // Admin replied → notify the resident who raised the complaint
      const userId = complaint.userId;
      if (!userId) return;
      await sendToUser(userId, {
        title:        'Complaint Updated',
        body:         `Admin replied: "${_truncate(msg.content, 80)}"`,
        type:         'complaint_reply',
        referenceId:  complaintId,
        referenceType: 'complaint',
        route:        'complaint_detail',
        aptId,
        saveToFirestore: true,
      });
    } else {
      // Resident sent a message → notify admin
      await sendToApartment(aptId, 'admin', {
        title:        'New Message on Complaint',
        body:         `${msg.senderName ?? 'Resident'}: ${_truncate(msg.content, 80)}`,
        type:         'complaint',
        referenceId:  complaintId,
        referenceType: 'complaint',
        route:        'complaint_detail',
        aptId,
        saveToFirestore: true,
      });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FCM — Payment updated
//   Case A: Resident submitted payment  → FCM + notification to admin
//   Case B: Admin verified payment      → FCM + notification to resident
//   Case C: Admin rejected payment      → FCM + notification to resident
// ─────────────────────────────────────────────────────────────────────────────

exports.onPaymentUpdated = onDocumentUpdated('payments/{paymentId}', async (event) => {
  const before    = event.data.before.data();
  const after     = event.data.after.data();
  const aptId     = after.apartmentId;
  if (!aptId) return;

  const paymentId = event.params.paymentId;
  const billId    = after.billId;
  const userId    = after.userId;
  const unit      = after.unitNumber ?? after.flatNumber ?? '?';

  // Case A: Resident submitted / reported payment
  if (!before.transactionId && after.transactionId && !after.adminVerified) {
    await sendToApartment(aptId, 'admin', {
      title:        'Payment Received',
      body:         `Flat ${unit} marked the maintenance bill as paid. Awaiting verification.`,
      type:         'payment_received',
      referenceId:  billId ?? paymentId,
      referenceType: 'payment',
      route:        'payment_detail',
      aptId,
      saveToFirestore: true,
    });
    return;
  }

  // Case B: Admin verified payment
  if (!before.adminVerified && after.adminVerified && after.status === 'paid') {
    if (!userId) return;
    await sendToUser(userId, {
      title:        'Payment Approved ✓',
      body:         'Your payment has been verified successfully.',
      type:         'payment_approved',
      referenceId:  billId ?? paymentId,
      referenceType: 'payment',
      route:        'payment_detail',
      aptId,
      saveToFirestore: true,
    });
    return;
  }

  // Case C: Admin rejected payment
  const justRejected =
    after.status === 'rejected' && before.status !== 'rejected';
  if (justRejected && userId) {
    await sendToUser(userId, {
      title:        'Payment Rejected',
      body:         'Your payment could not be verified. Please upload the payment receipt again.',
      type:         'payment_rejected',
      referenceId:  billId ?? paymentId,
      referenceType: 'payment',
      route:        'payment_detail',
      aptId,
      saveToFirestore: true,
    });
  }
});
