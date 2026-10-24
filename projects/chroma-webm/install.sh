#!/bin/bash
set -euo pipefail
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/chroma-webm"
APP="$HOME/Applications/Chroma WebM.app"
SERVICE="$HOME/Library/Services/Chroma to WebM.workflow"
PYTHON="$(command -v python3)"
command -v ffmpeg >/dev/null
command -v ffprobe >/dev/null
mkdir -p "$INSTALL_DIR" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$SERVICE/Contents"
if [ "$SOURCE_DIR" != "$INSTALL_DIR" ]; then
  cp "$SOURCE_DIR/backend.py" "$SOURCE_DIR/ChromaWebM.swift" "$SOURCE_DIR/test_backend.py" "$SOURCE_DIR/test_sampling.py" "$SOURCE_DIR/install.sh" "$SOURCE_DIR/workflow-template.wflow" "$SOURCE_DIR/README.md" "$INSTALL_DIR/"
fi
swiftc -O "$SOURCE_DIR/ChromaWebM.swift" -o "$APP/Contents/MacOS/ChromaWebM" -framework Cocoa
cp "$SOURCE_DIR/backend.py" "$APP/Contents/Resources/backend.py"
"$PYTHON" - "$APP" "$SERVICE" "$PYTHON" "$SOURCE_DIR/workflow-template.wflow" <<'PY'
import copy, pathlib, plistlib, sys, uuid
app,service,python=map(pathlib.Path,sys.argv[1:4])
info={"CFBundleIdentifier":"local.chroma.webm","CFBundleName":"Chroma WebM","CFBundleDisplayName":"Chroma WebM","CFBundleExecutable":"ChromaWebM","CFBundlePackageType":"APPL","CFBundleShortVersionString":"1.0","NSHighResolutionCapable":True,"NSPrincipalClass":"NSApplication","LSMinimumSystemVersion":"13.0","ChromaPython":str(python),"CFBundleDocumentTypes":[{"CFBundleTypeName":"Video","CFBundleTypeRole":"Editor","LSItemContentTypes":["public.movie"],"LSHandlerRank":"Alternate"}]}
(app/"Contents/Info.plist").write_bytes(plistlib.dumps(info))
template=pathlib.Path(sys.argv[4])
doc=plistlib.loads(template.read_bytes())
action=doc["actions"][0]["action"]
action["ActionParameters"]["COMMAND_STRING"]='/usr/bin/open -n -a "$HOME/Applications/Chroma WebM.app" --args "$@"\n'
action["UUID"]=str(uuid.uuid4()).upper()
action["InputUUID"]=str(uuid.uuid4()).upper()
action["OutputUUID"]=str(uuid.uuid4()).upper()
(service/"Contents/document.wflow").write_bytes(plistlib.dumps(doc))
(service/"Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier":"local.chroma.webm.quickaction","CFBundleName":"Chroma to WebM","CFBundleVersion":"1","NSServices":[{"NSMenuItem":{"default":"Chroma to WebM"},"NSMessage":"runWorkflowAsService","NSRequiredContext":{"NSApplicationIdentifier":"com.apple.finder"},"NSSendFileTypes":["public.movie"]}]}))
PY
plutil -lint "$APP/Contents/Info.plist" "$SERVICE/Contents/document.wflow" "$SERVICE/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
/System/Library/CoreServices/pbs -flush
echo "Installed: $APP"
echo "Finder Quick Action: Chroma to WebM"

