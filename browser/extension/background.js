// Hands the cover to the local helper (native messaging), which only writes it
// to a file the DMS widget reads.
chrome.runtime.onMessage.addListener((message) => {
  chrome.runtime.sendNativeMessage("io.github.ilyamen.dms_album_cover", message).catch(() => {});
});
