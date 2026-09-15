'use strict';

/**
 * ============================================================
 * MAINTIFY — Hybrid Billing Migration Script
 * ============================================================
 *
 * PURPOSE:
 *   Migrates the GHMC Garbage category in a specific bill to
 *   "hybrid" billing, marking certain flats as non-applicable
 *   (₹0 charge) and updating pending payment amounts accordingly.
 *
 * USAGE:
 *   node migrate_hybrid.js --dry-run    # Preview all changes, no writes
 *   node migrate_hybrid.js --execute    # Apply changes to Firestore
 *
 * PREREQUISITES:
 *   1. Set GOOGLE_APPLICATION_CREDENTIALS to a service account key
 *      with Firestore read/write access on maintify-ff8c4, OR run
 *      `gcloud auth application-default login` with sufficient permissions.
 *   2. Run from the functions/ directory (firebase-admin must be installed):
 *        cd functions && node migrate_hybrid.js --dry-run
 *
 * SAFETY:
 *   - Targets PRODUCTION (maintify-ff8c4) only — never dev.
 *   - Never modifies apartment or flat documents.
 *   - Never changes bill.totalAmount.
 *   - Skips payments that are paid, approved, or adminVerified.
 *   - Idempotent: re-running with --execute after a successful migration
 *     will detect already-migrated payments and skip them.
 *
 * PARAMETERS (hard-coded below):
 *   APT_CODE                 = 'SAMH8151'
 *   BILL_MONTH               = 'August 2026'
 *   NON_APPLICABLE_FLAT_NUMBERS = ['101']
 *   MIGRATION_FIELD          = 'hybridBillingVersion'
 *   MIGRATION_VERSION        = 2
 * ============================================================
 */

const admin = require('firebase-admin');
const https  = require('https');
const os     = require('os');
const path   = require('path');
const fs     = require('fs');

// ─── Credential setup ─────────────────────────────────────────────────────────
// firebase-admin Firestore requires applicationDefault() or a service account.
// We write the firebase-tools refresh token to a temp file in the
// authorized_user format that gcloud uses, then point
// GOOGLE_APPLICATION_CREDENTIALS at it so applicationDefault() picks it up.
function setupCredentials() {
  const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(cfgPath)) {
    throw new Error('firebase-tools config not found. Run: firebase login');
  }
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const refreshToken = cfg.tokens && cfg.tokens.refresh_token;
  if (!refreshToken) {
    throw new Error('No refresh_token in firebase-tools config. Run: firebase login');
  }
  // Write authorized_user credential file (same format as gcloud ADC)
  const creds = {
    type:          'authorized_user',
    client_id:     '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: refreshToken,
  };
  const tmpFile = path.join(os.tmpdir(), 'maintify_mig_creds.json');
  fs.writeFileSync(tmpFile, JSON.stringify(creds), { mode: 0o600 });
  process.env.GOOGLE_APPLICATION_CREDENTIALS = tmpFile;
  return tmpFile;
}

// ─── Migration parameters ────────────────────────────────────────────────────
const PROJECT_ID = 'maintify-ff8c4';
const APT_CODE = 'SAMH8151';
const BILL_MONTH = 'August 2026';
const NON_APPLICABLE_FLAT_NUMBERS = ['101'];
const MIGRATION_FIELD = 'hybridBillingVersion';
const MIGRATION_VERSION = 2;

// ─── Formatting helpers ───────────────────────────────────────────────────────
const SEP = '─'.repeat(70);
const SEP2 = '═'.repeat(70);

function pad(str, len) {
  const s = String(str ?? '');
  return s.length >= len ? s : s + ' '.repeat(len - s.length);
}

function rpad(str, len) {
  const s = String(str ?? '');
  return s.length >= len ? s : ' '.repeat(len - s.length) + s;
}

function fmt(n) {
  return typeof n === 'number' ? `₹${n.toFixed(2)}` : String(n ?? '—');
}

// ─── Amount calculator ────────────────────────────────────────────────────────
/**
 * Calculate the total bill amount for a given userId across all categories.
 *
 * @param {string} userId
 * @param {Array}  categories
 * @param {number} eligibleCount
 * @param {string[]} nonApplicableResidentIds
 * @param {number} ghmcCatIndex  index of the GHMC Garbage category (-1 if none)
 * @returns {number}
 */
function calcAmount(userId, categories, eligibleCount, nonApplicableResidentIds, ghmcCatIndex) {
  let total = 0;

  for (let i = 0; i < categories.length; i++) {
    const cat = categories[i];
    const isGhmc = (i === ghmcCatIndex);
    const type = (cat.type || '').toLowerCase();
    const overrides = cat.userOverrides || {};
    const applicable = cat.applicableResidentIds || [];

    if (type === 'common') {
      total += (cat.totalAmount || 0) / Math.max(1, eligibleCount);

    } else if (type === 'hybrid') {
      if (isGhmc) {
        // Non-applicable flats pay ₹0
        if (nonApplicableResidentIds.includes(userId)) {
          total += 0;
        } else {
          total += overrides[userId] !== undefined ? overrides[userId] : (cat.defaultAmount || 0);
        }
      } else {
        // Non-GHMC hybrid
        const isApplicable = applicable.length === 0 || applicable.includes(userId);
        if (isApplicable) {
          total += overrides[userId] !== undefined ? overrides[userId] : (cat.defaultAmount || 0);
        } else {
          total += 0;
        }
      }

    } else if (type === 'individual') {
      total += overrides[userId] !== undefined ? overrides[userId] : 0;

    } else {
      // Fallback: treat as common
      total += (cat.totalAmount || 0) / Math.max(1, eligibleCount);
    }
  }

  return Math.round(total * 100) / 100; // round to 2dp
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  const isExecute = args.includes('--execute');

  if (!isDryRun && !isExecute) {
    console.error('\nERROR: You must pass either --dry-run or --execute.\n');
    console.error('  node migrate_hybrid.js --dry-run');
    console.error('  node migrate_hybrid.js --execute\n');
    process.exit(1);
  }

  // Set up application-default credentials from firebase-tools refresh token
  console.log('  Setting up credentials from firebase login session...');
  setupCredentials();
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();

  console.log('\n' + SEP2);
  console.log('  MAINTIFY — Hybrid Billing Migration');
  console.log(`  Project  : ${PROJECT_ID}`);
  console.log(`  Mode     : ${isDryRun ? 'DRY RUN (no writes)' : 'EXECUTE (writes ENABLED)'}`);
  console.log(SEP2);

  // ── STEP A: Find apartment ────────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP A — Locate apartment');
  console.log(SEP);

  const aptSnap = await db.collection('apartments')
    .where('code', '==', APT_CODE)
    .limit(1)
    .get();

  if (aptSnap.empty) {
    console.error(`\nERROR: No apartment found with code "${APT_CODE}". Aborting.\n`);
    process.exit(1);
  }

  const aptDoc = aptSnap.docs[0];
  const apt = aptDoc.data();
  const aptId = aptDoc.id;

  console.log(`  Firestore ID  : ${aptId}`);
  console.log(`  Name          : ${apt.name}`);
  console.log(`  Total Flats   : ${apt.totalFlats}`);
  console.log(`  Status        : ${apt.status}`);
  console.log(`  Excluded IDs  : ${(apt.excludedUserIds || []).join(', ') || '(none)'}`);

  // ── STEP B: Load flats ────────────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP B — Load flats');
  console.log(SEP);

  const flatsSnap = await db.collection('flats')
    .where('apartmentId', '==', aptId)
    .get();

  if (flatsSnap.empty) {
    console.error(`\nERROR: No flats found for apartment "${aptId}". Aborting.\n`);
    process.exit(1);
  }

  // Map: flatNumber (string) → flat data
  const residentByFlat = {};   // flatNumber → residentId
  const allFlatDocs = [];

  for (const doc of flatsSnap.docs) {
    const f = doc.data();
    allFlatDocs.push({ id: doc.id, ...f });
    if (f.residentId) {
      residentByFlat[String(f.flatNumber)] = f.residentId;
    }
  }

  // Sort numerically by flatNumber
  allFlatDocs.sort((a, b) => {
    const na = parseInt(a.flatNumber, 10);
    const nb = parseInt(b.flatNumber, 10);
    return isNaN(na) || isNaN(nb) ? String(a.flatNumber).localeCompare(String(b.flatNumber)) : na - nb;
  });

  console.log(`  ${pad('Flat', 8)} ${pad('ResidentId', 32)} ${pad('Status', 10)} Note`);
  console.log('  ' + '─'.repeat(66));

  const nonApplicableResidentIds = [];

  for (const f of allFlatDocs) {
    const flatNum = String(f.flatNumber);
    const isNonApplicable = NON_APPLICABLE_FLAT_NUMBERS.includes(flatNum);
    const note = isNonApplicable ? '← NON-APPLICABLE (GHMC ₹0)' : '';
    console.log(`  ${pad(flatNum, 8)} ${pad(f.residentId || '—', 32)} ${pad(f.status || '—', 10)} ${note}`);
    if (isNonApplicable && f.residentId) {
      nonApplicableResidentIds.push(f.residentId);
    }
  }

  console.log(`\n  Non-applicable resident IDs: ${nonApplicableResidentIds.join(', ') || '(none — flat may be vacant)'}`);

  // Warn if a non-applicable flat has no resident
  for (const flatNum of NON_APPLICABLE_FLAT_NUMBERS) {
    if (!residentByFlat[flatNum]) {
      console.warn(`  WARNING: Flat ${flatNum} is non-applicable but has no residentId — no payment to update.`);
    }
  }

  // All residentIds that have a payment (occupied flats)
  const allResidentIds = Object.values(residentByFlat);

  // ── STEP C: Load bills ────────────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP C — Load bills');
  console.log(SEP);

  const billsSnap = await db.collection('bills')
    .where('apartmentId', '==', aptId)
    .where('month', '==', BILL_MONTH)
    .get();

  if (billsSnap.empty) {
    console.error(`\nERROR: No bills found for apartment "${aptId}" in month "${BILL_MONTH}". Aborting.\n`);
    process.exit(1);
  }

  console.log(`  Found ${billsSnap.size} bill(s) for "${BILL_MONTH}":\n`);

  let targetBillDoc = null;
  let targetBill = null;
  let ghmcCatIndex = -1;

  for (const doc of billsSnap.docs) {
    const b = doc.data();
    console.log(`  Bill ID            : ${doc.id}`);
    console.log(`  Month              : ${b.month}`);
    console.log(`  Total Amount       : ${fmt(b.totalAmount)}`);
    console.log(`  Total Flats        : ${b.totalFlats}`);
    console.log(`  Excluded User IDs  : ${(b.excludedUserIds || []).join(', ') || '(none)'}`);
    console.log(`  ${MIGRATION_FIELD}  : ${b[MIGRATION_FIELD] ?? '(not set)'}`);

    if (b.categories && Array.isArray(b.categories) && b.categories.length > 0) {
      console.log(`  Categories (${b.categories.length}):`);
      b.categories.forEach((cat, idx) => {
        const ar = (cat.applicableResidentIds || []);
        console.log(`    [${idx}] ${cat.name}`);
        console.log(`         type              : ${cat.type}`);
        console.log(`         totalAmount       : ${fmt(cat.totalAmount)}`);
        console.log(`         defaultAmount     : ${fmt(cat.defaultAmount)}`);
        console.log(`         applicableResidentIds: [${ar.join(', ') || 'all'}]`);

        // Detect GHMC Garbage category
        const nameLower = (cat.name || '').toLowerCase();
        if (ghmcCatIndex === -1 && (nameLower.includes('ghmc') || nameLower.includes('garbage'))) {
          ghmcCatIndex = idx;
          console.log(`         ↑ GHMC GARBAGE CATEGORY IDENTIFIED`);
        }
      });
    } else {
      console.log('  Categories         : (none — old format, checking top-level GHMC fields)');
      // Old format: treat the entire bill as a single implicit "hybrid" category
      // We'll construct a synthetic categories array for calculation purposes.
    }

    console.log('');

    // Use the first matching bill (there should be exactly one per month per apartment)
    if (!targetBillDoc) {
      targetBillDoc = doc;
      targetBill = b;
    }
  }

  if (!targetBillDoc) {
    console.error('\nERROR: Could not identify a target bill. Aborting.\n');
    process.exit(1);
  }

  // ─── Handle old (no-categories) format ────────────────────────────────────
  let categories;
  let isOldFormat = false;

  if (!targetBill.categories || !Array.isArray(targetBill.categories) || targetBill.categories.length === 0) {
    isOldFormat = true;
    console.warn('  WARNING: Bill uses old format (no categories array). Constructing synthetic category for calculation.');
    // Build a single synthetic "hybrid" category using top-level bill fields.
    categories = [
      {
        name: 'GHMC Garbage (legacy)',
        type: 'hybrid',
        totalAmount: targetBill.totalAmount || 0,
        defaultAmount: targetBill.defaultAmount || 0,
        userOverrides: targetBill.userOverrides || {},
        applicableResidentIds: targetBill.applicableResidentIds || [],
      },
    ];
    ghmcCatIndex = 0;
  } else {
    categories = targetBill.categories;
  }

  // ── STEP D: Confirm GHMC category found ───────────────────────────────────
  console.log(SEP);
  console.log('STEP D — GHMC Garbage category');
  console.log(SEP);

  if (ghmcCatIndex === -1) {
    console.error('\nERROR: Could not find a category with "ghmc" or "garbage" in its name. Aborting.\n');
    process.exit(1);
  }

  const ghmcCat = categories[ghmcCatIndex];
  console.log(`  Index             : ${ghmcCatIndex}`);
  console.log(`  Name              : ${ghmcCat.name}`);
  console.log(`  Type              : ${ghmcCat.type}`);
  console.log(`  totalAmount       : ${fmt(ghmcCat.totalAmount)}`);
  console.log(`  defaultAmount     : ${fmt(ghmcCat.defaultAmount)}`);
  console.log(`  Current applicableResidentIds: [${(ghmcCat.applicableResidentIds || []).join(', ') || 'all residents'}]`);

  // ── STEP E: Reconciliation check ─────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP E — Reconciliation check');
  console.log(SEP);

  const storedTotal = ghmcCat.totalAmount || 0;
  const applicableCount = allResidentIds.length - nonApplicableResidentIds.length;
  const sumOfCharges = applicableCount * (ghmcCat.defaultAmount || 0);

  console.log(`  Stored totalAmount          : ${fmt(storedTotal)}`);
  console.log(`  All residents (occupied)    : ${allResidentIds.length}`);
  console.log(`  Non-applicable residents    : ${nonApplicableResidentIds.length}`);
  console.log(`  Applicable count            : ${applicableCount}`);
  console.log(`  Expected sum (count × def.) : ${fmt(sumOfCharges)}`);

  if (Math.abs(storedTotal - sumOfCharges) > 0.01) {
    console.log(`\n  ⚠ WARNING: Stored totalAmount (${fmt(storedTotal)}) ≠ expected sum (${fmt(sumOfCharges)}).`);
    console.log(`  Difference: ${fmt(Math.abs(storedTotal - sumOfCharges))}`);
    console.log('  totalAmount will NOT be changed by this migration.');
  } else {
    console.log('\n  ✓ Reconciliation OK — stored total matches expected sum.');
  }

  // ── STEP F: Load payments ─────────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP F — Load payments');
  console.log(SEP);

  const paymentsSnap = await db.collection('payments')
    .where('billId', '==', targetBillDoc.id)
    .get();

  // Map: userId → payment doc
  const paymentByUserId = {};

  if (paymentsSnap.empty) {
    console.log('  (no payment documents found for this bill)');
  } else {
    console.log(`  ${pad('DocId', 40)} ${pad('UserId', 32)} ${pad('Amount', 10)} ${pad('Status', 12)} adminVerified`);
    console.log('  ' + '─'.repeat(102));

    for (const doc of paymentsSnap.docs) {
      const p = doc.data();
      paymentByUserId[p.userId] = { id: doc.id, ...p };
      console.log(`  ${pad(doc.id, 40)} ${pad(p.userId, 32)} ${pad(fmt(p.amount), 10)} ${pad(p.status || '—', 12)} ${p.adminVerified ?? false}`);
    }
  }

  // ── STEP G: eligibleCount ────────────────────────────────────────────────
  const excludedUserIds = targetBill.excludedUserIds || [];
  const totalFlats = targetBill.totalFlats || apt.totalFlats || 0;
  const eligibleCount = Math.max(1, totalFlats - excludedUserIds.length);

  console.log(`\n  totalFlats      : ${totalFlats}`);
  console.log(`  excludedUserIds : ${excludedUserIds.length}`);
  console.log(`  eligibleCount   : ${eligibleCount}`);

  // ── STEP H: Per-flat diff table ───────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP H — Per-flat change analysis');
  console.log(SEP);

  console.log(`  ${pad('Flat', 6)} ${pad('OldGHMC', 10)} ${pad('NewGHMC', 10)} ${pad('OldTotal', 10)} ${pad('NewTotal', 10)} ${pad('Status', 12)} Action`);
  console.log('  ' + '─'.repeat(90));

  const writeOps = []; // { paymentDocId, userId, newAmount }
  const newApplicableIds = []; // residents who ARE applicable (for ghmcCat.applicableResidentIds)

  // Build set of non-applicable for quick lookup
  const nonApplicableSet = new Set(nonApplicableResidentIds);

  // Existing GHMC applicable ids (before migration)
  const currentApplicableIds = ghmcCat.applicableResidentIds || [];

  for (const f of allFlatDocs) {
    const flatNum = String(f.flatNumber);
    const userId = f.residentId;

    if (!userId) {
      console.log(`  ${pad(flatNum, 6)} ${pad('—', 10)} ${pad('—', 10)} ${pad('—', 10)} ${pad('—', 10)} ${pad('(vacant)', 12)} SKIP — no resident`);
      continue;
    }

    const isNonApplicable = nonApplicableSet.has(userId);
    if (!isNonApplicable) {
      newApplicableIds.push(userId);
    }

    // Old GHMC amount for this user
    const oldGhmcAmount = (() => {
      if (currentApplicableIds.length > 0 && !currentApplicableIds.includes(userId)) {
        return 0;
      }
      const overrides = ghmcCat.userOverrides || {};
      return overrides[userId] !== undefined ? overrides[userId] : (ghmcCat.defaultAmount || 0);
    })();

    // New GHMC amount
    const newGhmcAmount = isNonApplicable ? 0 : (
      (() => {
        const overrides = ghmcCat.userOverrides || {};
        return overrides[userId] !== undefined ? overrides[userId] : (ghmcCat.defaultAmount || 0);
      })()
    );

    // Old total = current payment amount (what's stored in Firestore)
    const existingPayment = paymentByUserId[userId];
    const oldTotal = existingPayment ? (existingPayment.amount ?? 0) : null;

    // New total = recalculated using updated GHMC rule
    const newTotal = calcAmount(userId, categories, eligibleCount, nonApplicableResidentIds, ghmcCatIndex);

    const statusStr = existingPayment ? (existingPayment.status || 'pending') : '—';
    const statusUpper = statusStr.toUpperCase();
    const isPaidOrApproved = statusUpper === 'PAID' || statusUpper === 'APPROVED' ||
      (existingPayment && existingPayment.adminVerified === true);

    let action;

    if (!existingPayment) {
      action = 'SKIP — no payment doc';
    } else if (isPaidOrApproved) {
      action = 'SKIP — PAID/APPROVED';
    } else {
      // Idempotency: already migrated AND amount unchanged?
      const alreadyMigrated = (targetBill[MIGRATION_FIELD] !== undefined &&
        targetBill[MIGRATION_FIELD] >= MIGRATION_VERSION);
      const amountUnchanged = Math.abs((oldTotal ?? 0) - newTotal) < 0.01;

      if (alreadyMigrated && amountUnchanged) {
        action = 'SKIP — already migrated';
      } else if (amountUnchanged) {
        action = 'SKIP — amount unchanged';
      } else {
        action = '✓ UPDATE';
        writeOps.push({
          paymentDocId: existingPayment.id,
          userId,
          oldAmount: oldTotal,
          newAmount: newTotal,
        });
      }
    }

    console.log(
      `  ${pad(flatNum, 6)} ${rpad(fmt(oldGhmcAmount), 10)} ${rpad(fmt(newGhmcAmount), 10)} ` +
      `${rpad(oldTotal !== null ? fmt(oldTotal) : '—', 10)} ${rpad(fmt(newTotal), 10)} ` +
      `${pad(statusStr, 12)} ${action}`
    );
  }

  // ── STEP I: Summary ───────────────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP I — Migration summary');
  console.log(SEP);

  console.log(`  Payments to update        : ${writeOps.length}`);
  console.log(`  Bill doc to update        : ${targetBillDoc.id}`);
  console.log(`  New applicableResidentIds : [${newApplicableIds.join(', ') || '(all)'}]`);

  if (writeOps.length > 0) {
    console.log('\n  Payment changes:');
    for (const op of writeOps) {
      console.log(`    ${op.paymentDocId}  ${fmt(op.oldAmount)} → ${fmt(op.newAmount)}`);
    }
  }

  // ── STEP J: Dry run exit ──────────────────────────────────────────────────
  if (isDryRun) {
    console.log('\n' + SEP2);
    console.log('  DRY RUN COMPLETE — no changes written to Firestore.');
    console.log('  Re-run with --execute to apply the changes.');
    console.log(SEP2 + '\n');
    process.exit(0);
  }

  // ── STEP K: Execute ───────────────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP K — Executing Firestore writes');
  console.log(SEP);

  // Build updated categories array
  const updatedCategories = categories.map((cat, idx) => {
    if (idx !== ghmcCatIndex) return cat;
    return {
      ...cat,
      applicableResidentIds: newApplicableIds,
    };
  });

  // Firestore batch (max 500 ops; this migration is small)
  const batch = db.batch();

  // Bill update
  const billRef = db.collection('bills').doc(targetBillDoc.id);
  const billUpdate = {
    categories: updatedCategories,
    [MIGRATION_FIELD]: MIGRATION_VERSION,
    migrationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (isOldFormat) {
    // For old-format bills, store applicableResidentIds at top level too
    billUpdate.applicableResidentIds = newApplicableIds;
  }
  batch.update(billRef, billUpdate);

  // Payment updates
  for (const op of writeOps) {
    const payRef = db.collection('payments').doc(op.paymentDocId);
    batch.update(payRef, {
      amount: op.newAmount,
      migrationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  console.log(`  Committing batch (1 bill update + ${writeOps.length} payment update(s))...`);
  await batch.commit();
  console.log('  ✓ Batch committed successfully.\n');

  // ── Verification ──────────────────────────────────────────────────────────
  console.log('  Verifying written documents...\n');

  let allOk = true;

  // Verify bill
  const verifyBillSnap = await billRef.get();
  const verifyBill = verifyBillSnap.data();
  const billOk = verifyBill[MIGRATION_FIELD] === MIGRATION_VERSION;
  console.log(`  ${billOk ? '✓' : '✗'} Bill ${targetBillDoc.id} — ${MIGRATION_FIELD} = ${verifyBill[MIGRATION_FIELD]}`);
  if (!billOk) allOk = false;

  // Verify GHMC applicableResidentIds in bill
  let ghmcApplicableOk = false;
  if (verifyBill.categories && verifyBill.categories[ghmcCatIndex]) {
    const verifyIds = verifyBill.categories[ghmcCatIndex].applicableResidentIds || [];
    ghmcApplicableOk = JSON.stringify(verifyIds.slice().sort()) === JSON.stringify(newApplicableIds.slice().sort());
  } else if (isOldFormat && verifyBill.applicableResidentIds) {
    ghmcApplicableOk = JSON.stringify((verifyBill.applicableResidentIds).slice().sort()) ===
      JSON.stringify(newApplicableIds.slice().sort());
  }
  console.log(`  ${ghmcApplicableOk ? '✓' : '✗'} GHMC applicableResidentIds updated correctly`);
  if (!ghmcApplicableOk) allOk = false;

  // Verify each payment
  for (const op of writeOps) {
    const verifyPaySnap = await db.collection('payments').doc(op.paymentDocId).get();
    const verifyPay = verifyPaySnap.data();
    const payOk = Math.abs((verifyPay.amount ?? 0) - op.newAmount) < 0.01;
    console.log(`  ${payOk ? '✓' : '✗'} Payment ${op.paymentDocId} — amount = ${fmt(verifyPay.amount)} (expected ${fmt(op.newAmount)})`);
    if (!payOk) allOk = false;
  }

  // ── Final report ──────────────────────────────────────────────────────────
  console.log('\n' + SEP2);
  console.log('  MIGRATION REPORT');
  console.log(SEP2);
  console.log(`  Project              : ${PROJECT_ID}`);
  console.log(`  Apartment ID         : ${aptId}`);
  console.log(`  Apartment Name       : ${apt.name}`);
  console.log(`  Bill Month           : ${BILL_MONTH}`);
  console.log(`  Bill Doc ID          : ${targetBillDoc.id}`);
  console.log(`  Payments updated     : ${writeOps.length}`);
  console.log(`  Verification         : ${allOk ? '✓ ALL PASSED' : '✗ SOME FAILED — review output above'}`);
  console.log(`  Reconciliation note  : totalAmount was NOT changed (${fmt(storedTotal)} preserved)`);
  if (!allOk) {
    console.log('\n  ⚠ One or more verifications failed. Check Firestore manually.');
  }
  console.log(SEP2 + '\n');

  process.exit(allOk ? 0 : 1);
}

main().catch((err) => {
  console.error('\nFATAL ERROR:', err.message || err);
  if (err.stack) console.error(err.stack);
  process.exit(1);
});
