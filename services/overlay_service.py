import os
import shutil
import subprocess
import textwrap
import re
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from config import DEFAULT_FONT, BASE_DIR

# Paths to master template plates extracted from user's Hindi News Broadcast Template
PLATE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "static", "assets")
PLATE_TOP_BAR = os.path.join(PLATE_DIR, "plate_top_bar_rgba.png")
PLATE_SIDEBAR = os.path.join(PLATE_DIR, "plate_sidebar_clean_rgba.png")
PLATE_LOWER_THIRD = os.path.join(PLATE_DIR, "plate_lower_third_clean_rgba.png")
FRONTEND_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "frontend")
LANDSCAPE_FRONTEND_HTML = os.path.join(FRONTEND_DIR, "index.html")
PORTRAIT_FRONTEND_HTML = os.path.join(FRONTEND_DIR, "bhopal-news-bulletin.html")
FRONTEND_HTML = LANDSCAPE_FRONTEND_HTML
ANCHOR_IMG = os.path.join(PLATE_DIR, "Professional News Anchor Portrait.png")

def shape_devanagari(text: str) -> str:
    """
    Reorders Devanagari chhoti 'i' matra (\u093f) before consonants for proper visual rendering in PIL.
    """
    if not text:
        return ""
    pattern = r'([\u0915-\u0939](?:[\u094d][\u0915-\u0939])*)(\u093f)'
    return re.sub(pattern, r'\2\1', text)

def get_font(font_path: str, size: int):
    """Loads TTF font with fallback."""
    try:
        if font_path and os.path.exists(font_path):
            return ImageFont.truetype(font_path, size=size)
    except Exception as e:
        print(f"Font load error ({font_path}): {e}")
    return ImageFont.load_default()

def find_chrome_binary():
    """Detects available Chrome or Edge headless binary on Windows/Linux."""
    candidates = [
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "/usr/bin/google-chrome",
        "/usr/bin/chromium-browser",
        "/usr/bin/chromium",
        "google-chrome",
        "chromium"
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
        which_path = shutil.which(c)
        if which_path:
            return which_path
    return None

def render_html_overlay(
    headline_text: str,
    sub_headline: str,
    sidebar_items: list,
    enable_top_bar: bool,
    enable_sidebar: bool,
    enable_location: bool,
    location_text: str,
    enable_datetime: bool,
    time_text: str,
    date_text: str,
    day_text: str,
    enable_anchor: bool,
    ticker_tag: str,
    output_path: str,
    enable_ticker: bool = True,
    ticker_text: str = "",
    frame_x: int = 575,
    frame_y: int = 173,
    frame_w: int = 770,
    frame_h: int = 567,
    canvas_width: int = 1920,
    canvas_height: int = 1080,
    logo_path: str = None
) -> bool:
    """
    Renders 1080p broadcast overlay directly from the user's exact HTML/CSS template
    using Chrome/Edge headless for 100% pixel-perfect fidelity.
    """
    chrome_bin = find_chrome_binary()
    template_path = PORTRAIT_FRONTEND_HTML if canvas_height > canvas_width else LANDSCAPE_FRONTEND_HTML
    if not chrome_bin or not os.path.exists(template_path):
        return False

    try:
        with open(template_path, 'r', encoding='utf-8') as f:
            html = f.read()
        is_vertical = canvas_height > canvas_width

        # Ensure transparent page background so Chrome headless outputs true RGBA
        html = html.replace('html,body{width:100%;height:100%;background:#000;overflow:hidden}', 'html,body{width:100%;height:100%;background:transparent !important;overflow:hidden}')
        html = html.replace('background:#000', 'background:transparent')

        # Inject base href pointing dynamically to project root for universal relative asset resolution
        base_uri = Path(BASE_DIR).resolve().as_uri().rstrip('/') + '/'
        if '<head>' in html:
            html = html.replace('<head>', f'<head>\n  <base href="{base_uri}">', 1)
        elif '<HEAD>' in html:
            html = html.replace('<HEAD>', f'<HEAD>\n  <base href="{base_uri}">', 1)

        # Inject local Hind fonts for 100% offline pixel-perfect Devanagari typography
        local_font_css = '''
@font-face {
    font-family: 'Hind';
    src: url('fonts/Hind-Bold.ttf') format('truetype');
    font-weight: 700 900;
}
@font-face {
    font-family: 'Hind';
    src: url('fonts/Hind-Regular.ttf') format('truetype');
    font-weight: 400 600;
}
'''
        html = html.replace('</style>', local_font_css + '</style>', 1)

        # Normalize static asset references to clean relative paths
        html = html.replace("url('/static/assets/", "url('static/assets/")
        html = html.replace('url("/static/assets/', 'url("static/assets/')
        html = html.replace("url('/static/", "url('static/")
        html = html.replace('url("/static/', 'url("static/')

        if is_vertical:
            html = html.replace(
                '</style>',
                '<style>'
                f'html,body{{width:{canvas_width}px!important;height:{canvas_height}px!important;'
                'background:transparent!important;min-height:0!important;overflow:hidden!important;'
                'scrollbar-width:none!important;-ms-overflow-style:none!important;margin:0!important;padding:0!important;}'
                '::-webkit-scrollbar,*::-webkit-scrollbar{display:none!important;width:0!important;height:0!important;}'
                'body{justify-content:flex-start!important;align-items:flex-start!important;overflow:hidden!important;}'
                '.wrap{transform-origin:top left!important;position:absolute!important;left:0!important;top:0!important;}'
                '.poster{background:transparent!important}'
                '.redBg{background:transparent!important}'
                '.frame{background:transparent!important;box-shadow:none!important;border:none!important;padding:0!important;border-radius:0!important}'
                '.main-image{background:transparent!important}'
                '#tickerText,#track1,#track2,#tickerRoller,.ticker-roller,.roll-part{display:none!important;animation:none!important;opacity:0!important;visibility:hidden!important}'
                '</style>',
                1,
            )

        for pfx in ['src="/static/assets/', 'src="static/assets/', 'src="/static/', 'src="']:
            html = html.replace(f'{pfx}palace.jpg"', 'src="static/assets/palace.jpg"')
            html = html.replace(f'{pfx}globe.jpg"', 'src="static/assets/globe.jpg"')
            html = html.replace(f'{pfx}highway.jpg"', 'src="static/assets/highway.jpg"')

        # Inject dynamic logo
        if logo_path and os.path.exists(logo_path):
            logo_uri = Path(logo_path).resolve().as_uri()
            for pfx in ['src="logo.png"', 'src="static/logo.png"', 'src="/static/logo.png"']:
                html = html.replace(pfx, f'src="{logo_uri}"')
        else:
            default_logo = 'static/assets/shree_news_logo.png' if os.path.exists(os.path.join(BASE_DIR, 'static', 'assets', 'shree_news_logo.png')) else 'static/logo.png'
            for pfx in ['src="logo.png"', 'src="static/logo.png"', 'src="/static/logo.png"']:
                html = html.replace(pfx, f'src="{default_logo}"')

        # Transparent canvas & no studio-bg in overlay for 100% clean compositing over vbg
        if not is_vertical:
            overlay_16_css = (
                '<style>'
                'html,body{background:transparent !important;width:1920px!important;height:1080px!important;'
                'overflow:hidden!important;scrollbar-width:none!important;-ms-overflow-style:none!important;margin:0!important;padding:0!important;}'
                '::-webkit-scrollbar,*::-webkit-scrollbar{display:none!important;width:0!important;height:0!important;}'
                '#canvas{position:absolute;left:0;top:0;margin:0;width:1920px;height:1080px;'
                'transform:none;transform-origin:0 0;overflow:hidden;'
                'font-family:\'Hind\',\'Noto Sans Devanagari\',sans-serif;font-weight:700;color:#111;'
                'background:transparent !important;}'
                '.studio-bg, .glow, #previewFootageVideo, .footage-placeholder { display: none !important; }'
                '#frame { background: transparent !important; border: none !important; box-shadow: none !important; padding: 0 !important; border-radius: 0 !important; }'
                '#tickerText, #track { display: none !important; animation: none !important; }'
                '</style>'
            )
            html = html.replace('</style>', overlay_16_css + '</style>', 1)

        # Anchor layer positioning matching user alignment rules
        anchor_code = ""
        anchor_x = 400
        if not enable_sidebar:
            if frame_w > 950:
                anchor_x = max(20, min(140, frame_x - 700))
            else:
                anchor_x = max(60, min(240, (frame_x - 720) // 2 + 30))
        elif frame_w > 770:
            anchor_x = max(340, 400 - int((frame_w - 770) * 0.45))

        # Anchor top = brk_top - anchor_height(620) so anchor bottom touches brk top
        brk_top = 765 if enable_ticker else 897
        anchor_top = brk_top - 620

        if enable_anchor and os.path.exists(ANCHOR_IMG):
            anchor_uri = Path(ANCHOR_IMG).resolve().as_uri()
            anchor_code = f'''
            <!-- NEWS ANCHOR -->
            <div id="anchor" class="abs" style="left:{anchor_x}px;top:{anchor_top}px;width:720px;height:620px;z-index:14;pointer-events:none;display:flex;align-items:flex-end;justify-content:center;">
             <img src="{anchor_uri}" style="height:100%;width:auto;object-fit:contain;display:block;">
            </div>
            '''
        html = html.replace('<!-- FOOTAGE FRAME & LOCATION -->', anchor_code + '\n <!-- FOOTAGE FRAME & LOCATION -->')

        # Replace fit() to do nothing so it doesn't reposition canvas or declare c twice
        html = html.replace('function fit(){', 'function fit(){ return;')

        # Clean location text
        clean_loc = (location_text or 'भोपाल, मध्य प्रदेश').replace('📍', '').strip()

        # Format sidebar items (1 to 5 dynamic)
        items_list = []
        if sidebar_items:
            for it in sidebar_items[:5]:
                if it and it.strip():
                    items_list.append(it.strip())

        if not items_list and enable_sidebar:
            items_list = [
                "भोपाल से इस वक्त की बड़ी खबर",
                "प्रदेश में मौसम को लेकर नया अपडेट",
                "देश-दुनिया की खास खबरें"
            ]

        import json
        items_json = json.dumps(items_list, ensure_ascii=False)

        # Replace CONFIG block
        new_cfg = f'''const CONFIG = {{
  mainHeadline: {json.dumps(headline_text or "भोपाल में आज तेज बारिश, कई इलाकों में जलभराव", ensure_ascii=False)},
  subtitle: {json.dumps(sub_headline or "मौसम विभाग ने अगले 24 घंटे के लिए जारी किया अलर्ट", ensure_ascii=False)},
  location: {json.dumps(clean_loc, ensure_ascii=False)},
  sideHeadlines: {items_json},
  tickerText: "",
  useSystemClock: false,
  fixedTime: {json.dumps(time_text or "10:25 AM", ensure_ascii=False)},
  fixedDate: {json.dumps(date_text or "28 Oct 2026", ensure_ascii=False)},
  fixedWeekday: {json.dumps(day_text or "मंगलवार", ensure_ascii=False)}
}};'''

        html = re.sub(r'const CONFIG\s*=\s*\{[\s\S]*?\};', new_cfg, html, count=1)

        # Toggle & position scripts
        toggles = []
        # Landscape uses the configurable frame. Portrait keeps the reference
        # template's own frame geometry so preview and export remain identical.
        if not is_vertical:
            toggles.append(f'if($("frame")) {{ $("frame").style.left = "{frame_x}px"; $("frame").style.top = "{frame_y}px"; $("frame").style.width = "{frame_w}px"; $("frame").style.height = "{frame_h}px"; }}')
            toggles.append(f'if($("loc")) {{ $("loc").style.left = "{frame_x + 8}px"; $("loc").style.top = "{frame_y + 10}px"; }}')
        else:
            scale_factor = (frame_w / 770.0) if frame_w else 1.0
            std_w = 898
            top_bound = 340
            bottom_bound = 1150 if enable_ticker else 1320
            avail_h = bottom_bound - top_bound
            center_y = int((top_bound + bottom_bound) / 2)
            std_h = min(717, int(avail_h * 0.88))
            if scale_factor >= 1.0:
                t = min(1.0, (scale_factor - 1.0) / 1.5)
                scaled_w = int(std_w + (941 - std_w) * t)
                scaled_h = int(std_h + (avail_h - std_h) * t)
            else:
                scale_val = max(0.5, scale_factor)
                scaled_w = int(std_w * scale_val)
                scaled_h = int(std_h * scale_val)
            frame_x_vert = int((941 - scaled_w) / 2)
            frame_y_vert = int(center_y - (scaled_h / 2))

            toggles.append(f'if($("frame")) {{ $("frame").style.left = "{frame_x_vert}px"; $("frame").style.top = "{frame_y_vert}px"; $("frame").style.width = "{scaled_w}px"; $("frame").style.height = "{scaled_h}px"; }}')
            loc_x = max(22, frame_x_vert + 10)
            loc_y = max(355, frame_y_vert + 17)
            toggles.append(f'if($("loc")) {{ $("loc").style.left = "{loc_x}px"; $("loc").style.top = "{loc_y}px"; }}')
            toggles.append(f'if($("locationText")) {{ $("locationText").style.left = "{loc_x + 76}px"; $("locationText").style.top = "{loc_y + 31}px"; }}')

            # Inject actual user headlines and subtitle into portrait template
            hl_raw = headline_text or "भोपाल में आज तेज बारिश, कई इलाकों में जलभराव"
            if "," in hl_raw:
                parts = hl_raw.split(",", 1)
                h1_val = parts[0].strip() + ","
                h2_val = parts[1].strip()
            elif ":" in hl_raw:
                parts = hl_raw.split(":", 1)
                h1_val = parts[0].strip() + ":"
                h2_val = parts[1].strip()
            else:
                words = hl_raw.strip().split()
                if len(words) > 4:
                    mid = (len(words) + 1) // 2
                    h1_val = " ".join(words[:mid])
                    h2_val = " ".join(words[mid:])
                else:
                    h1_val = hl_raw
                    h2_val = ""

            toggles.append(f'if($("headline1")) $("headline1").textContent = {json.dumps(h1_val, ensure_ascii=False)};')
            toggles.append(f'if($("headline2")) $("headline2").textContent = {json.dumps(h2_val, ensure_ascii=False)};')
            
            clean_sub = (sub_headline or "").strip()
            if clean_sub:
                toggles.append(f'if($("subtitle")) {{ $("subtitle").textContent = {json.dumps(clean_sub, ensure_ascii=False)}; $("subtitle").style.display = "block"; }}')
                toggles.append('if(document.querySelector(".sub")) document.querySelector(".sub").style.display = "block";')
            else:
                toggles.append('if($("subtitle")) $("subtitle").style.display = "none";')
                toggles.append('if(document.querySelector(".sub")) document.querySelector(".sub").style.display = "none";')

            toggles.append('["tickerText","track1","track2","tickerRoller"].forEach(function(id){ var el = $(id); if(el) el.remove(); });')
            toggles.append('document.querySelectorAll(".ticker-roller,.roll-part").forEach(function(el){ el.remove(); });')

        if not enable_top_bar:
            toggles.append('if($("header")) $("header").style.display = "none";')
            toggles.append('if($("banner")) $("banner").style.display = "none";')
            toggles.append('document.querySelectorAll(".card").forEach(c => c.style.display = "none");')
            toggles.append('if($("logo")) $("logo").style.display = "none";')

        if not enable_sidebar or len(items_list) == 0:
            toggles.append('if($("left")) $("left").style.display = "none";')
        else:
            card_h = min(595, 95 + len(items_list) * 100)
            toggles.append(f'if($("left")) {{ $("left").style.display = "block"; $("left").style.height = "{card_h}px"; }}')

        if not enable_location:
            toggles.append('if($("loc")) $("loc").style.display = "none";')
            toggles.append('if($("locationText")) $("locationText").style.display = "none";')

        if not enable_ticker:
            toggles.append('if(document.querySelector(".poster")) document.querySelector(".poster").classList.add("ticker-off");')
            toggles.append('if($("under")) $("under").style.display = "none";')
            toggles.append('if($("time")) $("time").style.display = "none";')
            toggles.append('if($("date")) $("date").style.display = "none";')
            toggles.append('if($("label")) { $("label").style.display = "none"; $("label").style.setProperty("display", "none", "important"); }')
            toggles.append('if($("ticker")) { $("ticker").style.display = "none"; $("ticker").style.setProperty("display", "none", "important"); }')
            toggles.append('if($("tickerText")) { $("tickerText").style.display = "none"; $("tickerText").style.setProperty("display", "none", "important"); }')
            if not is_vertical:
                toggles.append('if($("brk")) $("brk").style.top = "897px";')
        else:
            if is_vertical:
                toggles.append('if(document.querySelector(".poster")) document.querySelector(".poster").classList.remove("ticker-off");')
            else:
                toggles.append('if($("brk")) $("brk").style.top = "765px";')
        if is_vertical and not enable_datetime:
            toggles.append('if(document.querySelector(".poster")) document.querySelector(".poster").classList.add("datetime-off");')
            toggles.append('if($("time")) $("time").style.display = "none";')
            toggles.append('if($("date")) $("date").style.display = "none";')
            toggles.append('if($("weekday")) $("weekday").style.display = "none";')
        elif is_vertical:
            toggles.append('if(document.querySelector(".poster")) document.querySelector(".poster").classList.remove("datetime-off");')
        if not is_vertical:
            if not enable_datetime:
                toggles.append('if($("time")) $("time").style.display = "none";')
                toggles.append('if($("date")) $("date").style.display = "none";')
                toggles.append('if($("label")) { $("label").style.left = "28px"; $("label").style.clipPath = "polygon(0 0,100% 0,100% 100%,0 100%)"; }')
                toggles.append('if($("ticker")) { $("ticker").style.left = "288px"; $("ticker").style.width = "1632px"; }')

        if ticker_tag:
            toggles.append(f'if($("label")) $("label").textContent = {json.dumps(ticker_tag, ensure_ascii=False)};')

        toggle_js = "\n".join(toggles)
        portrait_fit_js = ""
        if is_vertical:
            portrait_scale = canvas_width / 941
            portrait_fit_js = (
                f'var portraitWrap=document.getElementById("wrap");'
                f'if(portraitWrap){{portraitWrap.style.transform="scale({portrait_scale})";'
                f'portraitWrap.style.transformOrigin="top left";'
                f'portraitWrap.style.position="absolute";'
                f'portraitWrap.style.left="0px";'
                f'portraitWrap.style.top="0px";'
                f'portraitWrap.style.width="941px";'
                f'portraitWrap.style.height="1672px";}}'
            )
        helper_js = 'const $ = (id) => document.getElementById(id);' if is_vertical else ''
        extra_script = f'''
<script>
{helper_js}
{toggle_js}
{portrait_fit_js}
if (document.fonts && document.fonts.ready) {{
  document.fonts.ready.then(() => {{
    if (typeof fitAll === "function") fitAll();
    else if (typeof fitText === "function") fitText();
  }});
}} else {{
  if (typeof fitAll === "function") fitAll();
  else if (typeof fitText === "function") fitText();
}}
</script>
'''
        html = html.replace('</body>', extra_script + '\n</body>')

        # Write temp HTML file
        work_dir = os.path.dirname(os.path.abspath(output_path))
        os.makedirs(work_dir, exist_ok=True)
        temp_html_path = os.path.join(work_dir, "render_overlay_spec.html")
        with open(temp_html_path, 'w', encoding='utf-8') as f:
            f.write(html)

        file_url = Path(temp_html_path).resolve().as_uri()
        abs_out = os.path.abspath(output_path)
        chrome_profile = tempfile.mkdtemp(prefix="news_overlay_chrome_")
        cmd = [
            chrome_bin,
            '--headless=new',
            '--disable-gpu',
            '--no-sandbox',
            '--hide-scrollbars',
            '--allow-file-access-from-files',
            '--disable-dev-shm-usage',
            f'--user-data-dir={chrome_profile}',
            '--disable-extensions',
            '--no-first-run',
            '--no-default-browser-check',
            '--default-background-color=00000000',
            '--virtual-time-budget=2000',
            f'--screenshot={abs_out}',
            f'--window-size={canvas_width},{canvas_height}',
            file_url
        ]

        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        finally:
            shutil.rmtree(chrome_profile, ignore_errors=True)
        if res.returncode == 0 and os.path.exists(output_path) and os.path.getsize(output_path) > 10000:
            # Keep the browser's z-index layering intact. Layout elements above
            # the footage window must remain visible in the exported composite.
            return True
        else:
            print("Chrome headless overlay render error:", res.stderr)
            return False
    except Exception as e:
        print("HTML overlay rendering failed:", e)
        return False

def create_news_overlay(
    width: int = 1920,
    height: int = 1080,
    badge_text: str = "BREAKING NEWS",
    headline_text: str = "भोपाल में आज तेज बारिश, कई इलाकों में जलभराव",
    sub_headline: str = "मौसम विभाग ने अगले 24 घंटे के लिए जारी किया अलर्ट",
    ticker_tag: str = "ताजा खबर",
    ticker_text: str = "",
    theme_key: str = "red_alert",
    output_path: str = "overlay.png",
    output_tag_path: str = "overlay_tag.png",
    enable_top_bar: bool = True,
    enable_sidebar: bool = True,
    sidebar_items: list = None,
    enable_location: bool = True,
    location_text: str = "📍 भोपाल, मध्य प्रदेश",
    enable_datetime: bool = True,
    time_text: str = "10:25 AM",
    date_text: str = "28 Oct 2026",
    day_text: str = "मंगलवार",
    logo_path: str = None,
    enable_anchor: bool = False,
    enable_ticker: bool = True,
    frame_x: int = 575,
    frame_y: int = 173,
    frame_w: int = 770,
    frame_h: int = 567
) -> tuple:
    """
    Composites broadcast graphics onto a transparent 1920x1080 canvas.
    Uses Chrome/Edge headless snapshot for 100% exact fidelity with the user's template,
    with an automatic fallback to Pillow plate composition.
    """
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    is_vertical = height > width

    # Attempt pixel-perfect HTML rendering for both supported output sizes.
    if (not is_vertical and width == 1920 and height == 1080) or (
        is_vertical and width == 1080 and height == 1920
    ):
        html_ok = render_html_overlay(
            headline_text=headline_text,
            sub_headline=sub_headline,
            sidebar_items=sidebar_items,
            enable_top_bar=enable_top_bar,
            enable_sidebar=enable_sidebar,
            enable_location=enable_location,
            location_text=location_text,
            enable_datetime=enable_datetime,
            time_text=time_text,
            date_text=date_text,
            day_text=day_text,
            enable_anchor=enable_anchor,
            ticker_tag=ticker_tag,
            output_path=output_path,
            enable_ticker=enable_ticker,
            ticker_text=ticker_text,
            frame_x=frame_x,
            frame_y=frame_y,
            frame_w=frame_w,
            frame_h=frame_h,
            canvas_width=width,
            canvas_height=height,
            logo_path=logo_path
        )
        if html_ok:
            if is_vertical:
                if not enable_ticker:
                    v_ticker_x = -1
                elif not enable_datetime:
                    v_ticker_x = int(215 * (width / 941.0))
                else:
                    v_ticker_x = int(455 * (width / 941.0))
                return output_path, output_tag_path, v_ticker_x, int(1538 * (height / 1672.0))
            if not enable_ticker:
                ticker_start_x = -1
            elif not enable_datetime:
                ticker_start_x = 288
            else:
                ticker_start_x = 698
            ticker_y = 970
            return output_path, output_tag_path, ticker_start_x, ticker_y

    # Fallback to Pillow Plate Composition (works for 9:16 or when headless browser is absent)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    font_file = DEFAULT_FONT if os.path.exists(DEFAULT_FONT) else None

    # 1. Top Bar Plate ("आज की बड़ी खबर" + categories + "श्री NEWS 24x7" logo)
    if enable_top_bar and os.path.exists(PLATE_TOP_BAR):
        top_img = Image.open(PLATE_TOP_BAR).convert("RGBA")
        if is_vertical:
            top_w = width
            top_h = int(top_img.height * (width / top_img.width))
            top_img = top_img.resize((top_w, top_h), Image.Resampling.LANCZOS)
            canvas.paste(top_img, (0, 0), top_img)
        else:
            canvas.paste(top_img, (0, 0), top_img)

    # Dynamic Custom Logo Overlay on Top Bar
    if enable_top_bar and logo_path and os.path.exists(logo_path):
        try:
            custom_logo = Image.open(logo_path).convert("RGBA")
            custom_logo.thumbnail((260, 140), Image.Resampling.LANCZOS)
            lx = width - custom_logo.width - 25
            ly = 15
            canvas.paste(custom_logo, (lx, ly), custom_logo)
        except Exception as e:
            print(f"Custom logo paste error: {e}")

    # 2. Left Sidebar Plate ("मुख्य खबरें" 01 - 05)
    if enable_sidebar and os.path.exists(PLATE_SIDEBAR) and not is_vertical:
        sb_img = Image.open(PLATE_SIDEBAR).convert("RGBA")
        d_sb = ImageDraw.Draw(sb_img)
        f_sb = get_font(font_file, 19)

        if not sidebar_items:
            sidebar_items = [
                "भोपाल से इस वक्त की बड़ी खबर",
                "प्रदेश में मौसम को लेकर नया अपडेट",
                "देश-दुनिया की खास खबरें",
                "बाजार में आज का हाल",
                "खेल जगत से बड़ी अपडेट"
            ]

        slots_y = [115, 210, 305, 400, 495]
        for i, item_text in enumerate(sidebar_items[:5]):
            y_base = slots_y[i]
            lines = textwrap.wrap(item_text.strip(), width=16)
            if len(lines) == 1:
                d_sb.text((120, y_base + 14), shape_devanagari(lines[0]), font=f_sb, fill=(17, 24, 39, 255))
            elif len(lines) >= 2:
                d_sb.text((120, y_base + 3), shape_devanagari(lines[0]), font=f_sb, fill=(17, 24, 39, 255))
                d_sb.text((120, y_base + 26), shape_devanagari(lines[1]), font=f_sb, fill=(17, 24, 39, 255))

        canvas.paste(sb_img, (25, 140), sb_img)

    # 3. Location Pin Tag
    if enable_location and location_text.strip() and not is_vertical:
        d_canvas = ImageDraw.Draw(canvas)
        f_loc = get_font(font_file, 26)
        clean_loc = location_text.replace("📍", "").strip()
        loc_shaped = shape_devanagari(clean_loc)
        loc_bbox = f_loc.getbbox(loc_shaped)
        loc_tw = loc_bbox[2] - loc_bbox[0]
        pill_w = loc_tw + 60
        pill_h = 50
        pill_x = 1130
        pill_y = 185
        # Dark glass pill background
        d_canvas.rounded_rectangle(
            [pill_x, pill_y, pill_x + pill_w, pill_y + pill_h],
            radius=12,
            fill=(15, 23, 42, 220),
            outline=(255, 255, 255, 120),
            width=2
        )
        d_canvas.ellipse([pill_x + 16, pill_y + 17, pill_x + 32, pill_y + 33], fill=(239, 68, 68, 255))
        d_canvas.ellipse([pill_x + 21, pill_y + 22, pill_x + 27, pill_y + 27], fill=(255, 255, 255, 255))
        d_canvas.text((pill_x + 42, pill_y + 9), loc_shaped, font=f_loc, fill=(255, 255, 255, 255))

    # 4. Master Lower Third Plate (3D Breaking News chevron + Red bar + White bar + Clock + Date + Ticker)
    if os.path.exists(PLATE_LOWER_THIRD):
        lt_img = Image.open(PLATE_LOWER_THIRD).convert("RGBA")
        d_lt = ImageDraw.Draw(lt_img)

        f_headline = get_font(font_file, 44 if not is_vertical else 30)
        f_sub = get_font(font_file, 34 if not is_vertical else 24)
        f_time = get_font(font_file, 32 if not is_vertical else 20)
        f_date = get_font(font_file, 21 if not is_vertical else 15)

        clean_headline = shape_devanagari(headline_text.strip())
        d_lt.text((462, 47), clean_headline, font=f_headline, fill=(0, 0, 0, 200))
        d_lt.text((460, 45), clean_headline, font=f_headline, fill=(255, 255, 255, 255))

        if sub_headline and sub_headline.strip():
            clean_sub = shape_devanagari(sub_headline.strip())
            d_lt.text((460, 142), clean_sub, font=f_sub, fill=(15, 23, 42, 255))

        if enable_datetime:
            d_lt.text((60, 235), time_text or "10:25 AM", font=f_time, fill=(255, 255, 255, 255))
            d_lt.text((275, 225), date_text or "28 Oct 2026", font=f_date, fill=(15, 23, 42, 255))
            d_lt.text((295, 255), shape_devanagari(day_text or "मंगलवार"), font=f_date, fill=(15, 23, 42, 255))

        if is_vertical:
            lt_w = width
            lt_h = int(lt_img.height * (width / lt_img.width))
            lt_img = lt_img.resize((lt_w, lt_h), Image.Resampling.LANCZOS)
            canvas.paste(lt_img, (0, height - lt_h), lt_img)
        else:
            canvas.paste(lt_img, (0, 750), lt_img)

    canvas.save(output_path, "PNG")

    # Ticker coordinates
    ticker_start_x = int(715 * (width / 1920.0))
    ticker_y = int(960 if not is_vertical else (height - 65))

    return output_path, output_tag_path, ticker_start_x, ticker_y
