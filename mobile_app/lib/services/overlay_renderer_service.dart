import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/broadcast_config.dart';

class OverlayRendererService {
  /// Loads an image from the Flutter asset bundle as a ui.Image
  static Future<ui.Image> _loadAssetImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  /// Generates the high-fidelity transparent broadcast overlay PNG
  /// using the master web broadcast plate + Flutter's HarfBuzz Devanagari text engine.
  static Future<String> generateOverlay({
    required BroadcastConfig config,
    required int targetWidth,
    required int targetHeight,
  }) async {
    final isVertical = targetHeight > targetWidth;
    final plateAsset = isVertical
        ? 'assets/master_broadcast_plate_portrait.png'
        : 'assets/master_broadcast_plate.png';

    final ui.Image plate = await _loadAssetImage(plateAsset);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
    );

    final double scaleX = targetWidth / 1920.0;
    final double scaleY = targetHeight / 1080.0;

    // 1. Draw the master broadcast plate with 100% web design (3D chevrons, 3 cards, banner, logo)
    final srcRect = ui.Rect.fromLTWH(0, 0, plate.width.toDouble(), plate.height.toDouble());
    final dstRect = ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble());
    canvas.drawImageRect(plate, srcRect, dstRect, ui.Paint());

    // 2. Draw Main News Headline (Hind-Bold with correct HarfBuzz Devanagari ligatures)
    if (config.headlineText.trim().isNotEmpty) {
      final double hlX = (isVertical ? 40 : 545) * scaleX;
      final double hlY = (isVertical ? 1410 : 775) * scaleY;
      final double hlMaxW = (isVertical ? 1000 : 1335) * scaleX;
      final double hlFontSize = (isVertical ? 38 : 50) * scaleY;

      final textPainter = TextPainter(
        text: TextSpan(
          text: config.headlineText.trim(),
          style: TextStyle(
            color: Colors.white,
            fontSize: hlFontSize,
            fontWeight: FontWeight.w800,
            fontFamily: 'Hind',
            shadows: const [
              Shadow(
                color: Color(0x99000000),
                offset: Offset(0, 3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: hlMaxW);
      textPainter.paint(canvas, ui.Offset(hlX, hlY));
    }

    // 3. Draw Sub-Headline (Hind-SemiBold)
    if (config.subHeadline.trim().isNotEmpty) {
      final double subX = (isVertical ? 40 : 545) * scaleX;
      final double subY = (isVertical ? 1485 : 880) * scaleY;
      final double subMaxW = (isVertical ? 1000 : 1315) * scaleX;
      final double subFontSize = (isVertical ? 28 : 34) * scaleY;

      final subPainter = TextPainter(
        text: TextSpan(
          text: config.subHeadline.trim(),
          style: TextStyle(
            color: const Color(0xFF141414),
            fontSize: subFontSize,
            fontWeight: FontWeight.w700,
            fontFamily: 'Hind',
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      subPainter.layout(maxWidth: subMaxW);
      subPainter.paint(canvas, ui.Offset(subX, subY));
    }

    // 4. Draw Location Tag (if enabled)
    if (config.enableLocation && config.locationText.trim().isNotEmpty && !isVertical) {
      final cleanLoc = config.locationText.replaceAll('📍', '').trim();
      final locPainter = TextPainter(
        text: TextSpan(
          text: cleanLoc,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26 * scaleY,
            fontWeight: FontWeight.w700,
            fontFamily: 'Hind',
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      locPainter.layout();
      locPainter.paint(canvas, ui.Offset(1185 * scaleX, 203 * scaleY));
    }

    // 5. Export to PNG
    final picture = recorder.endRecording();
    final img = await picture.toImage(targetWidth, targetHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final overlayFile = File('${tempDir.path}/broadcast_overlay_$timestamp.png');
    await overlayFile.writeAsBytes(byteData!.buffer.asUint8List());

    return overlayFile.path;
  }
}

