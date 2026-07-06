/**
 * fix_cid_injection.js
 * Fixes all _cid-related compile errors by:
 * 1. Injecting `String _cid = '';` + initState loader into EVERY State<> class
 *    that uses _cid but doesn't have it defined.
 * 2. Replacing `(await DB.col(C.X))` in non-async contexts with DB.stream(C.X)
 *    or async* wrappers.
 * 3. Removing bad initState injections into non-State classes (_MetricCard etc.)
 */
'use strict';
const fs   = require('fs');
const path = require('path');

const DRY = process.argv.includes('--dry-run');
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

  // ── 1. Remove bad initState injected into non-State classes ──────────────
  // Pattern: class _XxxCard / _XxxWidget / _Xxx extends StatelessWidget
  // that got initState injected. Detect by: class extends something that is NOT State<>
  // We look for the injected block inside a class that extends something other than State<>
  // The injected block looks like:
  //   String _cid = '';
  // inside a class that extends StatelessWidget / _MetricCard etc.
  
  // Strategy: find all class bodies, check if they extend State<>, if not remove _cid field + initState block
  src = src.replace(
    /(class\s+\w+\s+extends\s+(?!State<)\w[^{]*\{)\s*\n\s*String _cid = '';/g,
    '$1'
  );
  
  // Remove injected initState block from non-State classes
  // The injected block is:
  //   @override
  //   void initState() {
  //     super.initState();
  //     LocalStorageService.getSavedCompanyId().then((id) {
  //       if (mounted) setState(() => _cid = id ?? '');
  //     });
  //   }
  // But only when it's inside a class that doesn't extend State<>
  // Simpler: remove it from classes that extend StatelessWidget
  src = src.replace(
    /(class\s+\w+\s+extends\s+StatelessWidget[^{]*\{[^}]*?)(\s*@override\s*\n\s*void initState\(\)\s*\{\s*\n\s*super\.initState\(\);\s*\n\s*LocalStorageService\.getSavedCompanyId\(\)\.then\(\(id\)\s*\{\s*\n\s*if\s*\(mounted\)\s*setState\(\(\)\s*=>\s*_cid\s*=\s*id\s*\?\?\s*''\);\s*\n\s*\}\);\s*\n\s*\})/gs,
    '$1'
  );

  // ── 2. Inject _cid into EVERY State<> class that uses _cid but lacks it ──
  // Find all "class _XState extends State<" blocks
  // For each, check if it uses _cid and if it has String _cid defined
  
  // Split into class segments to process individually
  // We use a regex to find each State class opening
  const stateClassRe = /class\s+(\w+)\s+extends\s+State<[^>]+>(?:\s+with\s+[^{]+)?\s*\{/g;
  let match;
  const classPositions = [];
  while ((match = stateClassRe.exec(src)) !== null) {
    classPositions.push({ name: match[1], start: match.index, end: match.index + match[0].length });
  }

  // Process in reverse order to not mess up positions
  for (let i = classPositions.length - 1; i >= 0; i--) {
    const cp = classPositions[i];
    // Find the end of this class by counting braces
    let depth = 0;
    let classEnd = cp.start;
    for (let j = cp.start; j < src.length; j++) {
      if (src[j] === '{') depth++;
      else if (src[j] === '}') {
        depth--;
        if (depth === 0) { classEnd = j; break; }
      }
    }
    const classBody = src.substring(cp.start, classEnd + 1);
    
    // Check if this class uses _cid
    if (!classBody.includes('_cid')) continue;
    
    // Check if _cid is already defined in this class
    if (/String\s+_cid\s*=/.test(classBody)) continue;
    
    // Need to inject _cid field + initState loader
    const insertAfter = cp.end; // right after the opening {
    
    const cidField = `\n  String _cid = '';`;
    
    // Check if initState already exists in this class
    const hasInitState = classBody.includes('void initState()');
    
    let injection = cidField;
    
    if (hasInitState) {
      // Just add the field; patch initState separately
      src = src.substring(0, insertAfter) + cidField + src.substring(insertAfter);
      
      // Now patch the initState in this class to add the _cid loader
      // Find the initState within this class
      const classBodyNew = src.substring(cp.start, classEnd + cidField.length + 1);
      const initStateMatch = /void initState\(\)\s*\{[^}]*super\.initState\(\);/.exec(classBodyNew);
      if (initStateMatch) {
        const absPos = cp.start + initStateMatch.index + initStateMatch[0].length;
        const loader = `\n    LocalStorageService.getSavedCompanyId().then((id) {\n      if (mounted) setState(() => _cid = id ?? '');\n    });`;
        // Only add if not already there
        const after = src.substring(absPos, absPos + 200);
        if (!after.includes('getSavedCompanyId')) {
          src = src.substring(0, absPos) + loader + src.substring(absPos);
        }
      }
    } else {
      // No initState — inject both field and initState
      const initStateBlock = `\n  @override\n  void initState() {\n    super.initState();\n    LocalStorageService.getSavedCompanyId().then((id) {\n      if (mounted) setState(() => _cid = id ?? '');\n    });\n  }`;
      injection = cidField + initStateBlock;
      src = src.substring(0, insertAfter) + injection + src.substring(insertAfter);
    }
  }

  // ── 3. Fix `(await DB.col(C.X))` in non-async contexts ───────────────────
  // Pattern: `stream: (await DB.col(C.X))` → `stream: DB.stream(C.X)`
  src = src.replace(
    /stream:\s*\(await\s+DB\.col\(([^)]+)\)\)/g,
    'stream: DB.stream($1)'
  );
  
  // Pattern: `return (await DB.col(C.X))` in non-async method → use async*
  // For simple cases: `return (await DB.col(C.X)).snapshots()` 
  // → wrap the method as async* and yield*
  // But this is complex; simpler: change the method to async and use await
  // Actually the safest fix for `return (await DB.col(C.X)).snapshots()` is:
  // Change the method signature to `async*` and `yield*`
  src = src.replace(
    /return\s+\(await\s+DB\.col\(([^)]+)\)\)\.snapshots\(\)/g,
    'yield* DB.stream($1)'
  );
  
  // For `return (await DB.col(C.X)).where(...).snapshots()` patterns
  src = src.replace(
    /return\s+\(await\s+DB\.col\(([^)]+)\)\)((?:\.[a-zA-Z]+\([^)]*\))*\.snapshots\(\))/g,
    'yield* DB.stream($1, query: (c) => c$2)'
  );

  // Pattern: `final x = (await DB.col(C.X));` in non-async → make async
  // These are harder — need to make the enclosing method async
  // For now, replace with DB.stream and use .first for one-shot reads
  
  // `final base = (await DB.col(C.X));` in a non-async build/stream method
  // → We need to make the method async. But since these are often in build()
  // which can't be async, we need a different approach.
  // Best fix: use FutureBuilder or change to use DB.stream
  
  // For `stream:` context already handled above.
  // For `final x = (await DB.col(C.X));` in a Widget build context:
  // Change to use a FutureBuilder or store in state.
  // For now, mark these as needing manual fix by converting to async method.
  
  // Simple cases: `final x = (await DB.col(C.X));` followed by `.snapshots()`
  src = src.replace(
    /final\s+(\w+)\s*=\s*\(await\s+DB\.col\(([^)]+)\)\);/g,
    'final $1 = await DB.col($2);'
  );

  // ── 4. Fix `_db` references → `DB.firestore` ─────────────────────────────
  src = src.replace(/\b_db\.batch\(\)/g, 'DB.firestore.batch()');
  src = src.replace(/\b_db\.collectionGroup\(/g, 'DB.firestore.collectionGroup(');
  src = src.replace(/\b_firestore\.batch\(\)/g, 'DB.firestore.batch()');
  src = src.replace(/\b_firestore\.collectionGroup\(/g, 'DB.firestore.collectionGroup(');

  // ── 5. Fix LoanRequestScreen const constructor issue ─────────────────────
  // `const LoanRequestScreen()` → `LoanRequestScreen()` (remove const)
  src = src.replace(/\bconst\s+LoanRequestScreen\(\)/g, 'LoanRequestScreen()');
  src = src.replace(/\bconst\s+QCReportScreen\(\)/g, 'QCReportScreen()');
  src = src.replace(/\bconst\s+MarketingQCReportScreen\(\)/g, 'MarketingQCReportScreen()');

  // ── 6. Ensure LocalStorageService is imported where _cid was injected ─────
  if (src.includes('_cid') && !src.includes('local_storage_service.dart')) {
    src = src.replace(
      /import 'package:uddoygi\/services\/db\.dart';/,
      `import 'package:uddoygi/services/db.dart';\nimport 'package:uddoygi/services/local_storage_service.dart';`
    );
  }

  if (src !== orig) {
    changed++;
    const rel = path.relative(process.cwd(), filePath);
    if (DRY) {
      console.log(`  [DRY] ${rel}`);
    } else {
      fs.writeFileSync(filePath, src, 'utf8');
      console.log(`  ✔  ${rel}`);
    }
  }
}

console.log(DRY ? '\n⚠️  DRY RUN\n' : '\n🔄  Fixing _cid injection errors...\n');
walk(LIB, fix);
console.log(`\n✅  Done. Updated: ${changed}`);
