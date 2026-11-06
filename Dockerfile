FROM python:3.10-slim

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=5000
ENV RENDER=true
ENV LOW_MEMORY_MODE=true

# Install FFmpeg, Chromium for Web UI HTML overlay rendering, and Hindi fonts
RUN apt-get update && apt-get install -y \
    ffmpeg \
    chromium \
    fonts-deva \
    fonts-dejavu-core \
    fonts-noto-core \
    fonts-freefont-ttf \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Ensure upload/output directories exist
RUN mkdir -p uploads outputs fonts

EXPOSE 5000

# Run with Gunicorn (1 worker, 4 threads for ultra-low memory under 512MB RAM, 10-min timeout for long renders)
CMD exec gunicorn --bind 0.0.0.0:${PORT:-5000} --workers 1 --threads 4 --timeout 600 app:app
