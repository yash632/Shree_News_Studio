import os
import time
import threading
from config import UPLOAD_FOLDER, OUTPUT_FOLDER

# Maximum allowed disk usage for generated outputs (150 MB safe limit for Render free tier)
MAX_OUTPUT_DIR_BYTES = 150 * 1024 * 1024  

# Maximum age of temporary files before automatic garbage collection (15 minutes)
MAX_FILE_AGE_SECONDS = 15 * 60  

def get_dir_size(folder_path: str) -> int:
    """Calculates total byte size of a folder."""
    total = 0
    if not os.path.exists(folder_path):
        return 0
    for root, _, files in os.walk(folder_path):
        for f in files:
            fp = os.path.join(root, f)
            if not os.path.islink(fp):
                try:
                    total += os.path.getsize(fp)
                except OSError:
                    pass
    return total

def cleanup_expired_files():
    """
    Cleans up files older than MAX_FILE_AGE_SECONDS from uploads and outputs.
    Enforces a strict FIFO size quota to prevent server disk overflow.
    """
    now = time.time()
    
    # 1. Purge expired files from uploads
    for folder in [UPLOAD_FOLDER, OUTPUT_FOLDER]:
        if not os.path.exists(folder):
            continue
        for fname in os.listdir(folder):
            if fname.startswith('.'):
                continue
            fpath = os.path.join(folder, fname)
            try:
                if os.path.isfile(fpath):
                    file_age = now - os.path.getmtime(fpath)
                    # Voice previews expire even faster (after 5 mins)
                    is_preview = fname.startswith('preview_')
                    max_age = (5 * 60) if is_preview else MAX_FILE_AGE_SECONDS
                    if file_age > max_age:
                        os.remove(fpath)
            except Exception as e:
                pass

    # 2. Strict FIFO size cap on output folder
    current_size = get_dir_size(OUTPUT_FOLDER)
    if current_size > MAX_OUTPUT_DIR_BYTES:
        files = []
        for fname in os.listdir(OUTPUT_FOLDER):
            if fname.startswith('.'):
                continue
            fp = os.path.join(OUTPUT_FOLDER, fname)
            if os.path.isfile(fp):
                files.append((fp, os.path.getmtime(fp)))
        
        # Sort oldest first
        files.sort(key=lambda x: x[1])
        for fp, _ in files:
            if current_size <= MAX_OUTPUT_DIR_BYTES * 0.75:
                break
            try:
                sz = os.path.getsize(fp)
                os.remove(fp)
                current_size -= sz
            except Exception:
                pass

def start_cleanup_daemon(interval_seconds: int = 180):
    """Starts a non-blocking background daemon thread to maintain disk space."""
    def run_loop():
        while True:
            try:
                cleanup_expired_files()
            except Exception as e:
                print(f"Background cleanup error: {e}")
            time.sleep(interval_seconds)

    thread = threading.Thread(target=run_loop, daemon=True, name="DiskCleanupDaemon")
    thread.start()
