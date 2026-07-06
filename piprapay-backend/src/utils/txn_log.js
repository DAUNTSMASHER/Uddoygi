// piprapay-backend/src/utils/txn_log.js
// ─────────────────────────────────────────────────────────────────────────────
// Simple file-based transaction log for development.
// In production, replace with a real database (PostgreSQL, MongoDB, Firestore).
//
// Interface:
//   save(record)          — persist a new transaction
//   update(ppId, fields)  — update an existing record by pp_id
//   find(ppId)            — find a record by pp_id
//   findByOrderId(id)     — find a record by order_id
//   list(limit)           — list recent transactions
// ─────────────────────────────────────────────────────────────────────────────

const fs   = require('fs').promises;
const path = require('path');

const LOG_FILE = path.join(__dirname, '../../logs/transactions.json');

async function _read() {
  try {
    const raw = await fs.readFile(LOG_FILE, 'utf8');
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

async function _write(data) {
  await fs.mkdir(path.dirname(LOG_FILE), { recursive: true });
  await fs.writeFile(LOG_FILE, JSON.stringify(data, null, 2), 'utf8');
}

async function save(record) {
  const data = await _read();
  const key  = record.ppId || record.orderId;
  data[key]  = { ...record, savedAt: new Date().toISOString() };
  await _write(data);
  return data[key];
}

async function update(ppId, fields) {
  const data = await _read();
  // Try to find by ppId or by scanning for matching orderId
  let key = ppId;
  if (!data[key]) {
    const entry = Object.values(data).find(
      r => r.ppId === ppId || r.orderId === ppId
    );
    if (entry) key = entry.ppId || entry.orderId;
  }
  data[key] = { ...(data[key] || {}), ...fields, updatedAt: new Date().toISOString() };
  await _write(data);
  return data[key];
}

async function find(ppId) {
  const data = await _read();
  return data[ppId] ||
    Object.values(data).find(r => r.ppId === ppId) ||
    null;
}

async function findByOrderId(orderId) {
  const data = await _read();
  return Object.values(data).find(r => r.orderId === orderId) || null;
}

async function list(limit = 50) {
  const data = await _read();
  return Object.values(data)
    .sort((a, b) => new Date(b.savedAt) - new Date(a.savedAt))
    .slice(0, limit);
}

module.exports = { save, update, find, findByOrderId, list };
