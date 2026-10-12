#!/bin/sh
# Register or remove the native messaging helper for every Chromium-based
# browser that has a profile, and report which ones have it.
#   register.sh [install|uninstall|status]
# Runs as the user: everything goes into the browsers' own config directories.
set -eu

NAME=io.github.ilyamen.dms_album_cover
# Fixed by the "key" in extension/manifest.json
EXTENSION_ID=obfalgndoecbcdnmghpamnfhhiokimgh
here=$(dirname "$(readlink -f "$0")")
config=${XDG_CONFIG_HOME:-$HOME/.config}

browsers="Chrome:google-chrome Chromium:chromium Brave:BraveSoftware/Brave-Browser Edge:microsoft-edge Vivaldi:vivaldi"

manifest() {
    cat <<EOF
{
  "name": "$NAME",
  "description": "DMS Album Cover: full-size covers for the desktop widget",
  "path": "$here/host.py",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXTENSION_ID/"]
}
EOF
}

case ${1:-status} in
install)
    for entry in $browsers; do
        dir=$config/${entry#*:}
        [ -d "$dir" ] || continue
        mkdir -p "$dir/NativeMessagingHosts"
        manifest > "$dir/NativeMessagingHosts/$NAME.json"
    done
    ;;
uninstall)
    for entry in $browsers; do
        rm -f "$config/${entry#*:}/NativeMessagingHosts/$NAME.json"
    done
    ;;
status)
    printf '{"extension":"%s","extensionId":"%s","browsers":[' "$here/extension" "$EXTENSION_ID"
    sep=
    for entry in $browsers; do
        dir=$config/${entry#*:}
        [ -d "$dir" ] || continue
        file=$dir/NativeMessagingHosts/$NAME.json
        # Registered for this copy of the plugin, not one moved or removed since
        registered=false
        grep -qF "\"$here/host.py\"" "$file" 2>/dev/null && registered=true
        printf '%s{"name":"%s","registered":%s}' "$sep" "${entry%%:*}" "$registered"
        sep=,
    done
    printf ']}\n'
    ;;
*)
    echo "usage: $0 [install|uninstall|status]" >&2
    exit 2
    ;;
esac
