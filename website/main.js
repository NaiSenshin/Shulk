/**
 * Shulk Handheld Launcher - Official Website Client
 * Handles OS detection, dynamic GitHub release querying, sound effects, and UI interactivity.
 */

// Fallback release data if GitHub API is offline or rate-limited
const FALLBACK_RELEASE = {
    tag_name: "v1.1.2",
    name: "Shulk v1.1.2",
    published_at: "2026-09-13T13:50:00Z",
    html_url: "https://github.com/NaiSenshin/Shulk/releases/tag/v1.1.2",
    assets: {
        steamos: {
            name: "Shulk-1.1.2-SteamOS-Bazzite-Installer.tar.gz",
            size: 460133695,
            url: "https://github.com/NaiSenshin/Shulk/releases/download/v1.1.2/Shulk-1.1.2-SteamOS-Bazzite-Installer.tar.gz"
        },
        windows: {
            name: "Shulk-1.1.2-Windows-x64.zip",
            size: 206259220,
            url: "https://github.com/NaiSenshin/Shulk/releases/download/v1.1.2/Shulk-1.1.2-Windows-x64.zip"
        },
        linux: {
            name: "Shulk-1.1.2-Linux-x86_64.tar.gz",
            size: 186223638,
            url: "https://github.com/NaiSenshin/Shulk/releases/download/v1.1.2/Shulk-1.1.2-Linux-x86_64.tar.gz"
        }
    }
};

// --- Sound Effects Manager ---
class SoundManager {
    constructor() {
        this.enabled = localStorage.getItem('shulk_sfx') === 'true';
        this.clickAudio = new Audio('assets/sounds/click.ogg');
        this.levelUpAudio = new Audio('assets/sounds/levelup.ogg');
        this.orbAudio = new Audio('assets/sounds/orb.ogg');

        this.clickAudio.volume = 0.45;
        this.levelUpAudio.volume = 0.55;
        this.orbAudio.volume = 0.45;
    }

    playClick() {
        if (!this.enabled) return;
        try {
            this.clickAudio.currentTime = 0;
            this.clickAudio.play().catch(() => {});
        } catch (e) {}
    }

    playDownload() {
        if (!this.enabled) return;
        try {
            this.levelUpAudio.currentTime = 0;
            this.levelUpAudio.play().catch(() => {});
        } catch (e) {}
    }

    toggle() {
        this.enabled = !this.enabled;
        localStorage.setItem('shulk_sfx', this.enabled ? 'true' : 'false');
        if (this.enabled) this.playClick();
        return this.enabled;
    }
}

const sounds = new SoundManager();

// Format bytes into readable MB
function formatBytes(bytes) {
    if (!bytes || bytes <= 0) return "Unknown size";
    const mb = bytes / (1024 * 1024);
    return `${mb.toFixed(1)} MB`;
}

// Format ISO date into human-readable string
function formatDate(isoStr) {
    if (!isoStr) return "";
    try {
        const d = new Date(isoStr);
        return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
    } catch (e) {
        return "";
    }
}

// --- OS Detection ---
function detectUserOS() {
    const userAgent = window.navigator.userAgent.toLowerCase();
    const platform = (window.navigator.userAgentData?.platform || window.navigator.platform || "").toLowerCase();

    // Check for Steam Deck / SteamOS indicators
    if (userAgent.includes("steam deck") || userAgent.includes("steamos") || userAgent.includes("bazzite") || userAgent.includes("valve")) {
        return {
            id: "steamos",
            name: "Bazzite & SteamOS",
            tag: "Bazzite & SteamOS",
            target: "steamos"
        };
    }

    // Windows detection
    if (platform.includes("win") || userAgent.includes("windows")) {
        return {
            id: "windows",
            name: "Windows Handhelds & PC",
            tag: "Windows x64",
            target: "windows"
        };
    }

    if (/android|iphone|ipad/.test(userAgent)) {
        return { id: "other", name: "Desktop & Handheld", tag: "Choose your platform", target: "other" };
    }

    // Generic Linux
    if (platform.includes("linux") || userAgent.includes("linux") || userAgent.includes("x11")) {
        return {
            id: "linux",
            name: "Linux",
            tag: "Linux x86_64",
            target: "linux"
        };
    }

    // macOS
    if (platform.includes("mac") || userAgent.includes("macintosh")) {
        return {
            id: "mac",
            name: "macOS",
            tag: "macOS — no prebuilt download",
            target: "other"
        };
    }

    // Mobile / Other
    return {
        id: "other",
        name: "Desktop & Handheld",
        tag: "Cross-Platform",
        target: "other"
    };
}

// --- GitHub Release Data Fetcher ---
async function fetchLatestRelease() {
    try {
        const res = await fetch("https://api.github.com/repos/NaiSenshin/Shulk/releases/latest", {
            headers: {
                "Accept": "application/vnd.github+json"
            }
        });

        if (!res.ok) {
            console.warn(`GitHub API returned status ${res.status}, falling back to static release.`);
            return FALLBACK_RELEASE;
        }

        const data = await res.json();
        const parsed = {
            tag_name: data.tag_name || FALLBACK_RELEASE.tag_name,
            name: data.name || FALLBACK_RELEASE.name,
            published_at: data.published_at || FALLBACK_RELEASE.published_at,
            html_url: data.html_url || FALLBACK_RELEASE.html_url,
            assets: {
                steamos: FALLBACK_RELEASE.assets.steamos,
                windows: FALLBACK_RELEASE.assets.windows,
                linux: FALLBACK_RELEASE.assets.linux
            }
        };

        if (Array.isArray(data.assets)) {
            data.assets.forEach(asset => {
                const name = asset.name || "";
                if (name.includes("SteamOS") || name.includes("Bazzite") || name.includes("Installer")) {
                    parsed.assets.steamos = {
                        name: asset.name,
                        size: asset.size,
                        url: asset.browser_download_url
                    };
                } else if (name.includes("Windows") && name.endsWith(".zip")) {
                    parsed.assets.windows = {
                        name: asset.name,
                        size: asset.size,
                        url: asset.browser_download_url
                    };
                } else if (name.includes("Linux") && name.endsWith(".tar.gz") && !name.includes("Installer")) {
                    parsed.assets.linux = {
                        name: asset.name,
                        size: asset.size,
                        url: asset.browser_download_url
                    };
                }
            });
        }

        return parsed;
    } catch (err) {
        console.warn("Error querying GitHub releases API, using fallback:", err);
        return FALLBACK_RELEASE;
    }
}

// --- Apply Dynamic Release & OS to DOM ---
function applyDownloadConfig(release, detectedOS) {
    // 1. Update version pills
    document.querySelectorAll('.js-version-tag').forEach(el => {
        el.textContent = release.tag_name;
    });

    // 2. Update release date
    document.querySelectorAll('.js-release-date').forEach(el => {
        el.textContent = formatDate(release.published_at);
    });

    // 3. Update download card details
    // SteamOS / Bazzite
    const steamosBtn = document.getElementById('btn-download-steamos');
    const steamosSize = document.getElementById('steamos-asset-size');
    if (steamosBtn && release.assets.steamos) {
        steamosBtn.href = release.assets.steamos.url;
    }
    if (steamosSize && release.assets.steamos) {
        steamosSize.textContent = formatBytes(release.assets.steamos.size);
    }

    // Windows
    const winBtn = document.getElementById('btn-download-windows');
    const winSize = document.getElementById('windows-asset-size');
    if (winBtn && release.assets.windows) {
        winBtn.href = release.assets.windows.url;
    }
    if (winSize && release.assets.windows) {
        winSize.textContent = formatBytes(release.assets.windows.size);
    }

    // Linux Portable
    const linuxBtn = document.getElementById('btn-download-linux');
    const linuxSize = document.getElementById('linux-asset-size');
    if (linuxBtn && release.assets.linux) {
        linuxBtn.href = release.assets.linux.url;
    }
    if (linuxSize && release.assets.linux) {
        linuxSize.textContent = formatBytes(release.assets.linux.size);
    }

    // 4. Configure Hero CTA based on detected OS
    const heroBtn = document.getElementById('hero-download-btn');
    const heroBtnText = document.getElementById('hero-btn-text');
    const heroOsTag = document.getElementById('hero-detected-os');
    const heroSizeTag = document.getElementById('hero-asset-size');

    let activeAsset = release.assets.steamos;
    let targetCardId = 'card-steamos';
    let label = `Download for ${detectedOS.name}`;

    if (detectedOS.id === 'windows') {
        activeAsset = release.assets.windows;
        targetCardId = 'card-windows';
        label = `Download for Windows (x64)`;
    } else if (detectedOS.id === 'steamos') {
        activeAsset = release.assets.steamos;
        targetCardId = 'card-steamos';
        label = `Download for Bazzite & SteamOS`;
    } else if (detectedOS.id === 'linux') {
        activeAsset = release.assets.linux;
        targetCardId = 'card-linux';
        label = 'Download for Linux (x86_64)';
    } else if (detectedOS.id === 'mac' || detectedOS.id === 'other') {
        // Direct to downloads section
        label = `Browse All Downloads`;
        activeAsset = { url: "#downloads", size: null };
        targetCardId = null;
    }

    // Linux browsers often omit the distribution, so offer both packages.
    const alternateBtn = document.getElementById('hero-alternate-download');
    const alternateText = document.getElementById('hero-alternate-text');
    const isLinux = detectedOS.id === 'linux' || detectedOS.id === 'steamos';
    const linuxNote = document.getElementById('linux-download-note');
    if (linuxNote) linuxNote.hidden = !isLinux;
    if (alternateBtn) {
        alternateBtn.hidden = !isLinux;
        if (isLinux) {
            const alternatePlatform = detectedOS.id === 'steamos' ? 'linux' : 'steamos';
            alternateBtn.href = release.assets[alternatePlatform].url;
            alternateBtn.setAttribute('download', '');
            if (alternateText) alternateText.textContent = alternatePlatform === 'steamos'
                ? 'Bazzite & SteamOS Installer' : 'Linux Portable (x86_64)';
        }
    }
    if (isLinux) label = detectedOS.id === 'steamos'
        ? 'Bazzite & SteamOS Installer' : 'Linux Portable (x86_64)';

    if (heroBtn) {
        heroBtn.href = activeAsset.url;
        if (activeAsset.url.startsWith("http")) {
            heroBtn.setAttribute("download", "");
        } else {
            heroBtn.removeAttribute("download");
        }
    }
    if (heroBtnText) heroBtnText.textContent = label;
    if (heroOsTag) heroOsTag.textContent = detectedOS.tag;
    if (heroSizeTag) {
        if (isLinux) {
            heroSizeTag.textContent = `${release.tag_name} • Official Release`;
        } else if (activeAsset.size) {
            heroSizeTag.textContent = `${formatBytes(activeAsset.size)} • ${release.tag_name}`;
        } else {
            heroSizeTag.textContent = `${release.tag_name} • Official Release`;
        }
    }

    document.querySelectorAll(".download-card.highlighted").forEach(card => card.classList.remove("highlighted"));

    // Highlight recommended card in downloads grid
    if (targetCardId) {
        const card = document.getElementById(targetCardId);
        if (card) card.classList.add('highlighted');
    }
}

// --- Toast Notification ---
function showToast(message, icon = "assets/icons/grass_block.png") {
    let container = document.querySelector('.toast-container');
    if (!container) {
        container = document.createElement('div');
        container.className = 'toast-container';
        document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerHTML = `
        <img src="${icon}" style="width: 22px; height: 22px; image-rendering: pixelated;" alt="" />
        <span>${message}</span>
    `;
    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateY(10px)';
        toast.style.transition = 'all 0.3s ease';
        setTimeout(() => toast.remove(), 350);
    }, 3200);
}

// --- Event Listeners and Initialization ---
document.addEventListener('DOMContentLoaded', async () => {
    // 1. Sound toggle button
    const soundToggle = document.getElementById('sound-toggle');
    const updateSoundIcon = (enabled) => {
        if (!soundToggle) return;
        soundToggle.textContent = enabled ? 'Sound: on' : 'Sound: off';
        soundToggle.classList.toggle('muted', !enabled);
        soundToggle.setAttribute('aria-pressed', String(enabled));
    };
    if (soundToggle) {
        updateSoundIcon(sounds.enabled);
        soundToggle.addEventListener('click', () => {
            const state = sounds.toggle();
            updateSoundIcon(state);
            showToast(state ? "Sound Effects Enabled" : "Sound Effects Muted", "assets/icons/noteblock.png");
        });
    }

    // 2. Play sound on buttons and interactive elements
    document.querySelectorAll('.btn, .nav-link, .guide-tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            if (btn.classList.contains('js-download-trigger') && btn.getAttribute('href')?.startsWith('https://')) {
                sounds.playDownload();
                showToast("Opening download from GitHub…", "assets/icons/shulk.png");

                // Send download event telemetry
                try {
                    const platform = btn.dataset.platform || (btn.id.includes('alternate') ? 'steamos' : (detectedOS?.id || 'unknown'));
                    const href = btn.getAttribute('href') || '';
                    const assetName = href.split('/').pop() || '';
                    const payload = JSON.stringify({
                        platform: platform,
                        asset_name: assetName,
                        version: 'v1.1.2'
                    });
                    if (navigator.sendBeacon) {
                        navigator.sendBeacon('/api/track/download', payload);
                    } else {
                        fetch('/api/track/download', {method: 'POST', body: payload, headers: {'Content-Type': 'application/json'}});
                    }
                } catch (err) {}
            } else {
                sounds.playClick();
            }
        });
    });

    // 3. Tab switching for installation guides
    const guideTabs = document.querySelectorAll('.guide-tab-btn');
    const guidePanels = document.querySelectorAll('.guide-panel');

    document.querySelector('.guide-tabs').setAttribute('role', 'tablist');
    document.querySelector('.guide-tabs').setAttribute('aria-label', 'Installation platform');
    guideTabs.forEach((tab, index) => {
        tab.id = `tab-${tab.dataset.tab}`;
        tab.setAttribute('role', 'tab');
        tab.setAttribute('aria-controls', `panel-${tab.dataset.tab}`);
        tab.setAttribute('aria-selected', String(tab.classList.contains('active')));
        tab.tabIndex = tab.classList.contains('active') ? 0 : -1;
        const panel = document.getElementById(`panel-${tab.dataset.tab}`);
        panel.setAttribute('role', 'tabpanel');
        panel.setAttribute('aria-labelledby', tab.id);
        tab.addEventListener('keydown', event => {
            let next;
            if (event.key === 'ArrowRight') next = (index + 1) % guideTabs.length;
            if (event.key === 'ArrowLeft') next = (index + guideTabs.length - 1) % guideTabs.length;
            if (event.key === 'Home') next = 0;
            if (event.key === 'End') next = guideTabs.length - 1;
            if (next !== undefined) { event.preventDefault(); guideTabs[next].click(); guideTabs[next].focus(); }
        });
        tab.addEventListener('click', () => {
            const targetId = tab.dataset.tab;
            guideTabs.forEach(t => { t.classList.remove('active'); t.setAttribute('aria-selected', 'false'); t.tabIndex = -1; });
            guidePanels.forEach(p => p.classList.remove('active'));

            tab.classList.add('active');
            tab.setAttribute('aria-selected', 'true');
            tab.tabIndex = 0;
            const targetPanel = document.getElementById(`panel-${targetId}`);
            if (targetPanel) targetPanel.classList.add('active');
        });
    });

    // 4. Auto-detect OS and fetch GitHub releases
    const detectedOS = detectUserOS();
    applyDownloadConfig(FALLBACK_RELEASE, detectedOS);
    const releaseData = await fetchLatestRelease();
    applyDownloadConfig(releaseData, detectedOS);

    // Track Pageview Telemetry Beacon
    try {
        const viewPayload = JSON.stringify({
            path: window.location.pathname,
            referrer: document.referrer || '',
            os: detectedOS?.name || navigator.platform || 'Unknown'
        });
        if (navigator.sendBeacon) {
            navigator.sendBeacon('/api/track/view', viewPayload);
        } else {
            fetch('/api/track/view', {method: 'POST', body: viewPayload, headers: {'Content-Type': 'application/json'}});
        }
    } catch (e) {}

    // Match the installation guide to the selected download.
    if (['steamos', 'windows', 'linux'].includes(detectedOS.id)) {
        const guideTab = document.querySelector(`[data-tab="${detectedOS.id}"]`);
        if (guideTab) guideTab.click();
    }

    // Discreet shortcut to admin portal (`~` or `\` key)
    document.addEventListener('keydown', (e) => {
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
        if (e.key === '`' || e.key === '~' || e.key === '\\') {
            window.location.href = '/admin';
        }
    });

    // 5. Dynamic Announcement Bar Loader
    async function loadAnnouncement() {
        try {
            const res = await fetch('/api/announcement');
            if (!res.ok) return;
            const data = await res.json();
            if (!data || !data.enabled || !data.text) return;

            // Check if user previously dismissed this exact announcement update
            const dismissedTime = localStorage.getItem('shulk_announcement_dismissed');
            if (dismissedTime && parseInt(dismissedTime) >= data.updated_at) {
                return;
            }

            const bar = document.getElementById('site-announcement-bar');
            const textEl = document.getElementById('announcement-text');
            const linkEl = document.getElementById('announcement-link');
            const iconImg = document.getElementById('announcement-icon-img');
            const closeBtn = document.getElementById('announcement-close');

            if (!bar || !textEl) return;

            bar.className = 'announcement-bar style-' + (data.banner_style || 'emerald');
            textEl.textContent = data.text;

            // Icon by style
            if (iconImg) {
                if (data.banner_style === 'diamond') iconImg.src = 'assets/icons/diamond.png';
                else if (data.banner_style === 'gold') iconImg.src = 'assets/icons/gold.png';
                else if (data.banner_style === 'redstone') iconImg.src = 'assets/icons/redstone.png';
                else iconImg.src = 'assets/icons/emerald.png';
            }

            if (data.link_url && data.link_text) {
                linkEl.href = data.link_url;
                linkEl.textContent = data.link_text;
                linkEl.style.display = 'inline-block';
            } else {
                linkEl.style.display = 'none';
            }

            bar.style.display = 'block';

            if (closeBtn) {
                closeBtn.onclick = () => {
                    bar.style.display = 'none';
                    localStorage.setItem('shulk_announcement_dismissed', String(data.updated_at || Date.now()));
                };
            }
        } catch (e) {}
    }
    loadAnnouncement();
});
