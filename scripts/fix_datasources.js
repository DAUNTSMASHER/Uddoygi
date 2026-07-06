'use strict';
const fs = require('fs');
const path = require('path');

const DS_DIR = path.join(process.cwd(), 'lib', 'features', 'hr', 'data', 'datasources');
let changed = 0;

for (const file of fs.readdirSync(DS_DIR)) {
  if (!file.endsWith('.dart')) continue;
  const filePath = path.join(DS_DIR, file);
  let src = fs.readFileSync(filePath, 'utf8');
  const orig = src;

  // Add LocalStorageService import if missing
  if (src.includes('_cid') && !src.includes('local_storage_service')) {
    src = src.replace(
      "import 'package:uddoygi/services/db.dart';",
      "import 'package:uddoygi/services/db.dart';\nimport 'package:uddoygi/services/local_storage_service.dart';"
    );
  }

  // Replace DB.colSync(_cid, C.X) with DB.colSync(await LocalStorageService.getSavedCompanyId() ?? '', C.X)
  // But only in async methods
  // Strategy: replace _cid with a local variable resolution
  // First, find all methods that use _cid and make them async if not already
  
  // Replace DB.colSync(_cid, in async methods - add local _cid resolution
  // Simple approach: replace every occurrence of DB.colSync(_cid, with a helper
  
  // Add a helper getter to the class
  if (src.includes('DB.colSync(_cid,') || src.includes('DB.stream(C.')) {
    // Add _cid() helper method to the class
    const classMatch = src.match(/class\s+\w+\s*\{/);
    if (classMatch) {
      const insertPos = src.indexOf(classMatch[0]) + classMatch[0].length;
      const helper = `
  Future<String> _getCid() => LocalStorageService.getSavedCompanyId().then((v) => v ?? '');
`;
      if (!src.includes('_getCid()')) {
        src = src.substring(0, insertPos) + helper + src.substring(insertPos);
      }
    }
    
    // Now replace DB.colSync(_cid, C.X) in async methods
    // We need to add: final _cid = await _getCid(); before usage
    // Simple: replace method bodies that use _cid
    src = src.replace(
      /(\basync\s*\{)([^}]*?)DB\.colSync\(_cid,/gs,
      (match, asyncOpen, before) => {
        if (before.includes('final _cid =')) return match;
        return `${asyncOpen}\n    final _cid = await _getCid();${before}DB.colSync(_cid,`;
      }
    );
    
    // Fix DB.stream(C.X) - replace with a stream that resolves _cid
    src = src.replace(
      /Stream<QuerySnapshot>\s+\w+\([^)]*\)\s*=>\s*DB\.stream\(([^)]+)\);/g,
      (match, col) => {
        const methodName = match.match(/(\w+)\(/)[1];
        return `Stream<QuerySnapshot> ${methodName}() async* {
    final cid = await _getCid();
    yield* DB.colSync(cid, ${col}).snapshots();
  }`;
      }
    );
  }

  if (src !== orig) {
    changed++;
    fs.writeFileSync(filePath, src, 'utf8');
    console.log('  ✔  ' + file);
  }
}

console.log(`\n✅  Fixed ${changed} data sources.`);
