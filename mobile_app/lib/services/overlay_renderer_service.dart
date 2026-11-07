import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/broadcast_config.dart';

class FrameLayout {
  final double x;
  final double y;
  final double w;
  final double h;
  final double anchorX;
  FrameLayout({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.anchorX,
  });
}

class OverlayRendererService {
  static FrameLayout calculateFrameLayout(BroadcastConfig config) {
    final scaleVal = config.frameScale;
    final scale = scaleVal / 100.0;
    const stdW = 770.0;
    const stdH = 567.0;
    final showTop = config.enableTopBar;
    final showSidebar = config.enableSidebar;
    final showAnchor = config.enableAnchor;
    final showTicker = config.enableTicker;
    final brkTop = showTicker ? 765.0 : 897.0;

    final topNavBottom = showTop ? 148.0 : 0.0;
    final availH = math.max(100.0, brkTop - topNavBottom);
    final centerVerticalY = math.max(0.0, topNavBottom + (availH - stdH) / 2.0);

    double frameW = stdW;
    double frameH = stdH;
    double frameX = (1920.0 - stdW) / 2.0;
    double frameY = centerVerticalY;
    double anchorX = 100.0;

    if (scaleVal >= 100.0) {
      final t = math.min(1.0, (scaleVal - 100.0) / 150.0);
      frameW = stdW + (1920.0 - stdW) * t;
      frameH = stdH + (1080.0 - stdH) * t;
      final targetCenterY = (1080.0 - frameH) / 2.0;
      frameY = centerVerticalY + (targetCenterY - centerVerticalY) * t;
    } else {
      frameW = stdW * scale;
      frameH = stdH * scale;
      frameY = centerVerticalY + (stdH - frameH) / 2.0;
    }

    if (!showSidebar && !showAnchor) {
      frameX = (1920.0 - frameW) / 2.0;
      final freeH = brkTop - topNavBottom;
      frameY = topNavBottom + (freeH - frameH) / 2.0;
    } else if (showAnchor && showSidebar) {
      const openRight = 1000.0;
      final stdX = math.max(0.0, openRight + (1920.0 - openRight - stdW) / 2.0);
      final targetCenterX = (1920.0 - frameW) / 2.0;
      final t = scaleVal >= 100.0 ? math.min(1.0, (scaleVal - 100.0) / 150.0) : 0.0;
      frameX = stdX * (1.0 - t) + targetCenterX * t;
      anchorX = 380.0;
    } else if (!showAnchor && showSidebar) {
      const openStart = 400.0;
      final openWidth = 1920.0 - openStart;
      final stdX = math.max(0.0, openStart + (openWidth - stdW) / 2.0);
      final targetCenterX = (1920.0 - frameW) / 2.0;
      final t = scaleVal >= 100.0 ? math.min(1.0, (scaleVal - 100.0) / 150.0) : 0.0;
      frameX = stdX * (1.0 - t) + targetCenterX * t;
    } else if (showAnchor && !showSidebar) {
      anchorX = 100.0;
      const rightStart = 650.0;
      final rightWidth = 1920.0 - rightStart;
      final stdX = math.max(0.0, rightStart + (rightWidth - stdW) / 2.0);
      final targetCenterX = (1920.0 - frameW) / 2.0;
      final t = scaleVal >= 100.0 ? math.min(1.0, (scaleVal - 100.0) / 150.0) : 0.0;
      frameX = stdX * (1.0 - t) + targetCenterX * t;
    }

    return FrameLayout(
      x: frameX,
      y: frameY,
      w: frameW,
      h: frameH,
      anchorX: anchorX,
    );
  }

  static Future<ui.Image> _loadAssetImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  /// Generates the high-fidelity transparent broadcast overlay PNG
  static Future<String> generateOverlay({
    required BroadcastConfig config,
    required int targetWidth,
    required int targetHeight,
    String? customLogoPath,
  }) async {
    final isVertical = config.aspectRatio == "9:16";
    final plateAsset = isVertical
        ? 'assets/master_broadcast_plate_portrait.png'
        : 'assets/master_broadcast_plate.png';

    final ui.Image plate = await _loadAssetImage(plateAsset);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
    );

    final double scaleX = targetWidth / (isVertical ? 941.0 : 1920.0);
    final double scaleY = targetHeight / (isVertical ? 1672.0 : 1080.0);

    // Current time & date calculations
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = "$hour:$minute $ampm";

    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const hindiDays = ["रविवार", "सोमवार", "मंगलवार", "बुधवार", "गुरुवार", "शुक्रवार", "शनिवार"];
    final dateStr = "${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}";
    final dayStr = hindiDays[now.weekday % 7];

    // 1. Draw master broadcast plate
    final srcRect = ui.Rect.fromLTWH(0, 0, plate.width.toDouble(), plate.height.toDouble());
    final dstRect = ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble());
    canvas.drawImageRect(plate, srcRect, dstRect, ui.Paint());

    if (!isVertical) {
      final layout = calculateFrameLayout(config);

      // 2. Clear frame window so footage shows through!
      if (config.frameScale < 180.0) {
        canvas.drawRect(
          ui.Rect.fromLTWH(
            layout.x * scaleX,
            layout.y * scaleY,
            layout.w * scaleX,
            layout.h * scaleY,
          ),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      } else {
        // Full screen: clear whole central area behind graphics
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 148 * scaleY, targetWidth.toDouble(), (765 - 148) * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      }

      // 3. Top Bar Toggle
      if (!config.enableTopBar) {
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), 155 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      }

      // 4. Sidebar Toggle & Items
      if (!config.enableSidebar) {
        canvas.drawRect(
          ui.Rect.fromLTWH(20 * scaleX, 155 * scaleY, 390 * scaleX, 610 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      } else {
        for (int i = 0; i < math.min(5, config.sidebarItems.length); i++) {
          final itemText = config.sidebarItems[i].trim();
          if (itemText.isNotEmpty) {
            final textPainter = TextPainter(
              text: TextSpan(
                text: itemText,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 20 * scaleY,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Hind',
                ),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 2,
              ellipsis: '...',
            );
            textPainter.layout(maxWidth: 220 * scaleX);
            textPainter.paint(
              canvas,
              ui.Offset(130 * scaleX, (250 + i * 98) * scaleY),
            );
          }
        }
      }

      // 5. Studio Anchor Window (Picture-in-Picture)
      if (config.enableAnchor) {
        try {
          final anchorImg = await _loadAssetImage('assets/web/anchor.png');
          final brkTop = config.enableTicker ? 765.0 : 897.0;
          final anchorY = (brkTop - 620.0) * scaleY;
          final anchorX = layout.anchorX * scaleX;
          final anchorW = 720.0 * scaleX;
          final anchorH = 620.0 * scaleY;

          canvas.drawImageRect(
            anchorImg,
            ui.Rect.fromLTWH(0, 0, anchorImg.width.toDouble(), anchorImg.height.toDouble()),
            ui.Rect.fromLTWH(anchorX, anchorY, anchorW, anchorH),
            ui.Paint(),
          );
        } catch (_) {}
      }

      // 6. Location Tag Pin
      if (config.enableLocation && config.locationText.trim().isNotEmpty) {
        final locX = (layout.x + 8.0) * scaleX;
        final locY = (layout.y + 10.0) * scaleY;
        final cleanLoc = config.locationText.replaceAll('📍', '').trim();

        final pinBgPaint = ui.Paint()..color = const Color(0xFF0D1F5C);
        final pinRedPaint = ui.Paint()..color = const Color(0xFFE11D2A);

        final locPainter = TextPainter(
          text: TextSpan(
            text: cleanLoc,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22 * scaleY,
              fontWeight: FontWeight.w700,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        locPainter.layout();

        final tagW = locPainter.width + (64 * scaleX);
        final tagH = 46 * scaleY;

        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(locX, locY, tagW, tagH),
            const ui.Radius.circular(4),
          ),
          pinBgPaint,
        );

        canvas.drawRect(
          ui.Rect.fromLTWH(locX, locY, 44 * scaleX, tagH),
          pinRedPaint,
        );

        // Draw authentic White Map Pin SVG Icon inside the red box
        final pinCenterX = locX + 22 * scaleX;
        final pinCenterY = locY + 18 * scaleY;
        canvas.drawCircle(
          ui.Offset(pinCenterX, pinCenterY),
          8 * scaleX,
          ui.Paint()..color = Colors.white,
        );
        final pinPath = ui.Path()
          ..moveTo(pinCenterX - 7 * scaleX, pinCenterY + 4 * scaleY)
          ..lineTo(pinCenterX + 7 * scaleX, pinCenterY + 4 * scaleY)
          ..lineTo(pinCenterX, pinCenterY + 16 * scaleY)
          ..close();
        canvas.drawPath(pinPath, ui.Paint()..color = Colors.white);
        canvas.drawCircle(
          ui.Offset(pinCenterX, pinCenterY),
          3.5 * scaleX,
          ui.Paint()..color = const Color(0xFFC4121F),
        );

        locPainter.paint(canvas, ui.Offset(locX + 52 * scaleX, locY + 8 * scaleY));
      }

      // 7. Main News Headline
      if (config.headlineText.trim().isNotEmpty) {
        final double hlX = 545 * scaleX;
        final double hlY = (config.enableTicker ? 775 : 907) * scaleY;
        final double hlMaxW = 1335 * scaleX;
        final double hlFontSize = 46 * scaleY;

        final textPainter = TextPainter(
          text: TextSpan(
            text: config.headlineText.trim(),
            style: TextStyle(
              color: Colors.white,
              fontSize: hlFontSize,
              fontWeight: FontWeight.w800,
              fontFamily: 'Hind',
              shadows: const [
                Shadow(color: Color(0x99000000), offset: Offset(0, 3), blurRadius: 4),
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

      // 8. Sub-Headline
      if (config.subHeadline.trim().isNotEmpty) {
        final double subX = 545 * scaleX;
        final double subY = (config.enableTicker ? 880 : 1012) * scaleY;
        final double subMaxW = 1315 * scaleX;
        final double subFontSize = 32 * scaleY;

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

      // 9. Bottom Ticker & DateTime Bars (Seamless Dynamic Alignment matching web)
      if (!config.enableTicker) {
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 948 * scaleY, targetWidth.toDouble(), 132 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      } else {
        final bool showDT = config.enableDateTime;
        final double tagLeft = showDT ? 445 * scaleX : 28 * scaleX;
        final double tagWidth = showDT ? 250 * scaleX : 260 * scaleX;
        final double tickerLeft = showDT ? 695 * scaleX : 288 * scaleX;
        final double tickerWidth = showDT ? (1920 - 695) * scaleX : (1920 - 288) * scaleX;

        // Draw Under Silver Bar background
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 948 * scaleY, 1920 * scaleX, 132 * scaleY),
          ui.Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset(0, 948 * scaleY),
              ui.Offset(1920 * scaleX, 948 * scaleY),
              const [
                Color(0xFFD6D4D4),
                Color(0xFFE9C0CC),
                Color(0xFFFAF1F2),
                Color(0xFFF2EEEE),
                Color(0xFFDEDEDE),
              ],
              const [0.0, 0.16, 0.45, 0.70, 1.0],
            ),
        );

        if (showDT) {
          // Time Box
          canvas.drawRRect(
            ui.RRect.fromRectAndCorners(
              ui.Rect.fromLTWH(30 * scaleX, 970 * scaleY, 215 * scaleX, 88 * scaleY),
              topLeft: ui.Radius.circular(12 * scaleX),
              bottomLeft: ui.Radius.circular(12 * scaleX),
            ),
            ui.Paint()..color = const Color(0xFFE11D2A),
          );
          final timePainter = TextPainter(
            text: TextSpan(
              text: timeStr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 34 * scaleY,
                fontWeight: FontWeight.w800,
                fontFamily: 'Hind',
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          timePainter.layout();
          timePainter.paint(canvas, ui.Offset(48 * scaleX, 988 * scaleY));

          // Date Box
          canvas.drawRect(
            ui.Rect.fromLTWH(245 * scaleX, 970 * scaleY, 200 * scaleX, 88 * scaleY),
            ui.Paint()..color = Colors.white,
          );
          final datePainter = TextPainter(
            text: TextSpan(
              text: "$dateStr\n$dayStr",
              style: TextStyle(
                color: Colors.black,
                fontSize: 20 * scaleY,
                fontWeight: FontWeight.w700,
                fontFamily: 'Hind',
                height: 1.15,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          );
          datePainter.layout(maxWidth: 190 * scaleX);
          datePainter.paint(canvas, ui.Offset(250 * scaleX, 978 * scaleY));
        }

        // Ticker Tag (Red Box)
        final tagText = config.tickerTag.isNotEmpty ? config.tickerTag : "ताजा खबर";
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(tagLeft, 970 * scaleY, tagWidth, 88 * scaleY),
            ui.Radius.circular(showDT ? 0 : 8 * scaleX),
          ),
          ui.Paint()..color = const Color(0xFFE11D2A),
        );
        final tagPainter = TextPainter(
          text: TextSpan(
            text: tagText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34 * scaleY,
              fontWeight: FontWeight.w900,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tagPainter.layout();
        tagPainter.paint(canvas, ui.Offset(tagLeft + 25 * scaleX, 988 * scaleY));

        // Ticker Text (Dark Blue Strip)
        final tText = config.tickerText.isNotEmpty
            ? config.tickerText
            : "श्री न्यूज़ 24x7 | देश-दुनिया की हर बड़ी खबर | सबसे पहले और सबसे सटीक";
        canvas.drawRect(
          ui.Rect.fromLTWH(tickerLeft, 970 * scaleY, tickerWidth, 88 * scaleY),
          ui.Paint()..color = const Color(0xFF0F1E4A),
        );
        final tickerPainter = TextPainter(
          text: TextSpan(
            text: tText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30 * scaleY,
              fontWeight: FontWeight.w700,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        );
        tickerPainter.layout(maxWidth: tickerWidth - (40 * scaleX));
        tickerPainter.paint(canvas, ui.Offset(tickerLeft + 20 * scaleX, 992 * scaleY));
      }
    } else {
      // 9:16 Portrait Mode
      final topBound = config.enableTopBar ? 340.0 : 20.0;
      final bottomBound = config.enableTicker ? 1150.0 : 1320.0;
      final availH = bottomBound - topBound;
      final scaleVal = config.frameScale;
      final scale = scaleVal / 100.0;
      const stdW = 898.0;
      final stdH = math.min(717.0, availH * 0.88);

      double w, h;
      if (scaleVal >= 100.0) {
        final t = math.min(1.0, (scaleVal - 100.0) / 150.0);
        w = stdW + (941.0 - stdW) * t;
        h = stdH + (availH - stdH) * t;
      } else {
        w = stdW * scale;
        h = stdH * scale;
      }
      final x = (941.0 - w) / 2.0;
      final y = ((topBound + bottomBound) / 2.0) - (h / 2.0);

      canvas.drawRect(
        ui.Rect.fromLTWH(x * scaleX, y * scaleY, w * scaleX, h * scaleY),
        ui.Paint()..blendMode = ui.BlendMode.clear,
      );

      // Top Bar Toggle
      if (!config.enableTopBar) {
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), 350 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      }

      // Location Pin
      if (config.enableLocation && config.locationText.trim().isNotEmpty) {
        final locX = math.max(22.0, x + 10.0) * scaleX;
        final locY = math.max(topBound + 15.0, y + 17.0) * scaleY;
        final cleanLoc = config.locationText.replaceAll('📍', '').trim();

        final pinBgPaint = ui.Paint()..color = const Color(0xFF001A3C);
        final pinRedPaint = ui.Paint()..color = const Color(0xFFE70A24);

        final locPainter = TextPainter(
          text: TextSpan(
            text: cleanLoc,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26 * scaleY,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        locPainter.layout();

        final tagW = locPainter.width + (58 * scaleX);
        final tagH = 50 * scaleY;

        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(locX, locY, tagW, tagH),
            const ui.Radius.circular(8),
          ),
          pinBgPaint,
        );

        canvas.drawRect(
          ui.Rect.fromLTWH(locX, locY, 44 * scaleX, tagH),
          pinRedPaint,
        );

        // Draw authentic White Map Pin SVG Icon inside the red box
        final pinCenterX = locX + 22 * scaleX;
        final pinCenterY = locY + 20 * scaleY;
        canvas.drawCircle(
          ui.Offset(pinCenterX, pinCenterY),
          8 * scaleX,
          ui.Paint()..color = Colors.white,
        );
        final pinPath = ui.Path()
          ..moveTo(pinCenterX - 7 * scaleX, pinCenterY + 4 * scaleY)
          ..lineTo(pinCenterX + 7 * scaleX, pinCenterY + 4 * scaleY)
          ..lineTo(pinCenterX, pinCenterY + 16 * scaleY)
          ..close();
        canvas.drawPath(pinPath, ui.Paint()..color = Colors.white);
        canvas.drawCircle(
          ui.Offset(pinCenterX, pinCenterY),
          3.5 * scaleX,
          ui.Paint()..color = const Color(0xFFC4121F),
        );

        locPainter.paint(canvas, ui.Offset(locX + 50 * scaleX, locY + 10 * scaleY));
      }

      // Main News Headline
      if (config.headlineText.trim().isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: config.headlineText.trim(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 42 * scaleY,
              fontWeight: FontWeight.w800,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        );
        textPainter.layout(maxWidth: 540 * scaleX);
        textPainter.paint(canvas, ui.Offset(377 * scaleX, 1210 * scaleY));
      }

      // Sub-Headline
      if (config.subHeadline.trim().isNotEmpty) {
        final subPainter = TextPainter(
          text: TextSpan(
            text: config.subHeadline.trim(),
            style: TextStyle(
              color: const Color(0xFF111111),
              fontSize: 34 * scaleY,
              fontWeight: FontWeight.w700,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        );
        subPainter.layout(maxWidth: 850 * scaleX);
        subPainter.paint(canvas, ui.Offset(47 * scaleX, 1395 * scaleY));
      }

      // Ticker & DateTime in Portrait Mode
      if (!config.enableTicker) {
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 1450 * scaleY, targetWidth.toDouble(), 220 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      } else {
        final bool showDT = config.enableDateTime;
        final double tagLeft = showDT ? 268 * scaleX : 15 * scaleX;
        final double tagWidth = showDT ? 168 * scaleX : 200 * scaleX;
        final double tickerLeft = showDT ? 436 * scaleX : 215 * scaleX;
        final double tickerWidth = showDT ? 481 * scaleX : 711 * scaleX;

        // Draw ticker bar container
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(15 * scaleX, 1538 * scaleY, 917 * scaleX, 88 * scaleY),
            ui.Radius.circular(12 * scaleX),
          ),
          ui.Paint()..color = const Color(0xFF011C3D),
        );

        if (showDT) {
          // Time box
          canvas.drawRRect(
            ui.RRect.fromRectAndCorners(
              ui.Rect.fromLTWH(15 * scaleX, 1538 * scaleY, 130 * scaleX, 88 * scaleY),
              topLeft: ui.Radius.circular(12 * scaleX),
              bottomLeft: ui.Radius.circular(12 * scaleX),
            ),
            ui.Paint()..color = const Color(0xFFE03030),
          );
          final timePainter = TextPainter(
            text: TextSpan(
              text: timeStr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22 * scaleY,
                fontWeight: FontWeight.w800,
                fontFamily: 'Hind',
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          timePainter.layout();
          timePainter.paint(canvas, ui.Offset(25 * scaleX, 1568 * scaleY));

          // Date box
          canvas.drawRect(
            ui.Rect.fromLTWH(145 * scaleX, 1538 * scaleY, 123 * scaleX, 88 * scaleY),
            ui.Paint()..color = Colors.white,
          );
          final datePainter = TextPainter(
            text: TextSpan(
              text: "$dateStr\n$dayStr",
              style: TextStyle(
                color: Colors.black,
                fontSize: 16 * scaleY,
                fontWeight: FontWeight.w700,
                fontFamily: 'Hind',
                height: 1.1,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          );
          datePainter.layout(maxWidth: 115 * scaleX);
          datePainter.paint(canvas, ui.Offset(148 * scaleX, 1558 * scaleY));
        }

        // Ticker Tag
        final tagText = config.tickerTag.isNotEmpty ? config.tickerTag : "ताजा खबर";
        canvas.drawRRect(
          ui.RRect.fromRectAndCorners(
            ui.Rect.fromLTWH(tagLeft, 1538 * scaleY, tagWidth, 88 * scaleY),
            topLeft: ui.Radius.circular(showDT ? 0 : 12 * scaleX),
            bottomLeft: ui.Radius.circular(showDT ? 0 : 12 * scaleX),
          ),
          ui.Paint()..color = const Color(0xFFE03030),
        );
        final tagPainter = TextPainter(
          text: TextSpan(
            text: tagText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26 * scaleY,
              fontWeight: FontWeight.w900,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tagPainter.layout();
        tagPainter.paint(canvas, ui.Offset(tagLeft + 18 * scaleX, 1566 * scaleY));

        // Ticker Text
        final tText = config.tickerText.isNotEmpty
            ? config.tickerText
            : "श्री न्यूज़ 24x7 | देश-दुनिया की हर बड़ी खबर | सबसे पहले और सबसे सटीक";
        final tickerPainter = TextPainter(
          text: TextSpan(
            text: tText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24 * scaleY,
              fontWeight: FontWeight.w700,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        );
        tickerPainter.layout(maxWidth: tickerWidth - 25 * scaleX);
        tickerPainter.paint(canvas, ui.Offset(tickerLeft + 15 * scaleX, 1566 * scaleY));
      }
    }

    // Custom Logo if supplied
    if (config.enableTopBar && customLogoPath != null && File(customLogoPath).existsSync()) {
      try {
        final logoBytes = await File(customLogoPath).readAsBytes();
        final logoCodec = await ui.instantiateImageCodec(logoBytes);
        final logoFrame = await logoCodec.getNextFrame();
        final logoImg = logoFrame.image;

        final logoX = (isVertical ? 622 : 1625) * scaleX;
        final logoY = (isVertical ? 45 : 0) * scaleY;
        final logoW = (isVertical ? 319 : 295) * scaleX;
        final logoH = (isVertical ? 170 : 172) * scaleY;

        canvas.drawRect(
          ui.Rect.fromLTWH(logoX, logoY, logoW, logoH),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
        canvas.drawImageRect(
          logoImg,
          ui.Rect.fromLTWH(0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
          ui.Rect.fromLTWH(logoX, logoY, logoW, logoH),
          ui.Paint(),
        );
      } catch (_) {}
    }

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
