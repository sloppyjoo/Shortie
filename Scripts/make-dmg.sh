#!/bin/zsh
# Builds Shortie for Apple silicon and Intel and packs it into dist/Shortie-<version>.dmg,
# with a styled drag-to-Applications window.
#
# The app inside is re-signed ad hoc, so the DMG carries no personal certificate details.
# Usage: Scripts/make-dmg.sh
set -euo pipefail

ROOT=${0:A:h:h}
cd "$ROOT"
WORK=$(mktemp -d)
trap 'hdiutil detach -quiet "/Volumes/Shortie" 2>/dev/null || true; rm -rf "$WORK"' EXIT

echo "› Building"
xcodebuild -project Shortie.xcodeproj -scheme Shortie -configuration Release -derivedDataPath build \
    -allowProvisioningUpdates ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build -quiet
APP=build/Build/Products/Release/Shortie.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")

echo "› Signing a copy for distribution"
mkdir "$WORK/stage"
ditto "$APP" "$WORK/stage/Shortie.app"
cat > "$WORK/dist.entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.automation.apple-events</key>
	<true/>
</dict>
</plist>
EOF
codesign --force --deep --sign - --options runtime --entitlements "$WORK/dist.entitlements" "$WORK/stage/Shortie.app"
codesign --verify --deep --strict "$WORK/stage/Shortie.app"
ln -s /Applications "$WORK/stage/Applications"

echo "› Drawing the background"
mkdir "$WORK/stage/.background"
swift Scripts/dmg-background.swift "$WORK/bg.png" 1
swift Scripts/dmg-background.swift "$WORK/bg@2x.png" 2
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/stage/.background/background.tiff" 2>/dev/null

echo "› Laying out the window"
hdiutil detach -quiet "/Volumes/Shortie" 2>/dev/null || true
hdiutil create -quiet -volname Shortie -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -size 60m "$WORK/rw.dmg"
hdiutil attach -quiet -noverify -noautoopen "$WORK/rw.dmg"
osascript <<'EOF'
tell application "Finder"
	tell disk "Shortie"
		open
		set current view of container window to icon view
		set toolbar visible of container window to false
		set statusbar visible of container window to false
		set sidebar width of container window to 0
		-- 640 × 400 of content, plus the title bar.
		set the bounds of container window to {200, 120, 840, 548}
		set viewOptions to the icon view options of container window
		set arrangement of viewOptions to not arranged
		set icon size of viewOptions to 112
		set text size of viewOptions to 13
		set background picture of viewOptions to file ".background:background.tiff"
		set position of item "Shortie.app" of container window to {170, 180}
		set position of item "Applications" of container window to {470, 180}
		close
		open
		update without registering applications
		delay 1
		close
	end tell
end tell
EOF
# The disk shows Shortie's icon. This has to come after the Finder step, which removes it.
cp "$APP/Contents/Resources/AppIcon.icns" /Volumes/Shortie/.VolumeIcon.icns
xcrun SetFile -a C /Volumes/Shortie
rm -rf /Volumes/Shortie/.fseventsd
sync
hdiutil detach -quiet /Volumes/Shortie

echo "› Packing"
mkdir -p dist
rm -f "dist/Shortie-$VERSION.dmg"
hdiutil convert -quiet "$WORK/rw.dmg" -format ULFO -o "dist/Shortie-$VERSION.dmg"
hdiutil verify -quiet "dist/Shortie-$VERSION.dmg"
echo "✓ dist/Shortie-$VERSION.dmg ($(du -h "dist/Shortie-$VERSION.dmg" | cut -f1))"
