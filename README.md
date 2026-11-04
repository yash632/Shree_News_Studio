---
title: AI News Broadcast Studio
emoji: 📺
colorFrom: red
colorTo: indigo
sdk: gradio
sdk_version: 5.0.0
app_file: app.py
pinned: false
---

# 📺 AI News Studio - Automated News Video Generator

Ek professional, broadcast-grade **AI News Video Generator Web Platform** jo Facebook, Instagram Reels, YouTube Shorts aur Landscape news videos ko automatically create karta hai.

---

## 🌟 Key Features

1. **Dual Audio Pipeline**:
   - **Mode 1 (Text-to-Speech)**: Script likho aur realistic Hindi/Indian English news anchor voices (`hi-IN-MadhurNeural`, `hi-IN-SwaraNeural`) me audio generate karo.
   - **Mode 2 (Direct Audio Upload)**: Apni recorded voiceover audio file (MP3/WAV/M4A) direct upload karke video sync karo.
2. **Channel Logo Branding**:
   - Apna transparent logo upload karo aur position choose karo (Top-Right, Top-Left, Bottom-Right) + adjustable size slider.
3. **Broadcast News Elements**:
   - **🔴 Top Breaking News Badge**: Custom tag (e.g., `🔴 BREAKING NEWS`, `बड़ी खबर`, `LIVE`).
   - **Main Headline Lower-Third**: Bold headline card with sleek glassmorphism & accent bar.
   - **Animated Crawling Ticker (Marquee)**: Bottom me live TV jaisi smoothly scroll hone wali news ticker line (`x=w-t*speed`).
   - **Auto-Subtitles**: Optional on-screen subtitles.
4. **Multi-Format Support**:
   - **9:16 Vertical Reel / Shorts** (Instagram, FB Reels, YouTube Shorts)
   - **16:9 Landscape Video** (Facebook Watch, YouTube standard)
5. **Ultra-Low Memory Architecture (Render Free 512MB RAM Ready)**:
   - Memory-heavy video processing libraries use nahi ki gayi hain.
   - Direct FFmpeg streaming pipelines use hoti hain jo **< 60MB RAM** leti hain, isliye **Render ke 512MB Free Tier** par bina kisi crash ke smooth chalti hain.
   - Background non-blocking job worker hai jisse 30s HTTP request timeout ki problem nahi aati.

---

## 📁 Project Structure

```
News_Creation/
├── app.py                     # Main Flask server & API endpoints
├── config.py                  # Settings, themes, voices & paths
├── run.bat                    # 1-Click local runner for Windows
├── test_pipeline.py           # Automated end-to-end verification script
├── requirements.txt           # Lightweight dependencies for deployment
├── Dockerfile                 # Render Free Tier Docker deployment
├── render.yaml                # 1-Click Render Blueprint
├── services/
│   ├── tts_service.py         # Edge-TTS voice generation & SRT subtitles
│   ├── overlay_service.py     # Pillow broadcast lower-thirds & badges
│   ├── video_engine.py        # Low-memory FFmpeg video compositor & ticker
│   └── job_manager.py         # Asynchronous job queue & status tracker
├── templates/
│   └── index.html             # Broadcast Studio Web UI
├── static/
│   ├── css/style.css          # Dark broadcast glassmorphic styling
│   └── js/app.js              # Real-time mockup sync & polling logic
└── fonts/
    └── NotoSansDevanagari.ttf # Universal Hindi & English font
```

---

## 💻 Local Machine Par Kaise Chalayein?

Aapke system me Flask, FFmpeg aur Edge-TTS pehle se available hain. Koi bhi naya package install karne ki zaroorat nahi hai.

### Option 1: 1-Click Run
Folder me **`run.bat`** file par double-click karein.

### Option 2: Terminal se Run
```bash
python app.py
```
Browser me open karein: **`http://localhost:5000`**

---

## ☁️ Render Free Plan Par Kaise Host Karein?

Render par is platform ko Docker environment me host kiya ja sakta hai (Render ke Free Web Service plan me Docker 100% free hai aur isme FFmpeg pre-installed build hota hai):

### Step-by-Step Deployment:
1. Apna project **GitHub** par push karein:
   ```bash
   git init
   git add .
   git commit -m "AI News Studio initial commit"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<repo-name>.git
   git push -u origin main
   ```
2. **[Render.com](https://render.com)** par login karein.
3. **New +** button par click karke **Web Service** select karein.
4. Apni GitHub repository choose karein.
5. Settings:
   - **Environment**: `Docker` (Render automatically repository ke `Dockerfile` ko detect kar lega).
   - **Plan**: `Free` (512 MB RAM).
   - **Region**: Any (e.g. Oregon or Frankfurt).
6. **Create Web Service** par click karein.
7. 2-3 minute me build complete ho jayega aur aapko aapki free live URL mil jayegi (e.g. `https://ai-news-studio.onrender.com`).

---

## 🧪 Pipeline Verification

Platform ka complete end-to-end test karne ke liye:
```bash
python test_pipeline.py
```
Yeh script automatically 9:16 aur 16:9 dono formats me TTS, overlays, logos aur animated marquee ticker render karke verify karti hai.
