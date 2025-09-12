#!/usr/bin/env node
/**
 * local_fcm_worker.js
 * Polls Firestore for pending alert_dispatch docs and fans out FCM to
 * users/{uid}/fcmTokens/* — no Cloud Functions / billing required.
 */

const path = require('path');
const admin = require('firebase-admin');

// ✅ Proper yargs bootstrap
const { hideBin } = require('yargs/helpers');
const y = require('yargs/yargs')(hideBin(process.argv));

const argv = y
  .option('project', { type: 'string', demandOption: true, describe: 'GCP/Firebase project id' })
  .option('key', { type: 'string', describe: 'Path to serviceAccountKey.json (recommended)' })
  .option('collection', { type: 'string', default: 'alert_dispatch', describe: 'Collection to watch' })
  .option('field', { type: 'string', default: 'status', describe: 'Status field' })
  .option('pending', { type: 'string', default: 'pending', describe: 'Pending value' })
  .option('sent', { type: 'string', default: 'sent', describe: 'Sent value' })
  .option('error', { type: 'string', default: 'error', describe: 'Error value' })
  .option('interval', { type: 'number', default: 2000, describe: 'Poll interval (ms)' })
  .option('batch', { type: 'number', default: 10, describe: 'Max docs to process per poll' })
  .option('dryRun', { type: 'boolean', default: false, describe: 'Don’t send, just log' })
  .option('verbose', { type: 'boolean', default: false, describe: 'Verbose logging' })
  .help()
  .argv;

function log(...a) { if (argv.verbose) console.log(...a); }

if (argv.key) {
  const svc = require(path.resolve(argv.key));
  admin.initializeApp({
    credential: admin.credential.cert(svc),
    projectId: argv.project,
  });
} else {
  // Uses ADC if you’ve logged in via gcloud, etc.
  admin.initializeApp({ projectId: argv.project });
}

const db = admin.firestore();
const messaging = admin.messaging();

const COLL = argv.collection;
const STATUS_FIELD = argv.field;
const PENDING = argv.pending;
const SENT = argv.sent;
const ERROR = argv.error;
const INTERVAL = argv.interval;
const BATCH = argv.batch;

let processing = false;

async function listUserTokens(uid) {
  const snap = await db.collection('users').doc(uid).collection('fcmTokens').get();
  const tokens = new Set();
  snap.forEach(d => {
    const t = d.id || d.data()?.token || '';
    if (typeof t === 'string' && t.length > 10) tokens.add(t);
  });
  return Array.from(tokens);
}

function buildMessage(docData, tokens) {
  const title = docData.title || 'Notification';
  const body = docData.body || '';
  const data = {};
  if (docData.data && typeof docData.data === 'object') {
    for (const [k, v] of Object.entries(docData.data)) {
      if (typeof v === 'string') data[k] = v;
    }
  }
  data.source = data.source || 'local_fcm_worker';

  return {
    tokens,
    notification: { title, body },
    data,
    android: { priority: 'high', notification: { channelId: 'default' } },
    apns: { headers: { 'apns-priority': '10' } },
  };
}

async function processOne(doc) {
  const id = doc.id;
  const d = doc.data() || {};
  const uids = Array.isArray(d.uids) ? d.uids : (d.uid ? [d.uid] : []);
  log(`→ Processing ${COLL}/${id} for uids=${JSON.stringify(uids)}`);

  if (!uids.length) {
    await doc.ref.update({
      [STATUS_FIELD]: ERROR,
      error: 'No uids array/uid provided',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    log(`× ${id} — no uids`);
    return;
  }

  let tokens = [];
  for (const uid of uids) {
    try {
      const tks = await listUserTokens(uid);
      log(`   tokens for ${uid}: ${tks.length}`);
      tokens.push(...tks);
    } catch (e) {
      log(`   token fetch error for ${uid}:`, e.message);
    }
  }
  // ✅ This is the line that got truncated for you:
  tokens = Array.from(new Set(tokens));

  if (!tokens.length) {
    await doc.ref.update({
      [STATUS_FIELD]: ERROR,
      error: 'No device tokens found for provided uids',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    log(`× ${id} — no tokens`);
    return;
  }

  const msg = buildMessage(d, tokens);
  log(`   sending to ${tokens.length} token(s)…`);
  let success = 0, failure = 0;
  let response = null;

  try {
    if (argv.dryRun) {
      log('   [dryRun] would send:', JSON.stringify(msg.notification), msg.data || {});
      success = tokens.length;
    } else {
      response = await messaging.sendEachForMulticast(msg);
      success = response.successCount || 0;
      failure = response.failureCount || 0;
    }
    await doc.ref.update({
      [STATUS_FIELD]: SENT,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      tokenCount: tokens.length,
      successCount: success,
      failureCount: failure,
      lastResponse: argv.verbose ? JSON.stringify(response || {}) : admin.firestore.FieldValue.delete(),
    });
    log(`✓ ${id} — sent=${success}, failed=${failure}`);
  } catch (e) {
    await doc.ref.update({
      [STATUS_FIELD]: ERROR,
      error: e.message || String(e),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.error(`! ${id} — send error:`, e.message);
  }
}

async function tick() {
  if (processing) return;
  processing = true;
  try {
    const q = await db.collection(COLL)
      .where(STATUS_FIELD, '==', PENDING)
      .orderBy('createdAt', 'asc')
      .limit(BATCH)
      .get();

    if (q.empty) {
      log('(idle)');
      return;
    }

    for (const d of q.docs) {
      await processOne(d);
    }
  } catch (e) {
    console.error('tick error:', e.message);
  } finally {
    processing = false;
  }
}

console.log(`Local FCM worker started:
  project:     ${argv.project}
  collection:  ${COLL}
  statusField: ${STATUS_FIELD} (pending='${PENDING}', sent='${SENT}', error='${ERROR}')
  interval:    ${INTERVAL}ms  batch: ${BATCH}  dryRun: ${argv.dryRun ? 'yes' : 'no'}
`);

setInterval(tick, INTERVAL);

process.on('SIGINT', () => {
  console.log('\nStopping worker…');
  process.exit(0);
});
