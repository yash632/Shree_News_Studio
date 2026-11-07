import 'dart:io';
import 'dart:math' as math;
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:path_provider/path_provider.dart';
import '../models/broadcast_config.dart';
import 'overlay_renderer_service.dart';

class VideoEngineService {
  /// Gets exact media duration in seconds via FFprobe.
  static Future<double> getDuration(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();
      if (info != null && info.getDuration() != null) {
        return double.tryParse(info.getDuration()!) ?? 0.0;
      }
    } catch (_) {}
    return 0.0;
  }

  /// Checks if file contains an audio stream.
  static Future<bool> hasAudio(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();
      if (info != null && info.getStreams().isNotEmpty) {
        for (final stream in info.getStreams()) {
          if (stream.getType() == 'audio') return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Renders broadcast video locally on the mobile phone using hardware FFmpeg.
  static Future<String> renderVideo({
    required String videoPath,
    required String audioPath,
    required String overlayPath,
    required BroadcastConfig config,
    String? outroAudioPath,
    required Function(double progress, String status) onProgress,
  }) async {
    onProgress(0.05, "Analyzing media streams...");

    final videoDur = await getDuration(videoPath);
    final audioDur = await getDuration(audioPath);
    final outroDur = outroAudioPath != null ? await getDuration(outroAudioPath) : 0.0;
    final videoHasAudio = await hasAudio(videoPath);

    final isVertical = config.aspectRatio == "9:16";
    final targetW = isVertical ? 720 : 1280;
    final targetH = isVertical ? 1280 : 720;

    // Calculate total duration based on broadcast mode
    double targetDuration;
    double groundDur = config.groundClipDuration;

    if (config.audioMixMode == "intro_then_ground_outro") {
      targetDuration = audioDur + groundDur + outroDur;
    } else if (config.audioMixMode == "intro_then_ground") {
      targetDuration = audioDur + groundDur;
    } else {
      targetDuration = audioDur > 0 ? audioDur : (videoDur > 0 ? videoDur : 15.0);
    }

    onProgress(0.15, "Configuring hardware-accelerated video pipeline...");

    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${appDir.path}/shree_news_broadcast_$timestamp.mp4';

    // Prepare inputs
    final inputArgs = <String>[];

    // Input 0: Background video
    if (videoDur > 0 && videoDur < targetDuration) {
      inputArgs.addAll(['-stream_loop', '-1']);
    }
    inputArgs.addAll(['-i', videoPath]);

    // Input 1: Main Speech Audio
    inputArgs.addAll(['-i', audioPath]);

    int nextInputIdx = 2;

    // Input 2 (Optional): Outro Speech Audio
    int? outroInIdx;
    if (config.audioMixMode == "intro_then_ground_outro" &&
        outroAudioPath != null &&
        await File(outroAudioPath).exists()) {
      outroInIdx = nextInputIdx++;
      inputArgs.addAll(['-i', outroAudioPath]);
    }

    int groundVidInIdx = 0;
    int outroVidInIdx = 0;

    // Dedicated inputs for restart footage
    if (config.audioMixMode == "intro_then_ground" && config.restartFootage) {
      groundVidInIdx = nextInputIdx++;
      if (videoDur > 0 && videoDur < targetDuration) {
        inputArgs.addAll(['-stream_loop', '-1']);
      }
      inputArgs.addAll(['-i', videoPath]);
    } else if (config.audioMixMode == "intro_then_ground_outro") {
      if (config.restartFootage) {
        groundVidInIdx = nextInputIdx++;
        if (videoDur > 0 && videoDur < targetDuration) {
          inputArgs.addAll(['-stream_loop', '-1']);
        }
        inputArgs.addAll(['-i', videoPath]);
      }
      if (config.restartOutroFootage) {
        outroVidInIdx = nextInputIdx++;
        if (videoDur > 0 && videoDur < targetDuration) {
          inputArgs.addAll(['-stream_loop', '-1']);
        }
        inputArgs.addAll(['-i', videoPath]);
      }
    }

    // Input: Web UI Overlay PNG
    final overlayInIdx = nextInputIdx++;
    inputArgs.addAll(['-i', overlayPath]);

    // Build video filter graph
    final vFilters = <String>[];
    String baseVideo;

    if (config.audioMixMode == "intro_then_ground_outro") {
      if (config.restartFootage && config.restartOutroFootage) {
        vFilters.add(
          "[0:v]trim=0:${audioDur.toStringAsFixed(2)},setpts=PTS-STARTPTS[v1_cut];"
          "[$groundVidInIdx:v]trim=0:${groundDur.toStringAsFixed(2)},setpts=PTS-STARTPTS[v2_cut];"
          "[$outroVidInIdx:v]trim=0:${outroDur.toStringAsFixed(2)},setpts=PTS-STARTPTS[v3_cut];"
          "[v1_cut][v2_cut][v3_cut]concat=n=3:v=1:a=0[v_seq]",
        );
        baseVideo = "[v_seq]";
      } else {
        baseVideo = "[0:v]";
      }
    } else if (config.audioMixMode == "intro_then_ground" && config.restartFootage) {
      vFilters.add(
        "[0:v]trim=0:${audioDur.toStringAsFixed(2)},setpts=PTS-STARTPTS[v1_cut];"
        "[$groundVidInIdx:v]trim=0:${groundDur.toStringAsFixed(2)},setpts=PTS-STARTPTS[v2_cut];"
        "[v1_cut][v2_cut]concat=n=2:v=1:a=0[v_seq]",
      );
      baseVideo = "[v_seq]";
    } else {
      baseVideo = "[0:v]";
    }

    // Scaling & framing logic matching 6b456bd build_video_filter_graph
    if (config.frameScale >= 180.0) {
      // Wide / Full screen footage behind graphics
      vFilters.add(
        "$baseVideo scale=$targetW:$targetH:force_original_aspect_ratio=increase,"
        "crop=$targetW:$targetH,setsar=1[vbase];"
        "[vbase][$overlayInIdx:v]overlay=0:0[vout]",
      );
    } else {
      // Framed inside broadcast window
      if (!isVertical) {
        final layout = OverlayRendererService.calculateFrameLayout(config);
        final scaleX = targetW / 1920.0;
        final scaleY = targetH / 1080.0;

        final vidW = math.max(2, (layout.w * scaleX).round() ~/ 2 * 2);
        final vidH = math.max(2, (layout.h * scaleY).round() ~/ 2 * 2);
        final vidX = (layout.x * scaleX).round();
        final vidY = (layout.y * scaleY).round();

        vFilters.add("color=c=#0c1440:s=${targetW}x${targetH}:d=${targetDuration.toStringAsFixed(2)}[vbg]");
        vFilters.add(
          "$baseVideo scale=$vidW:$vidH:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1[vpip]",
        );
        vFilters.add("[vbg][vpip]overlay=x=$vidX:y=$vidY[vbase]");
        vFilters.add("[vbase][$overlayInIdx:v]overlay=0:0[vout]");
      } else {
        // 9:16 Portrait Framed
        final topBound = config.enableTopBar ? 340.0 : 20.0;
        final bottomBound = config.enableTicker ? 1150.0 : 1320.0;
        final availH = bottomBound - topBound;
        final scale = config.frameScale / 100.0;
        const stdW = 898.0;
        final stdH = math.min(717.0, availH * 0.88);

        final w = (stdW * scale).round();
        final h = (stdH * scale).round();
        final x = ((941.0 - w) / 2.0).round();
        final y = (((topBound + bottomBound) / 2.0) - (h / 2.0)).round();

        final scaleX = targetW / 941.0;
        final scaleY = targetH / 1672.0;

        final vidW = math.max(2, (w * scaleX).round() ~/ 2 * 2);
        final vidH = math.max(2, (h * scaleY).round() ~/ 2 * 2);
        final vidX = (x * scaleX).round();
        final vidY = (y * scaleY).round();

        vFilters.add("color=c=#000000:s=${targetW}x${targetH}:d=${targetDuration.toStringAsFixed(2)}[vbg]");
        vFilters.add(
          "$baseVideo scale=$vidW:$vidH:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1[vpip]",
        );
        vFilters.add("[vbg][vpip]overlay=x=$vidX:y=$vidY[vbase]");
        vFilters.add("[vbase][$overlayInIdx:v]overlay=0:0[vout]");
      }
    }

    // Audio filter graph
    final aFilters = <String>[];
    final introVol = config.muteDuringAnchor ? 0.0 : config.footageVolume;

    if (!videoHasAudio || config.audioMixMode == "voiceover_only") {
      // Voiceover only or silent footage
      if (config.audioMixMode == "intro_then_ground_outro" && outroInIdx != null) {
        aFilters.add(
          "[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur=${(audioDur + groundDur).toStringAsFixed(2)}[a_in_pad];"
          "[$outroInIdx:a]aformat=sample_rates=44100:channel_layouts=stereo[a_out_norm];"
          "[a_in_pad][a_out_norm]concat=n=2:v=0:a=1[aout]",
        );
      } else if (config.audioMixMode == "intro_then_ground") {
        aFilters.add(
          "[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur=${targetDuration.toStringAsFixed(2)}[aout]",
        );
      } else {
        aFilters.add("[1:a]aformat=sample_rates=44100:channel_layouts=stereo[aout]");
      }
    } else {
      if (config.audioMixMode == "intro_then_ground_outro" && outroInIdx != null) {
        aFilters.add(
          "[0:a]volume='if(between(t,${audioDur.toStringAsFixed(2)},${(audioDur + groundDur).toStringAsFixed(2)}),1.0,${introVol.toStringAsFixed(2)})':eval=frame[footage_stream];"
          "[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur=${(audioDur + groundDur).toStringAsFixed(2)}[a_in_pad];"
          "[$outroInIdx:a]aformat=sample_rates=44100:channel_layouts=stereo[a_out_norm];"
          "[a_in_pad][a_out_norm]concat=n=2:v=0:a=1[voice_stream];"
          "[voice_stream][footage_stream]amix=inputs=2:duration=longest:dropout_transition=0:normalize=0[aout]",
        );
      } else if (config.audioMixMode == "intro_then_ground") {
        aFilters.add(
          "[0:a]volume='if(lt(t,${audioDur.toStringAsFixed(2)}),${introVol.toStringAsFixed(2)},1.0)':eval=frame[a_seq];"
          "[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur=${targetDuration.toStringAsFixed(2)}[a_pad];"
          "[a_pad][a_seq]amix=inputs=2:duration=longest:dropout_transition=0:normalize=0[aout]",
        );
      } else {
        // Mode 1: voiceover_ambient
        aFilters.add(
          "[0:a]volume=${config.footageVolume.toStringAsFixed(2)}[vga];"
          "[1:a]volume=1.0[vca];"
          "[vca][vga]amix=inputs=2:duration=first:dropout_transition=2:normalize=0[aout]",
        );
      }
    }

    final fullFilterComplex = "${vFilters.join(';')};${aFilters.join(';')}";

    final cmd = [
      "-y",
      ...inputArgs,
      "-filter_complex", fullFilterComplex,
      "-map", "[vout]",
      "-map", "[aout]",
      "-c:v", "libx264",
      "-preset", "ultrafast",
      "-threads", "4",
      "-crf", "24",
      "-c:a", "aac",
      "-b:a", "192k",
      "-pix_fmt", "yuv420p",
      "-t", targetDuration.toStringAsFixed(2),
      "-movflags", "+faststart",
      outputPath,
    ];

    onProgress(0.35, "Rendering TV broadcast video locally...");

    FFmpegKitConfig.enableStatisticsCallback((stats) {
      final timeMs = stats.getTime();
      if (timeMs > 0 && targetDuration > 0) {
        final currentSec = timeMs / 1000.0;
        final p = 0.35 + ((currentSec / targetDuration) * 0.60).clamp(0.0, 0.60);
        onProgress(p, "Rendering video with mobile GPU: ${(p * 100).toInt()}%...");
      }
    });

    final session = await FFmpegKit.executeWithArguments(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode) && await File(outputPath).exists()) {
      onProgress(1.0, "Broadcast video ready!");
      return outputPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception("FFmpeg Rendering Failed:\n$logs");
    }
  }
}
