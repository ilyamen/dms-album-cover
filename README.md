# Album Cover for DankMaterialShell

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) desktop widget with the cover of the playing track and play, previous and next buttons over MPRIS. Scrolling over it changes the volume.

Based on [Dank Album Widget](https://github.com/kmf/dank-album-widget) by kmf.

## Full-size covers from web players

Web players such as YouTube Music and Yandex Music pass tiny covers to MPRIS, often 100 pixels or less, which look blurry at widget size. The pages themselves know the full-size cover: they give it to `navigator.mediaSession`.

The plugin comes with a small extension for Chromium-based browsers (Chrome, Chromium, Brave, Edge, Vivaldi) that reads the largest cover from `navigator.mediaSession` and passes it to a local helper through native messaging. The helper writes it to `~/.cache/dms-album-cover/now-playing.json`, and the widget uses it while its title matches the playing track. Nothing is sent anywhere, and the extension reads nothing on the page besides the media session.

To set it up, open the plugin settings in DMS:

1. Press **Set up helper**. This registers the helper with every supported browser that has a profile.
2. Open `chrome://extensions`, turn on Developer mode, press **Load unpacked** and choose the `browser/extension` folder of the plugin. The settings page shows the path and can copy it.

The browser loads the extension from the plugin folder, so keep the plugin where it is.

## Installation

In DMS Settings → Plugins, add the registry `https://github.com/ilyamen/dms-plugin-registry.git` and install **Album Cover** from Browse, or:

```sh
git clone https://github.com/ilyamen/dms-album-cover ~/.config/DankMaterialShell/plugins/albumCover
```

## Removal

Press **Remove helper** in the plugin settings, remove the extension in the browser, then uninstall the plugin. `browser/register.sh uninstall` removes the helper registration from the command line.

## License

MIT
