// Extension world: forwards what page.js found to the background script
window.addEventListener("message", (event) => {
  if (event.source !== window || !event.data || !event.data.__dmsAlbumCover) return;
  const { title, artist, album, art } = event.data;
  if (typeof art !== "string" || !/^https?:/.test(art)) return;
  chrome.runtime.sendMessage({ title: String(title), artist: String(artist), album: String(album), art }).catch(() => {});
});
