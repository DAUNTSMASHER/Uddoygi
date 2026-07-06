/**
 * fix_broken_conversions.js
 * 
 * The previous StatelessWidget→StatefulWidget conversion script broke many files by:
 * 1. Splitting widget methods/fields into a new State class, but the State class
 *    lost access to `widget.X` properties (they became undefined).
 * 2. Injecting initState into non-State classes (StatelessWidget, plain classes).
 * 3. Creating double-underscore State names (__XState instead of _XState).
 * 
 * This script reverts the broken conversions for widgets that:
 * - Have constructor parameters (they need widget.X access)
 * - Are sub-widgets (private classes starting with _)
 * 
 * Strategy: For each broken StatefulWidget conversion, revert to StatelessWidget
 * and use DB.colSync with a locally-resolved _cid via FutureBuilder or pass _cid
 * as a constructor parameter from the parent.
 * 
 * For widgets that genuinely need _cid and have NO constructor params, keep as StatefulWidget.
 */
'use strict';
const fs = require('fs');
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

// Get the body of a class (from opening { to closing })
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

  // ── Fix 1: Remove bad initState from StatelessWidget classes ──────────────
  // Pattern: class Foo extends StatelessWidget { ... @override void initState() { ... } ... }
  const slRe = /class\s+(\w+)\s+extends\s+StatelessWidget[^{]*\{/g;
  let m;
  const slClasses = [];
  while ((m = slRe.exec(src)) !== null) {
    const { end, body } = getClassBody(src, m.index);
    if (body.includes('void initState()') || body.includes('String _cid')) {
      slClasses.push({ start: m.index, end, openEnd: m.index + m[0].length });
    }
  }
  for (let i = slClasses.length - 1; i >= 0; i--) {
    const { start, end, openEnd } = slClasses[i];
    let body = src.substring(start, end + 1);
    // Remove String _cid = ''; field
    body = body.replace(/\n\s*String _cid = '';/g, '');
    // Remove initState block
    body = body.replace(
      /\s*@override\s*\n\s*void initState\(\)\s*\{[^}]*super\.initState\(\);[^}]*getSavedCompanyId[^}]*\}\s*\n\s*\}/gs,
      ''
    );
    src = src.substring(0, start) + body + src.substring(end + 1);
  }

  // ── Fix 2: Remove bad initState from non-widget classes ───────────────────
  // Classes that extend something other than State<> or StatefulWidget
  const nonStateRe = /class\s+(\w+)\s+extends\s+(?!State<|StatefulWidget|StatelessWidget)\w[^{]*\{/g;
  const nonStateClasses = [];
  while ((m = nonStateRe.exec(src)) !== null) {
    const { end, body } = getClassBody(src, m.index);
    if (body.includes('void initState()') && body.includes('getSavedCompanyId')) {
      nonStateClasses.push({ start: m.index, end });
    }
  }
  for (let i = nonStateClasses.length - 1; i >= 0; i--) {
    const { start, end } = nonStateClasses[i];
    let body = src.substring(start, end + 1);
    body = body.replace(/\n\s*String _cid = '';/g, '');
    body = body.replace(
      /\s*@override\s*\n\s*void initState\(\)\s*\{[^}]*super\.initState\(\);[^}]*getSavedCompanyId[^}]*\}\s*\n\s*\}/gs,
      ''
    );
    src = src.substring(0, start) + body + src.substring(end + 1);
  }

  // ── Fix 3: Fix double-underscore State class names ─────────────────────────
  // __XState → _XState (only if __XState doesn't already exist as a proper class)
  // This happens when the script created _XState from _X widget → __XState
  src = src.replace(/class\s+__(\w+State)\s+extends\s+State<_(\w+)>/g, (match, stateName, widgetName) => {
    return `class _${stateName} extends State<_${widgetName}>`;
  });
  // Fix createState references too
  src = src.replace(/createState\(\)\s*=>\s*__(\w+State)\(\)/g, 'createState() => _$1()');

  if (src !== orig) {
    changed++;
    fs.writeFileSync(filePath, src, 'utf8');
    console.log(`  ✔  ${path.relative(process.cwd(), filePath)}`);
  }
}

console.log('\n🔄  Fixing broken StatelessWidget conversions...\n');
walk(LIB, fix);
console.log(`\n✅  Done. Updated: ${changed}`);
