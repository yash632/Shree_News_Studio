import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
OUTPUT_FOLDER = os.path.join(BASE_DIR, 'outputs')
FONTS_FOLDER = os.path.join(BASE_DIR, 'fonts')

DEFAULT_FONT = os.path.join(FONTS_FOLDER, 'NotoSansDevanagari.ttf')
if not os.path.exists(DEFAULT_FONT):
    # Windows fallback
    if os.path.exists("C:/Windows/Fonts/mangal.ttf"):
        DEFAULT_FONT = "C:/Windows/Fonts/mangal.ttf"
    elif os.path.exists("C:/Windows/Fonts/arial.ttf"):
        DEFAULT_FONT = "C:/Windows/Fonts/arial.ttf"

DEFAULT_LOGO = os.path.join(BASE_DIR, 'favicon.png')
if not os.path.exists(DEFAULT_LOGO):
    DEFAULT_LOGO = os.path.join(BASE_DIR, 'static', 'favicon.png')
if not os.path.exists(DEFAULT_LOGO):
    DEFAULT_LOGO = None

# Ensure runtime directories exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)
os.makedirs(FONTS_FOLDER, exist_ok=True)

# Max upload size (500MB safe streaming upload)
MAX_CONTENT_LENGTH = 500 * 1024 * 1024

# Auto-load .env if present
_env_path = os.path.join(BASE_DIR, '.env')
if os.path.exists(_env_path):
    try:
        with open(_env_path, 'r', encoding='utf-8') as _f:
            for _line in _f:
                _line = _line.strip()
                if _line and not _line.startswith('#') and '=' in _line:
                    _k, _v = _line.split('=', 1)
                    os.environ.setdefault(_k.strip(), _v.strip().strip("'\""))
    except Exception:
        pass

# AI Configuration
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
MISTRAL_API_KEY = os.environ.get("MISTRAL_API_KEY", "")

def is_low_memory_environment() -> bool:
    """
    Detects if the application is running in a memory-constrained environment
    such as Render.com free tier (512MB RAM) or a container with < 1.5GB RAM.
    On local machines (e.g. user's 16GB laptop), returns False so full 1080p,
    maximum CPU threads, and best quality settings are used.
    """
    if os.environ.get("RENDER") == "true" or "RENDER_SERVICE_ID" in os.environ or "RENDER_INSTANCE_ID" in os.environ:
        return True
    if os.environ.get("PORT") == "10000":
        return True
    env_override = os.environ.get("LOW_MEMORY_MODE", "").lower()
    if env_override in ("true", "1", "yes"):
        return True
    if env_override in ("false", "0", "no"):
        return False
    if os.path.exists("/sys/fs/cgroup/memory.max"):
        try:
            with open("/sys/fs/cgroup/memory.max", "r") as f:
                val = f.read().strip()
                if val != "max" and int(val) < 1500 * 1024 * 1024:
                    return True
        except Exception:
            pass
    if os.path.exists("/sys/fs/cgroup/memory/memory.limit_in_bytes"):
        try:
            with open("/sys/fs/cgroup/memory/memory.limit_in_bytes", "r") as f:
                val = f.read().strip()
                if int(val) < 1500 * 1024 * 1024:
                    return True
        except Exception:
            pass
    if os.path.exists("/proc/meminfo"):
        try:
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        kb = int(line.split()[1])
                        if kb < 1500000:
                            return True
        except Exception:
            pass
    try:
        import psutil
        total_ram_gb = psutil.virtual_memory().total / (1024 ** 3)
        if total_ram_gb < 1.5:
            return True
    except Exception:
        pass
    return False

# Supported Voices for High Quality News Anchors
NEWS_VOICES = [
    {"id": "hi-IN-MadhurNeural", "name": "★ Madhur (Hindi Male - Classic News Anchor) [Edge-TTS]", "lang": "Hindi"},
    {"id": "hi-IN-SwaraNeural", "name": "★ Swara (Hindi Female - Classic News Anchor) [Edge-TTS]", "lang": "Hindi"},
    {"id": "en-US-AndrewMultilingualNeural", "name": "★ Andrew (Deep Male News Broadcaster) [Edge-TTS]", "lang": "Hindi / English"},
    {"id": "en-US-AvaMultilingualNeural", "name": "★ Ava (Prime-time Female Anchor) [Edge-TTS]", "lang": "Hindi / English"},
    {"id": "google-hi", "name": "★ Google Studio (Hindi Female - Smooth & Clear)", "lang": "Hindi"},
    {"id": "en-US-BrianMultilingualNeural", "name": "Brian (Authoritative TV Anchor) [Edge-TTS]", "lang": "Hindi / English"},
    {"id": "en-US-EmmaMultilingualNeural", "name": "Emma (Crisp Studio Anchor) [Edge-TTS]", "lang": "Hindi / English"},
    {"id": "en-IN-PrabhatNeural", "name": "Prabhat (Indian English Male Anchor) [Edge-TTS]", "lang": "Indian English"},
    {"id": "en-IN-NeerjaNeural", "name": "Neerja (Indian English Female Anchor) [Edge-TTS]", "lang": "Indian English"}
]

# Color Themes for News Graphic Layouts
NEWS_THEMES = {
    "red_alert": {
        "name": "Breaking Red (Classic News)",
        "badge_bg": "#D32F2F",
        "badge_text": "#FFFFFF",
        "headline_bg": "#1A1A1A",
        "headline_text": "#FFFFFF",
        "accent": "#FFD700",
        "ticker_bg": "#D32F2F",
        "ticker_text": "#FFFFFF"
    },
    "deep_blue": {
        "name": "Broadcast Blue & Gold",
        "badge_bg": "#0D47A1",
        "badge_text": "#FFFFFF",
        "headline_bg": "#001E3D",
        "headline_text": "#FFFFFF",
        "accent": "#FFC107",
        "ticker_bg": "#0D47A1",
        "ticker_text": "#FFFFFF"
    },
    "dark_gold": {
        "name": "Dark Studio Gold",
        "badge_bg": "#B8860B",
        "badge_text": "#000000",
        "headline_bg": "#121212",
        "headline_text": "#F5F5F5",
        "accent": "#FFD700",
        "ticker_bg": "#1F1F1F",
        "ticker_text": "#FFD700"
    },
    "emerald": {
        "name": "Emerald Channel",
        "badge_bg": "#00796B",
        "badge_text": "#FFFFFF",
        "headline_bg": "#002B24",
        "headline_text": "#FFFFFF",
        "accent": "#A7FFEB",
        "ticker_bg": "#00796B",
        "ticker_text": "#FFFFFF"
    }
}
