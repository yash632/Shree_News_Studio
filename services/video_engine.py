import os
import subprocess
import shutil
import datetime
from typing import Callable, Optional
from config import DEFAULT_FONT, NEWS_THEMES
from services.overlay_service import create_news_overlay

def get_media_duration(file_path: str) -> float:
    """Returns the duration of an audio or video file in seconds."""
    cmd = [
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        file_path
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return float(res.stdout.strip())
    except Exception as e:
        print(f"Warning: Failed to get duration for {file_path}: {e}")
        return 0.0

def has_audio_stream(file_path: str) -> bool:
    """Checks whether the file has at least one audio stream."""
    if not file_path or not os.path.exists(file_path):
        return False
    cmd = [
        "ffprobe",
        "-v", "error",
        "-select_streams", "a",
        "-show_entries", "stream=codec_type",
        "-of", "csv=p=0",
        file_path
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True)
        return "audio" in res.stdout
    except Exception:
        return False

def build_video_filter_graph(
    target_w: int,
    target_h: int,
    overlay_path: str,
    tag_overlay_path: Optional[str] = None,
    ticker_text_file: Optional[str] = None,
    logo_path: Optional[str] = None,
    font_file: str = DEFAULT_FONT,
    ticker_font_size: int = 30,
    ticker_y: int = 1000,
    ticker_start_x: int = 450,
    ticker_speed: int = 180,
    enable_anchor: bool = False,
    anchor_image_path: Optional[str] = None,
    is_vertical: bool = False,
    frame_x: int = 575,
    frame_y: int = 173,
    frame_w: int = 770,
    frame_h: int = 567,
    enable_ticker: bool = True,
    enable_sidebar: bool = False,
    audio_mix_mode: str = "voiceover_ambient",
    restart_footage: bool = False,
    intro_duration: float = 0.0,
    total_duration: float = 0.0,
    current_input_start: int = 2,
    restart_outro_footage: bool = False,
    ground_duration: float = 0.0,
    outro_duration: float = 0.0
) -> tuple:
    """
    Builds the FFmpeg -filter_complex chain matching Screenshot 2.
    """
    extra_inputs = []
    filters = []
    current_input_idx = current_input_start

    # 1. Base Footage Layer
    bg_asset = (
        os.path.join("static", "assets", "Glossy Red News Broadcast Waves.png")
        if is_vertical
        else os.path.join("static", "assets", "Glossy Red News Waves.png")
    )
    if os.path.exists(bg_asset):
        bg_input_idx = current_input_idx
        current_input_idx += 1
        extra_inputs.extend(["-loop", "1", "-i", bg_asset.replace('\\', '/')])
        filters.append(
            f"[{bg_input_idx}:v]scale={target_w}:{target_h}:force_original_aspect_ratio=increase,"
            f"crop={target_w}:{target_h},setsar=1,format=rgba[vbg]"
        )
    else:
        fallback_c = "0x8d010b" if is_vertical else "0x0c1440"
        filters.append(f"color=s={target_w}x{target_h}:c={fallback_c},format=rgba[vbg]")

    if audio_mix_mode == "intro_then_ground_outro" and intro_duration > 0 and outro_duration > 0 and ground_duration > 0:
        if restart_footage and restart_outro_footage:
            filters.append(
                f"[0:v]split=3[v_raw1][v_raw2][v_raw3];"
                f"[v_raw1]trim=0:{intro_duration:.2f},setpts=PTS-STARTPTS[v1_cut];"
                f"[v_raw2]trim=0:{ground_duration:.2f},setpts=PTS-STARTPTS[v2_cut];"
                f"[v_raw3]trim=0:{outro_duration:.2f},setpts=PTS-STARTPTS[v3_cut];"
                f"[v1_cut][v2_cut][v3_cut]concat=n=3:v=1:a=0[v_seq]"
            )
            base_v_in = "[v_seq]"
        elif restart_footage and not restart_outro_footage:
            filters.append(
                f"[0:v]split=2[v_raw1][v_raw2];"
                f"[v_raw1]trim=0:{intro_duration:.2f},setpts=PTS-STARTPTS[v1_cut];"
                f"[v_raw2]trim=0:{ground_duration + outro_duration:.2f},setpts=PTS-STARTPTS[v2_cut];"
                f"[v1_cut][v2_cut]concat=n=2:v=1:a=0[v_seq]"
            )
            base_v_in = "[v_seq]"
        elif not restart_footage and restart_outro_footage:
            filters.append(
                f"[0:v]split=2[v_raw1][v_raw2];"
                f"[v_raw1]trim=0:{intro_duration + ground_duration:.2f},setpts=PTS-STARTPTS[v1_cut];"
                f"[v_raw2]trim=0:{outro_duration:.2f},setpts=PTS-STARTPTS[v2_cut];"
                f"[v1_cut][v2_cut]concat=n=2:v=1:a=0[v_seq]"
            )
            base_v_in = "[v_seq]"
        else:
            base_v_in = "[0:v]"
    elif restart_footage and audio_mix_mode == "intro_then_ground" and intro_duration > 0 and total_duration > intro_duration:
        ground_dur = max(2.0, total_duration - intro_duration)
        filters.append(
            f"[0:v]split=2[v_raw1][v_raw2];"
            f"[v_raw1]trim=0:{intro_duration:.2f},setpts=PTS-STARTPTS[v1_cut];"
            f"[v_raw2]trim=0:{ground_dur:.2f},setpts=PTS-STARTPTS[v2_cut];"
            f"[v1_cut][v2_cut]concat=n=2:v=1:a=0[v_seq]"
        )
        base_v_in = "[v_seq]"
    else:
        base_v_in = "[0:v]"

    if is_vertical:
        # Scale video according to footage size slider smoothly up to full screen (1080x1920)
        portrait_scale_x = target_w / 941.0
        portrait_scale_y = target_h / 1672.0
        scale_factor = (frame_w / 770.0) if frame_w else 1.0
        std_w = 898
        top_bound = 340
        bottom_bound = 1150 if enable_ticker else 1320
        avail_h = bottom_bound - top_bound
        center_y = int((top_bound + bottom_bound) / 2)
        std_h = min(717, int(avail_h * 0.88))
        if scale_factor >= 1.0:
            t = min(1.0, (scale_factor - 1.0) / 1.5)
            base_w = int(std_w + (941 - std_w) * t)
            base_h = int(std_h + (avail_h - std_h) * t)
        else:
            scale_val = max(0.5, scale_factor)
            base_w = int(std_w * scale_val)
            base_h = int(std_h * scale_val)
        base_x = int((941 - base_w) / 2)
        base_y = int(center_y - (base_h / 2))

        vid_w = max(2, (int(base_w * portrait_scale_x) // 2) * 2)
        vid_h = max(2, (int(base_h * portrait_scale_y) // 2) * 2)
        vid_x = int(base_x * portrait_scale_x)
        vid_y = int(base_y * portrait_scale_y)
        if scale_factor >= 1.8:
            filters.append(
                f"{base_v_in}scale={vid_w}:{vid_h}:force_original_aspect_ratio=increase,"
                f"crop={vid_w}:{vid_h},setsar=1[vpip]"
            )
            filters.append(f"[vbg][vpip]overlay=x={vid_x}:y={vid_y}[vbase]")
        else:
            filters.append(
                f"{base_v_in}scale={vid_w}:{vid_h}:force_original_aspect_ratio=decrease:force_divisible_by=2,"
                f"setsar=1[vpip]"
            )
            filters.append(f"[vbg][vpip]overlay=x=({target_w}-w)/2:y={vid_y}+({vid_h}-h)/2[vbase]")
    else:
        # Keep the complete uploaded footage visible inside the configured window.
        # The browser preview uses object-fit: contain, so export must use the
        # same aspect-ratio-preserving behavior instead of cropping the source.
        vid_w = max(2, (int(frame_w * (target_w / 1920.0)) // 2) * 2)
        vid_h = max(2, (int(frame_h * (target_h / 1080.0)) // 2) * 2)
        if not enable_sidebar and not enable_anchor:
            vid_x = (target_w - vid_w) // 2
            vid_y = int(frame_y * (target_h / 1080.0))
            overlay_x = f"({target_w}-w)/2"
            overlay_y = f"{vid_y}+({vid_h}-h)/2"
        else:
            vid_x = int(frame_x * (target_w / 1920.0))
            vid_y = int(frame_y * (target_h / 1080.0))
            overlay_x = f"{vid_x}+({vid_w}-w)/2"
            overlay_y = f"{vid_y}+({vid_h}-h)/2"
        filters.append(
            f"{base_v_in}scale={vid_w}:{vid_h}:force_original_aspect_ratio=decrease:force_divisible_by=2,"
            f"setsar=1[vpip]"
        )
        filters.append(f"[vbg][vpip]overlay=x={overlay_x}:y={overlay_y}[vbase]")

    current_stream = "[vbase]"

    # 2. Broadcast News Graphic Overlay (Top Bar + Sidebar + Lower Thirds + Frame)
    overlay_input_idx = current_input_idx
    current_input_idx += 1
    extra_inputs.extend(["-i", overlay_path])
    filters.append(f"{current_stream}[{overlay_input_idx}:v]overlay=0:0[vframe]")
    current_stream = "[vframe]"

    # 3. Animated Scrolling News Ticker Text (Bounded strictly inside ticker strip)
    if enable_ticker and ticker_start_x > 0 and ticker_text_file and os.path.exists(ticker_text_file):
        rel_font = font_file.replace('\\', '/').replace(':', '\\:')
        rel_txt = os.path.relpath(ticker_text_file, os.getcwd()).replace('\\', '/').replace(':', '\\:')
        
        if is_vertical:
            strip_h = int(88 * (target_h / 1672.0))
            strip_w = target_w - ticker_start_x - int(25 * (target_w / 941.0))
            t_font_size = int(32 * (target_w / 941.0))
        else:
            strip_w = target_w - ticker_start_x
            strip_h = int(88 * (target_h / 1080.0))
            t_font_size = ticker_font_size
        
        strip_w = max(100, (int(strip_w) // 2) * 2)
        strip_h = max(20, (int(strip_h) // 2) * 2)
        
        filters.append(f"color=s={strip_w}x{strip_h}:c=black@0.0,format=rgba[tbox]")
        filters.append(
            f"[tbox]drawtext=fontfile='{rel_font}':textfile='{rel_txt}':"
            f"fontcolor=white:fontsize={t_font_size}:"
            f"y=(h-text_h)/2:"
            f"x=w-mod(t*{ticker_speed}\\,w+text_w)[ttext]"
        )
        filters.append(f"{current_stream}[ttext]overlay={ticker_start_x}:{ticker_y}[vticker]")
        current_stream = "[vticker]"

    filter_complex_str = ";".join(filters)
    return extra_inputs, filter_complex_str, current_stream

def render_news_video(
    video_input_path: str,
    audio_input_path: str,
    output_video_path: str,
    badge_text: str = "BREAKING NEWS",
    headline_text: str = "भोपाल में आज तेज बारिश, कई इलाकों में जलभराव",
    sub_headline: str = "मौसम विभाग ने अगले 24 घंटे के लिए जारी किया अलर्ट",
    ticker_text: str = "भोपाल | इंदौर | ग्वालियर | जबलपुर | उज्जैन | सागर | रीवा | और देश-दुनिया की हर खबर",
    ticker_tag: str = "ताजा खबर",
    theme_key: str = "red_alert",
    aspect_ratio: str = "16:9",
    logo_input_path: Optional[str] = None,
    # New Broadcast Options from Screenshot 2
    enable_top_bar: bool = True,
    enable_sidebar: bool = True,
    sidebar_items: Optional[list] = None,
    enable_location: bool = True,
    location_text: str = "📍 भोपाल, मध्य प्रदेश",
    enable_datetime: bool = True,
    time_text: str = "10:25 AM",
    date_text: str = "28 Oct 2026",
    day_text: str = "मंगलवार",
    enable_anchor: bool = False,
    enable_ticker: bool = True,
    frame_x: int = 575,
    frame_y: int = 173,
    frame_w: int = 770,
    frame_h: int = 567,
    audio_mix_mode: str = "voiceover_ambient",
    footage_volume: float = 0.20,
    ground_clip_duration: float = 10.0,
    restart_footage: bool = False,
    outro_audio_path: Optional[str] = None,
    restart_outro_footage: bool = False,
    progress_callback: Optional[Callable[[int, str], None]] = None
) -> bool:
    """
    Renders professional broadcast news video matching Screenshot 2.
    """
    work_dir = os.path.dirname(output_video_path)
    job_prefix = os.path.splitext(os.path.basename(output_video_path))[0]
    
    if aspect_ratio == "9:16":
        target_w, target_h = 1080, 1920
        ticker_font_size = 28
    else:  # 16:9 Landscape default
        target_w, target_h = 1920, 1080
        ticker_font_size = 28

    if progress_callback:
        progress_callback(10, "Analyzing audio and video duration...")

    has_anchor_aud = bool(
        audio_input_path
        and os.path.exists(audio_input_path)
        and has_audio_stream(audio_input_path)
    )
    if has_anchor_aud:
        audio_duration = get_media_duration(audio_input_path)
        if audio_duration <= 0.5:
            audio_duration = 5.0
    else:
        audio_duration = 0.0

    video_duration = get_media_duration(video_input_path)
    if video_duration <= 0.1:
        print(f"Invalid video input duration: {video_duration}")
        if progress_callback:
            progress_callback(-1, "Unable to read the uploaded video footage. Please ensure the file is a valid MP4 or MOV video.")
        return False

    if progress_callback:
        progress_callback(25, "Generating Screenshot 2 broadcast news overlays...")

    overlay_img_path = os.path.join(work_dir, f"{job_prefix}_overlay.png")
    tag_img_path = os.path.join(work_dir, f"{job_prefix}_tag.png")
    
    base_path, generated_tag_path, ticker_start_x, ticker_y = create_news_overlay(
        width=target_w,
        height=target_h,
        badge_text=badge_text,
        headline_text=headline_text,
        sub_headline=sub_headline,
        ticker_tag=ticker_tag,
        ticker_text=ticker_text,
        theme_key=theme_key,
        output_path=overlay_img_path,
        output_tag_path=tag_img_path,
        enable_top_bar=enable_top_bar,
        enable_sidebar=enable_sidebar,
        sidebar_items=sidebar_items,
        enable_location=enable_location,
        location_text=location_text,
        enable_datetime=enable_datetime,
        time_text=time_text,
        date_text=date_text,
        day_text=day_text,
        logo_path=logo_input_path,
        enable_anchor=enable_anchor,
        enable_ticker=enable_ticker,
        frame_x=frame_x,
        frame_y=frame_y,
        frame_w=frame_w,
        frame_h=frame_h
    )

    # Animated ticker text file
    ticker_txt_path = None
    if enable_ticker and ticker_text.strip():
        ticker_txt_path = os.path.join(work_dir, f"{job_prefix}_ticker.txt")
        ticker_value = " ".join(ticker_text.strip().splitlines())
        formatted_ticker = f"  +++  {ticker_value}  +++  "
        with open(ticker_txt_path, "w", encoding="utf-8") as f:
            f.write(formatted_ticker)

    if progress_callback:
        progress_callback(40, "Assembling broadcast compositor...")

    anchor_studio_asset = "static/assets/studio_plate_anchor.png" if os.path.exists("static/assets/studio_plate_anchor.png") else ("static/assets/anchor_studio.jpg" if os.path.exists("static/assets/anchor_studio.jpg") else None)

    has_outro_aud = bool(
        outro_audio_path
        and os.path.exists(outro_audio_path)
        and has_audio_stream(outro_audio_path)
    )
    outro_dur = get_media_duration(outro_audio_path) if has_outro_aud else 0.0

    if not has_anchor_aud:
        ground_dur = 0.0
        target_duration = video_duration
    elif audio_mix_mode == "intro_then_ground_outro":
        ground_dur = max(2.0, float(ground_clip_duration))
        target_duration = audio_duration + ground_dur + outro_dur
    elif audio_mix_mode == "intro_then_ground":
        ground_dur = max(2.0, float(ground_clip_duration))
        target_duration = audio_duration + ground_dur
    else:
        ground_dur = 0.0
        target_duration = audio_duration

    current_input_start = 3 if has_outro_aud else 2

    extra_inputs, filter_complex, final_video_stream = build_video_filter_graph(
        target_w=target_w,
        target_h=target_h,
        overlay_path=base_path,
        tag_overlay_path=generated_tag_path,
        ticker_text_file=ticker_txt_path,
        ticker_font_size=ticker_font_size,
        ticker_y=ticker_y,
        ticker_start_x=ticker_start_x,
        ticker_speed=190,
        enable_anchor=enable_anchor,
        anchor_image_path=anchor_studio_asset,
        is_vertical=(aspect_ratio == "9:16"),
        frame_x=frame_x,
        frame_y=frame_y,
        frame_w=frame_w,
        frame_h=frame_h,
        enable_ticker=enable_ticker,
        enable_sidebar=enable_sidebar,
        audio_mix_mode=audio_mix_mode,
        restart_footage=restart_footage,
        intro_duration=audio_duration,
        total_duration=target_duration,
        current_input_start=current_input_start,
        restart_outro_footage=restart_outro_footage,
        ground_duration=ground_dur,
        outro_duration=outro_dur
    )

    # Build FFmpeg command inputs
    input_args = []
    if video_duration > 0 and video_duration < target_duration:
        input_args.extend(["-stream_loop", "-1"])
    input_args.extend(["-i", video_input_path])

    if has_audio_stream(audio_input_path):
        input_args.extend(["-i", audio_input_path])
    else:
        input_args.extend(["-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo"])

    if has_outro_aud:
        input_args.extend(["-i", outro_audio_path])

    input_args.extend(extra_inputs)

    # Build Broadcast Audio Mixing Filter Graph
    has_video_aud = has_audio_stream(video_input_path)
    footage_vol = max(0.0, min(1.0, float(footage_volume)))

    audio_filters = []
    if not has_anchor_aud:
        if has_video_aud:
            audio_filters.append(f"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,volume=1.0[aout]")
        else:
            audio_filters.append(f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo[aout]")
    elif audio_mix_mode == "voiceover_only" or not has_video_aud or footage_vol <= 0.001:
        if audio_mix_mode == "intro_then_ground_outro" and has_outro_aud:
            audio_filters.append(
                f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur={audio_duration + ground_dur:.2f}[a_in_pad];"
                f"[2:a]aformat=sample_rates=44100:channel_layouts=stereo[a_out_norm];"
                f"[a_in_pad][a_out_norm]concat=n=2:v=0:a=1[aout]"
            )
        else:
            audio_filters.append(f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo[aout]")
    elif audio_mix_mode == "intro_then_ground_outro" and has_outro_aud:
        if restart_footage and restart_outro_footage:
            audio_filters.append(
                f"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,asplit=3[a_raw1][a_raw2][a_raw3];"
                f"[a_raw1]atrim=0:{audio_duration:.2f},asetpts=PTS-STARTPTS,volume={footage_vol:.2f}[a1_cut];"
                f"[a_raw2]atrim=0:{ground_dur:.2f},asetpts=PTS-STARTPTS,volume=1.0[a2_cut];"
                f"[a_raw3]atrim=0:{outro_dur:.2f},asetpts=PTS-STARTPTS,volume={footage_vol:.2f}[a3_cut];"
                f"[a1_cut][a2_cut][a3_cut]concat=n=3:v=0:a=1[footage_stream];"
                f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur={audio_duration + ground_dur:.2f}[a_in_pad];"
                f"[2:a]aformat=sample_rates=44100:channel_layouts=stereo[a_out_norm];"
                f"[a_in_pad][a_out_norm]concat=n=2:v=0:a=1[voice_stream];"
                f"[voice_stream][footage_stream]amix=inputs=2:duration=longest[aout]"
            )
        elif restart_footage and not restart_outro_footage:
            audio_filters.append(
                f"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,asplit=2[a_raw1][a_raw2];"
                f"[a_raw1]atrim=0:{audio_duration:.2f},asetpts=PTS-STARTPTS,volume={footage_vol:.2f}[a1_cut];"
                f"[a_raw2]atrim=0:{ground_dur + outro_dur:.2f},asetpts=PTS-STARTPTS,volume=1.0[a2_cut];"
                f"[a1_cut][a2_cut]concat=n=2:v=0:a=1[a_restarted];"
                f"[a_restarted]volume='if(between(t,{audio_duration:.2f},{audio_duration + ground_dur:.2f}),1.0,{footage_vol:.2f})':eval=frame[footage_stream];"
                f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur={audio_duration + ground_dur:.2f}[a_in_pad];"
                f"[2:a]aformat=sample_rates=44100:channel_layouts=stereo[a_out_norm];"
                f"[a_in_pad][a_out_norm]concat=n=2:v=0:a=1[voice_stream];"
                f"[voice_stream][footage_stream]amix=inputs=2:duration=longest[aout]"
            )
        elif not restart_footage and restart_outro_footage:
            audio_filters.append(
                f"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,asplit=2[a_raw1][a_raw2];"
                f"[a_raw1]atrim=0:{audio_duration + ground_dur:.2f},asetpts=PTS-STARTPTS,volume='if(lt(t,{audio_duration:.2f}),{footage_vol:.2f},1.0)':eval=frame[a12_cut];"
                f"[a_raw2]atrim=0:{outro_dur:.2f},asetpts=PTS-STARTPTS,volume={footage_vol:.2f}[a3_cut];"
                f"[a12_cut][a3_cut]concat=n=2:v=0:a=1[footage_stream];"
                f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur={audio_duration + ground_dur:.2f}[a_in_pad];"
                f"[2:a]aformat=sample_rates=44100:channel_layouts=stereo[a_out_norm];"
                f"[a_in_pad][a_out_norm]concat=n=2:v=0:a=1[voice_stream];"
                f"[voice_stream][footage_stream]amix=inputs=2:duration=longest[aout]"
            )
        else:
            audio_filters.append(
                f"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,volume='if(between(t,{audio_duration:.2f},{audio_duration + ground_dur:.2f}),1.0,{footage_vol:.2f})':eval=frame[footage_stream];"
                f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur={audio_duration + ground_dur:.2f}[a_in_pad];"
                f"[2:a]aformat=sample_rates=44100:channel_layouts=stereo[a_out_norm];"
                f"[a_in_pad][a_out_norm]concat=n=2:v=0:a=1[voice_stream];"
                f"[voice_stream][footage_stream]amix=inputs=2:duration=longest[aout]"
            )
    elif audio_mix_mode == "intro_then_ground":
        if restart_footage:
            audio_filters.append(
                f"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,asplit=2[a_raw1][a_raw2];"
                f"[a_raw1]atrim=0:{audio_duration:.2f},asetpts=PTS-STARTPTS,volume={footage_vol:.2f}[a1t];"
                f"[a_raw2]atrim=0:{ground_dur:.2f},asetpts=PTS-STARTPTS,volume=1.0[a2t];"
                f"[a1t][a2t]concat=n=2:v=0:a=1[a_ground_seq];"
                f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur={target_duration:.2f}[a_vca];"
                f"[a_vca][a_ground_seq]amix=inputs=2:duration=longest[aout]"
            )
        else:
            audio_filters.append(
                f"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,volume='if(lt(t,{audio_duration:.2f}),{footage_vol:.2f},1.0)':eval=frame[a_ground_seq];"
                f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo,apad=whole_dur={target_duration:.2f}[a_vca];"
                f"[a_vca][a_ground_seq]amix=inputs=2:duration=longest[aout]"
            )
    else:  # "voiceover_ambient" default
        audio_filters.append(
            f"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,volume={footage_vol:.2f}[vga];"
            f"[1:a]aformat=sample_rates=44100:channel_layouts=stereo,volume=1.0[vca];"
            f"[vca][vga]amix=inputs=2:duration=first:dropout_transition=2[aout]"
        )

    full_filter_complex = filter_complex + ";" + ";".join(audio_filters)

    cmd = [
        "ffmpeg", "-y",
        *input_args,
        "-filter_complex", full_filter_complex,
        "-map", final_video_stream,
        "-map", "[aout]",
        "-c:v", "libx264",
        "-preset", "veryfast",
        "-crf", "23",
        "-c:a", "aac",
        "-b:a", "192k",
        "-pix_fmt", "yuv420p",
        "-t", str(target_duration),
        "-movflags", "+faststart",
        output_video_path
    ]

    if progress_callback:
        progress_callback(55, "Rendering broadcast video...")

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace"
        )
        _, stderr_output = process.communicate()

        if process.returncode != 0:
            print(f"FFmpeg failed with code {process.returncode}:\n{stderr_output}")
            clean_err = "Video rendering failed. Please ensure the video footage format is supported (MP4/H.264)."
            if "Invalid argument" in stderr_output:
                clean_err = "Video encoding error: unsupported resolution or frame rate in uploaded footage."
            elif "No such file" in stderr_output:
                clean_err = "Required media asset was not found on server."
            elif "Out of memory" in stderr_output or "Cannot allocate memory" in stderr_output:
                clean_err = "Server memory exceeded during rendering. Try a shorter video clip."
            if progress_callback:
                progress_callback(-1, clean_err)
            return False

        if progress_callback:
            progress_callback(96, "Video rendered! Assembling final broadcast container...")
        return True

    except Exception as e:
        print(f"Error during video rendering: {e}")
        if progress_callback:
            progress_callback(-1, "An unexpected error occurred during video rendering. Please try again.")
        return False
    finally:
        # Immediate cleanup of intermediate overlay images and text files
        for tmp in [overlay_img_path, tag_img_path, ticker_txt_path]:
            if tmp and os.path.exists(tmp):
                try:
                    os.remove(tmp)
                except Exception:
                    pass
