'use strict';
const fs = require('fs');
const f = 'lib/features/factory/presentation/factory/purchase_order.dart';
let src = fs.readFileSync(f, 'utf8');

// Fix Bengali text in the card display
src = src.replace("Text('\u09b8\u09b0\u09ac\u09b0\u09be\u09b9\u0995\u09be\u09b0\u09c0: $supplier')", "Text('Supplier: \$supplier')");
src = src.replace("Text('\u099c\u09ae\u09be\u09a6\u09be\u09a8\u0995\u09be\u09b0\u09c0: $submittedBy')", "Text('Submitted by: \$submittedBy')");
src = src.replace("Text('\u09aa\u09cd\u09b0\u09a4\u09cd\u09af\u09be\u09b6\u09bf\u09a4 \u09a4\u09be\u09b0\u09bf\u0996: $expected')", "Text('Expected: \$expected')");
src = src.replace("Text('\u0986\u0987\u099f\u09c7\u09ae \u09b8\u0982\u0996\u09cd\u09af\u09be: ${items.length}')", "Text('Items: \${items.length}')");
src = src.replace("label: const Text('\u0997\u09cd\u09b0\u09b9\u09a3 \u0995\u09b0\u09c1\u09a8')", "label: const Text('Accept')");
src = src.replace("label: const Text('\u09ac\u09be\u09a4\u09bf\u09b2 \u0995\u09b0\u09c1\u09a8')", "label: const Text('Reject')");

// Fix remaining Bengali text in status display area
src = src.replace(/'\u09b8\u09cd\u099f\u09cd\u09af\u09be\u099f\u09be\u09b8: /g, "'Status: ");

fs.writeFileSync(f, src, 'utf8');
console.log('Done');
