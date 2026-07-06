/**
 * fix_stateless_cid.js
 * Converts StatelessWidgets that use _cid into StatefulWidgets.
 * Also fixes State classes that use _cid but don't have the field.
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

function getClassBody(src, classStart) {
  let depth = 0, end = classStart;
  for (let j = classStart; j < src.length; j++) {
    if (src[j] === '{') depth++;
    else if (src[j] === '}') {
      depth--;
      if (depth === 0) { end = j; break; }
    }
  }
  return { end, body: src.substring(classStart, end + 1) };
}

function fix(filePath) {
  let src = fs.readFileSync(filePath, 'utf8');
  const orig = src;

  // Find all StatelessWidget classes that use _cid
  const classRe = /class\s+(\w+)\s+extends\s+StatelessWidget(?:\s+with\s+[^{]+)?\s*\{/g;
  let match;
  const toConvert = [];
  
  while ((match = classRe.exec(src)) !== null) {
    const { end, body } = getClassBody(src, match.index);
    if (body.includes('_cid')) {
      toConvert.push({ name: match[1], start: match.index, end, fullMatch: match[0] });
    }
  }

  if (toConvert.length === 0) return;

  // Process in reverse order to preserve positions
  for (let i = toConvert.length - 1; i >= 0; i--) {
    const { name, start, end, fullMatch } = toConvert[i];
    const stateName = `_${name}State`;
    const body = src.substring(start, end + 1);

    // Check if a State class already exists for this widget
    if (src.includes(`class ${stateName} extends State<${name}>`)) {
      // State class exists but _cid might be missing in it
      // Handle separately below
      continue;
    }

    // Extract the build method from the StatelessWidget
    // Replace: class Foo extends StatelessWidget { ... @override Widget build(...) { ... } }
    // With: class Foo extends StatefulWidget { ... @override State<Foo> createState() => _FooState(); }
    //        class _FooState extends State<Foo> { String _cid = ''; @override void initState() { ... } @override Widget build(...) { ... } }

    // Find the build method start in the body
    const buildMatch = /(@override\s+Widget\s+build\s*\(BuildContext\s+\w+\)\s*\{)/.exec(body);
    if (!buildMatch) continue;

    // Find const constructor
    const constCtorRe = new RegExp(`const\\s+${name}\\s*\\(`);
    
    // Build the new classes
    // 1. Extract fields/constructors before build
    const beforeBuild = body.substring(body.indexOf('{') + 1, body.indexOf(buildMatch[0]));
    // 2. Extract build method content
    const buildStart = body.indexOf(buildMatch[0]);
    const buildBodyStart = buildStart + buildMatch[0].length;
    // Find matching } for build
    let depth = 1, buildEnd = buildBodyStart;
    for (let j = buildBodyStart; j < body.length; j++) {
      if (body[j] === '{') depth++;
      else if (body[j] === '}') {
        depth--;
        if (depth === 0) { buildEnd = j; break; }
      }
    }
    const buildBody = body.substring(buildBodyStart, buildEnd);
    // 3. Extract anything after build
    const afterBuild = body.substring(buildEnd + 1, body.length - 1).trim();

    // Build replacement
    const newStatefulClass = `class ${name} extends StatefulWidget {
${beforeBuild.trimEnd()}
  @override
  State<${name}> createState() => ${stateName}();
}

class ${stateName} extends State<${name}> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {${buildBody}}${afterBuild ? '\n\n  ' + afterBuild.split('\n').join('\n  ') : ''}
}`;

    src = src.substring(0, start) + newStatefulClass + src.substring(end + 1);
  }

  // Now fix State classes that use _cid but don't have it defined
  const stateRe = /class\s+(\w+)\s+extends\s+State<[^>]+>(?:\s+with\s+[^{]+)?\s*\{/g;
  let sm;
  const stateClasses = [];
  while ((sm = stateRe.exec(src)) !== null) {
    const { end, body } = getClassBody(src, sm.index);
    if (body.includes('_cid') && !/String\s+_cid\s*=/.test(body)) {
      stateClasses.push({ name: sm[1], start: sm.index, end, openEnd: sm.index + sm[0].length });
    }
  }

  for (let i = stateClasses.length - 1; i >= 0; i--) {
    const { openEnd, start, end } = stateClasses[i];
    const body = src.substring(start, end + 1);
    
    const cidField = '\n  String _cid = \'\';';
    const hasInitState = body.includes('void initState()');
    
    if (hasInitState) {
      // Just add the field
      src = src.substring(0, openEnd) + cidField + src.substring(openEnd);
      // Also add the loader to initState
      const bodyNew = src.substring(start, end + cidField.length + 1);
      const initM = /void initState\(\)\s*\{[^}]*super\.initState\(\);/.exec(bodyNew);
      if (initM) {
        const absPos = start + initM.index + initM[0].length;
        const after = src.substring(absPos, absPos + 200);
        if (!after.includes('getSavedCompanyId')) {
          const loader = `\n    LocalStorageService.getSavedCompanyId().then((id) {\n      if (mounted) setState(() => _cid = id ?? '');\n    });`;
          src = src.substring(0, absPos) + loader + src.substring(absPos);
        }
      }
    } else {
      const initBlock = `${cidField}\n\n  @override\n  void initState() {\n    super.initState();\n    LocalStorageService.getSavedCompanyId().then((id) {\n      if (mounted) setState(() => _cid = id ?? '');\n    });\n  }`;
      src = src.substring(0, openEnd) + initBlock + src.substring(openEnd);
    }
  }

  // Ensure LocalStorageService is imported
  if (src.includes('_cid') && !src.includes('local_storage_service.dart')) {
    src = src.replace(
      /import 'package:uddoygi\/services\/db\.dart';/,
      `import 'package:uddoygi/services/db.dart';\nimport 'package:uddoygi/services/local_storage_service.dart';`
    );
  }

  if (src !== orig) {
    changed++;
    fs.writeFileSync(filePath, src, 'utf8');
    console.log(`  ✔  ${path.relative(process.cwd(), filePath)}`);
  }
}

console.log('\n🔄  Converting StatelessWidgets with _cid to StatefulWidgets...\n');
walk(LIB, fix);
console.log(`\n✅  Done. Updated: ${changed}`);
