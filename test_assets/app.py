import os
import uuid
import time
import datetime
from flask import Flask, render_template, request, jsonify, send_from_directory, Response, stream_with_context
from flask_cors import CORS
from flask_socketio import SocketIO, join_room, leave_room, emit
from werkzeug.utils import secure_filename

from config import (
    UPLOAD_FOLDER,
    OUTPUT_FOLDER,
    MAX_CONTENT_LENGTH,
    NEWS_VOICES,
    NEWS_THEMES,
    DEFAULT_LOGO,
    GROQ_API_KEY,
    MISTRAL_API_KEY
)
from services.job_manager import job_manager
from services.tts_service import generate_tts_audio

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")

@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With, Range'
    response.headers['Access-Control-Expose-Headers'] = 'Content-Range, Accept-Ranges, Content-Length'
    return response

@app.route('/api/<path:subpath>', methods=['OPTIONS'])
def handle_options_preflight(subpath):
    response = jsonify({'status': 'ok'})
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With, Range'
    return response

def emit_job_progress(job_id: str, job_data: dict):
    """
    Sends progress update strictly to the private room of the requesting client.
    Guarantees that no other user receives someone else's progress or video data.
    """
    socketio.emit('job_progress', {
        'success': True,
        'job_id': job_id,
        'job': job_data
    }, room=job_id)

job_manager.set_progress_emitter(emit_job_progress)

@socketio.on('join_job')
def handle_join_job(data):
    """Client subscribes exclusively to updates for their specific job_id."""
    if not isinstance(data, dict):
        return
    job_id = data.get('job_id')
    if not job_id:
        return
    join_room(job_id)
    # Immediately send latest state if available
    status = job_manager.get_job_status(job_id)
    if status:
        emit('job_progress', {
            'success': True,
            'job_id': job_id,
            'job': status
        }, room=job_id)

@socketio.on('leave_job')
def handle_leave_job(data):
    """Client unsubscribes from the job room when rendering completes or fails."""
    if not isinstance(data, dict):
        return
    job_id = data.get('job_id')
    if job_id:
        leave_room(job_id)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['OUTPUT_FOLDER'] = OUTPUT_FOLDER
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH

ALLOWED_VIDEO_EXTS = {'.mp4', '.mov', '.mkv', '.avi', '.webm'}
ALLOWED_AUDIO_EXTS = {'.mp3', '.wav', '.m4a', '.aac', '.ogg'}
ALLOWED_IMAGE_EXTS = {'.png', '.jpg', '.jpeg', '.webp'}

def is_allowed_file(filename: str, extensions: set) -> bool:
    ext = os.path.splitext(filename)[1].lower()
    return ext in extensions

@app.route('/favicon.ico')
def favicon():
    return send_from_directory('static', 'favicon.png', mimetype='image/png')

@app.route('/portrait-template')
def portrait_template():
    return send_from_directory('frontend', 'bhopal-news-bulletin.html')

@app.route('/<any(palace,globe,highway):img_name>.jpg')
def strip_thumbnails(img_name):
    return send_from_directory('static/assets', f'{img_name}.jpg')

@app.route('/')
@app.route('/studio')
@app.route('/flask')
@app.route('/flask/')
def index():
    return render_template(
        'index.html',
        voices=NEWS_VOICES,
        themes=NEWS_THEMES,
        default_logo='/static/favicon.png' if DEFAULT_LOGO else None
    )

@app.route('/voices', methods=['GET'])
@app.route('/api/voices', methods=['GET'])
@app.route('/backend_api/voices', methods=['GET'])
def get_voices():
    return jsonify({"success": True, "voices": NEWS_VOICES})

@app.route('/themes', methods=['GET'])
@app.route('/api/themes', methods=['GET'])
@app.route('/backend_api/themes', methods=['GET'])
def get_themes():
    return jsonify({"success": True, "themes": NEWS_THEMES})

@app.route('/preview-voice', methods=['POST'])
@app.route('/api/preview-voice', methods=['POST'])
@app.route('/backend_api/preview-voice', methods=['POST'])
def preview_voice():
    """Generates a fast, low-latency audio preview of the selected voice."""
    data = request.get_json(silent=True) or {}
    voice_id = data.get('voice_id', 'hi-IN-SwaraNeural')
    sample_text = data.get('text', 'नमस्ते, यह आज की मुख्य और बड़ी ख़बर है।').strip()
    if len(sample_text) > 350:
        sample_text = sample_text[:350]
    speed = float(data.get('speed', 1.0))

    preview_filename = f"preview_{uuid.uuid4().hex[:8]}.mp3"
    preview_path = os.path.join(OUTPUT_FOLDER, preview_filename)

    try:
        success = generate_tts_audio(
            text=sample_text,
            voice=voice_id,
            output_audio_path=preview_path,
            speed=speed
        )
        if success:
            return jsonify({
                "success": True,
                "audio_url": f"/outputs/{preview_filename}"
            })
        else:
            return jsonify({"success": False, "error": "Voice preview failed"}), 500
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/generate', methods=['POST'])
@app.route('/api/generate', methods=['POST'])
@app.route('/backend_api/generate', methods=['POST'])
def generate_video():
    """Handles video generation job submission."""
    # 1. Video file validation
    if 'video' not in request.files:
        return jsonify({"success": False, "error": "Background video footage is required."}), 400
    
    video_file = request.files['video']
    if not video_file or video_file.filename == '':
        return jsonify({"success": False, "error": "No video footage selected."}), 400
    
    if not is_allowed_file(video_file.filename, ALLOWED_VIDEO_EXTS):
        return jsonify({"success": False, "error": "Invalid video format. Supported: MP4, MOV, MKV, WEBM."}), 400

    job_id = job_manager.create_job()
    video_ext = os.path.splitext(video_file.filename)[1].lower()
    video_path = os.path.join(UPLOAD_FOLDER, f"{job_id}_video{video_ext}")
    video_file.save(video_path)

    # 2. Audio selection (TTS vs Direct Upload)
    audio_mode = request.form.get('audio_mode', 'tts')
    tts_text = request.form.get('tts_text', '').strip()
    tts_voice = request.form.get('tts_voice', 'hi-IN-MadhurNeural')
    tts_speed = float(request.form.get('tts_speed', 1.0))
    uploaded_audio_path = None

    if audio_mode == 'tts':
        # Text script is optional - if blank, news broadcast generates using footage audio & graphics
        pass
    else:
        if 'audio' not in request.files:
            return jsonify({"success": False, "error": "Audio file is required for Upload Audio mode."}), 400
        audio_file = request.files['audio']
        if not audio_file or audio_file.filename == '':
            return jsonify({"success": False, "error": "No audio file selected."}), 400
        if not is_allowed_file(audio_file.filename, ALLOWED_AUDIO_EXTS):
            return jsonify({"success": False, "error": "Invalid audio format. Supported: MP3, WAV, M4A, AAC."}), 400
        
        audio_ext = os.path.splitext(audio_file.filename)[1].lower()
        uploaded_audio_path = os.path.join(UPLOAD_FOLDER, f"{job_id}_audio{audio_ext}")
        audio_file.save(uploaded_audio_path)

    # 3. Logo (Default to Shree News logo or favicon.png)
    logo_path = None
    if 'logo' in request.files:
        logo_file = request.files['logo']
        if logo_file and logo_file.filename != '' and is_allowed_file(logo_file.filename, ALLOWED_IMAGE_EXTS):
            logo_ext = os.path.splitext(logo_file.filename)[1].lower()
            logo_path = os.path.join(UPLOAD_FOLDER, f"{job_id}_logo{logo_ext}")
            logo_file.save(logo_path)

    if not logo_path:
        if os.path.exists("frontend/logo.png"):
            logo_path = "frontend/logo.png"
        elif os.path.exists("static/logo.png"):
            logo_path = "static/logo.png"
        elif os.path.exists("static/shree_news_logo.png"):
            logo_path = "static/shree_news_logo.png"
        elif DEFAULT_LOGO and os.path.exists(DEFAULT_LOGO):
            logo_path = DEFAULT_LOGO

    # 4. News Broadcast Styling & Metadata
    badge_text = request.form.get('badge_text', 'BREAKING NEWS').strip()
    headline_text = request.form.get('headline_text', 'भोपाल में आज तेज बारिश, कई इलाकों में जलभराव').strip()
    sub_headline = request.form.get('sub_headline', 'मौसम विभाग ने अगले 24 घंटे के लिए जारी किया अलर्ट').strip()
    ticker_text = request.form.get('ticker_text', 'भोपाल | इंदौर | ग्वालियर | जबलपुर | उज्जैन | सागर | रीवा | और देश-दुनिया की हर खबर').strip()
    ticker_tag = request.form.get('ticker_tag', 'ताजा खबर').strip()
    theme_key = request.form.get('theme_key', 'red_alert')
    aspect_ratio = request.form.get('aspect_ratio', '16:9')

    # Broadcast Audio Mixing & Timeline Controls
    audio_mix_mode = request.form.get('audio_mix_mode', 'voiceover_only').strip()
    try:
        footage_vol_raw = float(request.form.get('footage_volume', 20))
        footage_volume = max(0.0, min(1.0, footage_vol_raw / 100.0 if footage_vol_raw > 1.0 else footage_vol_raw))
    except (ValueError, TypeError):
        footage_volume = 0.20

    try:
        ground_clip_duration = max(2.0, float(request.form.get('ground_clip_duration', 10.0)))
    except (ValueError, TypeError):
        ground_clip_duration = 10.0

    restart_footage = request.form.get('restart_footage', 'false').lower() in ('true', '1', 'yes', 'on')
    outro_text = request.form.get('outro_text', '').strip()
    restart_outro_footage = request.form.get('restart_outro_footage', 'false').lower() in ('true', '1', 'yes', 'on')

    # Optional Broadcast Elements from Screenshot 2
    # HTML checkboxes send value when checked, send NOTHING when unchecked
    enable_top_bar = 'enable_top_bar' in request.form
    enable_sidebar = 'enable_sidebar' in request.form
    enable_location = 'enable_location' in request.form
    location_text = request.form.get('location_text', '📍 भोपाल, मध्य प्रदेश').strip()
    enable_datetime = 'enable_datetime' in request.form
    enable_anchor = 'enable_anchor' in request.form
    enable_ticker = 'enable_ticker' in request.form

    try:
        frame_x = int(request.form.get('frame_x', 575))
        frame_y = int(request.form.get('frame_y', 173))
        frame_w = int(request.form.get('frame_w', 770))
        frame_h = int(request.form.get('frame_h', 567))
    except (ValueError, TypeError):
        frame_x, frame_y, frame_w, frame_h = 575, 173, 770, 567

    # Current time & date defaults
    now = datetime.datetime.now()
    time_text = request.form.get('time_text', now.strftime("%I:%M %p")).strip()
    date_text = request.form.get('date_text', now.strftime("%d %b %Y")).strip()
    
    hindi_days = {0: "सोमवार", 1: "मंगलवार", 2: "बुधवार", 3: "गुरुवार", 4: "शुक्रवार", 5: "शनिवार", 6: "रविवार"}
    day_text = request.form.get('day_text', hindi_days.get(now.weekday(), "मंगलवार")).strip()

    # Sidebar 5 bullet points
    sidebar_items = []
    for i in range(1, 6):
        item_val = request.form.get(f'sidebar_item_{i}', '').strip()
        if item_val:
            sidebar_items.append(item_val)

    if not headline_text:
        return jsonify({"success": False, "error": "News Headline is required."}), 400

    # 5. Launch asynchronous background processing
    job_manager.process_job_async(
        job_id=job_id,
        video_path=video_path,
        audio_mode=audio_mode,
        tts_text=tts_text,
        tts_voice=tts_voice,
        tts_speed=tts_speed,
        uploaded_audio_path=uploaded_audio_path,
        badge_text=badge_text,
        headline_text=headline_text,
        sub_headline=sub_headline,
        ticker_text=ticker_text,
        ticker_tag=ticker_tag,
        theme_key=theme_key,
        aspect_ratio=aspect_ratio,
        logo_path=logo_path,
        enable_top_bar=enable_top_bar,
        enable_sidebar=enable_sidebar,
        sidebar_items=sidebar_items,
        enable_location=enable_location,
        location_text=location_text,
        enable_datetime=enable_datetime,
        time_text=time_text,
        date_text=date_text,
        day_text=day_text,
        enable_anchor=enable_anchor,
        enable_ticker=enable_ticker,
        frame_x=frame_x,
        frame_y=frame_y,
        frame_w=frame_w,
        frame_h=frame_h,
        audio_mix_mode=audio_mix_mode,
        footage_volume=footage_volume,
        ground_clip_duration=ground_clip_duration,
        restart_footage=restart_footage,
        outro_text=outro_text,
        restart_outro_footage=restart_outro_footage
    )

    return jsonify({
        "success": True,
        "job_id": job_id,
        "message": "Video rendering started."
    })

@app.route('/status/<job_id>', methods=['GET'])
@app.route('/api/status/<job_id>', methods=['GET'])
@app.route('/backend_api/status/<job_id>', methods=['GET'])
def job_status(job_id):
    """Returns the live status of the generation job."""
    status = job_manager.get_job_status(job_id)
    if not status:
        return jsonify({"success": False, "error": "Job not found."}), 404
    return jsonify({"success": True, "job": status})

@app.route('/outputs/<path:filename>')
def serve_output(filename):
    """Serves rendered video or audio files."""
    return send_from_directory(OUTPUT_FOLDER, filename)

@app.route('/generate-script-stream', methods=['POST'])
@app.route('/api/generate-script-stream', methods=['POST'])
@app.route('/backend_api/generate-script-stream', methods=['POST'])
def generate_script_stream():
    """Generates an authentic Hindi news anchor script using LangChain with streaming enabled."""
    data = request.get_json() or {}
    topic = data.get('topic', '').strip()
    provider = data.get('provider', 'groq').lower()
    model_name = data.get('model', '').strip()

    if not topic:
        return jsonify({"error": "Topic is required"}), 400

    system_prompt = ("""
    आप Shree News 24×7 के वरिष्ठ हिंदी टीवी न्यूज़ एंकर, न्यूज़ एडिटर और प्रोफेशनल ब्रॉडकास्ट स्क्रिप्ट राइटर हैं।

आपका काम यूज़र द्वारा दिए गए किसी भी न्यूज़ टॉपिक, घटना या जानकारी को एक वास्तविक भारतीय हिंदी न्यूज़ चैनल की तरह प्रस्तुत करना है।

आपकी स्क्रिप्ट ऐसी होनी चाहिए, जैसे कोई अनुभवी टीवी न्यूज़ एंकर लाइव न्यूज़ बुलेटिन में कैमरे के सामने समाचार पढ़ रहा हो।

सबसे महत्वपूर्ण बात: आपकी भाषा किताबी, साहित्यिक या सामान्य आर्टिकल जैसी नहीं होनी चाहिए। भाषा वास्तविक टीवी न्यूज़ एंकर की बोलने वाली हिंदी होनी चाहिए।

STRICT NEWS BROADCASTING LANGUAGE RULES:

1. ANCHOR SPEAKING STYLE:

- छोटे, सीधे, प्रभावशाली और स्पष्ट वाक्यों का प्रयोग करें।
- ऐसे वाक्य लिखें जिन्हें न्यूज़ एंकर बिना अटके कैमरे के सामने बोल सके।
- सामान्य लिखित हिंदी के बजाय वास्तविक टीवी न्यूज़ ब्रॉडकास्ट में इस्तेमाल होने वाली भाषा अपनाएं।
- वाक्यों को अनावश्यक रूप से लंबा न बनाएं।
- Passive Voice के बजाय Active Voice को प्राथमिकता दें।
- अनावश्यक सहायक शब्दों और भारी-भरकम वाक्य संरचना से बचें।
- जहां जरूरी हो, वहां छोटे और प्रभावशाली वाक्यों का प्रयोग करें।
- भाषा में न्यूज़ एंकर जैसी गंभीरता, ऊर्जा और स्वाभाविक उतार-चढ़ाव होना चाहिए।

2. NATURAL NEWS VOCABULARY:

न्यूज़ एंकर द्वारा इस्तेमाल किए जाने वाले वास्तविक शब्दों और वाक्यांशों का प्रयोग करें।

उदाहरण:

सामान्य लिखित भाषा:
"50 लोगों की जान चली गई है।"

टीवी न्यूज़ भाषा:
"हादसे में 50 लोगों की मौत हुई।"

सामान्य लिखित भाषा:
"घायलों को उपचार के लिए अस्पतालों में भेजा जा रहा है।"

टीवी न्यूज़ भाषा:
"घायलों को अस्पताल पहुंचाया गया।"

सामान्य लिखित भाषा:
"प्रशासन द्वारा आवश्यक कदम उठाए जा रहे हैं।"

टीवी न्यूज़ भाषा:
"प्रशासन अलर्ट मोड पर है।"

सामान्य लिखित भाषा:
"इस घटना के बाद पूरे इलाके में भय का माहौल है।"

टीवी न्यूज़ भाषा:
"घटना के बाद इलाके में दहशत है।"

सामान्य लिखित भाषा:
"मौसम विभाग द्वारा चेतावनी जारी की गई है।"

टीवी न्यूज़ भाषा:
"मौसम विभाग ने अलर्ट जारी किया है।"

इन उदाहरणों को भाषा की शैली समझने के लिए इस्तेमाल करें। हर खबर में एक जैसे वाक्य दोहराने से बचें।

3. PROFESSIONAL NEWS ANCHOR VOCABULARY:

आवश्यकता के अनुसार इन जैसे शब्दों और वाक्यांशों का इस्तेमाल करें:

बड़ी खबर, इस वक्त की अहम खबर, ताजा अपडेट, मिली जानकारी के मुताबिक, शुरुआती जानकारी के अनुसार, मौके पर अफरा-तफरी, प्रशासन अलर्ट, पुलिस मौके पर मौजूद, जांच के आदेश, राहत और बचाव कार्य जारी, भारी नुकसान, कई इलाकों में असर, लोगों में दहशत, मौसम विभाग का अलर्ट, प्रशासन की कार्रवाई, मामले की जांच जारी।

इनका इस्तेमाल केवल तभी करें जब वे खबर के तथ्यों से मेल खाते हों।

4. BREAKING NEWS PRESENTATION:

- खबर की शुरुआत प्रभावशाली होनी चाहिए।
- पहली लाइन में ही मुख्य घटना और उसका सबसे महत्वपूर्ण पहलू सामने आना चाहिए।
- शुरुआत में अनावश्यक भूमिका या लंबा परिचय न दें।
- खबर को इस तरह प्रस्तुत करें कि दर्शक शुरुआत से ही घटना को समझ सकें।
- महत्वपूर्ण जानकारी को पहले रखें और उसके बाद जरूरी विवरण दें।
- हर लाइन में नई जानकारी होनी चाहिए।
- एक ही बात को अलग-अलग शब्दों में बार-बार न दोहराएं।

5. STRICT JOURNALISM RULES:

- 'शहीद' शब्द का इस्तेमाल सामान्य दुर्घटना, अपराध, बीमारी, आग या अन्य हादसों में कभी न करें।
- 'शहीद' शब्द केवल देश की रक्षा में वीरगति प्राप्त करने वाले सैनिकों या पात्र सुरक्षा कर्मियों के लिए ही इस्तेमाल करें।
- दुर्घटनाओं में मौत, मृतक, जान गई, घायल और हताहत जैसे उपयुक्त शब्दों का प्रयोग करें।
- किसी भी घटना के बारे में अपनी तरफ से आंकड़े, मृतकों की संख्या, घायलों की संख्या, स्थान, तारीख या प्रशासनिक बयान न बनाएं।
- यूज़र द्वारा दी गई जानकारी को ही तथ्य मानें।
- जानकारी अधूरी होने पर अपुष्ट तथ्यों को निश्चित रूप में प्रस्तुत न करें।
- जरूरत पड़ने पर बताया जा रहा है, शुरुआती जानकारी के मुताबिक या आधिकारिक पुष्टि का इंतजार है जैसे शब्दों का प्रयोग करें।
- किसी अफवाह को पक्की खबर की तरह प्रस्तुत न करें।

6. HINDI LANGUAGE:

- मुख्य स्क्रिप्ट शुद्ध और स्वाभाविक देवनागरी हिंदी में लिखें।
- अंग्रेजी शब्दों का प्रयोग केवल वहीं करें जहां वे टीवी न्यूज़ में सामान्य रूप से इस्तेमाल होते हैं।
- भाषा आम दर्शकों को आसानी से समझ आनी चाहिए।
- कठिन साहित्यिक शब्दों और अनावश्यक संस्कृतनिष्ठ भाषा से बचें।

7. PUNCTUATION AND TTS RULES:

- आउटपुट में सामान्य विराम चिह्नों का इस्तेमाल अनिवार्य है।
- पूर्ण विराम (।), अल्पविराम (,), प्रश्नवाचक चिह्न (?) और आवश्यकतानुसार विस्मयादिबोधक चिह्न (!) का प्रयोग करें।
- वाक्यों के बीच सही जगह विराम दें ताकि Text-to-Speech में स्वाभाविक बोलने का अंदाज आए।
- Markdown formatting का इस्तेमाल बिल्कुल न करें।
- Asterisk, Hashtags, Bullets, Markdown Headings और अनावश्यक सजावटी Symbols का इस्तेमाल न करें।
- सामान्य punctuation को कभी न हटाएं।

8. SCRIPT WRITING STYLE:

- स्क्रिप्ट 4 से 6 प्रभावशाली वाक्यों की हो।
- स्क्रिप्ट की शुरुआत हमेशा इस वाक्य से करें:
"नमस्कार, इस वक्त की बड़ी खबर..."
- इसके बाद सीधे मुख्य घटना की जानकारी दें।
- हर वाक्य का अपना महत्व होना चाहिए।
- स्क्रिप्ट का अंत किसी महत्वपूर्ण अपडेट, प्रशासनिक कार्रवाई या उपलब्ध जानकारी पर करें।
- बिना तथ्य के काल्पनिक निष्कर्ष या नाटकीय बयान न जोड़ें।

9. OUTPUT FORMAT:

हमेशा नीचे दिए गए चार सेक्शन इसी क्रम में दें। इनके अलावा कोई अतिरिक्त जानकारी, स्पष्टीकरण या टिप्पणी न लिखें।

===HEADLINE===
एक प्रभावशाली और संक्षिप्त मुख्य न्यूज़ हेडलाइन।

===SUB_HEADLINE===
मुख्य खबर को स्पष्ट करने वाली एक छोटी सब-हेडलाइन।

===TICKER===
न्यूज़ चैनल के नीचे चलने वाली संक्षिप्त अपडेट लाइनें। हर अपडेट को | से अलग करें।

===SCRIPT===
न्यूज़ एंकर द्वारा कैमरे के सामने बोली जाने वाली 4 से 6 वाक्यों की प्रोफेशनल स्क्रिप्ट।

FINAL INSTRUCTION:

हमेशा एक अनुभवी भारतीय हिंदी टीवी न्यूज़ एंकर की तरह लिखें, न कि किसी समाचार लेख के लेखक की तरह।

आपकी स्क्रिप्ट पढ़ने पर ऐसा महसूस होना चाहिए कि Shree News 24×7 का एंकर लाइव न्यूज़ बुलेटिन प्रस्तुत कर रहा है।

सीधी भाषा, छोटे वाक्य, वास्तविक न्यूज़ शब्दावली, सही विराम चिह्न और प्रोफेशनल ब्रॉडकास्टिंग टोन आपकी सर्वोच्च प्राथमिकता है।
    """
    )

    groq_key = os.environ.get("GROQ_API_KEY") or GROQ_API_KEY
    mistral_key = os.environ.get("MISTRAL_API_KEY") or MISTRAL_API_KEY

    def generate():
        try:
            if provider == 'mistral' or (not groq_key and mistral_key):
                if not mistral_key:
                    yield "Error: MISTRAL_API_KEY not configured."
                    return
                from langchain_mistralai import ChatMistralAI
                from langchain_core.messages import SystemMessage, HumanMessage
                llm = ChatMistralAI(
                    model=model_name or "mistral-small-latest",
                    mistral_api_key=mistral_key,
                    streaming=True,
                    temperature=0.5,
                )
            else:
                if not groq_key:
                    yield "Error: GROQ_API_KEY not configured. Please set GROQ_API_KEY in environment or config."
                    return
                from langchain_groq import ChatGroq
                from langchain_core.messages import SystemMessage, HumanMessage
                chosen_model = model_name or "qwen/qwen3.8-27b"
                llm = ChatGroq(
                    model=chosen_model,
                    groq_api_key=groq_key,
                    streaming=True,
                    temperature=0.6,
                )

            messages = [
                SystemMessage(content=system_prompt),
                HumanMessage(content=f"Topic: {topic}")
            ]
            for chunk in llm.stream(messages):
                if chunk.content:
                    yield chunk.content
        except Exception as e:
            yield f"\n[AI Error: {str(e)}]"

    return Response(stream_with_context(generate()), mimetype='text/plain; charset=utf-8')

# Start background cleanup daemon on server launch
from services.cleaner import start_cleanup_daemon
start_cleanup_daemon(interval_seconds=180)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 7860))
    debug_mode = os.environ.get('FLASK_DEBUG', 'false').lower() in ('true', '1')

    # If running in Hugging Face Spaces (ZeroGPU environment)
    if os.environ.get('SPACE_ID') or os.environ.get('GRADIO_SERVER_PORT'):
        import gradio as gr
        from a2wsgi import WSGIMiddleware
        from starlette.staticfiles import StaticFiles
        from fastapi.middleware.cors import CORSMiddleware

        # 1. ZeroGPU Anchor Function (Required by Hugging Face ZeroGPU startup scanner)
        try:
            import spaces
            @spaces.GPU
            def zero_gpu_anchor(val=""):
                return f"ZeroGPU Active {val}"
        except Exception:
            def zero_gpu_anchor(val=""):
                return f"Active {val}"

        with gr.Blocks(title="Shree News Studio Backend") as demo:
            gr.Markdown("## 📺 Shree News Studio Backend Engine")
            gr.Markdown("Status: **Active** | Runtime: **Hugging Face ZeroGPU**")
            _in = gr.Textbox(value="1", visible=False)
            _out = gr.Textbox(visible=False)
            _b = gr.Button("Init", visible=False)
            _b.click(fn=zero_gpu_anchor, inputs=_in, outputs=_out)

        # 2. Add FastAPI CORS middleware for cross-origin access from Render frontend
        demo.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
            expose_headers=["*"]
        )

        # 3. Mount Flask on /backend_api (bypasses Gradio's internal /api collision completely)
        flask_asgi = WSGIMiddleware(app)
        demo.app.mount("/backend_api", flask_asgi)

        # 4. Mount outputs so rendered videos stream directly to Render frontend
        if not os.path.exists("outputs"):
            os.makedirs("outputs", exist_ok=True)
        demo.app.mount("/outputs", StaticFiles(directory="outputs"), name="outputs")

        print(f"Starting ZeroGPU Backend on Hugging Face Spaces (Port {port})...")
        demo.launch(
            server_name="0.0.0.0",
            server_port=port,
            show_error=True
        )
    else:
        print(f"Starting Shree News Studio server on http://0.0.0.0:{port}")
        socketio.run(app, host='0.0.0.0', port=port, debug=debug_mode, allow_unsafe_werkzeug=True)
