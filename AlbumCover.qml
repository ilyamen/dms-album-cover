import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    width: widgetWidth
    height: widgetHeight
    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    minWidth: 140
    minHeight: 140
    readonly property int defaultWidth: 240
    readonly property int defaultHeight: 240
    readonly property bool forceSquare: true

    property bool hideWhenIdle: pluginData.hideWhenIdle ?? false

    property MprisPlayer activePlayer: MprisController.activePlayer
    property real scrollAccumulatorY: 0
    property real touchpadThreshold: 100
    property string lastArtUrl: ""

    readonly property bool hoverPreview: MprisController.isFirefoxYoutubeHoverPreview(activePlayer)
    readonly property bool hasPlayer: activePlayer !== null && !hoverPreview
    readonly property bool hideChrome: hideWhenIdle && !hasPlayer
    readonly property bool isPlaying: hasPlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    readonly property color accent: MediaAccentService.accent
    readonly property color onAccent: MediaAccentService.onAccent

    // Full-size cover from the browser extension (browser/), written by its helper.
    // Used only while its title matches the playing track, so a cover from a tab
    // that has stopped never sticks to another player.
    property var bridge: ({})
    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/dms-album-cover/now-playing.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.bridge = JSON.parse(text());
            } catch (e) {
                root.bridge = {};
            }
        }
    }

    // The browser helper is registered whenever the widget loads, so a fresh
    // install or a moved plugin needs no extra step. DMS has no uninstall hook:
    // when the widget unloads because the plugin was disabled or its folder is
    // gone, the registrations and the cache are removed here instead.
    readonly property string pluginDir: PluginService.availablePlugins["albumCover"]?.pluginDirectory ?? ""
    property string registeredDir: ""

    onPluginDirChanged: {
        if (pluginDir === "" || pluginDir === registeredDir)
            return;
        registeredDir = pluginDir;
        Proc.runCommand("albumCover.register", ["sh", pluginDir + "/browser/register.sh", "install"], () => {});
    }

    Component.onDestruction: {
        if (registeredDir === "")
            return;
        const disabled = SettingsData.getPluginSetting("albumCover", "enabled", true) === false;
        Proc.runCommand("albumCover.cleanup", ["sh", "-c", 'sleep 2; [ "$2" = disabled ] || [ ! -e "$1/plugin.json" ] || exit 0; '
            + 'config=${XDG_CONFIG_HOME:-$HOME/.config}; '
            + 'rm -f "$config"/*/NativeMessagingHosts/io.github.ilyamen.dms_album_cover.json "$config"/*/*/NativeMessagingHosts/io.github.ilyamen.dms_album_cover.json; '
            + 'rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/dms-album-cover"', "sh", registeredDir, disabled ? "disabled" : "enabled"], () => {});
    }

    function normTitle(s) {
        return (s || "").toString().trim().toLowerCase();
    }

    readonly property string bridgeArt: {
        const p = activePlayer;
        if (!p || !bridge.art)
            return "";
        return normTitle(p.trackTitle) !== "" && normTitle(p.trackTitle) === normTitle(bridge.title) ? bridge.art : "";
    }

    readonly property string artUrl: {
        if (bridgeArt !== "")
            return bridgeArt;
        const resolved = TrackArtService.resolvedArtUrl;
        if (resolved !== "")
            return resolved;
        const p = activePlayer;
        if (!p)
            return "";
        if (p.trackArtUrl)
            return p.trackArtUrl;
        const m = p.metadata;
        return m && m["mpris:artUrl"] ? m["mpris:artUrl"].toString() : "";
    }
    readonly property string displayArt: artUrl || lastArtUrl
    readonly property bool hasArt: displayArt !== "" && hasPlayer

    onArtUrlChanged: {
        if (artUrl !== "")
            lastArtUrl = artUrl;
        if (!hasPlayer)
            lastArtUrl = "";
    }

    readonly property real side: Math.min(width, height)
    readonly property int playSize: Math.round(Math.max(44, Math.min(64, side * 0.22)))
    readonly property int skipSize: Math.round(Math.max(36, Math.min(52, playSize * 0.82)))
    readonly property int playIconSize: Math.round(playSize * 0.5)
    readonly property int skipIconSize: Math.round(skipSize * 0.5)
    readonly property int controlMargin: Math.round(Math.max(Theme.spacingS, side * 0.06))
    readonly property int controlSpacing: Math.round(Math.max(Theme.spacingS, side * 0.04))

    function handleVolumeWheel(wheelEvent) {
        if (root.hideChrome || !AudioService.sink?.audio)
            return;

        wheelEvent.accepted = true;
        const deltaY = wheelEvent.angleDelta.y;
        if (deltaY === 0)
            return;

        const step = AudioService.wheelVolumeStep || SettingsData.audioWheelScrollAmount || 5;
        const isMouseWheelY = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;
        if (isMouseWheelY) {
            AudioService.adjustDefaultSinkVolume(String(step), deltaY > 0 ? 1 : -1);
            return;
        }

        root.scrollAccumulatorY += deltaY;
        if (Math.abs(root.scrollAccumulatorY) >= root.touchpadThreshold) {
            AudioService.adjustDefaultSinkVolume("1", root.scrollAccumulatorY > 0 ? 1 : -1);
            root.scrollAccumulatorY = 0;
        }
    }

    ClippingRectangle {
        id: sleeve
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        visible: !root.hideChrome

        Image {
            id: cover
            anchors.fill: parent
            source: root.displayArt
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            visible: root.hasArt && status === Image.Ready
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            z: 1
            onWheel: wheel => root.handleVolumeWheel(wheel)
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            visible: !cover.visible
            width: parent.width - Theme.spacingL * 2

            DIcon {
                name: "album"
                size: Math.round(Math.max(Theme.iconSizeLarge, root.side * 0.28))
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: !root.hasPlayer
                text: I18n.tr("No Media")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.round(root.playSize + root.controlMargin * 2.4)
            visible: root.hasPlayer

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.withAlpha(Theme.surface, 0)
                }
                GradientStop {
                    position: 1.0
                    color: Theme.withAlpha(Theme.surface, 0.55)
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.controlMargin
            spacing: root.controlSpacing
            z: 2

            DActionButton {
                buttonSize: root.skipSize
                radius: root.skipSize / 2
                iconName: "skip_previous"
                iconSize: root.skipIconSize
                iconColor: Theme.surfaceText
                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHighest, 0.78)
                enabled: root.hasPlayer
                tooltipText: I18n.tr("Previous")
                onClicked: MprisController.previousOrRewind()
            }

            StyledRect {
                width: root.playSize
                height: root.playSize
                radius: root.playSize / 2
                color: root.accent
                opacity: root.hasPlayer ? 1 : 0.45

                DIcon {
                    anchors.centerIn: parent
                    name: root.isPlaying ? "pause" : "play_arrow"
                    size: root.playIconSize
                    color: root.onAccent
                }

                StateLayer {
                    disabled: !root.hasPlayer || !(root.activePlayer?.canTogglePlaying ?? false)
                    stateColor: root.onAccent
                    cornerRadius: parent.radius
                    tooltipText: root.isPlaying ? I18n.tr("Pause") : I18n.tr("Play")
                    onClicked: {
                        if (root.activePlayer?.canTogglePlaying)
                            root.activePlayer.togglePlaying();
                    }
                }
            }

            DActionButton {
                buttonSize: root.skipSize
                radius: root.skipSize / 2
                iconName: "skip_next"
                iconSize: root.skipIconSize
                iconColor: Theme.surfaceText
                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHighest, 0.78)
                enabled: root.hasPlayer
                tooltipText: I18n.tr("Next")
                onClicked: MprisController.next()
            }
        }
    }
}
