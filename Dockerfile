FROM python:3.10-slim

# Avoid interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PORT=7860

# Install FFmpeg and system dependencies (including Hindi fonts)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    fonts-deva \
    fonts-noto-core \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user (required by Hugging Face Spaces)
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR $HOME/app

# Copy requirements and install
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy project files
COPY --chown=user . .

# Ensure upload and output directories exist
RUN mkdir -p uploads outputs

EXPOSE 7860

CMD ["python", "app.py"]
