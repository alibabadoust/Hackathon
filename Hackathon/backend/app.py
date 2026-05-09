"""
ChromaGuide Backend - Flask API
================================
Backend server that handles image analysis via Google Gemini Vision API (FREE).
Uses the latest google-genai SDK.

Environment Variables Required:
  - GEMINI_API_KEY: Your Google Gemini API key (free from aistudio.google.com)
"""

import os
import uuid
import base64
import logging
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename

from google import genai
from google.genai import types

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
# Helpers
# ---------------------------------------------------------------------------
def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def analyze_with_gemini(image_path: Path, zero_g_mode: bool) -> str:
    """Send the image to Google Gemini 2.0 Flash and return analysis text."""
    with open(image_path, "rb") as f:
        image_bytes = f.read()

    ext = image_path.suffix.lower().lstrip(".")
    mime_map = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
                "webp": "image/webp", "gif": "image/gif"}
    mime_type = mime_map.get(ext, "image/jpeg")

    prompt = build_prompt(zero_g_mode)

    response = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=[
            types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
            types.Part.from_text(text=prompt),
        ],
    )

    return response.text


# ---------------------------------------------------------------------------
# API Endpoints
# ---------------------------------------------------------------------------
@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "healthy",
        "service": "ChromaGuide API",
        "version": "4.0.0",
        "ai_model": "Google Gemini 2.0 Flash (Free)",
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

    filename = secure_filename(file.filename)
    unique_name = f"{uuid.uuid4().hex}_{filename}"
    image_path = UPLOAD_DIR / unique_name
    file.save(str(image_path))
    logger.info(f"Image received | Zero-G: {zero_g_mode}")

    try:
        analysis_text = analyze_with_gemini(image_path, zero_g_mode)
        logger.info("Gemini 2.0 Flash analysis complete ✅")

        return jsonify({
            "success": True,
            "analysis_text": analysis_text,
            "zero_g_mode": zero_g_mode,
            "antigravity_easter_egg": zero_g_mode,
        }), 200

    except Exception as e:
        logger.error(f"Analysis error: {e}")
        return jsonify({
            "success": False,
            "error": f"Analysis failed: {str(e)}"
        }), 500

    finally:
        if image_path.exists():
            image_path.unlink()


# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_ENV", "development") == "development"
    logger.info(f"🚀 ChromaGuide API v4.0 starting on port {port} — Gemini 2.0 Flash!")
    app.run(host="0.0.0.0", port=port, debug=debug)
