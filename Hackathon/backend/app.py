"""
ChromaGuide Backend - Flask API
================================
Backend server that handles image analysis via Google Gemini Vision API (FREE).
Text-to-speech is handled on the device using expo-speech.

Environment Variables Required:
  - GEMINI_API_KEY: Your Google Gemini API key (free from aistudio.google.com)

Endpoints:
  POST /analyze     — Upload an image for outfit analysis
  GET  /health      — Health check
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

import google.generativeai as genai

ANTIGRAVITY_LOADED = True  # 🥚 Easter egg flag

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
app = Flask(__name__)
CORS(app)

app.config["SECRET_KEY"] = os.getenv("FLASK_SECRET_KEY", "chromaguide-hackathon-2026")
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16 MB max upload

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "webp", "gif"}

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("chromaguide")

# Configure Gemini
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# ---------------------------------------------------------------------------
# System Prompt
# ---------------------------------------------------------------------------
SYSTEM_PROMPT_BASE = """You are ChromaGuide, a highly descriptive fashion and color-matching assistant designed specifically for blind and visually impaired users.

Your Core Responsibilities:
1. Color Identification - Describe every visible color in the outfit using vivid, everyday language (e.g., "sky blue", "warm honey gold", "charcoal grey"). Avoid hex codes or technical jargon.
2. Garment Description - Identify each clothing item (shirt, trousers, jacket, shoes, accessories, etc.) and describe its style, fit, and texture if visible.
3. Color Compatibility Rating - Rate the overall color harmony on a scale of 1-10 and explain why (complementary, analogous, clashing, etc.).
4. Practical Recommendations - Suggest 1-2 small changes that could improve the outfit.
5. Occasion Suitability - Briefly note whether the outfit works for casual, business, formal, or outdoor settings.

Structure your response EXACTLY like this:

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

Important: Use PLAIN TEXT only. Keep your total response under 250 words. Speak warmly and clearly."""

ZERO_G_ADDON = """

ZERO-GRAVITY MODE ACTIVATED - Also evaluate the outfit for zero-gravity safety:

6. Float Risk Assessment - Identify any loose items that would float or become hazards in microgravity.
7. Space Aesthetic Rating - Rate the outfit Space-Readiness on a scale of 1-10.
8. Antigravity Recommendation - Suggest one modification for zero-G safety.

Add this section:

Zero-G Safety Report:
- Float Risk: [Low / Medium / High]
- [List each hazard]

Space-Readiness Score: [X] out of 10
[Explanation]

Antigravity Recommendation:
[Your suggestion]"""


def build_prompt(zero_g_mode: bool) -> str:
    prompt = SYSTEM_PROMPT_BASE
    if zero_g_mode:
        prompt += ZERO_G_ADDON
    return prompt


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def analyze_with_gemini(image_path: Path, zero_g_mode: bool) -> str:
    """Send the image to Google Gemini Vision API and return analysis text."""
    model = genai.GenerativeModel("gemini-2.0-flash")

    # Read and base64-encode image
    with open(image_path, "rb") as f:
        image_data = base64.b64encode(f.read()).decode("utf-8")

    # Determine MIME type
    ext = image_path.suffix.lower().lstrip(".")
    mime_map = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
                "webp": "image/webp", "gif": "image/gif"}
    mime_type = mime_map.get(ext, "image/jpeg")

    prompt = build_prompt(zero_g_mode)
    if zero_g_mode:
        prompt += "\n\nPlease analyze this outfit image. Zero-Gravity Mode is ACTIVE."
    else:
        prompt += "\n\nPlease analyze this outfit image."

    response = model.generate_content([
        {
            "inline_data": {
                "mime_type": mime_type,
                "data": image_data
            }
        },
        prompt
    ])

    return response.text


# ---------------------------------------------------------------------------
# API Endpoints
# ---------------------------------------------------------------------------
@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "service": "ChromaGuide API",
        "version": "3.0.0",
        "ai_model": "Google Gemini 1.5 Flash (Free)",
        "tts": "on-device (expo-speech)",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "antigravity_loaded": ANTIGRAVITY_LOADED,
    })


@app.route("/analyze", methods=["POST"])
def analyze_outfit():
    """
    Main endpoint: accepts an image and returns outfit analysis.
    Uses Google Gemini Vision (free tier).
    """
    if "image" not in request.files:
        return jsonify({"success": False, "error": "No image file provided."}), 400

    file = request.files["image"]
    if file.filename == "":
        return jsonify({"success": False, "error": "Empty filename."}), 400

    if not allowed_file(file.filename):
        return jsonify({"success": False, "error": f"Unsupported file type."}), 400

    zero_g_mode = request.form.get("zero_g_mode", "false").lower() == "true"

    filename = secure_filename(file.filename)
    unique_name = f"{uuid.uuid4().hex}_{filename}"
    image_path = UPLOAD_DIR / unique_name
    file.save(str(image_path))
    logger.info(f"Image saved: {image_path} | Zero-G: {zero_g_mode}")

    try:
        analysis_text = analyze_with_gemini(image_path, zero_g_mode)
        logger.info("Gemini analysis complete.")

        return jsonify({
            "success": True,
            "analysis_text": analysis_text,
            "zero_g_mode": zero_g_mode,
            "antigravity_easter_egg": zero_g_mode,
        }), 200

    except Exception as e:
        logger.error(f"Error: {e}")
        return jsonify({"success": False, "error": "Analysis failed. Please try again."}), 500

    finally:
        if image_path.exists():
            image_path.unlink()


# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_ENV", "development") == "development"
    logger.info(f"🚀 ChromaGuide API starting on port {port} — Powered by Gemini (Free!)")
    app.run(host="0.0.0.0", port=port, debug=debug)
