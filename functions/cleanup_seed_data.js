/**
 * One-time script to remove DbSeeder test data from production Firestore.
 * Uses @google-cloud/firestore with the Firebase CLI's stored OAuth2 token.
 */

const { Firestore } = require('@google-cloud/firestore');
const { OAuth2Client } = require('google-auth-library');
const fs   = require('fs');
const path = require('path');

const PROJECT_ID = 'maintify-ff8c4';
const APT_ID     = 'apt_greenvalley';

// ── Load Firebase CLI OAuth2 credential ───────────────────────────────────────
function makeCredential() {
  const cfgPath = path.join(process.env.HOME, '.config/configstore/firebase-tools.json');
  const cfg     = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const tokens  = cfg.tokens || {};

  const client = new OAuth2Client();
  client.setCredentials({
    access_token:  tokens.access_token,
    refresh_token: tokens.refresh_token,
    expiry_date:   tokens.token_expiry,
  });
  return client;
}

const db = new Firestore({
  projectId:  PROJECT_ID,
  authClient: makeCredential(),
});

// ── Helpers ───────────────────────────────────────────────────────────────────

async function deleteQuery(query, label) {
  const snap = await query.get();
  if (snap.empty) { console.log(`  ${label}: nothing to delete`); return 0; }
  for (let i = 0; i < snap.docs.length; i += 400) {
    const batch = db.batch();
    snap.docs.slice(i, i + 400).forEach(d => batch.delete(d.ref));
    await batch.commit();
  }
  console.log(`  ${label}: deleted ${snap.size}`);
  return snap.size;
}

async function deleteDoc(colId, docId) {
  const ref  = db.collection(colId).doc(docId);
  const snap = await ref.get();
  if (!snap.exists) { console.log(`  ${colId}/${docId}: not found`); return; }
  await ref.delete();
  console.log(`  ${colId}/${docId}: deleted`);
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function run() {
  console.log(`\nCleaning seed data from: ${PROJECT_ID}\n`);

  await deleteDoc('apartments', APT_ID);

  for (const flat of ['101', '102', '103']) {
    await deleteDoc('flats', `${APT_ID}_${flat}`);
  }

  await deleteQuery(
    db.collection('users').where('apartmentId', '==', APT_ID),
    `users (apartmentId=${APT_ID})`,
  );

  await deleteQuery(
    db.collection('bills').where('apartmentId', '==', APT_ID),
    `bills`,
  );

  await deleteQuery(
    db.collection('payments').where('apartmentId', '==', APT_ID),
    `payments`,
  );

  // Complaints + messages subcollection
  const cSnap = await db.collection('complaints').where('apartmentId', '==', APT_ID).get();
  if (!cSnap.empty) {
    for (const doc of cSnap.docs) {
      await deleteQuery(doc.ref.collection('messages'), `  complaints/${doc.id}/messages`);
      await doc.ref.delete();
    }
    console.log(`  complaints: deleted ${cSnap.size}`);
  } else {
    console.log('  complaints: nothing to delete');
  }

  await deleteQuery(
    db.collection('meetings').where('apartmentId', '==', APT_ID),
    `meetings`,
  );

  await deleteQuery(
    db.collection('notifications').where('apartmentId', '==', APT_ID),
    `notifications`,
  );

  await deleteDoc('_meta', 'seeded_v5');

  console.log('\nDone. All seed data removed from production.\n');
}

run().catch(e => { console.error('\nFailed:', e.message || e); process.exit(1); });
