import 'package:flutter/widgets.dart';

class Responsive {
  static double width(BuildContext context) => MediaQuery.of(context).size.width;
  static double height(BuildContext context) => MediaQuery.of(context).size.height;
  
  // Scale a value based on screen width, with an optional clamp to prevent it from getting too big on tablets
  // Standard app style: let Flutter handle logical pixel scaling naturally
  static double scale(BuildContext context, double value, {double maxMultiplier = 1.3}) {
    return value; // No artificial multiplier
  }
  
  static double font(BuildContext context, double size) {
    return size; // No artificial multiplier
  }
}
