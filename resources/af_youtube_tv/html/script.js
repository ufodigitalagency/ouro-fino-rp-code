(() => {
    'use strict';

    const query = new URLSearchParams(window.location.search);
    const statusElement = document.getElementById('status');
    const resourceName = typeof GetParentResourceName === 'function'
        ? GetParentResourceName()
        : 'af_youtube_tv';

    let youtubePlayer = null;
    let playerReady = false;
    let statusTimer = null;
    let pendingVideoId = extractVideoId(query.get('url'));
    let pendingVolume = parseVolume(query.get('volume'),0);
    let pendingMuted = parseBool(query.get('muted'),true);
    let pendingPlayback = {
        state: query.get('autoplay') === '0' ? 'paused' : 'playing',
        time: 0,
        revision: 0
    };
    const channel = String(query.get('channel') || 'world');
    const loop = parseBool(query.get('loop'),false);

    function parseBool(value,fallback) {
        if (value === null || value === undefined || value === '') return fallback;
        return value === true || value === 1 || value === '1' || String(value).toLowerCase() === 'true';
    }

    function parseVolume(value,fallback) {
        const parsed = Number(value);
        if (!Number.isFinite(parsed)) return fallback;
        return Math.max(0,Math.min(100,Math.round(parsed)));
    }

    function extractVideoId(input) {
        const value = String(input || '').trim();
        if (/^[A-Za-z0-9_-]{11}$/.test(value)) return value;

        const patterns = [
            /[?&]v=([A-Za-z0-9_-]{11})/,
            /youtu\.be\/([A-Za-z0-9_-]{11})/,
            /youtube(?:-nocookie)?\.com\/embed\/([A-Za-z0-9_-]{11})/,
            /youtube\.com\/(?:live|shorts)\/([A-Za-z0-9_-]{11})/
        ];

        for (const pattern of patterns) {
            const match = value.match(pattern);
            if (match) return match[1];
        }
        return '';
    }

    function showStatus(message,isError = false,timeout = 3500) {
        window.clearTimeout(statusTimer);
        statusElement.textContent = message;
        statusElement.classList.toggle('error',isError);
        statusElement.classList.add('visible');
        if (timeout > 0) {
            statusTimer = window.setTimeout(() => statusElement.classList.remove('visible'),timeout);
        }
    }

    function postStatus(extra = {}) {
        fetch(`https://${resourceName}/duiStatus`,{
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                channel,
                ready: playerReady,
                videoId: pendingVideoId,
                playerState: getPlayerState(),
                ...extra
            })
        }).catch(() => {});
    }

    function getPlayerState() {
        if (!playerReady || !youtubePlayer || typeof youtubePlayer.getPlayerState !== 'function') return -1;
        try { return youtubePlayer.getPlayerState(); } catch (_) { return -1; }
    }

    function isLiveStream() {
        if (!playerReady || !youtubePlayer) return false;
        try {
            const data = youtubePlayer.getVideoData ? youtubePlayer.getVideoData() : {};
            return data && data.isLive === true;
        } catch (_) {
            return false;
        }
    }

    function applyVolume() {
        if (!playerReady || !youtubePlayer) return;
        try {
            youtubePlayer.setVolume(pendingVolume);
            if (pendingMuted || pendingVolume <= 0) youtubePlayer.mute();
            else youtubePlayer.unMute();
        } catch (_) {}
    }

    function applyPlayback() {
        if (!playerReady || !youtubePlayer) return;
        const wantedTime = Math.max(0,Number(pendingPlayback.time) || 0);

        try {
            const currentTime = Number(youtubePlayer.getCurrentTime()) || 0;
            if (wantedTime > 0 && !isLiveStream() && Math.abs(currentTime - wantedTime) > 1.75) {
                youtubePlayer.seekTo(wantedTime,true);
            }

            if (pendingPlayback.state === 'paused') youtubePlayer.pauseVideo();
            else if (pendingPlayback.state === 'stopped') youtubePlayer.stopVideo();
            else youtubePlayer.playVideo();
        } catch (_) {}
    }

    function loadVideo(videoId,startSeconds = 0) {
        const validId = extractVideoId(videoId);
        if (!validId) {
            showStatus('Link ou ID do YouTube inválido.',true,0);
            return false;
        }

        pendingVideoId = validId;
        pendingPlayback.time = Math.max(0,Number(startSeconds) || 0);
        if (playerReady && youtubePlayer) {
            try {
                youtubePlayer.loadVideoById({ videoId: validId,startSeconds: pendingPlayback.time });
                window.setTimeout(() => {
                    applyVolume();
                    applyPlayback();
                },100);
            } catch (_) {}
        }
        return true;
    }

    function createPlayer() {
        if (!pendingVideoId) {
            showStatus('Nenhum vídeo válido configurado.',true,0);
            postStatus({ error: 'invalid_video' });
            return;
        }

        youtubePlayer = new YT.Player('player',{
            width: '100%',
            height: '100%',
            videoId: pendingVideoId,
            playerVars: {
                autoplay: 1,
                controls: 0,
                disablekb: 1,
                fs: 0,
                iv_load_policy: 3,
                modestbranding: 1,
                playsinline: 1,
                rel: 0,
                loop: loop ? 1 : 0,
                playlist: loop ? pendingVideoId : undefined,
                origin: window.location.origin
            },
            events: {
                onReady(event) {
                    playerReady = true;
                    youtubePlayer = event.target;
                    applyVolume();
                    applyPlayback();
                    postStatus();
                },
                onStateChange(event) {
                    if (loop && event.data === YT.PlayerState.ENDED) {
                        try { event.target.playVideo(); } catch (_) {}
                    }
                    postStatus({ playerState: event.data });
                },
                onError(event) {
                    showStatus(`O YouTube recusou este vídeo (erro ${event.data}).`,true,0);
                    postStatus({ error: event.data });
                },
                onAutoplayBlocked() {
                    showStatus('A reprodução automática foi bloqueada pelo player.',true,0);
                    postStatus({ error: 'autoplay_blocked' });
                }
            }
        });
    }

    function handleMessage(rawData) {
        let data = rawData;
        if (typeof data === 'string') {
            try { data = JSON.parse(data); } catch (_) { return; }
        }
        if (!data || typeof data !== 'object') return;

        const type = data.type || data.action;
        if (type === 'setVolume') {
            pendingVolume = parseVolume(data.volume,pendingVolume);
            pendingMuted = Object.prototype.hasOwnProperty.call(data,'muted')
                ? parseBool(data.muted,pendingMuted)
                : pendingVolume <= 0;
            applyVolume();
            return;
        }

        if (type === 'setMuted') {
            pendingMuted = parseBool(data.muted,pendingMuted);
            applyVolume();
            return;
        }

        if (type === 'setPlayback') {
            pendingPlayback = {
                state: String(data.state || pendingPlayback.state || 'playing'),
                time: Math.max(0,Number(data.time) || 0),
                revision: Number(data.revision) || 0
            };
            applyPlayback();
            return;
        }

        if (type === 'setUrl') {
            loadVideo(data.url || data.videoId || '',data.time);
            return;
        }

        if (type === 'reload') {
            loadVideo(pendingVideoId,pendingPlayback.time);
        }
    }

    window.addEventListener('message',event => handleMessage(event.data));
    window.onYouTubeIframeAPIReady = createPlayer;

    const apiScript = document.createElement('script');
    apiScript.src = 'https://www.youtube.com/iframe_api';
    apiScript.async = true;
    apiScript.onerror = () => {
        showStatus('Não foi possível carregar a API do YouTube.',true,0);
        postStatus({ error: 'api_load_failed' });
    };
    document.head.appendChild(apiScript);

    window.setTimeout(() => {
        if (!playerReady) showStatus('Aguardando resposta do YouTube...',false,3500);
    },8000);
})();
