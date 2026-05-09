"""
ChromaGuide Backend - Flask API
================================
Aziz's Task: Backend server that handles image analysis via Claude Vision API,
converts results to audio via Google TTS, and serves both text + audio to the frontend.

Environment Variables Required:
  - ANTHROPIC_API_KEY: Your Claude API key
  - GOOGLE_APPLICATION_CREDENTIALS: Path to Google Cloud service account JSON (for TTS)
  - FLASK_SECRET_KEY: (optional) Secret key for Flask sessions

Endpoints:
  POST /analyze     — Upload an image for outfit analysis
  GET  /audio/<id>  — Retrieve a generated audio file
  GET  /health      — Health check
"""

import os
import uuid
import base64
import logging
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, request, jsonify, send_file, abort
from flask_cors import CORS
from werkzeug.utils import secure_filename

import anthropic
from google.cloud import texttospeech

# NOTE: Python's `import antigravity` easter egg is referenced here.
# When zero_g_mode is active, we set antigravity_easter_egg=True in the API
# response, signaling the frontend to trigger floating UI animations.
# (Importing antigravity in production opens a browser tab — we flag it instead.)
ANTIGRAVITY_LOADED = True  # 🥚 Easter egg flag

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
app = Flask(__name__)
CORS(app)  # Allow cross-origin requests from the React Native app

app.config["SECRET_KEY"] = os.getenv("FLASK_SECRET_KEY", "chromaguide-hackathon-2026")
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16 MB max upload

UPLOAD_DIR = Path("uploads")
AUDIO_DIR = Path("audio_output")
UPLOAD_DIR.mkdir(exist_ok=True)
AUDIO_DIR.mkdir(exist_ok=True)

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "webp", "gif"}

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("chromaguide")

# ---------------------------------------------------------------------------
# Claude Vision — System Prompt (Samin's Prompt)
# ---------------------------------------------------------------------------
SYSTEM_PROMPT_BASE = """\
You are **ChromaGuide**, a highly descriptive fashion and color-matching assistant \
designed specifically for blind and visually impaired users.

## Your Core Responsibilities
1. **Color Identification** — Describe every visible color in the outfit using \
vivid, everyday language (e.g., "sky blue", "warm honey gold", "charcoal grey"). \
Avoid hex codes or technical jargon.
2. **Garment Description** — Identify each clothing item (shirt, trousers, jacket, \
shoes, accessories, etc.) and describe its style, fit, and texture if visible.
3. **Color Compatibility Rating** — Rate the overall color harmony on a scale of \
1–10 and explain *why* (complementary, analogous, clashing, etc.).
4. **Practical Recommendations** — Suggest 1–2 small changes that could improve \
the outfit (e.g., "A navy belt would tie the look together").
5. **Occasion Suitability** — Briefly note whether the outfit works for casual, \
business, formal, or outdoor settings.

## Output Format
Structure your response EXACTLY like this so it is screen-reader friendly:

Outfit Overview:
[2-3 sentence high-level description]

Colors Detected:
- [Item]: [Color description]
- ...

Color Harmony Score: [X] out of 10
[1-2 sentence explanation]

Style Notes:
[2-3 sentences on fit, texture, overall vibe]

Recommendations:
1. [Suggestion 1]
2. [Suggestion 2]

Occasion: [Casual / Business / Formal / Outdoor / etc.]

## Important Rules
- Use PLAIN TEXT only. Do NOT use markdown bold (**), headings (#), or any formatting \
that a screen reader cannot parse naturally.
- Keep your total response under 250 words for conciseness.
- Speak as if describing to a friend — warm, clear, and helpful.
"""

ZERO_G_ADDON = """

## ZERO-GRAVITY MODE ACTIVATED
In addition to ALL of the above, you MUST also evaluate the outfit for \
zero-gravity / space-station safety and aesthetics. Apply these extra rules:

6. **Float Risk Assessment** — Identify any loose items that would float, drift, \
or become hazards in microgravity. Examples:
   - Loose ties, scarves, or ribbons: "WARNING: This tie will float upward and \
drift into your face during zero-G maneuvers."
   - Skirts or dresses: "ALERT: This skirt will drift upward in zero gravity. \
Consider magnetic hem weights or switching to fitted pants."
   - Unbuttoned collars, loose cuffs, dangling jewelry: flag them all.
7. **Space Aesthetic Rating** — Rate the outfit's "Space-Readiness" on a scale of \
1–10 (does it look like something a stylish astronaut would wear?).
8. **Antigravity Recommendation** — Suggest one modification that would make the \
outfit both fashionable AND zero-G safe.

Add this section to your response:

Zero-G Safety Report:
- Float Risk: [Low / Medium / High]
- [List each hazard item and the risk]

Space-Readiness Score: [X] out of 10
[Explanation]

Antigravity Recommendation:
[Your suggestion for making this outfit zero-G fabulous]
"""


def build_system_prompt(zero_g_mode: bool) -> str:
    """Construct the full system prompt, conditionally adding Zero-G rules."""
    prompt = SYSTEM_PROMPT_BASE
    if zero_g_mode:
        prompt += ZERO_G_ADDON
    return prompt


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def encode_image_to_base64(filepath: Path) -> str:
    """Read an image file and return its base64-encoded string."""
    with open(filepath, "rb") as f:
        return base64.standard_b64encode(f.read()).decode("utf-8")


def get_media_type(filename: str) -> str:
    """Map file extension to MIME type for the Claude API."""
    ext = filename.rsplit(".", 1)[1].lower()
    mapping = {
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "webp": "image/webp",
        "gif": "image/gif",
    }
    return mapping.get(ext, "image/jpeg")


def analyze_with_claude(image_path: Path, zero_g_mode: bool) -> str:
    """
    Send the image to Claude Vision API and return the outfit analysis text.
    """
    client = anthropic.Anthropic()  # Uses ANTHROPIC_API_KEY env var

    image_b64 = encode_image_to_base64(image_path)
    media_type = get_media_type(image_path.name)
    system_prompt = build_system_prompt(zero_g_mode)

    user_message = "Please analyze this outfit image."
    if zero_g_mode:
        user_message += " Zero-Gravity Mode is ACTIVE — include the full space safety assessment."

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1500,
        system=system_prompt,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": image_b64,
                        },
                    },
                    {
                        "type": "text",
                        "text": user_message,
                    },
                ],
            }
        ],
    )

    return message.content[0].text


def synthesize_speech(text: str, audio_id: str) -> Path:
    """
    Convert analysis text to speech using Google Cloud TTS.
    Returns the path to the generated MP3 file.
    """
    client = texttospeech.TextToSpeechClient()

    synthesis_input = texttospeech.SynthesisInput(text=text)

    # Use a clear, natural-sounding voice optimized for accessibility
    voice = texttospeech.VoiceSelectionParams(
        language_code="en-US",
        name="en-US-Neural2-J",  # High-quality neural voice
        ssml_gender=texttospeech.SsmlVoiceGender.MALE,
    )

    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3,
        speaking_rate=0.95,  # Slightly slower for clarity
        pitch=0.0,
    )

    response = client.synthesize_speech(
        input=synthesis_input,
        voice=voice,
        audio_config=audio_config,
    )

    audio_path = AUDIO_DIR / f"{audio_id}.mp3"
    with open(audio_path, "wb") as out:
        out.write(response.audio_content)

    logger.info(f"Audio saved: {audio_path}")
    return audio_path


# ---------------------------------------------------------------------------
# API Endpoints
# ---------------------------------------------------------------------------
@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint for deployment platforms."""
    return jsonify({
        "status": "healthy",
        "service": "ChromaGuide API",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "antigravity_loaded": ANTIGRAVITY_LOADED,
    })


@app.route("/analyze", methods=["POST"])
def analyze_outfit():
    """
    Main endpoint: accepts an image upload and returns outfit analysis.

    Request:
      - Form field 'image': the outfit image file
      - Form field 'zero_g_mode': "true" or "false" (optional, defaults to false)

    Response JSON:
      {
        "success": true,
        "analysis_text": "...",
        "audio_url": "/audio/<id>",
        "audio_id": "<uuid>",
        "zero_g_mode": true/false,
        "antigravity_easter_egg": true/false
      }
    """
    # --- Validate image upload ---
    if "image" not in request.files:
        return jsonify({
            "success": False,
            "error": "No image file provided. Please upload an outfit photo."
        }), 400

    file = request.files["image"]
    if file.filename == "":
        return jsonify({
            "success": False,
            "error": "Empty filename. Please select a valid image."
        }), 400

    if not allowed_file(file.filename):
        return jsonify({
            "success": False,
            "error": f"Unsupported file type. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
        }), 400

    # --- Parse Zero-G mode ---
    zero_g_mode = request.form.get("zero_g_mode", "false").lower() == "true"

    # --- Save uploaded image ---
    filename = secure_filename(file.filename)
    unique_name = f"{uuid.uuid4().hex}_{filename}"
    image_path = UPLOAD_DIR / unique_name
    file.save(str(image_path))
    logger.info(f"Image saved: {image_path} | Zero-G Mode: {zero_g_mode}")

    try:
        # --- Step 1: Analyze with Claude Vision ---
        analysis_text = analyze_with_claude(image_path, zero_g_mode)
        logger.info("Claude analysis complete.")

        # --- Step 2: Convert to speech ---
        audio_id = uuid.uuid4().hex
        synthesize_speech(analysis_text, audio_id)
        logger.info("TTS synthesis complete.")

        # --- Build response ---
        response_data = {
            "success": True,
            "analysis_text": analysis_text,
            "audio_url": f"/audio/{audio_id}",
            "audio_id": audio_id,
            "zero_g_mode": zero_g_mode,
            "antigravity_easter_egg": zero_g_mode,  # 🥚 Tells frontend to trigger floating animation
        }

        return jsonify(response_data), 200

    except anthropic.APIError as e:
        logger.error(f"Claude API error: {e}")
        return jsonify({
            "success": False,
            "error": "AI analysis failed. Please try again."
        }), 502

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({
            "success": False,
            "error": "Something went wrong. Please try again."
        }), 500

    finally:
        # Clean up uploaded image to save space
        if image_path.exists():
            image_path.unlink()


@app.route("/audio/<audio_id>", methods=["GET"])
def get_audio(audio_id: str):
    """Serve a generated audio file by its ID."""
    # Sanitize the audio_id to prevent path traversal
    safe_id = secure_filename(audio_id)
    audio_path = AUDIO_DIR / f"{safe_id}.mp3"

    if not audio_path.exists():
        abort(404, description="Audio file not found.")

    return send_file(str(audio_path), mimetype="audio/mpeg", as_attachment=False)


# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_ENV", "development") == "development"
    logger.info(f"🚀 ChromaGuide API starting on port {port}")
    logger.info(f"🛸 Antigravity flag active — Zero-G Mode available!")
    app.run(host="0.0.0.0", port=port, debug=debug)
