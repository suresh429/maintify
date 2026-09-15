'use strict';

/**
 * ============================================================
 * MAINTIFY — Create Missing Payment for Flat 502
 * ============================================================
 *
 * PURPOSE:
 *   Creates the missing payment document for flat 502 resident
 *   (userId: KZsI8Pva61PE076SsmGUTOZjIkB2) for the August 2026
 *   bill in SAMH8151 (maintify-ff8c4 / PROD).
 *
 * USAGE:
 *   node create_missing_payment.js --dry-run    # Preview, no writes
 *   node create_missing_payment.js --execute    # Write to Firestore
 *
 * Document ID format: ${billId}_${userId}
 * ============================================================
 */

const admin = require('firebase-admin');
const os    = require('os');
const path  = require('path');
const fs    = require('fs');

// ─── Credential setup (same as migrate_hybrid.js) ────────────────────────────
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
  const creds = {
    type:          'authorized_user',
    client_id:     '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: refreshToken,
  };
  const tmpFile = path.join(os.tmpdir(), 'maintify_mig_creds.json');
  fs.writeFileSync(tmpFile, JSON.stringify(creds), { mode: 0o600 });
  process.env.GOOGLE_APPLICATION_CREDENTIALS = tmpFile;
}

// ─── Constants ───────────────────────────────────────────────────────────────
const PROJECT_ID  = 'maintify-ff8c4';
const BILL_ID     = 'bill_1789140869731';
const USER_ID     = 'KZsI8Pva61PE076SsmGUTOZjIkB2';
const FLAT_NUMBER = '502';
const APT_ID      = 'apt_1785249349037';
const AMOUNT      = 1421.10;
const DOC_ID      = `${BILL_ID}_${USER_ID}`;

const SEP  = '─'.repeat(70);
const SEP2 = '═'.repeat(70);

async function main() {
  const args      = process.argv.slice(2);
  const isDryRun  = args.includes('--dry-run');
  const isExecute = args.includes('--execute');

  if (!isDryRun && !isExecute) {
    console.error('\nERROR: You must pass either --dry-run or --execute.\n');
    console.error('  node create_missing_payment.js --dry-run');
    console.error('  node create_missing_payment.js --execute\n');
    process.exit(1);
  }

  console.log('  Setting up credentials from firebase login session...');
  setupCredentials();
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId:  PROJECT_ID,
  });

  const db = admin.firestore();

  console.log('\n' + SEP2);
  console.log('  MAINTIFY — Create Missing Payment (Flat 502)');
  console.log(`  Project  : ${PROJECT_ID}`);
  console.log(`  Mode     : ${isDryRun ? 'DRY RUN (no writes)' : 'EXECUTE (writes ENABLED)'}`);
  console.log(SEP2);

  // ── Step 1: Verify the bill exists ─────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP 1 — Verify bill exists');
  console.log(SEP);

  const billSnap = await db.collection('bills').doc(BILL_ID).get();
  if (!billSnap.exists) {
    console.error(`\nERROR: Bill document "${BILL_ID}" not found. Aborting.\n`);
    process.exit(1);
  }
  const bill = billSnap.data();
  console.log(`  Bill ID    : ${BILL_ID}`);
  console.log(`  Month      : ${bill.month}`);
  console.log(`  ApartmentId: ${bill.apartmentId}`);
  console.log(`  TotalAmount: ₹${bill.totalAmount}`);

  if (bill.apartmentId !== APT_ID) {
    console.error(`\nERROR: Bill appartmentId mismatch. Expected ${APT_ID}, got ${bill.apartmentId}. Aborting.\n`);
    process.exit(1);
  }

  // ── Step 2: Verify resident (flat 502) exists ───────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP 2 — Verify flat 502 resident');
  console.log(SEP);

  const userSnap = await db.collection('users').doc(USER_ID).get();
  if (!userSnap.exists) {
    console.error(`\nERROR: User "${USER_ID}" not found. Aborting.\n`);
    process.exit(1);
  }
  const user = userSnap.data();
  console.log(`  User ID    : ${USER_ID}`);
  console.log(`  Name       : ${user.name || user.displayName || '(unnamed)'}`);
  console.log(`  Email      : ${user.email || '(no email)'}`);
  console.log(`  ApartmentId: ${user.apartmentId}`);

  if (user.apartmentId !== APT_ID) {
    console.error(`\nERROR: User apartmentId mismatch. Expected ${APT_ID}, got ${user.apartmentId}. Aborting.\n`);
    process.exit(1);
  }

  // ── Step 3: Check if payment already exists ─────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP 3 — Check for existing payment');
  console.log(SEP);

  const paySnap = await db.collection('payments').doc(DOC_ID).get();
  if (paySnap.exists) {
    const existing = paySnap.data();
    console.log(`  ⚠ Payment document already exists!`);
    console.log(`  Doc ID : ${DOC_ID}`);
    console.log(`  Amount : ₹${existing.amount}`);
    console.log(`  Status : ${existing.status}`);
    console.log('\n  Nothing to do — payment already exists. Exiting.\n');
    process.exit(0);
  }
  console.log(`  ✓ No existing payment found for doc ID: ${DOC_ID}`);

  // ── Step 4: Preview the payment to create ───────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP 4 — Payment to create');
  console.log(SEP);

  const now = new Date();
  const paymentData = {
    billId:       BILL_ID,
    userId:       USER_ID,
    apartmentId:  APT_ID,
    unitNumber:   FLAT_NUMBER,
    amount:       AMOUNT,
    status:       'Pending',
    adminVerified: false,
    month:        bill.month,
    createdAt:    admin.firestore.FieldValue.serverTimestamp(),
    updatedAt:    admin.firestore.FieldValue.serverTimestamp(),
    createdByMigration: true,
    migrationNote: 'Created by create_missing_payment.js — payment was missing from initial bill creation',
  };

  console.log(`  Document ID  : ${DOC_ID}`);
  console.log(`  billId       : ${paymentData.billId}`);
  console.log(`  userId       : ${paymentData.userId}`);
  console.log(`  apartmentId  : ${paymentData.apartmentId}`);
  console.log(`  unitNumber   : ${paymentData.unitNumber}`);
  console.log(`  amount       : ₹${paymentData.amount}`);
  console.log(`  status       : ${paymentData.status}`);
  console.log(`  adminVerified: ${paymentData.adminVerified}`);
  console.log(`  month        : ${paymentData.month}`);

  // ── Step 5: Dry run exit ─────────────────────────────────────────────────────
  if (isDryRun) {
    console.log('\n' + SEP2);
    console.log('  DRY RUN COMPLETE — no changes written to Firestore.');
    console.log('  Re-run with --execute to create the payment document.');
    console.log(SEP2 + '\n');
    process.exit(0);
  }

  // ── Step 6: Write to Firestore ───────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP 5 — Writing to Firestore');
  console.log(SEP);

  const payRef = db.collection('payments').doc(DOC_ID);
  await payRef.set(paymentData);
  console.log('  ✓ Payment document created.\n');

  // ── Step 7: Verify ───────────────────────────────────────────────────────────
  console.log('  Verifying written document...\n');
  const verifySnap = await payRef.get();
  if (!verifySnap.exists) {
    console.error('  ✗ VERIFICATION FAILED: document not found after write!\n');
    process.exit(1);
  }
  const verify = verifySnap.data();
  const amtOk     = Math.abs((verify.amount ?? 0) - AMOUNT) < 0.01;
  const statusOk  = verify.status === 'Pending';
  const billIdOk  = verify.billId === BILL_ID;
  const userIdOk  = verify.userId === USER_ID;
  const allOk     = amtOk && statusOk && billIdOk && userIdOk;

  console.log(`  ${amtOk    ? '✓' : '✗'} amount     = ₹${verify.amount} (expected ₹${AMOUNT})`);
  console.log(`  ${statusOk ? '✓' : '✗'} status     = ${verify.status}`);
  console.log(`  ${billIdOk ? '✓' : '✗'} billId     = ${verify.billId}`);
  console.log(`  ${userIdOk ? '✓' : '✗'} userId     = ${verify.userId}`);

  console.log('\n' + SEP2);
  console.log('  RESULT');
  console.log(SEP2);
  console.log(`  Document    : payments/${DOC_ID}`);
  console.log(`  Amount      : ₹${AMOUNT}`);
  console.log(`  Flat        : ${FLAT_NUMBER}`);
  console.log(`  Verification: ${allOk ? '✓ ALL PASSED' : '✗ SOME FAILED — check output above'}`);
  console.log(SEP2 + '\n');

  process.exit(allOk ? 0 : 1);
}

main().catch((err) => {
  console.error('\nFATAL ERROR:', err.message || err);
  if (err.stack) console.error(err.stack);
  process.exit(1);
});
