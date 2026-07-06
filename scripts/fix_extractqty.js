'use strict';
const fs = require('fs');
const f = 'lib/features/marketing/presentation/widgets/customer_order_summary.dart';
let src = fs.readFileSync(f, 'utf8');

// Fix fold<int> with _extractQty - cast to int
src = src.replace(
  /items\.fold<int>\(0,\s*\(sum,\s*item\)\s*=>\s*sum\s*\+\s*_extractQty\(item\['qty'\]\)\)/g,
  "items.fold<int>(0, (sum, item) => sum + _extractQty(item['qty']))"
);

// Ensure _extractQty always returns int by adding .toInt() where needed
// The issue is sum + _extractQty might produce num if sum is num
// Fix: use explicit int cast
src = src.replace(
  /items\.fold<int>\(0,\s*\(sum,\s*item\)\s*=>\s*sum\s*\+\s*_extractQty\(item\['qty'\]\)\)/g,
  "items.fold<int>(0, (sum, item) => (sum + _extractQty(item['qty'])).toInt())"
);

fs.writeFileSync(f, src, 'utf8');
console.log('Fixed _extractQty fold');
