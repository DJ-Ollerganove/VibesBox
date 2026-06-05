// Aus Projektroot: dart run tool/strip_app_icon_alpha.dart [eingabe.png [ausgabe.png]]
// Flacht RGBA auf opakes RGB (weißer Hintergrund) — App Store verlangt kein Alpha beim 1024-Marketing-Icon.
import 'dart:io';

import 'package:image/image.dart';

void main(List<String> args) {
  final inPath = args.isNotEmpty
      ? args[0]
      : 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png';
  final outPath = args.length > 1 ? args[1] : inPath;

  final inputFile = File(inPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Datei fehlt: $inPath');
    exit(1);
  }

  final src = decodeImage(inputFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('PNG konnte nicht decodiert werden: $inPath');
    exit(1);
  }

  if (!src.hasAlpha) {
    stdout.writeln('Kein Alpha-Kanal — unverändert: $inPath');
    if (outPath != inPath) {
      File(outPath).writeAsBytesSync(inputFile.readAsBytesSync());
    }
    return;
  }

  final dst = Image(width: src.width, height: src.height, numChannels: 3);
  fill(dst, color: ColorRgb8(255, 255, 255));
  compositeImage(dst, src);

  File(outPath).writeAsBytesSync(encodePng(dst));
  stdout.writeln('Opakes RGB-PNG geschrieben: $outPath (${src.width}x${src.height})');
}
