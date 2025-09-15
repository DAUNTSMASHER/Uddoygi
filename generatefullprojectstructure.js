#!/usr/bin/env node
/**
 * generatefullprojectstructure.js
 *
 * Produce a thorough Markdown snapshot of:
 *  A) Local project structure (directory tree + key file previews)
 *  B) Firebase resources (Firestore schema samples, Storage listing, Auth stats)
 *
 * USAGE:
 *   node generatefullprojectstructure.js \
 *     --dir . \
 *     --projectId your-firebase-project-id \
 *     --credentials /abs/path/to/serviceAccount.json \
 *     --maxDepth 6 --maxFilesPerDir 200 \
 *     --sampleDocs 5 --sampleSubcols 5 --sampleStorage 100 \
 *     --format markdown
 *
 * QUICK START:
 *   npm i firebase-admin
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 *   node generatefullprojectstructure.js --dir . --projectId your-project
 *
 * NOTES:
 * - By default, email/phone are redacted when listing Auth users. Use --no-redact to show full values.
 * - This script prints to STDOUT. Redirect to a file if needed, e.g.:
 *     node generatefullprojectstructure.js ... > PROJECT_SNAPSHOT.md
 */

const fs = require('fs');
const fsp = fs.promises;
const path = require('path');

// ---------- CLI ARGS ----------
const args = parseArgs(process.argv.slice(2), {
  dir: { type: 'string', default: process.cwd() },
  projectId: { type: 'string', default: '' },
  credentials: { type: 'string', default: process.env.GOOGLE_APPLICATION_CREDENTIALS || '' },
  format: { type: 'string', default: 'markdown' },

  maxDepth: { type: 'number', default: 6 },
  maxFilesPerDir: { type: 'number', default: 200 },
  maxPreviewBytes: { type: 'number', default: 4096 },

  sampleDocs: { type: 'number', default: 5 },        // per collection
  sampleSubcols: { type: 'number', default: 5 },     // per document
  sampleStorage: { type: 'number', default: 100 },   // max objects to list per bucket/prefix
  redact: { type: 'boolean', default: true },        // redact auth PII
  'no-redact': { type: 'boolean', default: false },  // override
});

if (args['no-redact']) args.redact = false;

// ---------- Firebase Admin (lazy init) ----------
let admin = null;
let firestore = null;
let storage = null;
let auth = null;

async function initFirebase() {
  if (admin) return;
  try {
    admin = require('firebase-admin');

    const opts = {};
    if (args.credentials) {
      const sa = require(path.resolve(args.credentials));
      opts.credential = admin.credential.cert(sa);
      if (!args.projectId && sa.project_id) args.projectId = sa.project_id;
    } else {
      // Will rely on GOOGLE_APPLICATION_CREDENTIALS or ADC
      opts.credential = admin.credential.applicationDefault();
    }
    if (args.projectId) opts.projectId = args.projectId;

    admin.initializeApp(opts);
    firestore = admin.firestore();
    storage = admin.storage();
    auth = admin.auth();
  } catch (e) {
    throw new Error(
      `Failed to initialize Firebase Admin SDK. Ensure 'npm i firebase-admin' and valid credentials.\n` +
      `Details: ${e.message}`
    );
  }
}

// ---------- Local Tree Walk ----------
const DEFAULT_IGNORES = [
  'node_modules', '.git', '.dart_tool', '.idea', '.vscode', '.gradle', '.github',
  'build', 'dist', 'out', 'coverage', 'Pods', '.firebase', '.firebase-tools',
  '.DS_Store', '.fleet', '.parcel-cache', '.next', '.nuxt', '.expo',
  // Flutter/Android/iOS heavy dirs:
  'ios/Pods', 'android/.gradle', 'android/app/build',
];

async function walkDir(root, {
  depth = 0,
  maxDepth = 6,
  maxFilesPerDir = 200,
  ignores = DEFAULT_IGNORES,
}) {
  const rel = path.relative(args.dir, root) || '.';
  let entries = [];
  try {
    entries = await fsp.readdir(root, { withFileTypes: true });
  } catch {
    return { name: path.basename(root), type: 'dir', children: [], error: 'unreadable' };
  }

  // filter + sort: dirs first then files, alphabetical
  entries = entries
    .filter(d => !ignores.some(ig => matchesIgnore(path.join(rel, d.name), ig)))
    .sort((a, b) => {
      if (a.isDirectory() && !b.isDirectory()) return -1;
      if (!a.isDirectory() && b.isDirectory()) return 1;
      return a.name.localeCompare(b.name);
    })
    .slice(0, maxFilesPerDir);

  const children = [];
  for (const entry of entries) {
    const full = path.join(root, entry.name);
    let stat;
    try {
      stat = await fsp.lstat(full);
    } catch {
      children.push({ name: entry.name, type: 'unknown', error: 'stat failed' });
      continue;
    }
    if (stat.isSymbolicLink()) {
      children.push({ name: entry.name, type: 'symlink' });
      continue;
    }
    if (entry.isDirectory()) {
      if (depth >= maxDepth) {
        children.push({ name: entry.name, type: 'dir', truncated: true });
      } else {
        children.push(await walkDir(full, { depth: depth + 1, maxDepth, maxFilesPerDir, ignores }));
      }
    } else {
      children.push({ name: entry.name, type: 'file', size: stat.size });
    }
  }
  return { name: path.basename(root), type: 'dir', children };
}

function matchesIgnore(relPath, ignore) {
  if (ignore.includes('/')) {
    // path prefix ignore
    return relPath.startsWith(ignore);
  }
  // basename ignore
  return path.basename(relPath) === ignore;
}

function renderTree(node, prefix = '') {
  const lines = [];
  if (node.type === 'dir') {
    lines.push(prefix + (prefix ? '┬ ' : '') + node.name + '/');
    const children = node.children || [];
    const lastIdx = children.length - 1;
    children.forEach((child, i) => {
      const isLast = i === lastIdx;
      const branch = prefix ? (isLast ? '└─ ' : '├─ ') : '';
      const nextPrefix = prefix + (prefix ? (isLast ? '   ' : '│  ') : '');
      if (child.type === 'dir') {
        lines.push(prefix + branch + child.name + '/');
        const sub = renderTree(child, nextPrefix);
        // Drop the first line (it already prints child.name)
        lines.push(...sub.slice(1));
      } else if (child.type === 'file') {
        const sizeStr = (typeof child.size === 'number') ? ` (${formatBytes(child.size)})` : '';
        lines.push(prefix + branch + child.name + sizeStr);
      } else if (child.truncated) {
        lines.push(prefix + branch + child.name + '/ ...(depth truncated)');
      } else if (child.type === 'symlink') {
        lines.push(prefix + branch + child.name + ' -> [symlink]');
      } else {
        lines.push(prefix + branch + child.name + ` [${child.type || 'unknown'}]`);
      }
    });
  } else {
    lines.push(prefix + node.name);
  }
  return lines;
}

function formatBytes(n) {
  if (n === 0) return '0B';
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(n) / Math.log(1024));
  return (n / Math.pow(1024, i)).toFixed(1) + u[i];
}

async function previewIfExists(root, relPath, label = null) {
  const full = path.join(root, relPath);
  try {
    const stat = await fsp.stat(full);
    if (!stat.isFile()) return '';
    const buf = await fsp.readFile(full);
    const slice = buf.slice(0, args.maxPreviewBytes).toString('utf8');
    const cut = buf.length > args.maxPreviewBytes ? `\n... [truncated to ${args.maxPreviewBytes} bytes]\n` : '';
    return `\n**${label || relPath}**  \n\`\`\`${extToLang(relPath)}\n${slice}${cut}\`\`\`\n`;
  } catch {
    return '';
  }
}

function extToLang(p) {
  const ext = path.extname(p).toLowerCase();
  if (ext === '.json') return 'json';
  if (ext === '.yaml' || ext === '.yml') return 'yaml';
  if (ext === '.dart') return 'dart';
  if (ext === '.js' || ext === '.mjs' || ext === '.cjs') return 'javascript';
  if (ext === '.ts') return 'typescript';
  if (ext === '.gradle') return 'groovy';
  if (ext === '.xml') return 'xml';
  return '';
}

// ---------- Firebase Helpers ----------
async function summarizeFirestore() {
  await initFirebase();
  const db = firestore;

  const out = [];
  out.push(`### Firestore Overview\n`);
  const rootCols = await db.listCollections();
  if (!rootCols.length) {
    out.push(`No root collections found.\n`);
    return out.join('\n');
  }

  for (const col of rootCols) {
    out.push(`- **Collection:** \`${col.id}\``);
    // Attempt count aggregation (may fail on older emulator/SDK)
    let countStr = '';
    try {
      const agg = await col.count().get();
      countStr = ` (approx. ${agg.data().count} docs)`;
    } catch {
      countStr = '';
    }
    out[out.length - 1] += countStr;

    // Sample documents
    const snap = await col.limit(args.sampleDocs).get();
    if (snap.empty) {
      out.push(`  - (no documents)`);
      continue;
    }
    let idx = 0;
    for (const doc of snap.docs) {
      idx++;
      const data = doc.data();
      out.push(`  - Doc [${idx}] \`${doc.id}\` fields: \`${Object.keys(data).slice(0, 40).join(', ')}\``);

      // List subcollections for each doc
      try {
        const subcols = await doc.ref.listCollections();
        if (subcols.length) {
          out.push(`    - Subcollections: ${subcols.slice(0, args.sampleSubcols).map(s => `\`${s.id}\``).join(', ')}${subcols.length > args.sampleSubcols ? ' ...' : ''}`);
        }
      } catch {
        // ignore
      }
    }
  }
  return out.join('\n') + '\n';
}

async function summarizeStorage() {
  await initFirebase();
  const out = [];
  out.push(`### Storage Overview\n`);
  try {
    const [buckets] = await storage.getBuckets({ project: args.projectId || undefined });
    if (!buckets || !buckets.length) {
      out.push(`No buckets found.`);
      return out.join('\n') + '\n';
    }
    for (const b of buckets) {
      out.push(`- **Bucket:** \`${b.name}\``);
      try {
        const [files] = await b.getFiles({ maxResults: args.sampleStorage });
        if (!files.length) {
          out.push(`  - (no files within sample window)`);
        } else {
          const list = files.slice(0, args.sampleStorage).map(f => `\`${f.name}\``);
          out.push(`  - Sample (${list.length}): ${list.join(', ')}`);
        }
      } catch (e) {
        out.push(`  - Error listing files: ${e.message}`);
      }
    }
  } catch (e) {
    out.push(`Error listing buckets: ${e.message}`);
  }
  return out.join('\n') + '\n';
}

function redactStr(s) {
  if (!args.redact) return s;
  if (!s) return s;
  if (s.includes('@')) {
    const [u, d] = s.split('@');
    return `${u.slice(0, 2)}***@${d[0]}***`;
  }
  if (s.replace(/\D/g, '').length >= 7) {
    return s.slice(0, 2) + '***' + s.slice(-2);
  }
  return s[0] + '***';
}

async function summarizeAuth() {
  await initFirebase();
  const out = [];
  out.push(`### Auth Overview\n`);
  try {
    let nextPageToken = undefined;
    let count = 0;
    const sample = [];
    do {
      const res = await auth.listUsers(1000, nextPageToken);
      count += res.users.length;
      // collect up to 10 samples
      for (const u of res.users) {
        if (sample.length < 10) {
          sample.push({
            uid: args.redact ? u.uid.slice(0, 6) + '***' : u.uid,
            email: u.email ? redactStr(u.email) : undefined,
            phone: u.phoneNumber ? redactStr(u.phoneNumber) : undefined,
            provider: (u.providerData && u.providerData[0] && u.providerData[0].providerId) || 'password',
            disabled: !!u.disabled
          });
        }
      }
      nextPageToken = res.pageToken;
    } while (nextPageToken);

    out.push(`- Total users: **${count}**`);
    if (sample.length) {
      out.push(`- Sample users (redacted=${args.redact}):`);
      sample.forEach((s, i) => {
        out.push(`  - [${i + 1}] uid=${s.uid}, email=${s.email || '-'}, phone=${s.phone || '-'}, provider=${s.provider}, disabled=${s.disabled}`);
      });
    }
  } catch (e) {
    out.push(`Error listing users: ${e.message}`);
  }
  return out.join('\n') + '\n';
}

// ---------- Main Orchestrator ----------
(async () => {
  const started = new Date();

  // Local tree
  const tree = await walkDir(path.resolve(args.dir), {
    maxDepth: args.maxDepth,
    maxFilesPerDir: args.maxFilesPerDir
  });
  const treeText = renderTree(tree).join('\n');

  // Key file previews commonly present in Flutter/Firebase apps
  const previews = [];
  const likelyFiles = [
    'pubspec.yaml',
    'firebase.json',
    '.firebaserc',
    'Firestore.rules',
    'firestore.rules',
    'firestore.indexes.json',
    'storage.rules',
    'package.json',
    'lib/main.dart',
    'lib/firebase_options.dart',
    'android/app/google-services.json',
    'ios/Runner/GoogleService-Info.plist',
    'web/index.html',
    'lib/features/hr/presentation/screens/attendance_screen.dart',
    'lib/features/marketing/presentation/screens/sales_screen.dart',
    'lib/features/factory/presentation/screens/progress_update_screen.dart',
  ];
  for (const f of likelyFiles) {
    const block = await previewIfExists(args.dir, f);
    if (block) previews.push(block);
  }

  // Firebase sections
  let fbSections = '';
  try {
    await initFirebase();
    const fbIntro =
      `## Firebase Summary\n` +
      `- Project ID: **${args.projectId || '(from credentials/ADC)'}**\n` +
      `- Credentials: **${args.credentials ? 'explicit file' : (process.env.GOOGLE_APPLICATION_CREDENTIALS ? 'from env' : 'ADC/metadata')}**\n` +
      `- Redaction: **${args.redact}** (use --no-redact to disable)\n\n`;
    const fsr = await summarizeFirestore();
    const str = await summarizeStorage();
    const atr = await summarizeAuth();
    fbSections = fbIntro + fsr + '\n' + str + '\n' + atr;
  } catch (e) {
    fbSections =
      `## Firebase Summary\n` +
      `Could not initialize Firebase Admin SDK. ${e.message}\n` +
      `Ensure: npm i firebase-admin AND provide --credentials or GOOGLE_APPLICATION_CREDENTIALS.\n`;
  }

  // Render Markdown
  if (args.format === 'markdown') {
    const md =
`# Project Snapshot

Generated: ${started.toISOString()}

## Local Project Structure (root: \`${path.resolve(args.dir)}\`)

\`\`\`
${treeText}
\`\`\`

### Key File Previews
${previews.join('\n') || '_No common key files found or previews skipped._'}

${fbSections}

---

_This report is autogenerated by \`generatefullprojectstructure.js\`. You can paste it into ChatGPT so I can understand your project in detail._
`;
    process.stdout.write(md);
  } else {
    // JSON (if needed)
    const jsonOut = {
      generatedAt: started.toISOString(),
      root: path.resolve(args.dir),
      tree,
      previews: Object.fromEntries(await Promise.all(likelyFiles.map(async f => [f, await previewIfExists(args.dir, f)]))),
      firebase: fbSections // already markdown; keep simple
    };
    process.stdout.write(JSON.stringify(jsonOut, null, 2));
  }
})().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});

// ---------- Tiny CLI parser ----------
function parseArgs(argv, schema) {
  const out = {};
  for (const [k, v] of Object.entries(schema)) out[k] = v.default;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    if (!(key in schema)) continue;
    const spec = schema[key];
    if (spec.type === 'boolean') {
      out[key] = true;
    } else {
      const val = argv[i + 1];
      if (val == null) continue;
      i++;
      out[key] = spec.type === 'number' ? Number(val) : val;
    }
  }
  return out;
}
