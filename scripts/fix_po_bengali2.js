'use strict';
const fs = require('fs');
const f = 'lib/features/factory/presentation/factory/purchase_order.dart';
let src = fs.readFileSync(f, 'utf8');

// Fix remaining Bengali strings
const replacements = [
  ['\u0985\u09ac\u09b8\u09cd\u09a5\u09be: ${status == \'accepted\' ? \'\u0997\u09c3\u09b9\u09c0\u09a4\' : \'\u09ac\u09be\u09a4\u09bf\u09b2\'}',
   'Status: ${status == \'accepted\' ? \'Accepted\' : \'Rejected\'}'],
  ['\ud83d\uded2 \u09aa\u09a3\u09cd\u09af\u09c7\u09b0 \u09ae\u09c2\u09b2\u09cd\u09af \u098f\u09a8\u09cd\u099f\u09cd\u09b0\u09bf', 'Product Price Entry'],
  ['\u0987\u09a8\u09ad\u09af\u09bc\u09c7\u09b8 \u09a8\u09ae\u09cd\u09ac\u09b0', 'Invoice Number'],
  ['\u098f\u099c\u09c7\u09a8\u09cd\u099f\u09c7\u09b0 \u09a8\u09be\u09ae', 'Agent Name'],
  ['\u09aa\u09a3\u09cd\u09af\u09c7\u09b0 \u09a8\u09be\u09ae', 'Product Name'],
  ['\u09ae\u09c2\u09b2\u09cd\u09af', 'Price'],
  ['\u09aa\u09b0\u09bf\u09ae\u09be\u09a3', 'Quantity'],
  ['\u09b8\u09b0\u09ac\u09b0\u09be\u09b9\u0995\u09be\u09b0\u09c0', 'Supplier'],
  ['\u09b8\u0982\u09b0\u0995\u09cd\u09b7\u09a3 \u0995\u09b0\u09c1\u09a8', 'Save'],
  ['\u0995\u09cd\u09b0\u09af\u09bc \u09ac\u09bf\u09ac\u09b0\u09a3 \u09af\u09cb\u0997 \u0995\u09b0\u09c1\u09a8', 'Add Purchase Details'],
];

replacements.forEach(([from, to]) => {
  if (src.includes(from)) {
    src = src.split(from).join(to);
    console.log('Replaced:', from.substring(0, 20), '...');
  }
});

fs.writeFileSync(f, src, 'utf8');
console.log('Done');
