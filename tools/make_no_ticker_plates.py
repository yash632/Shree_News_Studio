import os
import subprocess
import tempfile
from pathlib import Path
from PIL import Image

chrome = r'C:\Program Files\Google\Chrome\Application\chrome.exe'

# 1. Landscape No-Ticker Plate
html_path = os.path.abspath('frontend/index.html')
with open(html_path, 'r', encoding='utf-8') as f:
    html = f.read()

# Make transparent and clear text
html = html.replace('background:radial-gradient(ellipse at 50% 45%,#1b2a6b 0%,#0c1440 45%,#2a0a14 100%)', 'background:transparent')
html = html.replace('html,body{width:100%;height:100%;background:#000;overflow:hidden}', 'html,body{width:1920px;height:1080px;background:transparent;overflow:hidden}')
html = html.replace('.glow{', '.glow{display:none!important;')
html = html.replace('CONFIG.mainHeadline', '""')
html = html.replace('CONFIG.subtitle', '""')
html = html.replace('CONFIG.location', '""')
html = html.replace('CONFIG.tickerText', '""')

# Hide ticker elements and move breaking news to 897px
no_ticker_css = '''
<style>
#under, #ticker, #label, #time, #date { display: none !important; }
#brk { top: 897px !important; }
</style>
'''
html = html.replace('</head>', no_ticker_css + '</head>')
base_uri = Path(os.path.abspath('frontend')).resolve().as_uri() + '/'
html = html.replace('<head>', f'<head>\n<base href="{base_uri}">')

temp_html = os.path.abspath('mobile_app/assets/clean_plate_no_ticker.html')
with open(temp_html, 'w', encoding='utf-8') as f:
    f.write(html)

out_land = os.path.abspath('mobile_app/assets/master_broadcast_plate_no_ticker.png')
user_data = tempfile.mkdtemp(prefix='chrome_plate_')
cmd = [
    chrome, '--headless=new', '--disable-gpu', '--no-sandbox',
    '--allow-file-access-from-files', f'--user-data-dir={user_data}',
    '--default-background-color=00000000', '--window-size=1920,1080',
    f'--screenshot={out_land}', Path(temp_html).resolve().as_uri()
]
res1 = subprocess.run(cmd, capture_output=True, text=True)

# 2. Portrait No-Ticker Plate
html_p_path = os.path.abspath('mobile_app/assets/web/bhopal-news-bulletin.html')
with open(html_p_path, 'r', encoding='utf-8') as f:
    html_p = f.read()

# In portrait, add class ticker-off and remove text content
html_p = html_p.replace('class="poster"', 'class="poster ticker-off"')
html_p = html_p.replace('श्री न्यूज़ 24x7 में आपका स्वागत है', '')
html_p = html_p.replace('हम आपके लिए लाए हैं ताज़ा समाचार', '')
html_p = html_p.replace('भोपाल, मध्य प्रदेश', '')
html_p = html_p.replace('श्री न्यूज़ 24x7 | देश-दुनिया की हर बड़ी खबर | सबसे पहले और सबसे सटीक', '')

# Ensure transparent background for video area
html_p = html_p.replace('<div class="a topbg"></div>', '')
scale_css = '''
<style>
html, body { width: 1080px; height: 1920px; background: transparent !important; margin: 0; padding: 0; overflow: hidden; }
.wrap { width: 1080px !important; height: 1920px !important; transform: scale(1.1477, 1.1483); transform-origin: 0 0; background: transparent !important; }
.poster { background: transparent !important; }
#mainImage { display: none !important; }
</style>
'''
html_p = html_p.replace('</head>', scale_css + '</head>')
base_p_uri = Path(os.path.abspath('mobile_app/assets/web')).resolve().as_uri() + '/'
html_p = html_p.replace('<head>', f'<head>\n<base href="{base_p_uri}">')

temp_p_html = os.path.abspath('mobile_app/assets/clean_plate_p_no_ticker.html')
with open(temp_p_html, 'w', encoding='utf-8') as f:
    f.write(html_p)

out_port = os.path.abspath('mobile_app/assets/master_broadcast_plate_portrait_no_ticker.png')
user_data_p = tempfile.mkdtemp(prefix='chrome_plate_p_')
cmd_p = [
    chrome, '--headless=new', '--disable-gpu', '--no-sandbox',
    '--allow-file-access-from-files', f'--user-data-dir={user_data_p}',
    '--default-background-color=00000000', '--window-size=1080,1920',
    f'--screenshot={out_port}', Path(temp_p_html).resolve().as_uri()
]
res2 = subprocess.run(cmd_p, capture_output=True, text=True)

# Cleanup temp files
for p in [temp_html, temp_p_html]:
    if os.path.exists(p):
        os.remove(p)

print('Landscape plate exists:', os.path.exists(out_land), Image.open(out_land).size if os.path.exists(out_land) else 'NO')
print('Portrait plate exists:', os.path.exists(out_port), Image.open(out_port).size if os.path.exists(out_port) else 'NO')
