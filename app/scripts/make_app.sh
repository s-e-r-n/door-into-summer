#!/bin/zsh
set -euo pipefail
product_name="DoorIntoSummer"
display_name="Door into Summer"
icon_name="AppIcon"
minimum_system_version="26.0"
package_root="${0:A:h:h}"
cd "$package_root"
swift build -c release --product "$product_name" >&2
bin_path="$(swift build -c release --product "$product_name" --show-bin-path)"
app_path="$package_root/.build/$display_name.app"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/$product_name" "$app_path/Contents/MacOS/$product_name"
cp -R "$bin_path/${product_name}_${product_name}.bundle" "$app_path/Contents/Resources/"
cp /System/Library/Sounds/Blow.aiff "$app_path/Contents/Resources/"
mkdir -p "$app_path/Contents/Resources/bin"
cp "$package_root/../bin/review_window.py" "$app_path/Contents/Resources/bin/"
cp -R "$package_root/../bin/review" "$app_path/Contents/Resources/bin/review"
rm -rf "$app_path/Contents/Resources/bin/review/__pycache__"
icon_plist="$package_root/.build/$icon_name.plist"
xcrun actool "$package_root/$icon_name.icon" --compile "$app_path/Contents/Resources" --app-icon "$icon_name" --platform macosx --target-device mac --minimum-deployment-target "$minimum_system_version" --output-partial-info-plist "$icon_plist" --output-format human-readable-text --errors --warnings >&2
bundle_icon_file="$(plutil -extract CFBundleIconFile raw "$icon_plist")"
bundle_icon_name="$(plutil -extract CFBundleIconName raw "$icon_plist")"
cat > "$app_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>$product_name</string>
	<key>CFBundleIconFile</key><string>$bundle_icon_file</string>
	<key>CFBundleIconName</key><string>$bundle_icon_name</string>
	<key>CFBundleIdentifier</key><string>com.waveprom.door-into-summer</string>
	<key>CFBundleName</key><string>$display_name</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>LSMinimumSystemVersion</key><string>$minimum_system_version</string>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$app_path" >&2
echo "$app_path"
