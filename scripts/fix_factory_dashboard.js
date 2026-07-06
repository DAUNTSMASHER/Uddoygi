'use strict';
const fs = require('fs');
const f = 'lib/features/factory/presentation/screens/factory_dashboard.dart';
let src = fs.readFileSync(f, 'utf8');

// Fix Bengali KPI labels in stat cards
src = src.replace("label: '\u0989\u09aa\u09b8\u09cd\u09a5\u09bf\u09a4\u09bf (\u0986\u099c)'", "label: 'Attendance (Today)'");
src = src.replace("label: '\u09b8\u09ae\u09cd\u09aa\u09a8\u09cd\u09a8 \u0985\u09b0\u09cd\u09a1\u09be\u09b0'", "label: 'Completed Orders'");
src = src.replace("label: '\u099a\u09b2\u09ae\u09be\u09a8 \u0985\u09b0\u09cd\u09a1\u09be\u09b0'", "label: 'Running Orders'");
src = src.replace("label: '\u098f \u09ae\u09be\u09b8\u09c7\u09b0 \u0989\u09ce\u09aa\u09be\u09a6\u09a8'", "label: 'Monthly Output'");
src = src.replace("label: '\u09ac\u0995\u09c7\u09af\u09bc\u09be \u098b\u09a3'", "label: 'Due Loans'");
src = src.replace("label: '\u0997\u09dc \u09b8\u09ae\u09cd\u09aa\u09a8\u09cd\u09a8\u09c7\u09b0 \u09b8\u09ae\u09af\u09bc'", "label: 'Avg Lead Time'");

// Fix _RangeFilter - replace empty container with working dropdown
src = src.replace(
  `class _RangeFilter extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangeFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(

    );
  }
}`,
  `class _RangeFilter extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangeFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white70),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Range>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: _brandRed),
          dropdownColor: Colors.white,
          style: const TextStyle(color: _brandRed, fontWeight: FontWeight.w700, fontSize: 12),
          items: const [
            DropdownMenuItem(value: _Range.thisMonth, child: Text('This month')),
            DropdownMenuItem(value: _Range.prevMonth, child: Text('Prev month')),
            DropdownMenuItem(value: _Range.last3,     child: Text('Last 3 months')),
            DropdownMenuItem(value: _Range.last12,    child: Text('One year')),
          ],
          onChanged: (r) {
            if (r != null) onChanged(r);
          },
        ),
      ),
    );
  }
}`
);

// Fix _StatCardRed value font size 26 -> 20
src = src.replace(
  `                      style: const TextStyle(
                        color: _brandRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),`,
  `                      style: const TextStyle(
                        color: _brandRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),`
);

// Fix _StatCardRed label font size 5-7 -> 9-12
src = src.replace(
  `                    minFontSize: 5,
                    maxFontSize: 7,      // lock to 5sp`,
  `                    minFontSize: 9,
                    maxFontSize: 12,`
);
src = src.replace(
  `                        fontWeight: FontWeight.w500,
                          fontSize: 7,        // lock to 5sp`,
  `                        fontWeight: FontWeight.w600,
                          fontSize: 12,`
);
// Remove the height: 1.05 line that was paired with the old tiny font
src = src.replace(`                          height: 1.05,\n`, '');

// Fix _StatCardPercent value font size 26 -> 20
src = src.replace(
  `                          style: const TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),`,
  `                          style: const TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),`
);

// Fix _StatCardPercent label font size 8 -> 12
src = src.replace(
  `                          style: const TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.w400,
                            fontSize: 8,
                          ),`,
  `                          style: const TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),`
);

// Fix _StatCardPercent minFontSize 6 -> 9
src = src.replace(
  `                  minFontSize: 6,
                  stepGranularity: 0.5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _brandRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,`,
  `                  minFontSize: 9,
                  stepGranularity: 0.5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _brandRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,`
);

// Remove flutter_animate import (no longer needed)
// Keep it since it might be used elsewhere - just leave it

fs.writeFileSync(f, src, 'utf8');
console.log('Factory dashboard fixed successfully');
