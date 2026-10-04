import 'package:flutter/widgets.dart';

/// Popover anchor for the system share sheet, which iPad requires: the
/// global rect of the widget that triggered the share. Anchoring to a whole
/// screen leaves the popover no room, so UIKit squeezes it against an edge.
Rect shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  return box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : const Rect.fromLTWH(0, 0, 1, 1);
}
