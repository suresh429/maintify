import 'package:flutter/material.dart';

/// Centers and constrains content width for authenticated web screens.
///
/// Usage inside a [SingleChildScrollView]:
/// ```dart
/// SingleChildScrollView(
///   child: WebPageContainer(
///     child: Column(children: [...]),
///   ),
/// )
/// ```
class WebPageContainer extends StatelessWidget {
  final Widget child;

  /// Maximum content width. Defaults to 960 (good for dashboards/forms).
  /// Use 1100+ for list/table screens.
  final double maxWidth;

  /// Inner padding. Defaults to 24px all sides.
  final EdgeInsets? padding;

  const WebPageContainer({
    super.key,
    required this.child,
    this.maxWidth = 960,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}
