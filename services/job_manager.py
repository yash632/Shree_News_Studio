import os
import time
import threading
import uuid
from typing import Dict, Any, Optional
from config import UPLOAD_FOLDER, OUTPUT_FOLDER
from services.tts_service import generate_tts_audio
from services.video_engine import render_news_video

class JobManager:
    def __init__(self, progress_emitter=None):
        self.jobs: Dict[str, Dict[str, Any]] = {}
        self.lock = threading.Lock()
        self.progress_emitter = progress_emitter

    def set_progress_emitter(self, emitter):
        self.progress_emitter = emitter

    def create_job(self) -> str:
        job_id = str(uuid.uuid4())[:8]
        with self.lock:
            self.jobs[job_id] = {
                "id": job_id,
                "status": "queued",
                "progress": 0,
                "message": "Queued for processing...",
                "created_at": time.time(),
                "output_video": f"news_{job_id}.mp4",
                "error": None
            }
        return job_id

    def get_job_status(self, job_id: str) -> Optional[Dict[str, Any]]:
        with self.lock:
            job = self.jobs.get(job_id)
            return dict(job) if job else None

    def update_progress(self, job_id: str, progress: int, message: str):
        job_snapshot = None
        with self.lock:
            if job_id in self.jobs:
                if progress == -1:
                    self.jobs[job_id]["status"] = "failed"
                    self.jobs[job_id]["error"] = message
                elif progress >= 100:
                    self.jobs[job_id]["status"] = "completed"
                    self.jobs[job_id]["progress"] = 100
                    self.jobs[job_id]["message"] = message
                else:
                    self.jobs[job_id]["status"] = "processing"
                    self.jobs[job_id]["progress"] = progress
                    self.jobs[job_id]["message"] = message
                job_snapshot = dict(self.jobs[job_id])

        if job_snapshot and self.progress_emitter:
            try:
                self.progress_emitter(job_id, job_snapshot)
            except Exception as e:
                print(f"[SocketIO] Error emitting progress for {job_id}: {e}")

    def process_job_async(
        self,
        job_id: str,
        video_path: str,
        audio_mode: str,
        tts_text: str,
        tts_voice: str,
        tts_speed: float,
        uploaded_audio_path: Optional[str],
        badge_text: str,
        headline_text: str,
        sub_headline: str,
        ticker_text: str,
        ticker_tag: str,
        theme_key: str,
        aspect_ratio: str,
        logo_path: Optional[str],
        enable_top_bar: bool,
        enable_sidebar: bool,
        sidebar_items: Optional[list],
        enable_location: bool,
        location_text: str,
        enable_datetime: bool,
        time_text: str,
        date_text: str,
        day_text: str,
        enable_anchor: bool,
        enable_ticker: bool = True,
        frame_x: int = 1122,
        frame_y: int = 182,
        frame_w: int = 770,
        frame_h: int = 567,
        audio_mix_mode: str = "voiceover_ambient",
        footage_volume: float = 0.20,
        ground_clip_duration: float = 10.0,
        restart_footage: bool = False,
        outro_text: str = "",
        restart_outro_footage: bool = False,
        mute_during_anchor: bool = True
    ):
        thread = threading.Thread(
            target=self._run_job,
            args=(
                job_id,
                video_path,
                audio_mode,
                tts_text,
                tts_voice,
                tts_speed,
                uploaded_audio_path,
                badge_text,
                headline_text,
                sub_headline,
                ticker_text,
                ticker_tag,
                theme_key,
                aspect_ratio,
                logo_path,
                enable_top_bar,
                enable_sidebar,
                sidebar_items,
                enable_location,
                location_text,
                enable_datetime,
                time_text,
                date_text,
                day_text,
                enable_anchor,
                enable_ticker,
                frame_x,
                frame_y,
                frame_w,
                frame_h,
                audio_mix_mode,
                footage_volume,
                ground_clip_duration,
                restart_footage,
                outro_text,
                restart_outro_footage,
                mute_during_anchor
            ),
            daemon=True
        )
        thread.start()

    def _run_job(
        self,
        job_id: str,
        video_path: str,
        audio_mode: str,
        tts_text: str,
        tts_voice: str,
        tts_speed: float,
        uploaded_audio_path: Optional[str],
        badge_text: str,
        headline_text: str,
        sub_headline: str,
        ticker_text: str,
        ticker_tag: str,
        theme_key: str,
        aspect_ratio: str,
        logo_path: Optional[str],
        enable_top_bar: bool,
        enable_sidebar: bool,
        sidebar_items: Optional[list],
        enable_location: bool,
        location_text: str,
        enable_datetime: bool,
        time_text: str,
        date_text: str,
        day_text: str,
        enable_anchor: bool,
        enable_ticker: bool = True,
        frame_x: int = 1122,
        frame_y: int = 182,
        frame_w: int = 770,
        frame_h: int = 567,
        audio_mix_mode: str = "voiceover_ambient",
        footage_volume: float = 0.20,
        ground_clip_duration: float = 10.0,
        restart_footage: bool = False,
        outro_text: str = "",
        restart_outro_footage: bool = False,
        mute_during_anchor: bool = True
    ):
        audio_path = None
        try:
            self.update_progress(job_id, 5, "Preparing media assets...")
            output_video_path = os.path.join(OUTPUT_FOLDER, f"news_{job_id}.mp4")

            # 1. Synthesize or fetch audio
            if audio_mode == "tts":
                if not tts_text:
                    audio_path = None
                    self.update_progress(job_id, 30, "No script provided — using footage audio & broadcast graphics...")
                else:
                    self.update_progress(job_id, 6, "Starting voiceover synthesis...")
                    audio_path = os.path.join(UPLOAD_FOLDER, f"{job_id}_speech.mp3")

                    # Run TTS in a sub-thread so we can pulse the progress bar
                    tts_done = threading.Event()
                    tts_success_holder = [False]

                    def _do_tts():
                        tts_success_holder[0] = generate_tts_audio(
                            text=tts_text,
                            voice=tts_voice,
                            output_audio_path=audio_path,
                            speed=tts_speed
                        )
                        tts_done.set()

                    tts_thread = threading.Thread(target=_do_tts, daemon=True)
                    tts_thread.start()

                    # Pulse 6% → 28% while TTS is running
                    pulse_pct = 6
                    pulse_messages = [
                        "Generating news voiceover...",
                        "Azure Edge-TTS synthesizing...",
                        "Streaming audio from Azure...",
                        "Finalizing voiceover audio..."
                    ]
                    msg_idx = 0
                    while not tts_done.wait(timeout=1.5):
                        pulse_pct = min(28, pulse_pct + 3)
                        self.update_progress(job_id, pulse_pct, pulse_messages[msg_idx % len(pulse_messages)])
                        msg_idx += 1

                    tts_thread.join()
                    if not tts_success_holder[0]:
                        self.update_progress(job_id, -1, "Voiceover generation failed.")
                        return
                    self.update_progress(job_id, 30, "Voiceover ready! Preparing overlay renders...")
            else:
                if not uploaded_audio_path or not os.path.exists(uploaded_audio_path):
                    self.update_progress(job_id, -1, "Uploaded audio file not found.")
                    return
                audio_path = uploaded_audio_path

            # 2. Outro speech synthesis for Mode 3 (3-Stage TV Package)
            outro_audio_path = None
            if audio_mix_mode == "intro_then_ground_outro":
                self.update_progress(job_id, 32, "Synthesizing anchor outro audio...")
                outro_audio_path = os.path.join(UPLOAD_FOLDER, f"{job_id}_outro_speech.mp3")
                final_outro_text = outro_text.strip() if outro_text and outro_text.strip() else "अभी के लिए इतना ही। देश और दुनिया की सभी बड़ी खबरों के लिए देखते रहिए श्री NEWS Twenty Four by Seven।"
                outro_success = generate_tts_audio(
                    text=final_outro_text,
                    voice=tts_voice,
                    output_audio_path=outro_audio_path,
                    speed=tts_speed
                )
                if not outro_success:
                    print(f"Warning: Outro TTS failed for job {job_id}")
                    outro_audio_path = None

            # 3. Render broadcast video
            def progress_cb(pct, msg):
                self.update_progress(job_id, pct, msg)

            render_success = render_news_video(
                video_input_path=video_path,
                audio_input_path=audio_path,
                output_video_path=output_video_path,
                badge_text=badge_text,
                headline_text=headline_text,
                sub_headline=sub_headline,
                ticker_text=ticker_text,
                ticker_tag=ticker_tag,
                theme_key=theme_key,
                aspect_ratio=aspect_ratio,
                logo_input_path=logo_path,
                enable_top_bar=enable_top_bar,
                enable_sidebar=enable_sidebar,
                sidebar_items=sidebar_items,
                enable_location=enable_location,
                location_text=location_text,
                enable_datetime=enable_datetime,
                time_text=time_text,
                date_text=date_text,
                day_text=day_text,
                enable_anchor=enable_anchor,
                enable_ticker=enable_ticker,
                frame_x=frame_x,
                frame_y=frame_y,
                frame_w=frame_w,
                frame_h=frame_h,
                audio_mix_mode=audio_mix_mode,
                footage_volume=footage_volume,
                ground_clip_duration=ground_clip_duration,
                restart_footage=restart_footage,
                outro_audio_path=outro_audio_path,
                restart_outro_footage=restart_outro_footage,
                mute_during_anchor=mute_during_anchor,
                progress_callback=progress_cb
            )

            if render_success:
                with self.lock:
                    self.jobs[job_id]["output_video"] = f"news_{job_id}.mp4"
                self.update_progress(job_id, 100, "Your professional news video is ready!")
            else:
                current_job = self.get_job_status(job_id)
                current_err = current_job.get("error") if current_job else None
                if not current_err:
                    self.update_progress(job_id, -1, "Video compilation failed. Please verify your video footage and settings.")

        except Exception as e:
            print(f"Exception in job {job_id}: {e}")
            self.update_progress(job_id, -1, "An unexpected server error occurred during processing. Please try again.")
        finally:
            # Immediate cleanup of raw uploaded assets to prevent disk fill-up on server
            for tmp_file in [video_path, audio_path, locals().get("outro_audio_path")]:
                if tmp_file and os.path.exists(tmp_file):
                    try:
                        os.remove(tmp_file)
                    except Exception:
                        pass

job_manager = JobManager()
