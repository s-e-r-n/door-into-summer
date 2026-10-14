#!/bin/zsh
set -euo pipefail
identity="$(security find-identity -v -p codesigning | awk '/"Apple Development: / { count++; hash = $2 } END { if (count == 1) print hash }')"
if [[ -z "$identity" ]]; then
	echo "install_app.sh needs exactly one valid Apple Development identity in the keychain" >&2
	exit 1
fi
built="$("${0:A:h}/make_app.sh")"
installed="/Applications/${built:t}"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$built" "$staging/${built:t}"
codesign --force --sign "$identity" "$staging/${built:t}" >&2
rm -rf "$installed"
mv "$staging/${built:t}" "$installed"
echo "$installed"
