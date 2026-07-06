'use strict';
/**
 * The fix_widget_props.js script incorrectly replaced named argument labels
 * like `noticeId: value` with `widget.noticeId: value` (invalid Dart syntax).
 * 
 * This script fixes: `widget.X: ` → `X: ` in named argument positions
 * but keeps `widget.X` in value positions.
 */
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

walk(LIB, (filePath) => {
  let src = fs.readFileSync(filePath, 'utf8');
  const orig = src;

  // Fix: `widget.X:` in named argument position → `X:`
  // Pattern: widget.propName: (where propName is a valid identifier)
  src = src.replace(/\bwidget\.(\w+):\s/g, '$1: ');
  
  // Fix: `widget.onTap:` specifically (common InkWell pattern)
  // Already covered above

  if (src !== orig) {
    changed++;
    fs.writeFileSync(filePath, src, 'utf8');
    console.log('  ✔  ' + path.relative(process.cwd(), filePath));
  }
});

console.log(`\n✅  Fixed ${changed} files.`);
