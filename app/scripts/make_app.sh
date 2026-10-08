#!/bin/zsh
set -euo pipefail
product_name="DoorIntoSummer"
display_name="Door into Summer"
package_root="${0:A:h:h}"
cd "$package_root"
swift build -c release --product "$product_name" >&2
bin_path="$(swift build -c release --product "$product_name" --show-bin-path)"
app_path="$package_root/.build/$display_name.app"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS"
cp "$bin_path/$product_name" "$app_path/Contents/MacOS/$product_name"
cat > "$app_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>$product_name</string>
	<key>CFBundleIdentifier</key><string>com.waveprom.door-into-summer</string>
	<key>CFBundleName</key><string>$display_name</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>LSMinimumSystemVersion</key><string>26.0</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key><true/>
	</dict>
</dict>
</plist>
PLIST
echo "$app_path"
