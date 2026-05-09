"""
ChromaGuide Backend - Flask API v5.0
=====================================
Production-grade backend with:
  ✅ Exponential backoff retry for 429 errors
  ✅ Image compression to reduce token usage
  ✅ In-memory cache to prevent duplicate API calls
  ✅ Google Gemini 2.0 Flash (free tier)

Environment Variables Required:
  - GEMINI_API_KEY: Your Google Gemini API key (free from aistudio.google.com)
"""

import os
import io
import uuid
import time
import hashlib
import logging
from datetime import datetime, timezone
from pathlib import Path
from functools import lru_cache
from collections import OrderedDict
import threading

from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename

from google import genai
from google.genai import types

# ---------------------------------------------------------------------------
# Image processing — Pillow (optional but recommended)
# ---------------------------------------------------------------------------
try:
    from PIL import Image
    PILLOW_AVAILABLE = True
except ImportError:
    PILLOW_AVAILABLE = False

ANTIGRAVITY_LOADED = True  # 🥚 Easter egg flag

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
app = Flask(__name__)
CORS(app)

app.config["SECRET_KEY"] = os.getenv("FLASK_SECRET_KEY", "chromaguide-hackathon-2026")
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16 MB

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "webp", "gif"}

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("chromaguide")

# Initialize Gemini client
client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

# ---------------------------------------------------------------------------
# In-Memory Cache (Thread-safe, LRU, TTL-based)
# ---------------------------------------------------------------------------
class AnalysisCache:
    """Simple thread-safe in-memory cache with TTL and max size."""

    def __init__(self, max_size=50, ttl_seconds=300):
        self._cache = OrderedDict()
        self._lock = threading.Lock()
        self.max_size = max_size
        self.ttl = ttl_seconds  # 5 minutes default

    def _make_key(self, image_bytes: bytes, zero_g: bool) -> str:
        """Create a hash key from image content + mode."""
        h = hashlib.md5(image_bytes).hexdigest()
        return f"{h}_{zero_g}"

    def get(self, image_bytes: bytes, zero_g: bool):
        key = self._make_key(image_bytes, zero_g)
        with self._lock:
            if key in self._cache:
                entry = self._cache[key]
                if time.time() - entry["ts"] < self.ttl:
                    self._cache.move_to_end(key)
                    logger.info("🎯 Cache HIT — skipping Gemini API call")
                    return entry["result"]
                else:
                    del self._cache[key]  # Expired
        return None

    def put(self, image_bytes: bytes, zero_g: bool, result: str):
        key = self._make_key(image_bytes, zero_g)
        with self._lock:
            if len(self._cache) >= self.max_size:
                self._cache.popitem(last=False)  # Remove oldest
            self._cache[key] = {"result": result, "ts": time.time()}

    @property
    def size(self):
        return len(self._cache)


# Global cache instance
cache = AnalysisCache(max_size=50, ttl_seconds=300)

# ---------------------------------------------------------------------------
# Retry Configuration
# ---------------------------------------------------------------------------
MAX_RETRIES = 3
INITIAL_BACKOFF = 2    # seconds
BACKOFF_MULTIPLIER = 2  # exponential: 2s, 4s, 8s

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
SYSTEM_PROMPT = """You are ChromaGuide, a highly descriptive fashion and color-matching assistant designed specifically for blind and visually impaired users.

Analyze the outfit in the image and structure your response EXACTLY like this:

Outfit Overview:
[2-3 sentence high-level description]

Colors Detected:
- [Item]: [Color description]

Color Harmony Score: [X] out of 10
[1-2 sentence explanation]

Style Notes:
[2-3 sentences on fit, texture, overall vibe]

Recommendations:
1. [Suggestion 1]
2. [Suggestion 2]

Occasion: [Casual / Business / Formal / Outdoor / etc.]

Rules: Use PLAIN TEXT only. Keep under 250 words. Be warm and clear."""

ZERO_G_ADDON = """

ZERO-GRAVITY MODE: Also add this section:

Zero-G Safety Report:
- Float Risk: [Low / Medium / High]
- [List hazard items]

Space-Readiness Score: [X] out of 10
[Explanation]

Antigravity Recommendation:
[Modification for zero-G safety]"""


def build_prompt(zero_g_mode: bool) -> str:
    prompt = SYSTEM_PROMPT
    if zero_g_mode:
        prompt += ZERO_G_ADDON
    return prompt


# ---------------------------------------------------------------------------
# Image Preprocessing — Compress to reduce tokens & cost
# ---------------------------------------------------------------------------
def compress_image(image_bytes: bytes, max_size=800, quality=70) -> tuple:
    """
    Compress and resize image to reduce Gemini token usage.
    - Resize so longest edge <= max_size pixels
    - Convert to JPEG at given quality
    - Returns (compressed_bytes, mime_type)
    """
    if not PILLOW_AVAILABLE:
        logger.warning("Pillow not installed — sending original image (larger tokens)")
        return image_bytes, "image/jpeg"

    try:
        img = Image.open(io.BytesIO(image_bytes))

        # Convert RGBA/P to RGB for JPEG
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")

        # Resize if larger than max_size
        w, h = img.size
        if max(w, h) > max_size:
            ratio = max_size / max(w, h)
            new_w, new_h = int(w * ratio), int(h * ratio)
            img = img.resize((new_w, new_h), Image.LANCZOS)
            logger.info(f"📐 Resized: {w}x{h} → {new_w}x{new_h}")

        # Compress to JPEG
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=quality, optimize=True)
        compressed = buf.getvalue()

        original_kb = len(image_bytes) / 1024
        compressed_kb = len(compressed) / 1024
        logger.info(f"🗜️ Compressed: {original_kb:.0f}KB → {compressed_kb:.0f}KB "
                     f"({(1 - compressed_kb/original_kb)*100:.0f}% smaller)")

        return compressed, "image/jpeg"

    except Exception as e:
        logger.warning(f"Compression failed, using original: {e}")
        return image_bytes, "image/jpeg"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def call_gemini_with_retry(image_bytes: bytes, mime_type: str, prompt: str) -> str:
    """
    Call Gemini API with exponential backoff retry on 429 errors.
    Retries up to MAX_RETRIES times: 2s, 4s, 8s delays.
    """
    last_error = None
    backoff = INITIAL_BACKOFF

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            logger.info(f"🤖 Gemini API call (attempt {attempt}/{MAX_RETRIES})")

            response = client.models.generate_content(
                model="gemini-1.5-flash",
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                    types.Part.from_text(text=prompt),
                ],
            )

            logger.info(f"✅ Gemini responded on attempt {attempt}")
            return response.text

        except Exception as e:
            last_error = e
            error_str = str(e)

            # Check if it's a rate limit (429) error
            if "429" in error_str or "RESOURCE_EXHAUSTED" in error_str:
                if attempt < MAX_RETRIES:
                    logger.warning(f"⏳ Rate limited (429). Retrying in {backoff}s "
                                   f"(attempt {attempt}/{MAX_RETRIES})...")
                    time.sleep(backoff)
                    backoff *= BACKOFF_MULTIPLIER
                    continue
                else:
                    logger.error(f"❌ Rate limited after {MAX_RETRIES} retries")
                    raise Exception(
                        "The AI service is temporarily busy. "
                        "Please wait 30 seconds and try again."
                    )
            else:
                # Non-retryable error — fail immediately
                logger.error(f"❌ Non-retryable error: {error_str}")
                raise

    raise last_error


def analyze_with_gemini(image_bytes: bytes, zero_g_mode: bool) -> str:
    """
    Full analysis pipeline:
    1. Check cache → return immediately if found
    2. Compress image → reduce token usage
    3. Call Gemini with retry → handle 429 errors
    4. Cache result → prevent duplicate calls
    """
    # Step 1: Check cache
    cached = cache.get(image_bytes, zero_g_mode)
    if cached:
        return cached

    # Step 2: Compress image
    compressed_bytes, mime_type = compress_image(image_bytes)

    # Step 3: Call Gemini with retry
    prompt = build_prompt(zero_g_mode)
    result = call_gemini_with_retry(compressed_bytes, mime_type, prompt)

    # Step 4: Cache the result
    cache.put(image_bytes, zero_g_mode, result)

    return result


# ---------------------------------------------------------------------------
# API Endpoints
# ---------------------------------------------------------------------------
@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "healthy",
        "service": "ChromaGuide API",
        "version": "5.1.0",
        "ai_model": "Google Gemini 1.5 Flash (Free)",
        "features": [
            "exponential_backoff_retry",
            "image_compression",
            "in_memory_cache",
        ],
        "cache_entries": cache.size,
        "tts": "on-device (expo-speech)",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })


@app.route("/analyze", methods=["POST"])
def analyze_outfit():
    if "image" not in request.files:
        return jsonify({"success": False, "error": "No image file provided."}), 400

    file = request.files["image"]
    if file.filename == "":
        return jsonify({"success": False, "error": "Empty filename."}), 400

    if not allowed_file(file.filename):
        return jsonify({"success": False, "error": "Unsupported file type."}), 400

    zero_g_mode = request.form.get("zero_g_mode", "false").lower() == "true"

    # Read image bytes directly (no need to save to disk first)
    image_bytes = file.read()
    logger.info(f"📸 Image received: {len(image_bytes)/1024:.0f}KB | Zero-G: {zero_g_mode}")

    try:
        analysis_text = analyze_with_gemini(image_bytes, zero_g_mode)
        logger.info("🎉 Analysis complete!")

        return jsonify({
            "success": True,
            "analysis_text": analysis_text,
            "zero_g_mode": zero_g_mode,
            "antigravity_easter_egg": zero_g_mode,
        }), 200

    except Exception as e:
        logger.error(f"💥 Analysis error: {e}")

        # Give user-friendly error for rate limits
        error_msg = str(e)
        if "busy" in error_msg.lower() or "429" in error_msg or "RESOURCE" in error_msg:
            return jsonify({
                "success": False,
                "error": "The AI service is temporarily busy. Please wait 30 seconds and try again."
            }), 429
        else:
            return jsonify({
                "success": False,
                "error": f"Debug Error: {str(e)}"
            }), 500


# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_ENV", "development") == "development"
    logger.info(f"🚀 ChromaGuide API v5.0 | Gemini 2.0 Flash | Retry + Cache + Compression")
    app.run(host="0.0.0.0", port=port, debug=debug)
