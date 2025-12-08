import 'package:flutter/widgets.dart';

class Responsive {
  const Responsive._();

  static double width(BuildContext context) => MediaQuery.of(context).size.width;

  static bool isMobile(BuildContext context) => width(context) < 720;

  static bool isTablet(BuildContext context) {
    final w = width(context);
    return w >= 720 && w < 1080;
  }

  static bool isDesktop(BuildContext context) => width(context) >= 1080;

  static EdgeInsets horizontalPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 48);
    }
    if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32);
    }
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  static double cardWidth(BuildContext context, {int columns = 2, double spacing = 16}) {
    if (!isDesktop(context)) return double.infinity;
    final totalWidth = width(context) - horizontalPadding(context).horizontal;
    return (totalWidth - (columns - 1) * spacing) / columns;
  }
}
