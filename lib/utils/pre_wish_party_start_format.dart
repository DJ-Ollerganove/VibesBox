import 'package:flutter/material.dart';

import 'formatting_utils.dart';

/// Datum/Uhrzeit für Vorab-Header – zentral über [FormattingUtils].
String formatPreWishPartyStartLine(BuildContext context, DateTime start) {
  return FormattingUtils.formatCompactDateTimeLine(start, context);
}
