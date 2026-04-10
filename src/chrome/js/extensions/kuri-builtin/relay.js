// Kuri network relay — runs in ISOLATED world (can access chrome.runtime)
// Receives network entries from background.js and forwards to MAIN world

// Receive pushes from background service worker
chrome.runtime.onMessage.addListener((msg) => {
    if (msg.type === 'kuri:networkEntries' && Array.isArray(msg.entries)) {
        window.postMessage({
            type: 'kuri:networkLogPush',
            entries: msg.entries,
        }, '*');
    }
});
