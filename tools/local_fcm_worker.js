#!/usr/bin/env node
'use strict';

// Fast, production-ready Firestore → FCM worker.
// One-time deploy: safe against sender receiving their own pushes, and
// resilient to token pollution across users.
//
// ENV (optional):
//   SERVICE_ACCOUNT_PATH=/abs/path/serviceAccountKey.json
//   FIREBASE_PROJECT_ID=uddyogi
//   DRY_RUN=1
//   JOB_CONCURRENCY=3
//   SWEEP_MS=5000
//   PROCESSING_TIMEOUT_MS=300000   // 5m, requeue stuck jobs
//   EXCLUDE_SENDER=1               // don't send to sender's devices
//   ENFORCE_OWNERSHIP=1            // drop tokens not owned by target uids
//   OWNERSHIP_CLEANUP=0            // also remove wrongly-owned tokens (heavier)

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

process.title = 'uddoygi-worker';

// ---------- credential auto-detect ----------
function findKey() {
  const candidates = [
    process.env.SERVICE_ACCOUNT_PATH,
    path.resolve(__dirname, 'serviceAccountKey.json'),
    path.resolve(__dirname, 'service-account.json'),
    path.resolve(process.cwd(), 'serviceAccountKey.json'),
    path.resolve(process.cwd(), 'service-account.json'),
  ].filter(Boolean);
  const hit = candidates.find(p => fs.existsSync(p));
  if (!hit) {
    console.error('❌ serviceAccountKey.json not found. Tried:\n' + candidates.join('\n'));
    process.exit(1);
  }
  return hit;
}
const KEY_PATH = findKey();
const SA = require(KEY_PATH);

admin.initializeApp({
  credential: admin.credential.cert(SA),
  projectId: process.env.FIREBASE_PROJECT_ID || SA.project_id,
});

const db  = admin.firestore();
const fcm = admin.messaging();
const fv  = admin.firestore.FieldValue;

console.log(`🔐 Admin initialized with: ${KEY_PATH} (project=${process.env.FIREBASE_PROJECT_ID || SA.project_id})`);

// ---------- tunables ----------
const DRY_RUN               = String(process.env.DRY_RUN || '') === '1';
const JOB_CONCURRENCY       = Math.max(1, parseInt(process.env.JOB_CONCURRENCY || '3', 10));
const SWEEP_MS              = Math.max(1000, parseInt(process.env.SWEEP_MS || '5000', 10));
const PROCESSING_TIMEOUT_MS = Math.max(60000, parseInt(process.env.PROCESSING_TIMEOUT_MS || '300000', 10));
const MULTICAST_LIMIT       = 500;
const EXCLUDE_SENDER        = String(process.env.EXCLUDE_SENDER ?? '1') === '1';
const ENFORCE_OWNERSHIP     = String(process.env.ENFORCE_OWNERSHIP ?? '1') === '1';
const OWNERSHIP_CLEANUP     = String(process.env.OWNERSHIP_CLEANUP ?? '0') === '1';

// ---------- utils ----------
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const chunk = (arr, n) => { const out=[]; for (let i=0;i<arr.length;i+=n) out.push(arr.slice(i,i+n)); return out; };
async function safeMerge(ref, patch) { try { await ref.set(patch, { merge: true }); } catch (_) {} }

// ---------- token resolution ----------
async function tokensForUids(uids) {
  const out = new Set();

  // batch get user docs
  const refs = uids.map(uid => db.collection('users').doc(uid));
  const snaps = await db.getAll(...refs);

  const needSub = [];
  for (let i = 0; i < snaps.length; i++) {
    const s = snaps[i];
    if (!s.exists) { needSub.push(uids[i]); continue; }
    const m = s.data() || {};
    const arr = Array.isArray(m.fcmTokens) ? m.fcmTokens : [];
    if (arr.length) arr.filter(Boolean).map(String).map(t => t.trim()).forEach(t => t && out.add(t));
    else needSub.push(uids[i]);
  }

  // fallback: subcollection
  for (const uid of needSub) {
    const sub = await db.collection('users').doc(uid).collection('fcmTokens').get();
    for (const d of sub.docs) {
      const tok = (d.data().token || '').toString().trim();
      if (tok) out.add(tok);
    }
  }
  return Array.from(out);
}

// quick owner cache to reduce reads for repeated tokens within the same process
const ownerCache = new Map(); // token -> Set<uids>

async function ownersOfToken(token) {
  if (ownerCache.has(token)) return ownerCache.get(token);
  const owners = new Set();

  // top-level array owners
  try {
    const q1 = await db.collection('users').where('fcmTokens', 'array-contains', token).get();
    q1.docs.forEach(d => owners.add(d.id));
  } catch (_) {}

  // subcollection owners
  try {
    const q2 = await db.collectionGroup('fcmTokens').where('token', '==', token).get();
    q2.docs.forEach(d => {
      const parent = d.ref.parent.parent;
      if (parent) owners.add(parent.id);
    });
  } catch (_) {}

  ownerCache.set(token, owners);
  return owners;
}

async function cleanupInvalidTokens(uids, badTokens) {
  if (!badTokens.length) return;
  const tasks = [];
  for (const uid of uids) {
    const ref = db.collection('users').doc(uid);
    tasks.push(ref.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...badTokens) }).catch(() => {}));
    for (const t of badTokens) {
      tasks.push(ref.collection('fcmTokens').doc(t).delete().catch(() => {}));
    }
  }
  try {
    await Promise.all(tasks);
    console.log(`🧹 Cleaned ${badTokens.length} invalid token(s) across ${uids.length} user(s).`);
  } catch (e) {
    console.warn('🧹 Cleanup error (non-fatal):', e.message || e);
  }
}

async function enforceOwnership(uids, tokens) {
  if (!ENFORCE_OWNERSHIP || !uids?.length) return tokens;
  const allow = new Set(uids);
  const filtered = [];
  const wrongOwners = new Map(); // token -> Set<uid>

  for (const t of tokens) {
    const owners = await ownersOfToken(t); // Set
    if (owners.size === 0) { filtered.push(t); continue; } // unknown owner, allow
    const intersect = [...owners].some(uid => allow.has(uid));
    if (intersect) filtered.push(t);
    else {
      wrongOwners.set(t, owners);
    }
  }

  if (wrongOwners.size && OWNERSHIP_CLEANUP) {
    // heavy but one-time repair whenever seen
    const tasks = [];
    for (const [tok, set] of wrongOwners.entries()) {
      for (const uid of set) {
        if (uids.includes(uid)) continue; // this one is allowed
        const ref = db.collection('users').doc(uid);
        tasks.push(ref.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(tok) }).catch(() => {}));
        tasks.push(ref.collection('fcmTokens').doc(tok).delete().catch(() => {}));
      }
    }
    Promise.allSettled(tasks).then(() => {
      console.log(`🧽 Ownership cleanup attempted for ${wrongOwners.size} token(s).`);
    });
  }

  return filtered;
}

// ---------- build message ----------
function buildMulticast({ title, body, data, tokens, priority = 'high', collapseKey }) {
  const androidPriority = priority === 'normal' ? 'normal' : 'high';
  return {
    tokens,
    notification: { title, body },
    data: {
      ...data,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: androidPriority,
      ttl: 0, // deliver NOW
      directBootOk: true,
      collapseKey,            // dedupe on device per job
      notification: {
        channelId: 'alert_channel', // must exist in client app
        sound: 'default',
        defaultSound: true,
      },
    },
    apns: {
      headers: { 'apns-priority': androidPriority === 'high' ? '10' : '5' },
      payload: { aps: { sound: 'default', 'thread-id': collapseKey || 'general' } },
    },
  };
}

// ---------- core job processor ----------
// expected job schema in alert_dispatch/{jobId}:
// {
//   status: 'pending'|'processing'|'sent'|'failed'|'no_tokens',
//   type:   'message'|'alert'|...,
//   title, body,
//   uids: [toUid1,...],            // target users
//   tokens?: [token1,...],         // optional direct tokens
//   senderUid?: 'uid',             // optional for exclude-sender
//   alertId?: 'abc',               // used as collapseKey
//   priority?: 'high'|'normal',
//   createdAtMs: number,
//   processingAt?: TS,
//   sentAt?: TS
// }
async function processJob(docRef) {
  // transactional lock + capture job once
  const job = await db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    if (!snap.exists) return null;
    const data = snap.data() || {};
    if (data.status !== 'pending') return null;
    tx.update(docRef, { status: 'processing', processingAt: fv.serverTimestamp() });
    return { id: snap.id, ...data };
  });

  if (!job) return;

  const jobId   = job.id;
  const title   = job.title || 'Notification';
  const body    = job.body  || '';
  const prio    = (job.priority || 'high').toLowerCase();
  const alertId = String(job.alertId || jobId);
  const uids    = Array.isArray(job.uids) ? job.uids : [];
  const sender  = job.senderUid || null;

  console.log(`🚚 Processing ${jobId} (${title})`);

  // resolve tokens
  let tokens = Array.isArray(job.tokens) ? job.tokens.filter(Boolean).map(String) : [];
  if (!tokens.length && uids.length) tokens = await tokensForUids(uids);
  tokens = tokens.map(t => t.trim()).filter(Boolean);

  // drop sender's devices if requested
  if (EXCLUDE_SENDER && sender) {
    const senderTokens = await tokensForUids([sender]);
    const senderSet = new Set(senderTokens);
    tokens = tokens.filter(t => !senderSet.has(t));
  }

  // enforce: tokens must belong to intended uids (avoid cross-user pollution)
  if (ENFORCE_OWNERSHIP && uids.length) {
    tokens = await enforceOwnership(uids, tokens);
  }

  // dedupe after filtering
  tokens = Array.from(new Set(tokens));

  if (!tokens.length) {
    await safeMerge(docRef, { status: 'no_tokens', updatedAt: fv.serverTimestamp() });
    console.warn('⚠️ NO_TOKENS for', jobId);
    return;
  }

  if (DRY_RUN) {
    console.log(`🧪 DRY_RUN: would send to ${tokens.length} token(s)`);
    await safeMerge(docRef, { status: 'sent', dryRun: true, sentAt: fv.serverTimestamp() });
    return;
  }

  // send in parallel chunks
  const chunks = chunk(tokens, MULTICAST_LIMIT);
  const failures = [];
  await Promise.all(chunks.map(async (group) => {
    const msg = buildMulticast({
      title,
      body,
      tokens: group,
      priority: prio,
      collapseKey: alertId,
      data: {
        alertId,
        priority: prio,
        type: String(job.type || 'message'),
      },
    });
    try {
      const res = await fcm.sendEachForMulticast(msg);
      res.responses.forEach((r, i) => {
        if (!r.success) {
          failures.push({
            token: group[i],
            code: r.error?.code || 'unknown',
            msg: r.error?.message || String(r.error || 'error'),
          });
        }
      });
    } catch (e) {
      group.forEach(t => failures.push({ token: t, code: 'send-chunk-error', msg: e.message || String(e) }));
    }
  }));

  // cleanup invalid tokens
  const badTokens = failures
    .filter(f => f.code === 'messaging/registration-token-not-registered' || /registration-token-not-registered/i.test(f.msg))
    .map(f => f.token);

  if (badTokens.length && uids.length) await cleanupInvalidTokens(uids, badTokens);

  const allFailed = failures.length === tokens.length;
  await safeMerge(docRef, {
    status: allFailed ? 'failed' : 'sent',
    sentAt: fv.serverTimestamp(),
    lastErrors: failures.slice(0, 10),
    failedCount: failures.length,
    successCount: tokens.length - failures.length,
    updatedAt: fv.serverTimestamp(),
  });

  console.log(
    allFailed
      ? `❌ All sends failed (${failures.length}) for ${jobId}`
      : failures.length
        ? `⚠️ Sent with ${failures.length} failures for ${jobId}`
        : `✅ Sent ${jobId}`
  );
}

// ---------- queue + concurrency ----------
const q = [];
let active = 0;

function enqueue(ref) {
  q.push(ref);
  pump();
}

async function pump() {
  while (active < JOB_CONCURRENCY && q.length) {
    const ref = q.shift();
    active++;
    processJob(ref)
      .catch(e => console.error('🔥 processJob error:', e.message || e))
      .finally(() => { active--; pump(); });
  }
}

// ---------- listener + sweep + timeout recovery ----------
let unsubscribe = null;

async function attachListener() {
  if (unsubscribe) return;
  const base = db.collection('alert_dispatch').where('status', '==', 'pending');
  unsubscribe = base.orderBy('createdAtMs', 'asc').limit(50).onSnapshot(
    (snap) => {
      snap.docChanges().forEach((c) => { if (c.type === 'added') enqueue(c.doc.ref); });
    },
    async (err) => {
      console.error('🔥 Snapshot error:', err.message || err);
    }
  );
}

async function sweep() {
  try {
    // pick up any pending jobs missed by snapshot
    const pend = await db.collection('alert_dispatch')
      .where('status', '==', 'pending').limit(100).get();
    pend.docs.forEach(d => enqueue(d.ref));

    // requeue "stuck" processing jobs older than timeout
    const cutoff = Date.now() - PROCESSING_TIMEOUT_MS;
    const stuck = await db.collection('alert_dispatch')
      .where('status', '==', 'processing')
      .where('createdAtMs', '<=', cutoff)
      .limit(100).get();

    const writes = [];
    stuck.docs.forEach(d => writes.push(d.ref.update({ status: 'pending' }).catch(() => {})));
    if (writes.length) {
      await Promise.allSettled(writes);
      console.log(`⏱️ Requeued ${writes.length} stuck job(s).`);
    }
  } catch (e) {
    console.error('⏱️ Sweep error:', e.message || e);
  }
}

// ---------- boot ----------
(async () => {
  await attachListener();
  await sweep();
  setInterval(sweep, SWEEP_MS);
})();

// ---------- shutdown ----------
function bye() {
  console.log('👋 worker exiting');
  try { if (unsubscribe) unsubscribe(); } catch (_) {}
  process.exit(0);
}
process.on('SIGINT', bye);
process.on('SIGTERM', bye);
