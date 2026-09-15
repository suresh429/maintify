'use strict';

/**
 * ============================================================
 * MAINTIFY — Fix GHMC totalAmount for August 2026 (SAMH8151)
 * ============================================================
 *
 * PROBLEM:
 *   The GHMC GARBAGE category totalAmount is 1200 (only 8 flats × ₹150).
 *   It should be 1350 (9 flats × ₹150 — all flats except 101).
 *   The ₹150 for flat 502 was missing because the resident hadn't
 *   signed up when the bill was created. But the charge still applies.
 *
 * CHANGES:
 *   - bills/bill_1789140869731
 *       categories[GHMC].totalAmount : 1200 → 1350  (+150)
 *       totalAmount                  : 13911 → 14061 (+150)
 *
 * USAGE:
 *   node fix_ghmc_total.js --dry-run
 *   node fix_ghmc_total.js --execute
 * ============================================================
 */

const admin = require('firebase-admin');
const os    = require('os');
const path  = require('path');
const fs    = require('fs');

function setupCredentials() {
  const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(cfgPath)) throw new Error('firebase-tools config not found. Run: firebase login');
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const refreshToken = cfg.tokens && cfg.tokens.refresh_token;
  if (!refreshToken) throw new Error('No refresh_token. Run: firebase login');
  const creds = {
    type: 'authorized_user',
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: refreshToken,
  };
  const tmpFile = path.join(os.tmpdir(), 'maintify_mig_creds.json');
  fs.writeFileSync(tmpFile, JSON.stringify(creds), { mode: 0o600 });
  process.env.GOOGLE_APPLICATION_CREDENTIALS = tmpFile;
}

const PROJECT_ID    = 'maintify-ff8c4';
const BILL_ID       = 'bill_1789140869731';
const GHMC_NAME_RE  = /ghmc|garbage/i;   // regex to find the GHMC category
const OLD_GHMC_TOTAL = 1200;
const NEW_GHMC_TOTAL = 1350;             // 9 flats × ₹150 (all except flat 101)
const DELTA          = NEW_GHMC_TOTAL - OLD_GHMC_TOTAL; // +150

const SEP  = '─'.repeat(70);
const SEP2 = '═'.repeat(70);
const fmt  = (n) => `₹${Number(n).toFixed(2)}`;

async function main() {
  const args     = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  const isExec   = args.includes('--execute');

  if (!isDryRun && !isExec) {
    console.error('\nERROR: Pass --dry-run or --execute\n');
    process.exit(1);
  }

  setupCredentials();
  admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId: PROJECT_ID });
  const db = admin.firestore();

  console.log('\n' + SEP2);
  console.log('  MAINTIFY — Fix GHMC totalAmount (August 2026 / SAMH8151)');
  console.log(`  Project : ${PROJECT_ID}`);
  console.log(`  Mode    : ${isDryRun ? 'DRY RUN (no writes)' : 'EXECUTE (writes ENABLED)'}`);
  console.log(SEP2);

  // ── Step 1: Load bill ────────────────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP 1 — Load bill');
  console.log(SEP);

  const billRef  = db.collection('bills').doc(BILL_ID);
  const billSnap = await billRef.get();
  if (!billSnap.exists) {
    console.error(`\nERROR: Bill "${BILL_ID}" not found.\n`);
    process.exit(1);
  }
  const bill = billSnap.data();

  console.log(`  Bill ID      : ${BILL_ID}`);
  console.log(`  Month        : ${bill.month}`);
  console.log(`  totalAmount  : ${fmt(bill.totalAmount)}`);
  console.log(`  Categories   : ${(bill.categories || []).length}`);

  // ── Step 2: Find GHMC category ───────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP 2 — Find GHMC category');
  console.log(SEP);

  const categories = bill.categories || [];
  let ghmcIdx = -1;

  categories.forEach((cat, idx) => {
    const match = GHMC_NAME_RE.test(cat.name || '');
    console.log(`  [${idx}] ${cat.name || '(unnamed)'}  type=${cat.type}  totalAmount=${fmt(cat.totalAmount)}  ${match ? '← GHMC' : ''}`);
    if (ghmcIdx === -1 && match) ghmcIdx = idx;
  });

  if (ghmcIdx === -1) {
    console.error('\nERROR: Could not find GHMC/Garbage category. Aborting.\n');
    process.exit(1);
  }

  const ghmcCat = categories[ghmcIdx];
  console.log(`\n  Found at index ${ghmcIdx}: "${ghmcCat.name}"`);
  console.log(`  Current totalAmount  : ${fmt(ghmcCat.totalAmount)}`);
  console.log(`  defaultAmount        : ${fmt(ghmcCat.defaultAmount)}`);
  console.log(`  applicableResidentIds: ${(ghmcCat.applicableResidentIds || []).length} residents`);

  // Validate current totalAmount
  if (Math.abs((ghmcCat.totalAmount || 0) - OLD_GHMC_TOTAL) > 0.01) {
    console.warn(`\n  ⚠ WARNING: GHMC totalAmount is ${fmt(ghmcCat.totalAmount)}, expected ${fmt(OLD_GHMC_TOTAL)}.`);
    console.warn('  It may have already been updated. Continuing to validate...');
  }

  // ── Step 3: Preview changes ──────────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP 3 — Changes to apply');
  console.log(SEP);

  const newBillTotal  = Math.round(((bill.totalAmount || 0) + DELTA) * 100) / 100;
  const newGhmcTotal  = NEW_GHMC_TOTAL;

  console.log(`  GHMC category totalAmount  : ${fmt(ghmcCat.totalAmount)} → ${fmt(newGhmcTotal)}  (+${fmt(DELTA)})`);
  console.log(`  Bill totalAmount           : ${fmt(bill.totalAmount)} → ${fmt(newBillTotal)}  (+${fmt(DELTA)})`);
  console.log(`\n  Reason: 9 flats × ₹150 = ₹1350 (all flats except 101)`);
  console.log(`          Flat 502 (₹150) was missing because resident hadn't signed up.`);

  // ── Step 4: Dry run exit ─────────────────────────────────────────────────────
  if (isDryRun) {
    console.log('\n' + SEP2);
    console.log('  DRY RUN COMPLETE — no changes written to Firestore.');
    console.log('  Re-run with --execute to apply.');
    console.log(SEP2 + '\n');
    process.exit(0);
  }

  // Already at the new value? (idempotency)
  if (Math.abs((ghmcCat.totalAmount || 0) - NEW_GHMC_TOTAL) < 0.01 &&
      Math.abs((bill.totalAmount || 0) - newBillTotal) < 0.01) {
    console.log('\n  ✓ Already up to date — nothing to change.\n');
    process.exit(0);
  }

  // ── Step 5: Execute ──────────────────────────────────────────────────────────
  console.log('\n' + SEP);
  console.log('STEP 4 — Writing to Firestore');
  console.log(SEP);

  // Build updated categories array
  const updatedCategories = categories.map((cat, idx) => {
    if (idx !== ghmcIdx) return cat;
    return { ...cat, totalAmount: newGhmcTotal };
  });

  await billRef.update({
    categories:  updatedCategories,
    totalAmount: newBillTotal,
    ghmcTotalFixedAt: admin.firestore.FieldValue.serverTimestamp(),
    ghmcTotalFixNote: 'Fixed flat-502 missing ₹150 GHMC contribution',
  });

  console.log('  ✓ Bill updated.\n');

  // ── Step 6: Verify ───────────────────────────────────────────────────────────
  console.log('  Verifying...\n');
  const verSnap = await billRef.get();
  const ver     = verSnap.data();
  const verGhmc = (ver.categories || [])[ghmcIdx] || {};

  const ghmcOk = Math.abs((verGhmc.totalAmount || 0) - newGhmcTotal) < 0.01;
  const billOk = Math.abs((ver.totalAmount || 0) - newBillTotal) < 0.01;

  console.log(`  ${ghmcOk ? '✓' : '✗'} GHMC totalAmount = ${fmt(verGhmc.totalAmount)} (expected ${fmt(newGhmcTotal)})`);
  console.log(`  ${billOk ? '✓' : '✗'} Bill totalAmount = ${fmt(ver.totalAmount)} (expected ${fmt(newBillTotal)})`);

  const allOk = ghmcOk && billOk;
  console.log('\n' + SEP2);
  console.log('  RESULT');
  console.log(SEP2);
  console.log(`  GHMC totalAmount : ${fmt(OLD_GHMC_TOTAL)} → ${fmt(newGhmcTotal)}`);
  console.log(`  Bill totalAmount : ${fmt(bill.totalAmount)} → ${fmt(newBillTotal)}`);
  console.log(`  Verification     : ${allOk ? '✓ ALL PASSED' : '✗ FAILED — check Firestore manually'}`);
  console.log(SEP2 + '\n');

  process.exit(allOk ? 0 : 1);
}

main().catch((err) => {
  console.error('\nFATAL ERROR:', err.message || err);
  if (err.stack) console.error(err.stack);
  process.exit(1);
});
