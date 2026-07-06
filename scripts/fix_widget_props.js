'use strict';
/**
 * For every StatefulWidget that has constructor parameters,
 * find its State class and fix bare property references to use widget.X
 * 
 * Pattern: class Foo extends StatefulWidget { final T bar; ... }
 * State class uses `bar` directly → should be `widget.bar`
 */
const fs = require('fs');
const path = require('path');
const LIB = path.join(process.cwd(), 'lib');
let totalChanged = 0;

function walk(dir, cb) {
  for (const e of fs.readdirSync(dir)) {
    const full = path.join(dir, e);
    if (fs.statSync(full).isDirectory()) walk(full, cb);
    else if (e.endsWith('.dart')) cb(full);
  }
}

function getClassEnd(src, classStart) {
  let depth = 0;
  for (let j = classStart; j < src.length; j++) {
    if (src[j] === '{') depth++;
    else if (src[j] === '}') {
      depth--;
      if (depth === 0) return j;
    }
  }
  return src.length - 1;
}

walk(LIB, (filePath) => {
  let src = fs.readFileSync(filePath, 'utf8');
  const orig = src;

  // Find all StatefulWidget classes with final fields
  const widgetRe = /class\s+(\w+)\s+extends\s+StatefulWidget\s*\{/g;
  let wm;
  while ((wm = widgetRe.exec(src)) !== null) {
    const widgetName = wm[1];
    const widgetEnd = getClassEnd(src, wm.index);
    const widgetBody = src.substring(wm.index, widgetEnd + 1);

    // Extract final field names
    const fieldRe = /\bfinal\s+\w+\??\s+(\w+);/g;
    const fields = [];
    let fm;
    while ((fm = fieldRe.exec(widgetBody)) !== null) {
      const name = fm[1];
      // Skip common widget fields that are not constructor params
      if (['key'].includes(name)) continue;
      fields.push(name);
    }
    if (fields.length === 0) continue;

    // Find the State class
    const stateRe = new RegExp(`class\\s+(\\w+)\\s+extends\\s+State<${widgetName}>\\s*\\{`);
    const sm = stateRe.exec(src);
    if (!sm) continue;

    const stateStart = sm.index;
    const stateEnd = getClassEnd(src, stateStart);
    let stateBody = src.substring(stateStart, stateEnd + 1);
    const origStateBody = stateBody;

    for (const field of fields) {
      // Replace bare `field` (not widget.field, not this.field, not final field, not String field, etc.)
      // Use negative lookbehind for widget., this., final , type declarations
      const re = new RegExp(
        `(?<![\\w.])(?<!widget\\.)(?<!this\\.)(?<!final\\s)(?<!\\w\\s)\\b${field}\\b(?!\\s*[=:])`,
        'g'
      );
      // More conservative: only replace when preceded by space, (, [, ,, =, !, ?, :, {, \n
      const safeRe = new RegExp(
        `(?<=[\\s(\\[,=!?:{\\n])${field}(?=[\\s.),\\]!?;:\\n])`,
        'g'
      );
      
      // Check if field is already declared in state body (String _cid, etc.)
      const fieldDeclRe = new RegExp(`\\bfinal\\s+\\w+\\??\\s+${field}\\s*[=;]|\\w+\\s+${field}\\s*=`);
      if (fieldDeclRe.test(stateBody)) continue;

      // Replace bare field references
      stateBody = stateBody.replace(safeRe, `widget.${field}`);
      // Fix double widget.widget.
      stateBody = stateBody.replace(new RegExp(`widget\\.widget\\.${field}`, 'g'), `widget.${field}`);
    }

    if (stateBody !== origStateBody) {
      src = src.substring(0, stateStart) + stateBody + src.substring(stateEnd + 1);
    }
  }

  if (src !== orig) {
    totalChanged++;
    fs.writeFileSync(filePath, src, 'utf8');
    console.log('  ✔  ' + path.relative(process.cwd(), filePath));
  }
});

console.log(`\n✅  Fixed ${totalChanged} files.`);
