#!/usr/bin/env node
/**
 * Dump Firestore structure + sample data + basic field type stats.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/serviceAccount.json \
 *   node tools/dumpFirestoreSchema.js --project <PROJECT_ID> --samples 3 --depth 1 [--collections users,invoices]
 *
 * Notes:
 * - --samples = number of sample docs per collection (default 2)
 * - --depth   = how deep to list subcollections under sampled docs (default 1)
 * - --collections = optional CSV to restrict which top-level collections to scan
 *
 * Output:
 * - A YAML section (easy to read)
 * - A JSON section (machine-readable)
 *
 * Safe to run on production; uses count() aggregation and limited sampling.
 */

const admin = require('firebase-admin');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

const argv = yargs(hideBin(process.argv))
  .option('project', { type: 'string', describe: 'GCP/Firebase Project ID' })
  .option('samples', { type: 'number', default: 2, describe: 'Sample docs per collection' })
  .option('depth', { type: 'number', default: 1, describe: 'Subcollection depth under sampled docs' })
  .option('collections', { type: 'string', describe: 'CSV of top-level collections to include' })
  .help().argv;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('ERROR: Set GOOGLE_APPLICATION_CREDENTIALS=/abs/path/serviceAccount.json');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: argv.project || undefined,
});

const db = admin.firestore();

function typeOfValue(v) {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  const t = typeof v;
  if (t === 'object') {
    // Firestore Timestamp (from admin SDK .data() you get JS Date—so we check Date)
    if (v instanceof Date) return 'timestamp';
    // Firestore GeoPoint
    if (v.latitude !== undefined && v.longitude !== undefined) return 'geopoint';
    return 'map';
  }
  return t;
}

function mergeStats(stats, data) {
  Object.entries(data).forEach(([k, v]) => {
    const t = typeOfValue(v);
    stats[k] = stats[k] || {};
    stats[k][t] = (stats[k][t] || 0) + 1;
  });
}

async function listSubcollections(docRef, depth, maxDepth, samples) {
  if (depth > maxDepth) return [];
  const subs = await docRef.listCollections();
  const out = [];
  for (const sub of subs) {
    // samples
    const snap = await sub.limit(samples).get();
    const sampleDocs = [];
    const fieldStats = {};
    for (const d of snap.docs) {
      const data = d.data();
      sampleDocs.push({ id: d.id, ...serializeData(data) });
      mergeStats(fieldStats, data);
    }
    // true count (server aggregation)
    const countSnap = await sub.count().get();
    const count = countSnap.data().count;

    out.push({
      name: sub.id,
      count,
      fieldStats,
      samples: sampleDocs,
      // no deeper recursion to avoid heavy reads; change if needed:
      subcollections: [],
    });
  }
  return out;
}

function serializeData(data) {
  // Convert Dates to ISO for readability
  const out = {};
  for (const [k, v] of Object.entries(data)) {
    if (v instanceof Date) {
      out[k] = v.toISOString();
    } else if (v && typeof v === 'object') {
      if (v.latitude !== undefined && v.longitude !== undefined) {
        out[k] = { _type: 'geopoint', latitude: v.latitude, longitude: v.longitude };
      } else if (v instanceof Buffer) {
        out[k] = { _type: 'bytes', length: v.length };
      } else if (Array.isArray(v)) {
        out[k] = v.map(x => (x instanceof Date ? x.toISOString() : x));
      } else {
        out[k] = v; // map
      }
    } else {
      out[k] = v;
    }
  }
  return out;
}

async function main() {
  const projectId = (await admin.app().options.projectId) || null;
  const result = { projectId, generatedAt: new Date().toISOString(), collections: [] };

  let collections = await db.listCollections();
  const filterCsv = (argv.collections || '').trim();
  if (filterCsv.length) {
    const allow = new Set(filterCsv.split(',').map(s => s.trim()).filter(Boolean));
    collections = collections.filter(c => allow.has(c.id));
  }

  // Sort by name for stable output
  collections.sort((a, b) => a.id.localeCompare(b.id));

  for (const col of collections) {
    const snap = await col.limit(argv.samples).get();
    const sampleDocs = [];
    const fieldStats = {};
    for (const d of snap.docs) {
      const data = d.data();
      sampleDocs.push({ id: d.id, ...serializeData(data) });
      mergeStats(fieldStats, data);
    }
    const countSnap = await col.count().get();
    const total = countSnap.data().count;

    const subSchema = [];
    if (argv.depth > 0) {
      for (const d of snap.docs.slice(0, argv.samples)) {
        const subs = await listSubcollections(d.ref, 1, argv.depth, argv.samples);
        subSchema.push({ docId: d.id, subcollections: subs });
      }
    }

    result.collections.push({
      name: col.id,
      count: total,
      fieldStats,
      samples: sampleDocs,
      subcollectionsBySampleDoc: subSchema,
    });
  }

  const yaml = objToYaml(result);
  console.log('-----BEGIN FIRESTORE_SCHEMA.YAML-----');
  console.log(yaml);
  console.log('-----END FIRESTORE_SCHEMA.YAML-----\n');

  console.log('-----BEGIN FIRESTORE_SCHEMA.JSON-----');
  console.log(JSON.stringify(result, null, 2));
  console.log('-----END FIRESTORE_SCHEMA.JSON-----');
}

// Tiny YAML emitter (no external deps)
function objToYaml(obj, indent = 0) {
  const pad = '  '.repeat(indent);
  if (obj === null) return 'null';
  if (Array.isArray(obj)) {
    if (obj.length === 0) return '[]';
    return obj.map(v => `${pad}- ${objToYaml(v, indent + 1).trimStart()}`).join('\n');
  }
  if (typeof obj === 'object') {
    const keys = Object.keys(obj);
    if (keys.length === 0) return '{}';
    return keys.map(k => {
      const v = obj[k];
      const head = `${pad}${k}:`;
      if (v === null || typeof v !== 'object' || (Array.isArray(v) && v.length === 0)) {
        return `${head} ${objToYaml(v, 0)}`;
      }
      return `${head}\n${objToYaml(v, indent + 1)}`;
    }).join('\n');
  }
  if (typeof obj === 'string') {
    if (/[:\-\n]/.test(obj)) return `"${obj.replace(/"/g, '\\"')}"`;
    return obj;
  }
  return String(obj);
}

main().catch(e => {
  console.error('DUMP ERROR:', e && e.message ? e.message : e);
  process.exit(1);
});
