import asyncio
import os
import sys
import re
import urllib.request
import urllib.parse
import edge_tts
from config import NEWS_VOICES

def _get_or_create_event_loop():
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    try:
        loop = asyncio.get_event_loop()
        if loop.is_closed():
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        return loop
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        return loop

async def _synthesize_edge_fast(text: str, voice: str, output_audio_path: str, rate_str: str = "+0%"):
    """
    Fast streaming Edge-TTS synthesis directly to disk.
    Applies speed adjustment natively inside Azure servers with zero FFmpeg overhead.
    """
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

    communicate = edge_tts.Communicate(text=text, voice=voice, rate=rate_str)
    await communicate.save(output_audio_path)

def _generate_google_hindi_fast(text: str, output_path: str) -> bool:
    """Fast Google TTS streaming for Hindi text."""
    parts = re.split(r'([।!?,\n]+)', text)
    chunks = []
    curr = ''
    for p in parts:
        if len(curr) + len(p) < 130:
            curr += p
        else:
            if curr.strip():
                chunks.append(curr.strip())
            curr = p
    if curr.strip():
        chunks.append(curr.strip())

    if not chunks:
        chunks = [text.strip()[:140]]

    with open(output_path, 'wb') as out_f:
        for chunk in chunks:
            if not chunk.strip():
                continue
            encoded = urllib.parse.quote(chunk.strip())
            url = f"https://translate.google.com/translate_tts?ie=UTF-8&q={encoded}&tl=hi&client=tw-ob"
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            try:
                with urllib.request.urlopen(req, timeout=5) as resp:
                    out_f.write(resp.read())
            except Exception as e:
                print(f"Google TTS chunk error: {e}")

    return os.path.exists(output_path) and os.path.getsize(output_path) > 0

def generate_tts_audio(text: str, voice: str, output_audio_path: str, output_srt_path: str = None, speed: float = 1.0) -> bool:
    """
    Ultra-fast TTS audio generation with native streaming speed control.
    """
    clean_text = text.strip()
    if not clean_text:
        return False

    # Calculate native rate string (+20%, -10%, etc.)
    percent = int(round((speed - 1.0) * 100))
    rate_str = f"+{percent}%" if percent >= 0 else f"{percent}%"

    if voice == "google-hi":
        return _generate_google_hindi_fast(clean_text, output_audio_path)

    # Fast Edge-TTS
    loop = _get_or_create_event_loop()
    try:
        loop.run_until_complete(_synthesize_edge_fast(
            text=clean_text,
            voice=voice,
            output_audio_path=output_audio_path,
            rate_str=rate_str
        ))
        return os.path.exists(output_audio_path) and os.path.getsize(output_audio_path) > 0
    except Exception as e:
        print(f"Edge-TTS streaming failed ({e}), using fast Google voice fallback...")
        return _generate_google_hindi_fast(clean_text, output_audio_path)

def get_available_voices():
    """Returns curated news anchor voices."""
    return NEWS_VOICES
