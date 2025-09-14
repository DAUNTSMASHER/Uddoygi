#!/usr/bin/env node
'use strict';

/**
 * tools/watch_live_devices.js
 * Live “who’s online” + Message tracker.
 *
 * Watches:
 *   - collectionGroup('devices')        → active devices by user
 *   - messages (recent)                 → new messages
 *   - alert_dispatch (recent)           → FCM push send status for each message (via alertId)
 *   - notifications (recent, type=message) → in-app/FCM banner doc + read status
 *
 * Shows two tables every REFRESH_MS:
 *  1) Active Devices
 *  2) Recent Messages (sender → receiver, push + banner timing)
 *
 * Filters:
 *   --uid=<uid>      only show a single user’s devices/messages
 *   --email=<email>  only show a single user’s devices/messages
 *
 * Env:
 *   SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
 *   FIREBASE_PROJECT_ID=uddyogi
 *   THRESHOLD_SEC=70         (device staleness cutoff)
 *   REFRESH_MS=1500          (table refresh interval)
 *   MSG_LOOKBACK_MIN=180     (look back this many minutes for messages/alerts/notifs)
 *   MSG_LIMIT=40             (max messages to keep in memory)
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// ---------- CLI args ----------
const argv = process.argv.slice(2);
const argMap = new Map(argv.map(a => {
  const [k, ...rest] = a.split('=');
  return [k, rest.join('=')];
}));
let filterUid = argMap.get('--uid') || null;
let filterEmail = argMap.get('--email') || null;

// ---------- credential auto-detect ----------
const candidates = [
  process.env.SERVICE_ACCOUNT_PATH,
  path.resolve(process.cwd(), 'service-account.json'),
  path.resolve(process.cwd(), 'serviceAccountKey.json'),
  path.resolve(__dirname, 'service-account.json'),
  path.resolve(__dirname, 'serviceAccountKey.json'),
].filter(Boolean);
const KEY_PATH = candidates.find(p => fs.existsSync(p));
if (!KEY_PATH) {
  console.error('❌ No service account key found.\nSearched:\n' + candidates.join('\n'));
  process.exit(1);
}

const sa = require(KEY_PATH);
admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: process.env.FIREBASE_PROJECT_ID || sa.project_id,
});
const db = admin.firestore();

// ---------- config ----------
const THRESHOLD_SEC   = Number(process.env.THRESHOLD_SEC   || 70);
const REFRESH_MS      = Number(process.env.REFRESH_MS      || 1500);
const MSG_LOOKBACK_MIN= Number(process.env.MSG_LOOKBACK_MIN|| 180);
const MSG_LIMIT       = Number(process.env.MSG_LIMIT       || 40);

// ---------- shared helpers ----------
const short = (s, n = 10) => (s || '').toString().length > n ? (s || '').toString().slice(0,n) + '…' : (s || '');
const fmtTime = (ms) => {
  if (!ms) return '';
  const d = new Date(ms);
  return d.toISOString().replace('T',' ').replace('Z','');
};
const ageSecs = (ms) => Math.max(0, Math.round((Date.now() - (ms || 0)) / 1000));
const withinSecs = (t1, t2, windowSec) => Math.abs(((t1||0)-(t2||0))/1000) <= windowSec;

// ---------- devices state ----------
/** deviceKey = `${uid}:${deviceId}` -> { uid, email, deviceId, platform, lastSeenMs, online, token } */
const devices = new Map();
/** uid -> email (cached) */
const emailCache = new Map();

// ---------- messages state ----------
/** messageId -> record */
const messages = new Map();
/** alertId (=messageId) -> {status, createdAtMs, sentAtMs, failedCount} */
const dispatches = new Map();
/** messageId -> {toUserId,toEmail,createdAtMs,read,readAtMs} (from notifications) */
const notifByMsg = new Map();

// ---------- filters helpers ----------
function rowMatchesUserFilters(uid, email) {
  if (filterUid   && uid   !== filterUid) return false;
  if (filterEmail && (email||'').toLowerCase() !== filterEmail.toLowerCase()) return false;
  return true;
}

async function ensureEmailForUid(uid) {
  if (!uid) return '';
  if (emailCache.has(uid)) return emailCache.get(uid);
  const snap = await db.collection('users').doc(uid).get().catch(() => null);
  const data = snap?.data() || {};
  const email = (data.email || data.officeEmail || data.personalEmail || '').toString();
  emailCache.set(uid, email);
  return email;
}

// ---------- Live devices listener ----------
(function watchDevices() {
  db.collectionGroup('devices').onSnapshot(async (snap) => {
    const tasks = [];
    snap.docChanges().forEach((c) => {
      const doc = c.doc;
      const uid = doc.ref.parent.parent?.id || 'unknown';
      const m = doc.data() || {};
      const deviceId   = doc.id;
      const lastSeenMs = m.lastSeen?.toMillis ? m.lastSeen.toMillis() : 0;
      if (!emailCache.has(uid)) tasks.push(ensureEmailForUid(uid));

      devices.set(`${uid}:${deviceId}`, {
        uid,
        email: emailCache.get(uid) || '',
        deviceId,
        platform: m.platform || 'unknown',
        lastSeenMs,
        online: !!m.online,
        token: m.token || '',
      });
    });
    await Promise.allSettled(tasks);

    // backfill emails where needed
    for (const [k, row] of devices) {
      if (!row.email && emailCache.has(row.uid)) {
        row.email = emailCache.get(row.uid);
        devices.set(k, row);
      }
    }
  }, (err) => console.error('🔥 devices snapshot error:', err));
})();

// ---------- Messages watcher ----------
(async function watchMessages() {
  // resolve uid if filtering by email only
  if (filterEmail && !filterUid) {
    const q = await db.collection('users').where('email','==',filterEmail).limit(1).get();
    if (!q.empty) filterUid = q.docs[0].id;
  }

  const since = Date.now() - MSG_LOOKBACK_MIN*60*1000;
  db.collection('messages')
    .orderBy('timestamp', 'desc')
    .limit(MSG_LIMIT)
    .onSnapshot(async (snap) => {
      const tasks = [];
      snap.docChanges().forEach((c) => {
        if (c.type !== 'added' && c.type !== 'modified') return;
        const d = c.doc;
        const m = d.data() || {};

        const messageId  = d.id;
        const sentAtMs   = m.timestamp?.toMillis ? m.timestamp.toMillis() : 0;
        if (sentAtMs && sentAtMs < since) return; // keep it recent

        const fromEmail  = (m.from || '').toString();
        const fromName   = (m.fromName || '').toString();
        const toArray    = Array.isArray(m.to) ? m.to : [];
        const toEmail    = (toArray[0] || (m.toEmail||'')).toString();
        const subject    = (m.subject || '').toString();
        const body       = (m.body || '').toString();
        const toUid      = (m.toUid || '').toString(); // we added this in your sender UI
        const toName     = (m.toName || '').toString();

        // Try to resolve sender uid by email (one-time cache)
        let fromUid = null;
        const cachedUid = [...emailCache.entries()].find(([,e]) => (e||'').toLowerCase() === (fromEmail||'').toLowerCase());
        if (cachedUid) fromUid = cachedUid[0];

        messages.set(messageId, {
          messageId, subject, body,
          fromEmail, fromName, fromUid,
          toEmail, toName, toUid,
          sentAtMs,
        });

        // also try to prefetch to/from emails if we only have uids
        if (toUid && !emailCache.has(toUid)) tasks.push(ensureEmailForUid(toUid));
        if (fromUid && !emailCache.has(fromUid)) tasks.push(ensureEmailForUid(fromUid));
      });

      await Promise.allSettled(tasks);

      // Backfill emails by uid if needed
      for (const msg of messages.values()) {
        if (!msg.toEmail && msg.toUid && emailCache.has(msg.toUid)) msg.toEmail = emailCache.get(msg.toUid);
        if (!msg.fromEmail && msg.fromUid && emailCache.has(msg.fromUid)) msg.fromEmail = emailCache.get(msg.fromUid);
      }
    }, (err) => console.error('🔥 messages snapshot error:', err));
})();

// ---------- alert_dispatch watcher (push job status) ----------
(function watchDispatch() {
  const sinceMs = Date.now() - MSG_LOOKBACK_MIN*60*1000;
  db.collection('alert_dispatch')
    .orderBy('createdAtMs', 'desc')
    .limit(200)
    .onSnapshot((snap) => {
      snap.docChanges().forEach((c) => {
        const d = c.doc;
        const m = d.data() || {};
        if ((m.createdAtMs||0) < sinceMs) return;

        const alertId = (m.alertId || d.id).toString(); // usually messageId
        dispatches.set(alertId, {
          alertId,
          status: (m.status || 'pending').toString(),
          createdAtMs: Number(m.createdAtMs || 0),
          sentAtMs: m.sentAt?.toMillis ? m.sentAt.toMillis() : 0,
          failedCount: Number(m.failedCount || 0),
        });
      });
    }, (err) => console.error('🔥 alert_dispatch snapshot error:', err));
})();

// ---------- notifications watcher (banner/read) ----------
(function watchNotifs() {
  const since = admin.firestore.Timestamp.fromMillis(Date.now() - MSG_LOOKBACK_MIN*60*1000);
  db.collection('notifications')
    .where('type', '==', 'message')
    .orderBy('createdAt', 'desc')
    .limit(200)
    .onSnapshot((snap) => {
      snap.docChanges().forEach((c) => {
        const d = c.doc;
        const m = d.data() || {};
        const msgId = (m.messageId || '').toString();
        if (!msgId) return;

        const createdAtMs = m.createdAt?.toMillis ? m.createdAt.toMillis() : 0;
        if (!createdAtMs || createdAtMs < since.toMillis()) return;

        notifByMsg.set(msgId, {
          messageId: msgId,
          toUserId : (m.toUserId || '').toString(),
          toEmail  : (m.to || '').toString(),
          createdAtMs,
          read     : !!m.read,
          readAtMs : m.readAt?.toMillis ? m.readAt.toMillis() : 0,
        });
      });
    }, (err) => console.error('🔥 notifications snapshot error:', err));
})();

// ---------- choose likely device for a user near a timestamp ----------
function guessDevice(uid, aroundMs, windowSec = 180) {
  let best = null;
  for (const row of devices.values()) {
    if (row.uid !== uid) continue;
    if (!withinSecs(row.lastSeenMs, aroundMs, windowSec)) continue;
    if (!best || row.lastSeenMs > best.lastSeenMs) best = row;
  }
  return best; // may be null
}

// ---------- render loop ----------
setInterval(() => {
  console.clear();

  // 1) Active devices
  const rowsDev = [];
  const perUser = new Map(); // email -> count

  for (const row of devices.values()) {
    const fresh = ageSecs(row.lastSeenMs) <= THRESHOLD_SEC && row.online === true;
    if (!fresh) continue;
    if (!rowMatchesUserFilters(row.uid, row.email)) continue;

    rowsDev.push({
      'User Email' : row.email || '(unknown)',
      'UID'        : short(row.uid, 6),
      'Device'     : short(row.deviceId, 12),
      'Platform'   : row.platform,
      'Age (s)'    : ageSecs(row.lastSeenMs),
      'Last Seen'  : fmtTime(row.lastSeenMs),
      'Online'     : row.online ? '✓' : '—',
      'Token'      : short(row.token, 16),
    });

    const key = (row.email || '(unknown)').toLowerCase();
    perUser.set(key, (perUser.get(key) || 0) + 1);
  }

  rowsDev.sort((a,b) => (a['User Email']||'').localeCompare(b['User Email']||'') || (a['Device']||'').localeCompare(b['Device']||''));

  console.log('================ Live Devices ================');
  console.log(`(online && lastSeen <= ${THRESHOLD_SEC}s)\n`);
  if (rowsDev.length === 0) console.log('No active devices.\n'); else console.table(rowsDev);

  console.log('================ Active Users =================');
  const usersTable = Array.from(perUser.entries())
    .sort((a,b) => a[0].localeCompare(b[0]))
    .map(([email, count]) => ({ 'User Email': email, 'Devices Online': count }));
  if (usersTable.length === 0) console.log('No active users.\n'); else console.table(usersTable);

  // 2) Recent messages
  const recentMsgs = Array.from(messages.values())
    .filter(m => rowMatchesUserFilters(m.fromUid || '', m.fromEmail) || rowMatchesUserFilters(m.toUid || '', m.toEmail))
    .sort((a,b) => (b.sentAtMs || 0) - (a.sentAtMs || 0))
    .slice(0, MSG_LIMIT);

  const msgRows = recentMsgs.map(m => {
    const disp = dispatches.get(m.messageId);
    const notif = notifByMsg.get(m.messageId);

    const pushStatus = disp ? disp.status : '—';
    const pushLatency = (disp && disp.sentAtMs && m.sentAtMs) ? `${Math.max(0, Math.round((disp.sentAtMs - m.sentAtMs)/1000))}s` : '';
    const notifLatency = (notif && notif.createdAtMs && m.sentAtMs) ? `${Math.max(0, Math.round((notif.createdAtMs - m.sentAtMs)/1000))}s` : '';
    const readLatency  = (notif && notif.readAtMs && m.sentAtMs) ? `${Math.max(0, Math.round((notif.readAtMs - m.sentAtMs)/1000))}s` : '';

    // Guess devices around events
    const senderDev   = (m.fromUid && m.sentAtMs) ? guessDevice(m.fromUid, m.sentAtMs) : null;
    const receiverDev = (m.toUid   && (notif?.createdAtMs || disp?.sentAtMs || m.sentAtMs))
      ? guessDevice(m.toUid, notif?.createdAtMs || disp?.sentAtMs || m.sentAtMs)
      : null;

    return {
      'MsgID'      : short(m.messageId, 8),
      'Subject'    : short(m.subject || '(no subject)', 18),
      'From'       : short(m.fromEmail || m.fromName || '(unknown)', 24),
      'To'         : short(m.toEmail   || m.toName   || '(unknown)', 24),
      'Sent'       : fmtTime(m.sentAtMs),
      'Push'       : pushStatus + (disp?.failedCount ? ` (${disp.failedCount} fail)` : ''),
      'Push Δ'     : pushLatency,
      'Banner'     : notif ? (notif.read ? 'read' : 'created') : '—',
      'Banner Δ'   : notifLatency,
      'Read Δ'     : readLatency,
      'SenderDev'  : senderDev ? `${senderDev.platform}/${short(senderDev.deviceId,8)}` : '—',
      'RecvDev'    : receiverDev ? `${receiverDev.platform}/${short(receiverDev.deviceId,8)}` : '—',
    };
  });

  console.log('\n================ Recent Messages ================');
  console.log(`(lookback ${MSG_LOOKBACK_MIN} min; limit ${MSG_LIMIT})\n`);
  if (msgRows.length === 0) console.log('No recent messages.\n'); else console.table(msgRows);

  if (filterUid || filterEmail) {
    console.log('Filters:',
      filterUid ? `--uid=${filterUid}` : '',
      filterEmail ? `--email=${filterEmail}` : '',
      '\n'
    );
  }
}, REFRESH_MS);

// graceful shutdown
process.on('SIGINT', () => { console.log('👋 bye'); process.exit(0); });
