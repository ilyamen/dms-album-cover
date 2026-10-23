import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "albumCover"

    readonly property string pluginDir: PluginService.availablePlugins["albumCover"]?.pluginDirectory ?? ""
    property var status: null
    property var lastCover: null
    readonly property var browsers: status?.browsers ?? []
    readonly property bool anyRegistered: browsers.some(b => b.registered)
    readonly property bool allRegistered: browsers.length > 0 && browsers.every(b => b.registered)

    Component.onCompleted: refresh()

    function refresh() {
        if (pluginDir === "")
            return;
        Proc.runCommand("albumCover.status", ["sh", pluginDir + "/browser/register.sh", "status"], (output, exitCode) => {
            try {
                root.status = exitCode === 0 ? JSON.parse(output) : null;
            } catch (e) {
                root.status = null;
            }
        });
    }

    function register() {
        Proc.runCommand("albumCover.register", ["sh", pluginDir + "/browser/register.sh", "install"], () => refresh());
    }

    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/dms-album-cover/now-playing.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.lastCover = JSON.parse(text());
            } catch (e) {
                root.lastCover = null;
            }
        }
    }

    ToggleSetting {
        settingKey: "hideWhenIdle"
        label: I18n.trFor("albumCover", "Hide When Idle")
        description: I18n.trFor("albumCover", "Fade the widget out when no MPRIS player is active")
        defaultValue: false
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("albumCover", "Full-size covers from the browser")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("albumCover", "Web players pass tiny covers to the system, often 100 pixels or less. A small extension for Chrome, Chromium, Brave, Edge or Vivaldi reads the full-size cover from the page and hands it to the widget through a local helper. It only reads what the page shows in the system media controls and sends nothing anywhere.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: bridgeColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: bridgeColumn

            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingS

                DIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.lastCover ? "check_circle" : root.anyRegistered ? "pending" : "warning"
                    size: Theme.iconSize
                    color: root.lastCover ? Theme.success : Theme.warning
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.lastCover)
                            return I18n.trFor("albumCover", "Last cover: %1 at %2").arg(root.lastCover.title).arg(new Date(root.lastCover.ts * 1000).toLocaleTimeString(Qt.locale(), "HH:mm"));
                        if (root.status && root.browsers.length === 0)
                            return I18n.trFor("albumCover", "No supported browser found");
                        if (root.anyRegistered)
                            return I18n.trFor("albumCover", "Helper ready, waiting for the extension");
                        return I18n.trFor("albumCover", "Helper not set up");
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
            }

            StyledText {
                width: parent.width
                visible: root.browsers.length > 0
                text: root.browsers.map(b => (b.registered ? "✓ " : "✗ ") + b.name).join("    ")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Row {
                spacing: Theme.spacingS

                DButton {
                    visible: !root.allRegistered && root.browsers.length > 0
                    text: I18n.trFor("albumCover", "Set up helper")
                    iconName: "download"
                    onClicked: root.register()
                }

            }
        }
    }

    StyledRect {
        width: parent.width
        height: stepsColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: stepsColumn

            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingS

            StyledText {
                width: parent.width
                text: I18n.trFor("albumCover", "Then add the extension to the browser once: open chrome://extensions, turn on Developer mode, press Load unpacked and choose this folder:")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                text: root.status?.extension ?? ""
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                color: Theme.surfaceVariantText
                wrapMode: Text.WrapAnywhere
            }

            Row {
                spacing: Theme.spacingS

                DButton {
                    text: I18n.trFor("albumCover", "Copy path")
                    iconName: "content_copy"
                    enabled: (root.status?.extension ?? "") !== ""
                    onClicked: Paths.copyPathToClipboard(root.status.extension)
                }

                DButton {
                    text: I18n.trFor("albumCover", "Open folder")
                    iconName: "folder_open"
                    enabled: (root.status?.extension ?? "") !== ""
                    onClicked: Quickshell.execDetached(["xdg-open", root.status.extension])
                }
            }

            StyledText {
                width: parent.width
                text: I18n.trFor("albumCover", "The browser loads the extension from this folder, so leave the plugin where it is. Disabling or uninstalling the plugin removes the helper; remove the extension in the browser yourself.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }
    }
}
