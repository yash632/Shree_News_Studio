// ============================================================
// Multi-Server Backend Configuration (Render UI <-> Hugging Face Backend)
// ============================================================
function getBackendUrl() {
    if (window.BACKEND_URL && window.BACKEND_URL.trim()) {
        return window.BACKEND_URL.trim().replace(/\/+$/, '');
    }
    const saved = localStorage.getItem('shree_backend_url');
    if (saved && saved.trim()) {
        return saved.trim().replace(/\/+$/, '');
    }
    return ''; // Same origin: Render hosts full stack directly
}

function setBackendUrl(url) {
    if (!url || !url.trim()) {
        localStorage.removeItem('shree_backend_url');
    } else {
        localStorage.setItem('shree_backend_url', url.trim().replace(/\/+$/, ''));
    }
    window.location.reload();
}

function apiUrl(path) {
    if (!path) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    const base = getBackendUrl();
    let cleanPath = path.startsWith('/') ? path : '/' + path;

    // When communicating with Hugging Face Space backend, route to /backend_api to bypass Gradio's reserved /api route
    if (base && base.includes('hf.space')) {
        cleanPath = cleanPath.replace(/^\/api\//, '/backend_api/');
    }

    return base ? (base + cleanPath) : cleanPath;
}

document.addEventListener('DOMContentLoaded', () => {
    // Form & Button
    const form = document.getElementById('newsForm');
    const generateBtn = document.getElementById('generateBtn');
    
    // File inputs & Dropzones
    const videoInput = document.getElementById('videoInput');
    const videoDropzone = document.getElementById('videoDropzone');
    const videoDropContent = document.getElementById('videoDropContent');
    const videoSelected = document.getElementById('videoSelected');
    const videoFileName = document.getElementById('videoFileName');
    const clearVideoBtn = document.getElementById('clearVideoBtn');

    const audioInput = document.getElementById('audioInput');
    const audioDropzone = document.getElementById('audioDropzone');
    const audioDropContent = document.getElementById('audioDropContent');
    const audioSelected = document.getElementById('audioSelected');
    const audioFileName = document.getElementById('audioFileName');
    const clearAudioBtn = document.getElementById('clearAudioBtn');

    const logoInput = document.getElementById('logoInput');
    const logoUploadBox = document.getElementById('logoUploadBox');
    const logoPreviewImg = document.getElementById('logoPreviewImg');

    // Backend Server Switcher Pill
    const backendServerPill = document.getElementById('backendServerPill');
    const backendStatusText = document.getElementById('backendStatusText');
    const currentBackend = getBackendUrl();
    if (backendStatusText) {
        if (currentBackend) {
            backendStatusText.textContent = `Backend: ${currentBackend.replace(/^https?:\/\//, '')}`;
        } else {
            backendStatusText.textContent = `Backend: Same-Domain`;
        }
    }
    if (backendServerPill) {
        backendServerPill.addEventListener('click', () => {
            const current = getBackendUrl() || 'https://yash632-shree-news-studio.hf.space';
            const entered = prompt(
                "Backend Processing Server URL:\n\n• For Hugging Face: https://yash632-shree-news-studio.hf.space\n• For Render or Local: Leave empty for same domain\n",
                current
            );
            if (entered !== null) {
                setBackendUrl(entered.trim());
            }
        });
    }

    // Audio Controls
    const tabModeTts = document.getElementById('tabModeTts');
    const tabModeUpload = document.getElementById('tabModeUpload');
    const audioModeInput = document.getElementById('audioModeInput');
    const ttsSection = document.getElementById('ttsSection');
    const uploadSection = document.getElementById('uploadSection');
    const ttsTextInput = document.getElementById('ttsTextInput');
    const scriptCharCount = document.getElementById('scriptCharCount');
    const ttsVoiceSelect = document.getElementById('ttsVoiceSelect');
    const previewVoiceBtn = document.getElementById('previewVoiceBtn');
    const voicePreviewAudio = document.getElementById('voicePreviewAudio');
    const ttsSpeedRange = document.getElementById('ttsSpeedRange');
    const speedVal = document.getElementById('speedVal');

    // Screenshot 2 Feature Toggles & Inputs
    const toggleTopBar = document.getElementById('toggleTopBar');
    const toggleSidebar = document.getElementById('toggleSidebar');
    const toggleLocation = document.getElementById('toggleLocation');
    const toggleDateTime = document.getElementById('toggleDateTime');
    const toggleAnchor = document.getElementById('toggleAnchor');
    const toggleTicker = document.getElementById('toggleTicker');

    const frameSizeSlider = document.getElementById('frameSizeSlider');
    const frameScaleLabel = document.getElementById('frameScaleLabel');
    const frameXInput = document.getElementById('frameXInput');
    const frameYInput = document.getElementById('frameYInput');
    const frameWInput = document.getElementById('frameWInput');
    const frameHInput = document.getElementById('frameHInput');

    const locationInput = document.getElementById('locationInput');
    const locationInputGroup = document.getElementById('locationInputGroup');
    const sidebarGroup = document.getElementById('sidebarGroup');
    const sidebarItemInputs = document.querySelectorAll('.sidebar-item-input');

    const headlineInput = document.getElementById('headlineInput');
    const subHeadlineInput = document.getElementById('subHeadlineInput');
    const tickerTagInput = document.getElementById('tickerTagInput');
    const tickerInput = document.getElementById('tickerInput');
    const aspectRadios = document.querySelectorAll('input[name="aspect_ratio"]');

    // Mockup Elements (Screenshot 2 Match)
    const previewWrapper = document.getElementById('previewWrapper');
    const previewRatioBadge = document.getElementById('previewRatioBadge');
    const mockAnchorBg = document.getElementById('mockAnchorBg');
    const mockTopBar = document.getElementById('mockTopBar');
    const mockSidebar = document.getElementById('mockSidebar');
    const mockSidebarList = document.getElementById('mockSidebarList');
    const mockLocation = document.getElementById('mockLocation');
    const mockHeadline = document.getElementById('mockHeadline');
    const mockSubHeadline = document.getElementById('mockSubHeadline');
    const mockTime = document.getElementById('mockTime');
    const mockDate = document.getElementById('mockDate');
    const mockDay = document.getElementById('mockDay');
    const mockDateTimeWrap = document.getElementById('mockDateTimeWrap');
    const mockTickerTag = document.getElementById('mockTickerTag');
    const mockTickerText = document.getElementById('mockTickerText');
    const mockLogoImg = document.getElementById('mockLogoImg');
    const finalVideoPlayer = document.getElementById('finalVideoPlayer');
    const previewCanvasBg = document.getElementById('previewCanvasBg');

    // Progress & Result
    const progressSection = document.getElementById('progressSection');
    const progressStatus = document.getElementById('progressStatus');
    const progressPercent = document.getElementById('progressPercent');
    const progressFill = document.getElementById('progressFill');
    const resultActions = document.getElementById('resultActions');
    const downloadVideoBtn = document.getElementById('downloadVideoBtn');
    const toast = document.getElementById('toast');

    function showToast(message, isError = false) {
        toast.textContent = message;
        toast.style.borderColor = isError ? 'var(--accent-red)' : '#10B981';
        toast.classList.add('show');
        setTimeout(() => toast.classList.remove('show'), 3500);
    }

    // 1. Audio Mode Switch
    tabModeTts.addEventListener('click', () => {
        tabModeTts.classList.add('active');
        tabModeUpload.classList.remove('active');
        audioModeInput.value = 'tts';
        ttsSection.style.display = 'block';
        uploadSection.style.display = 'none';
    });

    tabModeUpload.addEventListener('click', () => {
        tabModeUpload.classList.add('active');
        tabModeTts.classList.remove('active');
        audioModeInput.value = 'upload';
        ttsSection.style.display = 'none';
        uploadSection.style.display = 'block';
    });

    // Script character counter
    if (ttsTextInput) {
        ttsTextInput.addEventListener('input', () => {
            scriptCharCount.textContent = `${ttsTextInput.value.length} characters`;
        });
    }

    // Speed range
    ttsSpeedRange.addEventListener('input', () => {
        speedVal.textContent = parseFloat(ttsSpeedRange.value).toFixed(2) + 'x';
    });
    // Init display
    speedVal.textContent = parseFloat(ttsSpeedRange.value).toFixed(2) + 'x';

    // Broadcast Audio Mixing & Timeline Controls Interactivity
    const audioMixModeSelect = document.getElementById('audioMixModeSelect');
    const footageVolumeGroup = document.getElementById('footageVolumeGroup');
    const footageVolumeRange = document.getElementById('footageVolumeRange');
    const footageVolumeBadge = document.getElementById('footageVolumeBadge');
    const mode2Options = document.getElementById('mode2Options');
    const groundDurationRange = document.getElementById('groundDurationRange');
    const groundDurationBadge = document.getElementById('groundDurationBadge');
    const outroScriptGroup = document.getElementById('outroScriptGroup');
    const outroTextInput = document.getElementById('outroTextInput');
    const outroCharCount = document.getElementById('outroCharCount');

    if (audioMixModeSelect) {
        audioMixModeSelect.addEventListener('change', () => {
            stopTimelinePreview();
            const mode = audioMixModeSelect.value;
            if (mode === 'intro_then_ground_outro') {
                if (footageVolumeGroup) footageVolumeGroup.style.display = 'block';
                if (mode2Options) mode2Options.style.display = 'block';
                if (outroScriptGroup) outroScriptGroup.style.display = 'block';
            } else if (mode === 'intro_then_ground') {
                if (footageVolumeGroup) footageVolumeGroup.style.display = 'block';
                if (mode2Options) mode2Options.style.display = 'block';
                if (outroScriptGroup) outroScriptGroup.style.display = 'none';
            } else if (mode === 'voiceover_only') {
                if (footageVolumeGroup) footageVolumeGroup.style.display = 'none';
                if (mode2Options) mode2Options.style.display = 'none';
                if (outroScriptGroup) outroScriptGroup.style.display = 'none';
            } else {
                if (footageVolumeGroup) footageVolumeGroup.style.display = 'block';
                if (mode2Options) mode2Options.style.display = 'none';
                if (outroScriptGroup) outroScriptGroup.style.display = 'none';
            }
        });
    }

    if (outroTextInput && outroCharCount) {
        const updateOutroChars = () => {
            outroCharCount.textContent = `${outroTextInput.value.length} characters`;
        };
        outroTextInput.addEventListener('input', updateOutroChars);
        updateOutroChars();
    }

    if (footageVolumeRange && footageVolumeBadge) {
        footageVolumeRange.addEventListener('input', () => {
            footageVolumeBadge.textContent = `${footageVolumeRange.value}%`;
        });
    }

    function formatMinSec(totalSeconds) {
        const s = Math.max(0, Math.floor(totalSeconds || 0));
        const mins = Math.floor(s / 60);
        const secs = s % 60;
        const padMins = mins < 10 ? '0' + mins : mins;
        const padSecs = secs < 10 ? '0' + secs : secs;
        return `${padMins}:${padSecs} min`;
    }

    const groundDurationHint = document.getElementById('groundDurationHint');

    function updateGroundDurationBadge() {
        if (groundDurationRange && groundDurationBadge) {
            groundDurationBadge.textContent = formatMinSec(groundDurationRange.value);
        }
    }

    if (groundDurationRange) {
        groundDurationRange.addEventListener('input', updateGroundDurationBadge);
        updateGroundDurationBadge();
    }

    // Scriptless Confirmation Modal Elements & Handlers
    const noScriptModal = document.getElementById('noScriptModal');
    const closeNoScriptModalBtn = document.getElementById('closeNoScriptModalBtn');
    const cancelNoScriptBtn = document.getElementById('cancelNoScriptBtn');
    const confirmNoScriptProceedBtn = document.getElementById('confirmNoScriptProceedBtn');
    const modalActionWord = document.getElementById('modalActionWord');

    let pendingNoScriptAction = null; // 'generate' | 'preview'
    let bypassScriptCheck = false;

    function openNoScriptModal(action) {
        pendingNoScriptAction = action;
        if (modalActionWord) {
            modalActionWord.textContent = action === 'preview' ? 'preview' : 'generate';
        }
        if (noScriptModal) {
            noScriptModal.style.display = 'flex';
        }
    }

    function closeNoScriptModal() {
        pendingNoScriptAction = null;
        if (noScriptModal) {
            noScriptModal.style.display = 'none';
        }
    }

    if (closeNoScriptModalBtn) {
        closeNoScriptModalBtn.addEventListener('click', closeNoScriptModal);
    }
    if (cancelNoScriptBtn) {
        cancelNoScriptBtn.addEventListener('click', () => {
            closeNoScriptModal();
            if (ttsTextInput) {
                ttsTextInput.scrollIntoView({ behavior: 'smooth', block: 'center' });
                ttsTextInput.focus();
            }
        });
    }
    if (noScriptModal) {
        noScriptModal.addEventListener('click', (e) => {
            if (e.target === noScriptModal) {
                closeNoScriptModal();
            }
        });
    }
    if (confirmNoScriptProceedBtn) {
        confirmNoScriptProceedBtn.addEventListener('click', () => {
            const action = pendingNoScriptAction;
            closeNoScriptModal();
            bypassScriptCheck = true;
            if (action === 'generate') {
                if (typeof form.requestSubmit === 'function') {
                    form.requestSubmit();
                } else {
                    form.dispatchEvent(new Event('submit', { cancelable: true, bubbles: true }));
                }
            } else if (action === 'preview') {
                startTimelinePreview();
            }
        });
    }

    // Real-time Broadcast Audio & Timeline Preview Engine
    const previewTimelineBtn = document.getElementById('previewTimelineBtn');
    const monitorAudioPreviewBtn = document.getElementById('monitorAudioPreviewBtn');
    const timelineLiveStatus = document.getElementById('timelineLiveStatus');
    const timelineCurrentStage = document.getElementById('timelineCurrentStage');
    const timelineStageTime = document.getElementById('timelineStageTime');

    let isTimelinePreviewActive = false;
    let activePreviewTimer = null;
    let previewIntroAudio = null;
    let previewOutroAudio = null;

    function stopTimelinePreview() {
        if (!isTimelinePreviewActive && !activePreviewTimer && !previewIntroAudio) return;
        isTimelinePreviewActive = false;
        if (activePreviewTimer) {
            clearInterval(activePreviewTimer);
            activePreviewTimer = null;
        }
        if (previewIntroAudio) {
            previewIntroAudio.pause();
            previewIntroAudio.currentTime = 0;
            previewIntroAudio = null;
        }
        if (previewOutroAudio) {
            previewOutroAudio.pause();
            previewOutroAudio.currentTime = 0;
            previewOutroAudio = null;
        }

        // Reset video footage volume to muted loop
        if (previewFootageVideo) {
            previewFootageVideo.volume = 1.0;
            previewFootageVideo.muted = true;
        }
        if (portraitReferencePreview && portraitReferencePreview.contentWindow) {
            portraitReferencePreview.contentWindow.postMessage({
                type: 'portrait-audio-control',
                muted: true,
                volume: 1.0
            }, window.location.origin);
        }

        if (timelineLiveStatus) timelineLiveStatus.style.display = 'none';
        updatePreviewBtnState(false);
    }

    function updatePreviewBtnState(active) {
        const icon = active ? '⏹️' : '▶️';
        const text = active ? 'Stop Preview' : 'Preview Audio & Flow';
        const monitorText = active ? 'Stop Preview' : 'Live Audio Preview';

        const iconEl = document.getElementById('previewTimelineIcon');
        const textEl = document.getElementById('previewTimelineText');
        if (iconEl) iconEl.textContent = icon;
        if (textEl) textEl.textContent = text;

        const monIconEl = document.getElementById('monitorPreviewIcon');
        const monTextEl = document.getElementById('monitorPreviewText');
        if (monIconEl) monIconEl.textContent = icon;
        if (monTextEl) monTextEl.textContent = monitorText;
    }

    async function startTimelinePreview() {
        if (isTimelinePreviewActive) {
            stopTimelinePreview();
            return;
        }

        if (!previewFootageVideo || !previewFootageVideo.src) {
            showToast("Please upload video footage first.", true);
            return;
        }

        if (audioModeInput && audioModeInput.value === 'tts' && !(ttsTextInput?.value || '').trim()) {
            if (!bypassScriptCheck) {
                openNoScriptModal('preview');
                return;
            }
        }
        const wasBypassed = bypassScriptCheck;
        bypassScriptCheck = false;

        const mode = audioMixModeSelect ? audioMixModeSelect.value : 'voiceover_ambient';
        const footageVol = Math.max(0, Math.min(1, (parseFloat(footageVolumeRange?.value) || 20) / 100));
        const groundDur = parseFloat(groundDurationRange?.value) || 10;
        const restartFootage = restartFootageToggle ? restartFootageToggle.checked : false;
        const voiceId = ttsVoiceSelect ? ttsVoiceSelect.value : 'en-US-EmmaMultilingualNeural';
        const ttsSpeed = parseFloat(ttsSpeedRange?.value) || 1.3;

        const textEl = document.getElementById('previewTimelineText');
        if (textEl) textEl.textContent = 'Preparing...';
        const monTextEl = document.getElementById('monitorPreviewText');
        if (monTextEl) monTextEl.textContent = 'Preparing...';

        try {
            let introAudioUrl = null;
            let outroAudioUrl = null;

            const rawScriptText = (ttsTextInput?.value || '').trim();
            if (audioModeInput && audioModeInput.value === 'upload' && audioInput && audioInput.files && audioInput.files.length > 0) {
                introAudioUrl = URL.createObjectURL(audioInput.files[0]);
            } else if (!rawScriptText) {
                // Scriptless mode: no anchor voiceover audio
                introAudioUrl = null;
            } else {
                const introText = rawScriptText;
                const sampleText = introText.length > 300 ? introText.slice(0, 300) : introText;
                const resp = await fetch(apiUrl('/api/preview-voice'), {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ voice_id: voiceId, text: sampleText, speed: ttsSpeed })
                });
                const resData = await resp.json();
                if (!resData.success || !resData.audio_url) {
                    showToast("Voice preview failed.", true);
                    updatePreviewBtnState(false);
                    return;
                }
                introAudioUrl = apiUrl(resData.audio_url);
            }

            if (mode === 'intro_then_ground_outro') {
                const outroText = (outroTextInput?.value || '').trim() || "विशेष बुलेटिन में फिलहाल इतना ही, देश-दुनिया की बाकी खबरों के लिए देखते रहिए श्री NEWS 24x7...";
                const sampleOutro = outroText.length > 300 ? outroText.slice(0, 300) : outroText;
                const resp2 = await fetch(apiUrl('/api/preview-voice'), {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ voice_id: voiceId, text: sampleOutro, speed: ttsSpeed })
                });
                const resData2 = await resp2.json();
                if (resData2.success && resData2.audio_url) {
                    outroAudioUrl = apiUrl(resData2.audio_url);
                }
            }

            if (introAudioUrl) {
                previewIntroAudio = new Audio(introAudioUrl);
            }
            if (outroAudioUrl) {
                previewOutroAudio = new Audio(outroAudioUrl);
            }

            isTimelinePreviewActive = true;
            updatePreviewBtnState(true);
            if (timelineLiveStatus) timelineLiveStatus.style.display = 'block';

            if (!introAudioUrl) {
                // Scriptless footage audio playback mode
                setVideoFootageAudio(1.0, false);
                restartVideoFootage();
                if (timelineCurrentStage) timelineCurrentStage.textContent = "🔊 Footage Audio (Original Audio at 100%)";
                activePreviewTimer = setInterval(() => {
                    if (!isTimelinePreviewActive) return;
                    const cur = previewFootageVideo ? previewFootageVideo.currentTime : 0;
                    const tot = previewFootageVideo ? previewFootageVideo.duration || 1 : 1;
                    if (timelineStageTime) timelineStageTime.textContent = `${formatMinSec(cur)} / ${formatMinSec(tot)}`;
                }, 200);
                return;
            }

            function setVideoFootageAudio(vol, mute) {
                if (previewFootageVideo) {
                    previewFootageVideo.muted = mute;
                    previewFootageVideo.volume = mute ? 0.0 : Math.max(0, Math.min(1, vol));
                    previewFootageVideo.play().catch(() => {});
                }
                if (portraitReferencePreview && portraitReferencePreview.contentWindow) {
                    portraitReferencePreview.contentWindow.postMessage({
                        type: 'portrait-audio-control',
                        muted: mute,
                        volume: mute ? 0.0 : Math.max(0, Math.min(1, vol)),
                        action: 'play'
                    }, window.location.origin);
                }
            }

            function restartVideoFootage() {
                if (previewFootageVideo) {
                    previewFootageVideo.currentTime = 0;
                    previewFootageVideo.play().catch(() => {});
                }
                if (portraitReferencePreview && portraitReferencePreview.contentWindow) {
                    portraitReferencePreview.contentWindow.postMessage({
                        type: 'portrait-audio-control',
                        currentTime: 0,
                        action: 'play'
                    }, window.location.origin);
                }
            }

            if (mode === 'voiceover_only') {
                setVideoFootageAudio(0.0, true);
                if (timelineCurrentStage) timelineCurrentStage.textContent = "🔇 Mode 4: Voiceover Only (Footage Muted)";
                previewIntroAudio.volume = 1.0;
                previewIntroAudio.play();

                activePreviewTimer = setInterval(() => {
                    if (!isTimelinePreviewActive) return;
                    const cur = previewIntroAudio ? previewIntroAudio.currentTime : 0;
                    const tot = previewIntroAudio ? previewIntroAudio.duration || 1 : 1;
                    if (timelineStageTime) timelineStageTime.textContent = `${formatMinSec(cur)} / ${formatMinSec(tot)}`;
                }, 200);

                previewIntroAudio.onended = () => {
                    stopTimelinePreview();
                    showToast("Preview completed.");
                };

            } else if (mode === 'voiceover_ambient') {
                setVideoFootageAudio(footageVol, false);
                if (timelineCurrentStage) timelineCurrentStage.textContent = `🎙️ Mode 1: Anchor Speaking + Footage Ambient (${Math.round(footageVol * 100)}%)`;
                previewIntroAudio.volume = 1.0;
                previewIntroAudio.play();

                activePreviewTimer = setInterval(() => {
                    if (!isTimelinePreviewActive) return;
                    const cur = previewIntroAudio ? previewIntroAudio.currentTime : 0;
                    const tot = previewIntroAudio ? previewIntroAudio.duration || 1 : 1;
                    if (timelineStageTime) timelineStageTime.textContent = `${formatMinSec(cur)} / ${formatMinSec(tot)}`;
                }, 200);

                previewIntroAudio.onended = () => {
                    stopTimelinePreview();
                    showToast("Preview completed.");
                };

            } else if (mode === 'intro_then_ground') {
                setVideoFootageAudio(footageVol, false);
                if (timelineCurrentStage) timelineCurrentStage.textContent = `🎙️ Stage 1: Anchor Intro (Footage: ${Math.round(footageVol * 100)}%)`;
                previewIntroAudio.volume = 1.0;
                previewIntroAudio.play();

                activePreviewTimer = setInterval(() => {
                    if (!isTimelinePreviewActive) return;
                    const cur = previewIntroAudio ? previewIntroAudio.currentTime : 0;
                    const tot = previewIntroAudio ? previewIntroAudio.duration || 1 : 1;
                    if (timelineStageTime) timelineStageTime.textContent = `${formatMinSec(cur)} / ${formatMinSec(tot)}`;
                }, 200);

                previewIntroAudio.onended = () => {
                    if (!isTimelinePreviewActive) return;
                    if (activePreviewTimer) clearInterval(activePreviewTimer);

                    if (restartFootage) restartVideoFootage();
                    setVideoFootageAudio(1.0, false);
                    if (timelineCurrentStage) timelineCurrentStage.textContent = `🎬 Stage 2: Ground Video (100% Full Natural Sound)`;

                    let groundElapsed = 0;
                    activePreviewTimer = setInterval(() => {
                        if (!isTimelinePreviewActive) return;
                        groundElapsed += 0.2;
                        if (timelineStageTime) timelineStageTime.textContent = `${formatMinSec(groundElapsed)} / ${formatMinSec(groundDur)}`;
                        if (groundElapsed >= groundDur) {
                            stopTimelinePreview();
                            showToast("News Package preview completed.");
                        }
                    }, 200);
                };

            } else if (mode === 'intro_then_ground_outro') {
                setVideoFootageAudio(footageVol, false);
                if (timelineCurrentStage) timelineCurrentStage.textContent = `🎙️ Stage 1: Anchor Intro (Footage: ${Math.round(footageVol * 100)}%)`;
                previewIntroAudio.volume = 1.0;
                previewIntroAudio.play();

                activePreviewTimer = setInterval(() => {
                    if (!isTimelinePreviewActive) return;
                    const cur = previewIntroAudio ? previewIntroAudio.currentTime : 0;
                    const tot = previewIntroAudio ? previewIntroAudio.duration || 1 : 1;
                    if (timelineStageTime) timelineStageTime.textContent = `${formatMinSec(cur)} / ${formatMinSec(tot)}`;
                }, 200);

                previewIntroAudio.onended = () => {
                    if (!isTimelinePreviewActive) return;
                    if (activePreviewTimer) clearInterval(activePreviewTimer);

                    if (restartFootage) restartVideoFootage();
                    setVideoFootageAudio(1.0, false);
                    if (timelineCurrentStage) timelineCurrentStage.textContent = `🎬 Stage 2: Ground Video Clip (100% Original Audio)`;

                    let groundElapsed = 0;
                    activePreviewTimer = setInterval(() => {
                        if (!isTimelinePreviewActive) return;
                        groundElapsed += 0.2;
                        if (timelineStageTime) timelineStageTime.textContent = `${formatMinSec(groundElapsed)} / ${formatMinSec(groundDur)}`;

                        if (groundElapsed >= groundDur) {
                            if (activePreviewTimer) clearInterval(activePreviewTimer);

                            if (!isTimelinePreviewActive) return;
                            const restartOutro = document.getElementById('restartOutroFootageToggle')?.checked || false;
                            if (restartOutro) restartVideoFootage();
                            setVideoFootageAudio(footageVol, false);
                            if (timelineCurrentStage) timelineCurrentStage.textContent = `📺 Stage 3: Anchor Outro / Sign-off${restartOutro ? ' (Video Restarted)' : ''}`;

                            if (previewOutroAudio) {
                                previewOutroAudio.volume = 1.0;
                                previewOutroAudio.play();
                                activePreviewTimer = setInterval(() => {
                                    if (!isTimelinePreviewActive) return;
                                    const cur = previewOutroAudio ? previewOutroAudio.currentTime : 0;
                                    const tot = previewOutroAudio ? previewOutroAudio.duration || 1 : 1;
                                    if (timelineStageTime) timelineStageTime.textContent = `${formatMinSec(cur)} / ${formatMinSec(tot)}`;
                                }, 200);
                                previewOutroAudio.onended = () => {
                                    stopTimelinePreview();
                                    showToast("3-Stage TV Package preview completed!");
                                };
                            } else {
                                stopTimelinePreview();
                                showToast("3-Stage TV Package preview completed!");
                            }
                        }
                    }, 200);
                };
            }

        } catch (err) {
            console.error("Timeline preview error:", err);
            showToast("Error starting audio preview: " + err.message, true);
            stopTimelinePreview();
        }
    }

    if (previewTimelineBtn) previewTimelineBtn.addEventListener('click', startTimelinePreview);
    if (monitorAudioPreviewBtn) monitorAudioPreviewBtn.addEventListener('click', startTimelinePreview);

    // 2. Dropzone Setup
    function setupDropzone(zone, input, content, selected, fileNameEl) {
        zone.addEventListener('click', (e) => {
            if (e.target.closest('.btn-clear')) return;
            input.click();
        });

        zone.addEventListener('dragover', (e) => {
            e.preventDefault();
            zone.classList.add('dragover');
        });

        zone.addEventListener('dragleave', () => zone.classList.remove('dragover'));

        zone.addEventListener('drop', (e) => {
            e.preventDefault();
            zone.classList.remove('dragover');
            if (e.dataTransfer.files.length > 0) {
                input.files = e.dataTransfer.files;
                handleFileSelect();
                input.dispatchEvent(new Event('change'));
            }
        });

        input.addEventListener('change', handleFileSelect);

        function handleFileSelect() {
            if (input.files.length > 0) {
                const file = input.files[0];
                fileNameEl.textContent = `${file.name} (${(file.size / (1024 * 1024)).toFixed(1)} MB)`;
                content.style.display = 'none';
                selected.style.display = 'flex';
            }
        }
    }

    setupDropzone(videoDropzone, videoInput, videoDropContent, videoSelected, videoFileName);
    setupDropzone(audioDropzone, audioInput, audioDropContent, audioSelected, audioFileName);

    clearVideoBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        videoInput.value = '';
        videoDropContent.style.display = 'block';
        videoSelected.style.display = 'none';
    });

    clearAudioBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        audioInput.value = '';
        audioDropContent.style.display = 'block';
        audioSelected.style.display = 'none';
    });

    // 3. Logo Upload & Live Preview (Dynamic Canvas & Video Synchronization)
    const logoImg = document.getElementById('logoImg');
    const resetLogoBtn = document.getElementById('resetLogoBtn');
    const logoNote = document.querySelector('.logo-note');

    function applyLogoToPreview(dataUrl, fileName) {
        if (logoPreviewImg) logoPreviewImg.src = dataUrl;
        if (logoImg) logoImg.src = dataUrl;
        const portraitLogoBox = document.querySelector('.logoBox');
        if (portraitLogoBox) {
            portraitLogoBox.innerHTML = `<img src="${dataUrl}" style="width:100%;height:100%;object-fit:contain;">`;
        }
        if (logoNote) {
            logoNote.innerHTML = `✓ <strong>Custom Logo Active</strong>${fileName ? ` (${fileName})` : ''}`;
            logoNote.style.color = '#4ade80';
        }
        if (resetLogoBtn) resetLogoBtn.style.display = 'inline-block';
        syncPortraitPreview();
    }

    function revertToDefaultLogo() {
        if (logoInput) logoInput.value = '';
        if (logoPreviewImg) logoPreviewImg.src = '/static/logo.png';
        if (logoImg) logoImg.src = '/static/logo.png';
        const portraitLogoBox = document.querySelector('.logoBox');
        if (portraitLogoBox) {
            portraitLogoBox.innerHTML = `<img src="/static/logo.png" style="width:100%;height:100%;object-fit:contain;">`;
        }
        if (logoNote) {
            logoNote.innerHTML = '✓ <strong>logo.png</strong> active by default.';
            logoNote.style.color = '';
        }
        if (resetLogoBtn) resetLogoBtn.style.display = 'none';
        syncPortraitPreview();
    }

    if (logoUploadBox && logoInput) {
        logoUploadBox.addEventListener('click', () => logoInput.click());
        logoInput.addEventListener('change', () => {
            if (logoInput.files && logoInput.files.length > 0) {
                const file = logoInput.files[0];
                const reader = new FileReader();
                reader.onload = (e) => {
                    applyLogoToPreview(e.target.result, file.name);
                };
                reader.readAsDataURL(file);
            }
        });
    }

    if (resetLogoBtn) {
        resetLogoBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            revertToDefaultLogo();
        });
    }

    // 4. Live Broadcast Canvas Synchronization (Exact User Template)
    const previewFootageVideo = document.getElementById('previewFootageVideo');
    const footagePlaceholder = document.getElementById('footagePlaceholder');
    const portraitReferencePreview = document.getElementById('portraitReferencePreview');
    let portraitVideoUrl = '';
    const portraitFeatureState = { sidebar: false, anchor: false };

    function syncPortraitPreview() {
        if (!portraitReferencePreview || !portraitReferencePreview.contentWindow) return;
        const isVertical = document.querySelector('input[name="aspect_ratio"]:checked')?.value === '9:16';
        if (!isVertical) return;
        const scaleVal = frameSizeSlider ? parseInt(frameSizeSlider.value) : 100;
        const logoPreviewImg = document.getElementById('logoPreviewImg');
        portraitReferencePreview.contentWindow.postMessage({
            type: 'portrait-preview',
            headline: headlineInput ? headlineInput.value.trim() : '',
            subtitle: subHeadlineInput ? subHeadlineInput.value.trim() : '',
            location: locationInput ? locationInput.value : '',
            locationEnabled: !!(toggleLocation && toggleLocation.checked),
            datetimeEnabled: !!(toggleDateTime && toggleDateTime.checked),
            tickerEnabled: !!(toggleTicker && toggleTicker.checked),
            tickerTag: tickerTagInput ? tickerTagInput.value.trim() : '',
            ticker: tickerInput ? tickerInput.value.trim() : '',
            videoSrc: portraitVideoUrl,
            frameScale: scaleVal,
            logoSrc: logoPreviewImg ? logoPreviewImg.src : ''
        }, window.location.origin);
    }

    function updatePortraitFeatureState() {
        const isVertical = document.querySelector('input[name="aspect_ratio"]:checked')?.value === '9:16';
        const sidebarCard = toggleSidebar ? toggleSidebar.closest('.toggle-card') : null;
        const anchorCard = toggleAnchor ? toggleAnchor.closest('.toggle-card') : null;
        if (isVertical) {
            // Hide Sidebar and Anchor options completely in 9:16 Portrait mode
            if (sidebarCard) sidebarCard.style.display = 'none';
            if (anchorCard) anchorCard.style.display = 'none';
            if (toggleSidebar) toggleSidebar.checked = false;
            if (toggleAnchor) toggleAnchor.checked = false;
        } else {
            // Show Sidebar and Anchor options normally in 16:9 Landscape mode
            if (sidebarCard) sidebarCard.style.display = '';
            if (anchorCard) anchorCard.style.display = '';
        }
    }

    if (portraitReferencePreview) {
        portraitReferencePreview.addEventListener('load', syncPortraitPreview);
    }

    // Handle user video selection
    videoInput.addEventListener('change', () => {
        stopTimelinePreview();
        if (videoInput.files.length > 0) {
            const file = videoInput.files[0];
            const videoUrl = URL.createObjectURL(file);
            portraitVideoUrl = videoUrl;
            if (previewFootageVideo) {
                previewFootageVideo.src = videoUrl;
                previewFootageVideo.style.display = 'block';
                if (footagePlaceholder) footagePlaceholder.style.display = 'none';
                previewFootageVideo.play().catch(() => {});
            }

            // Detect exact video duration for ground duration slider
            const metaVideo = document.createElement('video');
            metaVideo.preload = 'metadata';
            metaVideo.src = videoUrl;
            metaVideo.onloadedmetadata = () => {
                const totalDur = Math.floor(metaVideo.duration || 0);
                if (totalDur >= 3) {
                    groundDurationRange.max = totalDur;
                    if (parseFloat(groundDurationRange.value) > totalDur) {
                        groundDurationRange.value = totalDur;
                    }
                    if (groundDurationHint) {
                        groundDurationHint.textContent = `Full video length: ${formatMinSec(totalDur)} (Slide to adjust ground duration)`;
                    }
                    updateGroundDurationBadge();
                }
            };

            syncPortraitPreview();
        }
    });

    clearVideoBtn.addEventListener('click', () => {
        stopTimelinePreview();
        if (groundDurationRange) {
            groundDurationRange.max = 300;
            if (groundDurationHint) {
                groundDurationHint.textContent = 'Time footage plays after anchor finishes';
            }
            updateGroundDurationBadge();
        }
        if (previewFootageVideo) {
            previewFootageVideo.pause();
            previewFootageVideo.src = '';
            portraitVideoUrl = '';
            previewFootageVideo.style.display = 'none';
            if (footagePlaceholder) footagePlaceholder.style.display = 'flex';
            syncPortraitPreview();
        }
    });

    // Auto-fit responsive scale for canvas inside preview wrapper (supports 16:9 and 9:16)
    function fitPreview() {
        const wrapper = document.getElementById('previewWrapper');
        const canvas = document.getElementById('canvas');
        if (!wrapper || !canvas) return;
        const isVertical = canvas.classList.contains('vertical-mode');
        const baseWidth = isVertical ? 1080 : 1920;
        const s = wrapper.clientWidth / baseWidth;
        canvas.style.transform = `scale(${s})`;
        canvas.style.transformOrigin = '0 0';
    }
    window.addEventListener('resize', fitPreview);
    if (window.ResizeObserver) {
        const wrapper = document.getElementById('previewWrapper');
        if (wrapper) {
            new ResizeObserver(() => fitPreview()).observe(wrapper);
        }
    }

    // Dynamic Text Fitting engine from user template
    const _cv = document.createElement('canvas').getContext('2d');
    function fitAll() {
        document.querySelectorAll('.fit').forEach(el => {
            const cs = getComputedStyle(el);
            _cv.font = (cs.fontWeight || '800') + ' 100px ' + (cs.fontFamily || "'Hind', sans-serif");
            const m = _cv.measureText(el.textContent);
            const L = m.actualBoundingBoxLeft || 0, Rr = m.actualBoundingBoxRight || m.width;
            const inkW = (L + Rr) || m.width, inkH = (m.actualBoundingBoxAscent + m.actualBoundingBoxDescent) || 0;
            let fs = 100 * (+el.dataset.w) / (inkW || 1);
            if (el.dataset.h && inkH) fs = Math.min(fs, 100 * (+el.dataset.h) / inkH);
            if (el.dataset.max) fs = Math.min(fs, +el.dataset.max);
            if (el.id === 'hl') {
                const maxW = 1335;
                let calcFs = Math.min(68, Math.max(38, Math.floor(100 * maxW / (inkW || 1))));
                el.style.fontSize = calcFs + 'px';
                return;
            }
            if (el.id === 'subt') {
                const maxW = 1315;
                let calcFs = Math.min(46, Math.max(26, Math.floor(100 * maxW / (inkW || 1))));
                el.style.fontSize = calcFs + 'px';
                return;
            }
            const k = fs / 100;
            const fa = m.fontBoundingBoxAscent, fd = m.fontBoundingBoxDescent;
            const lineCentreAboveBase = (fa !== undefined) ? (fa - fd) / 2 * k : fs * 0.3;
            const dx = (Rr - L) / 2 * k - m.width * k / 2;
            el.style.fontSize = fs + 'px';
            el.style.left = (+el.dataset.cx - dx) + 'px';
            el.style.top = (+el.dataset.by - lineCentreAboveBase) + 'px';
        });
    }

    // Live clock & calendar
    const hindiDays = ["रविवार", "सोमवार", "मंगलवार", "बुधवार", "गुरुवार", "शुक्रवार", "शनिवार"];
    const engMons = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    function tickClock() {
        const timeEl = document.getElementById('time');
        const dateEl = document.getElementById('date');
        if (!timeEl || !dateEl) return;
        const d = new Date();
        let h = d.getHours(), ap = h >= 12 ? "PM" : "AM";
        h = h % 12 || 12;
        timeEl.textContent = `${String(h).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')} ${ap}`;
        dateEl.innerHTML = `${String(d.getDate()).padStart(2, '0')} ${engMons[d.getMonth()]} ${d.getFullYear()}<br>${hindiDays[d.getDay()]}`;
    }
    setInterval(tickClock, 1000);
    tickClock();

    function updateMockup() {
        // 1. Top Bar Elements (Header, Banner, Cards, Logo)
        const headerEl = document.getElementById('header');
        const bannerEl = document.getElementById('banner');
        const card1 = document.getElementById('card1');
        const card2 = document.getElementById('card2');
        const card3 = document.getElementById('card3');
        const logoEl = document.getElementById('logo');
        const showTop = toggleTopBar ? toggleTopBar.checked : true;
        [headerEl, bannerEl, card1, card2, card3, logoEl].forEach(el => {
            if (el) el.style.display = showTop ? 'flex' : 'none';
        });
        if (showTop && headerEl) headerEl.style.display = 'block';
        if (showTop && bannerEl) bannerEl.style.display = 'block';

        // 2. Left Sidebar (Dynamic 1 to 5 Points)
        const leftEl = document.getElementById('left');
        const listEl = document.getElementById('list');
        const showSidebar = toggleSidebar ? toggleSidebar.checked : false;
        if (sidebarGroup) sidebarGroup.style.display = showSidebar ? 'block' : 'none';

        let hasSidebar = false;
        if (leftEl && listEl) {
            if (!showSidebar) {
                leftEl.style.display = 'none';
            } else {
                let activeItems = [];
                sidebarItemInputs.forEach(inp => {
                    const val = inp.value.trim();
                    if (val) activeItems.push(val);
                });

                if (activeItems.length === 0) {
                    activeItems = [
                        "भोपाल से इस वक्त की बड़ी खबर",
                        "प्रदेश में मौसम को लेकर नया अपडेट",
                        "यातायात व्यवस्था में हुआ बड़ा बदलाव"
                    ];
                }
                hasSidebar = true;
                leftEl.style.display = 'block';
                leftEl.style.height = `${Math.min(595, 95 + activeItems.length * 100)}px`;
                listEl.innerHTML = activeItems.map((h, i) =>
                    `<div class="news" style="top:${82 + i * 98}px"><div class="num">0${i + 1}</div><div class="tx">${h}</div></div>`
                ).join('');
            }
        }

        // 3. Date & Time Bar Toggle & Ticker Strip Alignment (Determines brkTop first)
        const timeEl = document.getElementById('time');
        const dateEl = document.getElementById('date');
        const labelEl = document.getElementById('label');
        const tickerEl = document.getElementById('ticker');
        const underEl = document.getElementById('under');
        const trackEl = document.getElementById('track');
        const brkEl = document.getElementById('brk');

        const showTicker = toggleTicker ? toggleTicker.checked : true;
        const showDT = toggleDateTime ? toggleDateTime.checked : true;

        // When ticker is ON, brk is at 765px. When ticker is OFF, brk moves down to 897px.
        const brkTop = showTicker ? 765 : 897;
        if (brkEl) brkEl.style.top = `${brkTop}px`;

        if (!showTicker) {
            [underEl, timeEl, dateEl, labelEl, tickerEl].forEach(el => {
                if (el) el.style.display = 'none';
            });
        } else {
            if (underEl) underEl.style.display = 'block';
            if (labelEl) labelEl.style.display = 'block';
            if (tickerEl) tickerEl.style.display = 'block';

            if (showDT) {
                if (timeEl) timeEl.style.display = 'block';
                if (dateEl) dateEl.style.display = 'block';
                if (labelEl) {
                    labelEl.style.left = '445px';
                    labelEl.style.clipPath = 'polygon(0 0,100% 0,100% 100%,0 100%,14px 50%)';
                }
                if (tickerEl) {
                    tickerEl.style.left = '698px';
                    tickerEl.style.width = '1222px';
                }
            } else {
                // Time & Date unchecked -> Shift 'ताजा खबर' and ticker all the way to left!
                if (timeEl) timeEl.style.display = 'none';
                if (dateEl) dateEl.style.display = 'none';
                if (labelEl) {
                    labelEl.style.left = '28px';
                    labelEl.style.clipPath = 'polygon(0 0,100% 0,100% 100%,0 100%)';
                }
                if (tickerEl) {
                    tickerEl.style.left = '288px';
                    tickerEl.style.width = '1632px';
                }
            }

            if (labelEl && tickerTagInput) {
                labelEl.textContent = tickerTagInput.value.trim() || 'ताजा खबर';
            }
            if (trackEl && tickerInput) {
                const t = tickerInput.value.trim() || 'भोपाल | इंदौर | ग्वालियर | जबलपुर | उज्जैन | सागर | रीवा | और देश-दुनिया की हर खबर';
                trackEl.innerHTML = `<span>${t}</span><span>${t}</span>`;
            }
        }

        // 4. Anchor & Video Footage Screen Positioning and Size Slider
        const frameEl = document.getElementById('frame');
        const anchorEl = document.getElementById('anchor');
        const showAnchor = toggleAnchor ? toggleAnchor.checked : false;
        if (anchorEl) {
            anchorEl.style.display = showAnchor ? 'flex' : 'none';
            if (showAnchor) {
                // Anchor bottom touches the top edge of Breaking News band exactly
                anchorEl.style.top = `${brkTop - 620}px`;
            }
        }

        const scaleVal = frameSizeSlider ? parseInt(frameSizeSlider.value) : 100;
        if (frameScaleLabel) {
            frameScaleLabel.textContent = `${scaleVal}% ${scaleVal === 100 ? '(Standard)' : (scaleVal > 180 ? '(Full Screen)' : (scaleVal > 100 ? '(Wide)' : '(Compact)'))}`;
        }
        const scale = scaleVal / 100;

        // Baseline standard (100%) window
        const stdW = 770;
        const stdH = 567;
        const topNavBottom = showTop ? 148 : 0;
        const availH = Math.max(100, brkTop - topNavBottom);
        const centerVerticalY = Math.max(0, Math.round(topNavBottom + (availH - stdH) / 2));

        let frameW, frameH, frameX, frameY;
        let anchorX = 100;

        if (scaleVal >= 100) {
            const t = Math.min(1.0, (scaleVal - 100) / 150);
            frameW = Math.round(stdW + (1920 - stdW) * t);
            frameH = Math.round(stdH + (1080 - stdH) * t);
            const targetCenterY = Math.round((1080 - frameH) / 2);
            frameY = Math.round(centerVerticalY + (targetCenterY - centerVerticalY) * t);
        } else {
            frameW = Math.round(stdW * scale);
            frameH = Math.round(stdH * scale);
            frameY = Math.round(centerVerticalY + (stdH - frameH) / 2);
        }

        if (!showSidebar && !showAnchor) {
            // STRICT 100% HORIZONTAL & VERTICAL CENTER AT ALL SCALES
            frameX = Math.round((1920 - frameW) / 2);
            const freeH = brkTop - topNavBottom;
            frameY = Math.round(topNavBottom + (freeH - frameH) / 2);
        } else if (showAnchor && showSidebar) {
            const openRight = 1000;
            const stdX = Math.max(0, Math.round(openRight + (1920 - openRight - stdW) / 2));
            const targetCenterX = Math.round((1920 - frameW) / 2);
            const t = scaleVal >= 100 ? Math.min(1.0, (scaleVal - 100) / 150) : 0;
            frameX = Math.round(stdX * (1 - t) + targetCenterX * t);
            anchorX = 380;
        } else if (!showAnchor && showSidebar) {
            const openStart = 400;
            const openWidth = 1920 - openStart;
            const stdX = Math.max(0, Math.round(openStart + (openWidth - stdW) / 2));
            const targetCenterX = Math.round((1920 - frameW) / 2);
            const t = scaleVal >= 100 ? Math.min(1.0, (scaleVal - 100) / 150) : 0;
            frameX = Math.round(stdX * (1 - t) + targetCenterX * t);
        } else if (showAnchor && !showSidebar) {
            anchorX = 100;
            const rightStart = 650;
            const rightWidth = 1920 - rightStart;
            const stdX = Math.max(0, Math.round(rightStart + (rightWidth - stdW) / 2));
            const targetCenterX = Math.round((1920 - frameW) / 2);
            const t = scaleVal >= 100 ? Math.min(1.0, (scaleVal - 100) / 150) : 0;
            frameX = Math.round(stdX * (1 - t) + targetCenterX * t);
        }
        if (frameEl) {
            frameEl.style.left = `${frameX}px`;
            frameEl.style.top = `${frameY}px`;
            frameEl.style.width = `${frameW}px`;
            frameEl.style.height = `${frameH}px`;
            frameEl.style.zIndex = '4';
        }
        if (anchorEl) {
            anchorEl.style.left = `${anchorX}px`;
        }
        if (frameXInput) frameXInput.value = frameX;
        if (frameYInput) frameYInput.value = frameY;
        if (frameWInput) frameWInput.value = frameW;
        if (frameHInput) frameHInput.value = frameH;
        // 5. Location Pin Tag Toggle & Update (Tracks top-left of video frame)
        const locEl = document.getElementById('loc');
        const locTextEl = document.getElementById('location');
        const showLoc = toggleLocation ? toggleLocation.checked : true;
        if (locationInputGroup) locationInputGroup.style.display = showLoc ? 'block' : 'none';
        if (locEl && locTextEl) {
            if (!showLoc) {
                locEl.style.display = 'none';
            } else {
                locEl.style.display = 'flex';
                locEl.style.left = `${frameX + 8}px`;
                locEl.style.top = `${frameY + 10}px`;
                const raw = (locationInput ? locationInput.value : '') || 'भोपाल, मध्य प्रदेश';
                locTextEl.textContent = raw.replace('📍', '').trim();
            }
        }


        // 6. Main Headlines & Subtitles
        const hlEl = document.getElementById('hl');
        const subtEl = document.getElementById('subt');
        if (hlEl && headlineInput) {
            hlEl.textContent = headlineInput.value.trim() || 'भोपाल में आज तेज बारिश, कई इलाकों में जलभराव';
        }
        if (subtEl && subHeadlineInput) {
            subtEl.textContent = subHeadlineInput.value.trim() || 'मौसम विभाग ने अगले 24 घंटे के लिए जारी किया अलर्ट';
        }

        fitAll();
        fitPreview();
        syncPortraitPreview();
    }

    // Attach listeners & auto-save settings
    [toggleTopBar, toggleSidebar, toggleLocation, toggleDateTime, toggleAnchor, toggleTicker].forEach(tg => {
        if (tg) tg.addEventListener('change', () => {
            updateMockup();
            debouncedSaveSettings();
        });
    });

    if (frameSizeSlider) {
        frameSizeSlider.addEventListener('input', () => {
            updateMockup();
            debouncedSaveSettings();
        });
    }

    [headlineInput, subHeadlineInput, locationInput, tickerTagInput, tickerInput].forEach(el => {
        if (el) el.addEventListener('input', () => {
            updateMockup();
            debouncedSaveSettings();
        });
    });

    sidebarItemInputs.forEach(inp => {
        inp.addEventListener('input', () => {
            updateMockup();
            debouncedSaveSettings();
        });
    });

    if (ttsVoiceSelect) ttsVoiceSelect.addEventListener('change', debouncedSaveSettings);
    if (ttsSpeedRange) ttsSpeedRange.addEventListener('input', debouncedSaveSettings);
    if (ttsTextInput) ttsTextInput.addEventListener('input', debouncedSaveSettings);
    if (audioMixModeSelect) audioMixModeSelect.addEventListener('change', debouncedSaveSettings);
    if (footageVolumeRange) footageVolumeRange.addEventListener('input', debouncedSaveSettings);
    if (groundDurationRange) groundDurationRange.addEventListener('input', debouncedSaveSettings);
    if (restartFootageToggle) restartFootageToggle.addEventListener('change', debouncedSaveSettings);
    if (outroTextInput) outroTextInput.addEventListener('input', debouncedSaveSettings);
    const restartOutroToggleEl = document.getElementById('restartOutroFootageToggle');
    if (restartOutroToggleEl) restartOutroToggleEl.addEventListener('change', debouncedSaveSettings);

    // LocalStorage Settings Persistence
    const SETTINGS_STORAGE_KEY = 'ai_news_studio_user_settings_v1';
    let saveTimeout = null;
    function debouncedSaveSettings() {
        clearTimeout(saveTimeout);
        saveTimeout = setTimeout(saveUserSettings, 350);
    }

    function saveUserSettings() {
        try {
            const currentRatio = document.querySelector('input[name="aspect_ratio"]:checked')?.value || '16:9';
            const settings = {
                aspect_ratio: currentRatio,
                audio_mode: audioModeInput ? audioModeInput.value : 'tts',
                tts_text: ttsTextInput ? ttsTextInput.value : '',
                tts_voice: ttsVoiceSelect ? ttsVoiceSelect.value : '',
                tts_speed: ttsSpeedRange ? ttsSpeedRange.value : '1.3',
                enable_top_bar: toggleTopBar ? toggleTopBar.checked : true,
                enable_sidebar: toggleSidebar ? toggleSidebar.checked : false,
                enable_location: toggleLocation ? toggleLocation.checked : true,
                enable_datetime: toggleDateTime ? toggleDateTime.checked : false,
                enable_anchor: toggleAnchor ? toggleAnchor.checked : false,
                enable_ticker: toggleTicker ? toggleTicker.checked : true,
                frame_scale: frameSizeSlider ? frameSizeSlider.value : '100',
                location_text: locationInput ? locationInput.value : '',
                headline_text: headlineInput ? headlineInput.value : '',
                sub_headline: subHeadlineInput ? subHeadlineInput.value : '',
                ticker_tag: tickerTagInput ? tickerTagInput.value : '',
                ticker_text: tickerInput ? tickerInput.value : '',
                ai_provider: aiProviderSelect ? aiProviderSelect.value : 'groq',
                sidebar_items: Array.from(sidebarItemInputs).map(inp => inp.value),
                audio_mix_mode: audioMixModeSelect ? audioMixModeSelect.value : 'voiceover_only',
                footage_volume: footageVolumeRange ? footageVolumeRange.value : '20',
                ground_clip_duration: groundDurationRange ? groundDurationRange.value : '10',
                restart_footage: restartFootageToggle ? restartFootageToggle.checked : false,
                outro_text: outroTextInput ? outroTextInput.value : '',
                restart_outro_footage: document.getElementById('restartOutroFootageToggle')?.checked || false
            };
            localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(settings));
        } catch (e) {
            console.warn('Could not save settings:', e);
        }
    }

    function loadUserSettings() {
        try {
            const raw = localStorage.getItem(SETTINGS_STORAGE_KEY);
            if (!raw) {
                if (toggleSidebar) toggleSidebar.checked = false;
                if (ttsVoiceSelect) ttsVoiceSelect.value = 'hi-IN-SwaraNeural';
                if (audioMixModeSelect) {
                    audioMixModeSelect.value = 'voiceover_only';
                    audioMixModeSelect.dispatchEvent(new Event('change'));
                }
                return;
            }
            const s = JSON.parse(raw);
            if (s.aspect_ratio) {
                const r = document.querySelector(`input[name="aspect_ratio"][value="${s.aspect_ratio}"]`);
                if (r) {
                    r.checked = true;
                    document.querySelectorAll('.format-option').forEach(opt => opt.classList.remove('active'));
                    r.closest('.format-option').classList.add('active');
                    const canvas = document.getElementById('canvas');
                    if (s.aspect_ratio === '9:16') {
                        previewWrapper.classList.remove('ratio-16-9');
                        previewWrapper.classList.add('ratio-9-16');
                        previewRatioBadge.textContent = '9:16 VERTICAL';
                        if (canvas) canvas.classList.add('vertical-mode');
                    } else {
                        previewWrapper.classList.remove('ratio-9-16');
                        previewWrapper.classList.add('ratio-16-9');
                        previewRatioBadge.textContent = '16:9 LANDSCAPE';
                        if (canvas) canvas.classList.remove('vertical-mode');
                    }
                }
            }
            if (s.audio_mode === 'upload' && tabModeUpload) {
                tabModeUpload.click();
            } else if (tabModeTts) {
                tabModeTts.click();
            }
            if (s.tts_text !== undefined && ttsTextInput) ttsTextInput.value = s.tts_text;
            if (ttsVoiceSelect) ttsVoiceSelect.value = s.tts_voice || 'hi-IN-SwaraNeural';
            if (s.tts_speed && ttsSpeedRange) {
                ttsSpeedRange.value = s.tts_speed;
                speedVal.textContent = parseFloat(s.tts_speed).toFixed(2) + 'x';
            }
            if (toggleTopBar && s.enable_top_bar !== undefined) toggleTopBar.checked = s.enable_top_bar;
            if (toggleSidebar && s.enable_sidebar !== undefined) toggleSidebar.checked = s.enable_sidebar;
            if (toggleLocation && s.enable_location !== undefined) toggleLocation.checked = s.enable_location;
            if (toggleDateTime && s.enable_datetime !== undefined) toggleDateTime.checked = s.enable_datetime;
            if (toggleAnchor && s.enable_anchor !== undefined) toggleAnchor.checked = s.enable_anchor;
            if (toggleTicker && s.enable_ticker !== undefined) toggleTicker.checked = s.enable_ticker;
            if (frameSizeSlider && s.frame_scale !== undefined) frameSizeSlider.value = s.frame_scale;
            if (locationInput && s.location_text !== undefined) locationInput.value = s.location_text;
            if (headlineInput && s.headline_text !== undefined) headlineInput.value = s.headline_text;
            if (subHeadlineInput && s.sub_headline !== undefined) subHeadlineInput.value = s.sub_headline;
            if (tickerTagInput && s.ticker_tag !== undefined) tickerTagInput.value = s.ticker_tag;
            if (tickerInput && s.ticker_text !== undefined) tickerInput.value = s.ticker_text;
            if (s.ai_provider && aiProviderSelect) aiProviderSelect.value = s.ai_provider;
            if (s.sidebar_items && Array.isArray(s.sidebar_items)) {
                sidebarItemInputs.forEach((inp, idx) => {
                    if (s.sidebar_items[idx] !== undefined) inp.value = s.sidebar_items[idx];
                });
            }
            if (scriptCharCount && ttsTextInput) scriptCharCount.textContent = `${ttsTextInput.value.length} characters`;

            // Restore Audio Mixing Mode & Settings from memory
            const mixMode = s.audio_mix_mode || 'voiceover_only';
            if (audioMixModeSelect) {
                audioMixModeSelect.value = mixMode;
                audioMixModeSelect.dispatchEvent(new Event('change'));
            }
            if (s.footage_volume !== undefined && footageVolumeRange) {
                footageVolumeRange.value = s.footage_volume;
                if (footageVolumeBadge) footageVolumeBadge.textContent = `${s.footage_volume}%`;
            }
            if (s.ground_clip_duration !== undefined && groundDurationRange) {
                groundDurationRange.value = s.ground_clip_duration;
                updateGroundDurationBadge();
            }
            if (restartFootageToggle && s.restart_footage !== undefined) {
                restartFootageToggle.checked = s.restart_footage;
            }
            if (outroTextInput && s.outro_text !== undefined) {
                outroTextInput.value = s.outro_text;
                if (outroCharCount) outroCharCount.textContent = `${outroTextInput.value.length} characters`;
            }
            const restartOutroToggle = document.getElementById('restartOutroFootageToggle');
            if (restartOutroToggle && s.restart_outro_footage !== undefined) {
                restartOutroToggle.checked = s.restart_outro_footage;
            }
        } catch (e) {
            console.warn('Could not load settings:', e);
        }
    }

    window.addEventListener('pagehide', saveUserSettings);

    // Aspect Ratio Toggle
    aspectRadios.forEach(radio => {
        radio.addEventListener('change', () => {
            document.querySelectorAll('.format-option').forEach(opt => opt.classList.remove('active'));
            radio.closest('.format-option').classList.add('active');

            const canvas = document.getElementById('canvas');
            if (radio.value === '16:9') {
                previewWrapper.classList.remove('ratio-9-16');
                previewWrapper.classList.add('ratio-16-9');
                previewRatioBadge.textContent = '16:9 LANDSCAPE';
                if (canvas) canvas.classList.remove('vertical-mode');
            } else {
                previewWrapper.classList.remove('ratio-16-9');
                previewWrapper.classList.add('ratio-9-16');
                previewRatioBadge.textContent = '9:16 VERTICAL';
                if (canvas) canvas.classList.add('vertical-mode');
            }
            updatePortraitFeatureState();
            updateMockup();
            fitPreview();
            debouncedSaveSettings();
        });
    });

    // Initial load from localStorage & layout sync
    loadUserSettings();
    updatePortraitFeatureState();
    setTimeout(() => {
        updateMockup();
        fitPreview();
    }, 80);
    setTimeout(fitAll, 700);

    // 5. Fast Voice Preview Button
    previewVoiceBtn.addEventListener('click', async () => {
        const voiceId = ttsVoiceSelect.value;
        const sampleText = ttsTextInput.value.trim() ? ttsTextInput.value.slice(0, 80) : "भोपाल में आज तेज बारिश दर्ज की गई है।";
        const currentSpeed = parseFloat(ttsSpeedRange.value) || 1.0;

        previewVoiceBtn.disabled = true;
        previewVoiceBtn.innerHTML = `<span>Loading...</span>`;

        try {
            const resp = await fetch(apiUrl('/api/preview-voice'), {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    voice_id: voiceId,
                    text: sampleText,
                    speed: currentSpeed
                })
            });
            const data = await resp.json();
            if (data.success && data.audio_url) {
                voicePreviewAudio.src = apiUrl(data.audio_url) + '?t=' + Date.now();
                voicePreviewAudio.load();
                voicePreviewAudio.play();
                showToast(`Playing voice preview at ${currentSpeed.toFixed(2)}x speed...`);
            } else {
                showToast(data.error || "Preview failed", true);
            }
        } catch (err) {
            showToast("Failed to connect for voice preview", true);
        } finally {
            previewVoiceBtn.disabled = false;
            previewVoiceBtn.innerHTML = `
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"></path></svg>
                Fast Preview
            `;
        }
    });

    // 6. Form Submission & Polling
    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        stopTimelinePreview();

        if (!videoInput.files || videoInput.files.length === 0) {
            showToast("Please upload video footage first.", true);
            return;
        }

        if (audioModeInput.value === 'tts' && !ttsTextInput.value.trim()) {
            if (!bypassScriptCheck) {
                openNoScriptModal('generate');
                return;
            }
        }
        bypassScriptCheck = false;

        if (audioModeInput.value === 'upload' && (!audioInput.files || audioInput.files.length === 0)) {
            showToast("Please select an audio file to upload.", true);
            return;
        }

        if (!headlineInput.value.trim()) {
            showToast("Please enter a news headline.", true);
            return;
        }

        const formData = new FormData(form);

        generateBtn.disabled = true;
        generateBtn.innerHTML = `<span class="btn-icon">⏳</span><span>SUBMITTING JOB...</span>`;
        
        progressSection.style.display = 'block';
        progressPercent.textContent = '1%';
        progressFill.style.width = '1%';
        progressStatus.textContent = 'Uploading media assets to server...';
        progressFill.style.backgroundColor = 'var(--accent-red)';
        resultActions.style.display = 'none';

        // Hide final player, show canvas preview
        finalVideoPlayer.style.display = 'none';
        finalVideoPlayer.pause();
        const previewCanvasBg = document.getElementById('previewCanvasBg');
        if (previewCanvasBg) previewCanvasBg.style.display = 'block';
        document.getElementById('canvas').style.display = 'block';

        const xhr = new XMLHttpRequest();
        xhr.open('POST', apiUrl('/api/generate'), true);

        // Upload progress listener
        xhr.upload.onprogress = (event) => {
            if (event.lengthComputable && event.total > 0) {
                const uploadPercent = Math.round((event.loaded / event.total) * 100);
                const overallPercent = Math.min(40, Math.round((event.loaded / event.total) * 40));
                progressPercent.textContent = `${overallPercent}%`;
                progressFill.style.width = `${overallPercent}%`;
                const mbLoaded = (event.loaded / (1024 * 1024)).toFixed(1);
                const mbTotal = (event.total / (1024 * 1024)).toFixed(1);
                progressStatus.textContent = `Uploading footage: ${mbLoaded}MB / ${mbTotal}MB (${uploadPercent}% uploaded)...`;
            }
        };

        xhr.onload = () => {
            try {
                let data;
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (parseErr) {
                    throw new Error(`Server response error (${xhr.status}). File might be too large.`);
                }

                if (xhr.status === 200 && data.success) {
                    progressPercent.textContent = '45%';
                    progressFill.style.width = '45%';
                    progressStatus.textContent = 'Media uploaded! Initializing video render...';
                    watchJobProgress(data.job_id);
                } else {
                    let errDetail = data.error;
                    if (errDetail && typeof errDetail === 'object') {
                        errDetail = errDetail.message || errDetail.error || JSON.stringify(errDetail);
                    }
                    throw new Error(errDetail || `Server error (${xhr.status})`);
                }
            } catch (err) {
                let friendlyMsg = err.message || "Failed to submit video generation job. Please try again.";
                if (friendlyMsg && typeof friendlyMsg === 'object') {
                    friendlyMsg = friendlyMsg.message || friendlyMsg.error || JSON.stringify(friendlyMsg);
                }
                showToast(friendlyMsg, true);
                resetGenerateBtn();
                progressStatus.innerHTML = `<span style="color: #ff6b6b; font-weight: 600;">⚠️ ${friendlyMsg}</span>`;
                progressFill.style.backgroundColor = 'var(--accent-red)';
                progressPercent.textContent = 'Failed';
            }
        };

        xhr.onerror = () => {
            const networkMsg = "Network connection lost during media upload. Please check server connection.";
            showToast(networkMsg, true);
            resetGenerateBtn();
            progressStatus.innerHTML = `<span style="color: #ff6b6b; font-weight: 600;">⚠️ ${networkMsg}</span>`;
            progressFill.style.backgroundColor = 'var(--accent-red)';
            progressPercent.textContent = 'Failed';
        };

        xhr.send(formData);
    });

    // ==========================================
    // Real-Time Socket.IO Progress Tracking
    // ==========================================
    let socket = null;
    try {
        if (typeof io !== 'undefined') {
            const socketHost = getBackendUrl() || window.location.origin;
            socket = io(socketHost, {
                transports: ['websocket', 'polling'],
                reconnection: true,
                reconnectionAttempts: 15,
                reconnectionDelay: 1000
            });
            socket.on('connect', () => {
                console.log('[SocketIO] Connected to broadcast server:', socketHost, 'session id:', socket.id);
            });
            socket.on('disconnect', (reason) => {
                console.log('[SocketIO] Disconnected from server:', reason);
            });
        } else {
            console.warn('[SocketIO] io library not detected, using fallback HTTP watcher.');
        }
    } catch (e) {
        console.warn('[SocketIO] Init error:', e);
        socket = null;
    }

    function watchJobProgress(jobId) {
        generateBtn.disabled = true;
        generateBtn.innerHTML = `<span class="btn-icon">⚡</span><span>RENDERING BROADCAST VIDEO...</span>`;

        let isCompleted = false;
        let fallbackInterval = null;
        let lastUpdateTime = Date.now();

        function handleProgress(job) {
            if (!job || isCompleted) return;
            lastUpdateTime = Date.now();

            const progress = Math.max(5, Math.min(100, job.progress || 0));
            progressPercent.textContent = `${progress}%`;
            progressFill.style.width = `${progress}%`;
            progressStatus.textContent = job.message || 'Processing broadcast...';

            if (job.status === 'completed') {
                isCompleted = true;
                cleanup();

                showToast("News Video Generated Successfully!");

                const videoFileName = (job.output_video && job.output_video !== 'null' && job.output_video !== 'None') ? job.output_video : `news_${jobId}.mp4`;
                const videoUrl = apiUrl(`/outputs/${videoFileName}`);
                const previewCanvasBg = document.getElementById('previewCanvasBg');
                if (previewCanvasBg) previewCanvasBg.style.display = 'none';
                finalVideoPlayer.src = videoUrl;
                finalVideoPlayer.style.display = 'block';
                finalVideoPlayer.load();
                finalVideoPlayer.play();

                downloadVideoBtn.href = videoUrl;
                downloadVideoBtn.setAttribute('download', videoFileName);
                resultActions.style.display = 'block';

                resetGenerateBtn();
            } else if (job.status === 'failed') {
                isCompleted = true;
                cleanup();

                let errorMsg = job.error || job.message || 'Video processing encountered an unexpected issue. Please check your footage and try again.';
                if (errorMsg && typeof errorMsg === 'object') {
                    errorMsg = errorMsg.message || errorMsg.error || JSON.stringify(errorMsg);
                }
                showToast(errorMsg, true);
                progressStatus.innerHTML = `<span style="color: #ff6b6b; font-weight: 600;">⚠️ ${errorMsg}</span>`;
                progressFill.style.backgroundColor = 'var(--accent-red)';
                progressPercent.textContent = 'Failed';

                const previewCanvasBg = document.getElementById('previewCanvasBg');
                if (previewCanvasBg) previewCanvasBg.style.display = 'block';
                resetGenerateBtn();
            }
        }

        function onJobProgressEvent(payload) {
            if (payload && payload.job_id === jobId && payload.job) {
                handleProgress(payload.job);
            }
        }

        function cleanup() {
            if (fallbackInterval) {
                clearInterval(fallbackInterval);
                fallbackInterval = null;
            }
            if (socket) {
                socket.off('job_progress', onJobProgressEvent);
                socket.emit('leave_job', { job_id: jobId });
            }
        }

        // 1. Join private Socket.IO room for this exact job
        if (socket) {
            socket.on('job_progress', onJobProgressEvent);
            socket.emit('join_job', { job_id: jobId });
        }

        // 2. High-Reliability Progress Poller (works seamlessly across multi-server and WSGI mounts)
        fallbackInterval = setInterval(async () => {
            if (isCompleted) {
                clearInterval(fallbackInterval);
                return;
            }
            if (!socket || !socket.connected || (Date.now() - lastUpdateTime > 1500)) {
                try {
                    const resp = await fetch(apiUrl(`/api/status/${jobId}`));
                    const data = await resp.json();
                    if (data && data.success && data.job) {
                        handleProgress(data.job);
                    }
                } catch (e) {
                    console.warn('[Progress Watcher] Status check:', e);
                }
            }
        }, 1500);
    }

    function resetGenerateBtn() {
        generateBtn.disabled = false;
        generateBtn.innerHTML = `<span class="btn-icon">⚡</span><span class="btn-text">GENERATE NEWS VIDEO</span>`;
    }


    // ==========================================
    // AI News Script Generator (LangChain Streaming)
    // ==========================================
    const aiTopicInput = document.getElementById('aiTopicInput');
    const generateAiScriptBtn = document.getElementById('generateAiScriptBtn');
    const aiProviderSelect = document.getElementById('aiProviderSelect');
    const aiScriptStatus = document.getElementById('aiScriptStatus');

    if (generateAiScriptBtn && aiTopicInput && ttsTextInput) {
        async function runAiScriptGeneration() {
            const topic = aiTopicInput.value.trim();
            if (!topic) {
                showToast('Kripya topic ya headline daalein.', true);
                aiTopicInput.focus();
                return;
            }

            const selectedOption = aiProviderSelect ? aiProviderSelect.options[aiProviderSelect.selectedIndex] : null;
            const provider = selectedOption ? selectedOption.value : 'groq';
            const model = selectedOption && selectedOption.dataset.model ? selectedOption.dataset.model : '';

            generateAiScriptBtn.disabled = true;
            generateAiScriptBtn.innerHTML = '<span>⏳ Likh raha hai...</span>';
            if (aiScriptStatus) {
                aiScriptStatus.style.display = 'block';
                aiScriptStatus.style.color = '#38bdf8';
                aiScriptStatus.textContent = 'Generating Script (' + (selectedOption ? selectedOption.text : provider) + ')...';
            }

            ttsTextInput.value = '';
            if (scriptCharCount) scriptCharCount.textContent = '0 characters';

            try {
                const response = await fetch(apiUrl('/api/generate-script-stream'), {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ topic, provider, model })
                });

                if (!response.ok) {
                    const errData = await response.json().catch(() => ({}));
                    throw new Error(errData.error || 'HTTP error ' + response.status);
                }

                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                let fullText = '';

                function parseAndApplyAiStream(rawText) {
                    const hTag = '===HEADLINE===';
                    const shTag = '===SUB_HEADLINE===';
                    const tTag = '===TICKER===';
                    const sTag = '===SCRIPT===';

                    const hIdx = rawText.indexOf(hTag);
                    const shIdx = rawText.indexOf(shTag);
                    const tIdx = rawText.indexOf(tTag);
                    const sIdx = rawText.indexOf(sTag);

                    if (hIdx !== -1) {
                        const end = (shIdx !== -1) ? shIdx : (tIdx !== -1 ? tIdx : (sIdx !== -1 ? sIdx : rawText.length));
                        const headline = rawText.slice(hIdx + hTag.length, end).trim();
                        if (headline && headlineInput && headlineInput.value !== headline) {
                            headlineInput.value = headline;
                            headlineInput.dispatchEvent(new Event('input'));
                        }
                    }

                    if (shIdx !== -1) {
                        const end = (tIdx !== -1) ? tIdx : (sIdx !== -1 ? sIdx : rawText.length);
                        const subHeadline = rawText.slice(shIdx + shTag.length, end).trim();
                        if (subHeadline && subHeadlineInput && subHeadlineInput.value !== subHeadline) {
                            subHeadlineInput.value = subHeadline;
                            subHeadlineInput.dispatchEvent(new Event('input'));
                        }
                    }

                    if (tIdx !== -1) {
                        const end = (sIdx !== -1) ? sIdx : rawText.length;
                        const ticker = rawText.slice(tIdx + tTag.length, end).trim();
                        if (ticker && tickerInput && tickerInput.value !== ticker) {
                            tickerInput.value = ticker;
                            tickerInput.dispatchEvent(new Event('input'));
                        }
                    }

                    if (sIdx !== -1) {
                        const script = rawText.slice(sIdx + sTag.length).trimStart();
                        if (ttsTextInput) {
                            ttsTextInput.value = script;
                            if (scriptCharCount) scriptCharCount.textContent = script.length + ' characters';
                            ttsTextInput.scrollTop = ttsTextInput.scrollHeight;
                        }
                    } else if (hIdx === -1 && shIdx === -1 && tIdx === -1) {
                        if (ttsTextInput) {
                            ttsTextInput.value = rawText;
                            if (scriptCharCount) scriptCharCount.textContent = rawText.length + ' characters';
                        }
                    }
                }

                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    const chunk = decoder.decode(value, { stream: true });
                    fullText += chunk;
                    parseAndApplyAiStream(fullText);
                }
                parseAndApplyAiStream(fullText);

                if (fullText.includes('[AI Error:') || fullText.startsWith('Error:')) {
                    if (aiScriptStatus) {
                        aiScriptStatus.style.color = 'var(--accent-red)';
                        aiScriptStatus.textContent = fullText;
                    }
                    showToast('AI Error: API key ya model check karein.', true);
                } else {
                    if (aiScriptStatus) {
                        aiScriptStatus.style.color = '#4ade80';
                        aiScriptStatus.textContent = 'Script Generation Completed.';
                    }
                    showToast('Script Generatinon Completed.');
                    if (typeof debouncedSaveSettings === 'function') debouncedSaveSettings();
                }
            } catch (err) {
                console.error('AI Script generation error:', err);
                if (aiScriptStatus) {
                    aiScriptStatus.style.color = 'var(--accent-red)';
                    aiScriptStatus.textContent = 'Error: ' + err.message;
                }
                showToast('Script generation failed: ' + err.message, true);
            } finally {
                generateAiScriptBtn.disabled = false;
                generateAiScriptBtn.innerHTML = '<span>✨ Script Likhein</span>';
            }
        }

        generateAiScriptBtn.addEventListener('click', runAiScriptGeneration);
        if (aiProviderSelect) aiProviderSelect.addEventListener('change', debouncedSaveSettings);
        aiTopicInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                runAiScriptGeneration();
            }
        });
    }

});
