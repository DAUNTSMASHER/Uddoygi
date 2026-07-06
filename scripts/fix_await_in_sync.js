/**
 * fix_await_in_sync.js
 * Fixes remaining compile errors:
 * 1. `(await DB.col(C.X))` used in non-async methods (build, stream return, etc.)
 *    → Replace with DB.stream(C.X) for stream contexts
 *    → Replace with DB.colSync(_cid, C.X) for query/build contexts
 * 2. `return (await DB.col(...)).snapshots()` → yield* DB.stream(...)
 * 3. `final x = await DB.col(C.X);` in build() → use FutureBuilder or colSync
 * 4. `_countStatus` bad yield* pattern
 * 5. `stream: DB.stream(C.X).orderBy(...)` — DB.stream returns a Stream, not a Query
 *    so we need to use DB.colSync(_cid, C.X).orderBy(...).snapshots()
 */
'use strict';
const fs   = require('fs');
const path = require('path');

const LIB = path.join(process.cwd(), 'lib');
let changed = 0;

function walk(dir, cb) {
  for (const e of fs.readdirSync(dir)) {
    const full = path.join(dir, e);
    if (fs.statSync(full).isDirectory()) walk(full, cb);
    else if (e.endsWith('.dart')) cb(full);
  }
}

function fix(filePath) {
  let src = fs.readFileSync(filePath, 'utf8');
  const orig = src;

  // ── Fix 1: `stream: DB.stream(C.X).orderBy(...)` 
  // DB.stream returns Stream<QuerySnapshot>, not a Query, so .orderBy() is invalid
  // These were incorrectly transformed by the previous script
  // Pattern: DB.stream(C.X).orderBy(...).snapshots()
  // → DB.colSync(_cid, C.X).orderBy(...).snapshots()
  src = src.replace(
    /DB\.stream\(([^)]+)\)((?:\.[a-zA-Z]+\([^)]*\))+)\.snapshots\(\)/g,
    (m, col, chain) => `DB.colSync(_cid, ${col})${chain}.snapshots()`
  );

  // ── Fix 2: `stream: DB.stream(C.X).where(...).snapshots()` same issue
  // Already covered by Fix 1 above

  // ── Fix 3: `yield* DB.stream(C.X, query: (c) => c.someChain.snapshots())`
  // This is invalid — DB.stream doesn't take a query parameter
  // Revert to: yield* DB.colSync(_cid, C.X).someChain.snapshots().map(...)
  src = src.replace(
    /yield\*\s+DB\.stream\(([^,)]+),\s*query:\s*\(c\)\s*=>\s*c((?:\.[a-zA-Z]+\([^)]*\))*\.snapshots\(\))\)/g,
    'yield* DB.colSync(_cid, $1)$2'
  );

  // ── Fix 4: `return (await DB.col(C.X)).snapshots()` in Stream methods
  // → yield* DB.colSync(_cid, C.X).snapshots()
  src = src.replace(
    /return\s+\(await\s+DB\.col\(([^)]+)\)\)((?:\.[a-zA-Z]+\([^)]*\))*\.snapshots\(\))/g,
    'yield* DB.colSync(_cid, $1)$2'
  );

  // ── Fix 5: `return (await DB.col(C.X))` without snapshots (one-shot future)
  // These are in async methods - just remove the outer parens
  src = src.replace(
    /return\s+\(await\s+DB\.col\(([^)]+)\)\)((?:\.[a-zA-Z]+\([^)]*\))*;)/g,
    'return (await DB.col($1))$2'
  );

  // ── Fix 6: `stream: (await DB.col(C.X))` → `stream: DB.colSync(_cid, C.X)`
  src = src.replace(
    /stream:\s*\(await\s+DB\.col\(([^)]+)\)\)/g,
    'stream: DB.colSync(_cid, $1)'
  );

  // ── Fix 7: `final x = await DB.col(C.X);` in build() context
  // These are in build() methods which can't be async
  // Convert to use colSync
  // Pattern: `Query<...> q = (await DB.col(C.X));` or `final x = await DB.col(C.X);`
  src = src.replace(
    /Query<Map<String,\s*dynamic>>\s+(\w+)\s*=\s*\(await\s+DB\.col\(([^)]+)\)\);/g,
    'Query<Map<String, dynamic>> $1 = DB.colSync(_cid, $2);'
  );
  src = src.replace(
    /final\s+(\w+)\s*=\s*await\s+DB\.col\(([^)]+)\);/g,
    'final $1 = DB.colSync(_cid, $2);'
  );

  // ── Fix 8: `_ref = (await DB.col(C.customers)).doc(...)` in initState
  // initState is async-capable via .then(), but `await` in non-async is the issue
  // The initState itself needs to be async or use .then()
  // Pattern: `_ref = (await DB.col(C.X)).doc(...)` in initState
  src = src.replace(
    /_ref\s*=\s*\(await\s+DB\.col\(([^)]+)\)\)\.doc\(([^)]+)\);/g,
    'DB.col($1).then((col) { if (mounted) setState(() => _ref = col.doc($2)); });'
  );

  // ── Fix 9: `(await DB.col(C.X)).doc(id).get()` inside Future.wait
  // These are in async methods - wrap properly
  src = src.replace(
    /\(await\s+DB\.col\(([^)]+)\)\)\.doc\(([^)]+)\)\.get\(\)/g,
    '(await DB.col($1)).doc($2).get()'
  );

  // ── Fix 10: `(await DB.col(C.X)).snapshots()` standalone
  src = src.replace(
    /\(await\s+DB\.col\(([^)]+)\)\)\.snapshots\(\)/g,
    'DB.colSync(_cid, $1).snapshots()'
  );

  // ── Fix 11: `(await DB.col(C.X)).orderBy(...).snapshots()`
  src = src.replace(
    /\(await\s+DB\.col\(([^)]+)\)\)((?:\.[a-zA-Z]+\([^)]*\))+\.snapshots\(\))/g,
    'DB.colSync(_cid, $1)$2'
  );

  // ── Fix 12: `(await DB.col(C.X)).where(...).get()` in async methods - OK, keep
  // These are fine if the enclosing method is async

  // ── Fix 13: `final stocksQ = (await DB.col(C.stocks));` → colSync
  src = src.replace(
    /final\s+(\w+)\s*=\s*\(await\s+DB\.col\(([^)]+)\)\);/g,
    'final $1 = DB.colSync(_cid, $2);'
  );

  // ── Fix 14: `_sumForRange` pattern - `return (await DB.col(...)).where(...).snapshots()`
  // These are in Stream-returning methods
  src = src.replace(
    /return\s+\(await\s+DB\.col\(([^)]+)\)\)\s*\n/g,
    'return DB.colSync(_cid, $1)\n'
  );

  // ── Fix 15: `yield* DB.stream(C.loans, query: ...)` bad pattern
  src = src.replace(
    /yield\*\s+DB\.stream\(([^,)]+),\s*query:[^)]+\)\.map\(/g,
    'yield* DB.colSync(_cid, $1).snapshots().map('
  );

  // ── Fix 16: `DB.stream(C.X).map(...)` - DB.stream already returns Stream<QuerySnapshot>
  // so .map() is valid. But if it was `DB.stream(C.X).where(...)` that's invalid.
  // Fix: `DB.stream(C.X).where(...)` → `DB.colSync(_cid, C.X).where(...).snapshots()`
  src = src.replace(
    /DB\.stream\(([^)]+)\)\.where\(/g,
    'DB.colSync(_cid, $1).where('
  );
  src = src.replace(
    /DB\.stream\(([^)]+)\)\.orderBy\(/g,
    'DB.colSync(_cid, $1).orderBy('
  );

  if (src !== orig) {
    changed++;
    fs.writeFileSync(filePath, src, 'utf8');
    console.log(`  ✔  ${path.relative(process.cwd(), filePath)}`);
  }
}

console.log('\n🔄  Fixing await-in-sync and stream errors...\n');
walk(LIB, fix);
console.log(`\n✅  Done. Updated: ${changed}`);
