// Page world: reads only navigator.mediaSession (title, artist, cover) and hands
// the largest cover to bridge.js. Nothing else is taken from the page.
(() => {
  let last = "";

  // sizes: "512x512", "96x96 128x128" or "any"
  function area(artwork) {
    let best = 0;
    for (const size of (artwork.sizes || "").split(/\s+/)) {
      if (size === "any") return 1e9;
      const match = /^(\d+)x(\d+)$/i.exec(size);
      if (match) best = Math.max(best, +match[1] * +match[2]);
    }
    return best;
  }

  // Some services put the size into the image address; ask for a large one
  function upgrade(url) {
    if (/avatars\.yandex\.net\/get-music-content\//.test(url))
      return url.replace(/\/\d+x\d+$/, "/1000x1000");
    return url;
  }

  function check() {
    const metadata = navigator.mediaSession && navigator.mediaSession.metadata;
    if (!metadata || !metadata.artwork || !metadata.artwork.length) return;
    const artwork = [...metadata.artwork].sort((a, b) => area(b) - area(a))[0];
    if (!artwork || !artwork.src) return;
    let url;
    try { url = upgrade(new URL(artwork.src, location.href).href); } catch (e) { return; }
    if (!/^https?:/.test(url)) return;
    const key = metadata.title + "\n" + metadata.artist + "\n" + url;
    if (key === last) return;
    last = key;
    window.postMessage({ __dmsAlbumCover: true, title: metadata.title || "", artist: metadata.artist || "", album: metadata.album || "", art: url }, "*");
  }

  setInterval(check, 1500);
})();
