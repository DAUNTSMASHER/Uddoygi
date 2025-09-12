#!/usr/bin/env node
'use strict';

/*
  fix_db.js — audit & debug your push setup from terminal

  Usage:
    node fix_db.js --project your-project-id --region us-central1 \
      --key "/absolute/path/serviceAccountKey.json" --testTrigger --verbose
*/

const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');
const argv = yargs(hideBin(process.argv))
  .option('project', { type: 'string', demandOption: true, describe: 'GCP/Firebase project id' })
  .option('region', { type: 'string', default: 'us-central1', describe: 'Functions region' })
  .option('key', { type: 'string', describe: 'Path to serviceAccountKey.json (optional; uses ADC if omitted)' })
  .option('testTrigger', { type: 'boolean', default: false, describe: 'Create alert_dispatch test doc and poll for processing' })
  .option('verbose', { type: 'boolean', default: false })
  .help().argv;

const admin = require('firebase-admin');
const { google } = require('googleapis');

function log(...a)  { console.log(...a); }
function warn(...a) { console.warn(...a); }

async function initAdmin() {
  if (argv.key) {
    const sa = require(argv.key);
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      projectId: argv.project || sa.project_id,
    });
  } else {
    admin.initializeApp({ projectId: argv.project });
  }
  return admin.firestore();
}

async function initGoogleAuth() {
  const scopes = ['https://www.googleapis.com/auth/cloud-platform'];
  if (argv.key) {
    const creds = require(argv.key);
    const auth = new google.auth.GoogleAuth({ credentials: creds, scopes });
    google.options({ auth });
  } else {
    const auth = await google.auth.getClient({ scopes });
    google.options({ auth });
  }
}

// --------- Firestore: inspect users/*/fcmTokens/* ----------
async function inspectFcmTokens(db) {
  const usersSnap = await db.collection('users').get();
  let usersWithTokens = 0;
  let tokenCount = 0;
  const sample = [];

  for (const doc of usersSnap.docs) {
    const tokensColRef = doc.ref.collection('fcmTokens');
    const tokenDocs = await tokensColRef.listDocuments();
    if (tokenDocs.length > 0) {
      usersWithTokens++;
      tokenCount += tokenDocs.length;
      if (sample.length < 5) sample.push({ uid: doc.id, count: tokenDocs.length });
    }
  }

  log('— FCM token audit —');
  log(`Users: ${usersSnap.size}`);
  log(`Users with tokens: ${usersWithTokens}`);
  log(`Total tokens: ${tokenCount}`);
  if (sample.length) log('Sample:', sample);
  log('');
  return { users: usersSnap.size, usersWithTokens, tokenCount };
}

// --------- Cloud Functions: list Gen1 + Gen2 ----------
async function listFunctionsAll(project, region) {
  const parent = `projects/${project}/locations/${region}`;
  const cfv1 = google.cloudfunctions('v1');
  const cfv2 = google.cloudfunctions('v2');

  let gen1 = [];
  let gen2 = [];

  try {
    const res1 = await cfv1.projects.locations.functions.list({ parent });
    gen1 = res1.data.functions || [];
  } catch (e) {
    warn('Gen1 list error:', e?.message || e);
  }

  try {
    const res2 = await cfv2.projects.locations.functions.list({ parent });
    gen2 = res2.data.functions || [];
  } catch (e) {
    warn('Gen2 list error:', e?.message || e);
  }

  if (argv.verbose) {
    log(`Gen1 functions found: ${gen1.length}`);
    log(`Gen2 functions found: ${gen2.length}`);
  }

  return { gen1, gen2 };
}

function funcShortName(f) {
  const parts = (f.name || '').split('/');
  return parts[parts.length - 1] || '';
}

function hasName(fn, wanted) {
  return funcShortName(fn) === wanted;
}

function isFirestoreTriggerV1(fn) {
  const et = fn.eventTrigger;
  if (!et) return false;
  const type = et.eventType || '';
  const res = et.resource || '';
  return type.includes('firestore') && res.includes('alert_dispatch');
}

function isFirestoreTriggerV2(fn) {
  const et = fn.eventTrigger;
  if (!et) return false;
  const type = et.eventType || '';
  if (!type.includes('firestore')) return false;
  const filters = et.eventFilters || [];
  return filters.some((f) => (f?.value || '').includes('alert_dispatch'));
}

function summarizeFunctions({ gen1, gen2 }) {
  const targets = ['sendAlert', 'sendDeptAlert'];

  const found = {};
  for (const t of targets) {
    found[t] = {
      gen1: gen1.find((f) => hasName(f, t)) || null,
      gen2: gen2.find((f) => hasName(f, t)) || null,
    };
  }

  const triggers = [
    ...gen1.filter(isFirestoreTriggerV1),
    ...gen2.filter(isFirestoreTriggerV2),
  ];

  log('— Cloud Functions audit —');
  for (const t of targets) {
    const g1 = found[t].gen1 ? 'YES' : 'no';
    const g2 = found[t].gen2 ? 'YES' : 'no';
    log(`${t}: Gen1=${g1}, Gen2=${g2}`);
  }
  log(`alert_dispatch triggers: ${triggers.length > 0 ? 'YES' : 'no'}`);
  if (argv.verbose && triggers.length) {
    log('Trigger(s):', triggers.map((f) => funcShortName(f)));
  }
  log('');

  return { found, triggers };
}

// --------- Optional trigger test: create doc & poll ----------
async function testAlertDispatch(db) {
  log('— Trigger test —');
  const ref = await db.collection('alert_dispatch').add({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'pending',
    title: 'fix_db.js test',
    message: `Ping @ ${new Date().toISOString()}`,
  });
  log('Created', ref.path);

  const deadline = Date.now() + 30_000; // 30s
  let updated = null;

  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 3000));
    const snap = await ref.get();
    const d = snap.data() || {};
    if ((d.status && d.status !== 'pending') || d.sentAt || d.error) {
      updated = d;
      break;
    }
    if (argv.verbose) log('…waiting for trigger to process');
  }

  if (updated) {
    log('Trigger processed doc:', {
      status: updated.status,
      sentAt: updated.sentAt,
      error: updated.error,
    });
  } else {
    warn('No update observed within 30s. Check function logs.');
  }
  log('');
}

(async () => {
  try {
    const db = await initAdmin();
    await initGoogleAuth();

    await inspectFcmTokens(db);

    const fx = await listFunctionsAll(argv.project, argv.region);
    const summary = summarizeFunctions(fx);

    const hasCallable =
      summary.found.sendAlert.gen1 || summary.found.sendAlert.gen2 ||
      summary.found.sendDeptAlert.gen1 || summary.found.sendDeptAlert.gen2;

    const hasTrigger = summary.triggers.length > 0;

    if (!hasCallable && !hasTrigger) {
      warn('No sendAlert/sendDeptAlert callable functions AND no alert_dispatch trigger found.');
      warn('You need EITHER the callable(s) OR the Firestore trigger.');
    }

    if (argv.testTrigger) {
      if (!hasTrigger) {
        warn('No alert_dispatch Firestore trigger detected; --testTrigger will still insert a doc, but nothing may process it.');
      }
      await testAlertDispatch(db);
    }

    log('Done.');
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
})();
