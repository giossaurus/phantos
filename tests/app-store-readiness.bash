#!/bin/bash
# Checks a built PhantOS.app against what App Store review and App Store Connect ask for.
#
# Usage: tests/app-store-readiness.bash <path to PhantOS.app>

app=$1
repo=$(cd "$(dirname "$0")/.." && pwd)
failures=0
fail() {
    echo "FAIL: $*"
    failures=$((failures + 1))
}
plist() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

# Apps that call required-reason APIs must say why, in a privacy manifest per bundle.
for bundle in "$app" "$app"/PlugIns/*.appex; do
    manifest=$bundle/PrivacyInfo.xcprivacy
    if [ ! -f "$manifest" ]; then
        fail "no PrivacyInfo.xcprivacy in $(basename "$bundle")"
        continue
    fi
    [ "$(plist "$manifest" NSPrivacyTracking)" = false ] || fail "$(basename "$bundle") doesn't declare no tracking"
    declared=$(plutil -convert json -o - "$manifest" | python3 -I -c '
import json, sys
for entry in json.load(sys.stdin).get("NSPrivacyAccessedAPITypes", []):
    print(entry["NSPrivacyAccessedAPIType"], *entry["NSPrivacyAccessedAPITypeReasons"])')
    for category in UserDefaults FileTimestamp; do
        echo "$declared" | grep -q "NSPrivacyAccessedAPICategory$category " ||
            fail "$(basename "$bundle") doesn't declare why it uses $category"
    done
done
declared=$(plutil -convert json -o - "$app/PrivacyInfo.xcprivacy" 2>/dev/null | python3 -I -c '
import json, sys
for entry in json.load(sys.stdin).get("NSPrivacyAccessedAPITypes", []):
    print(entry["NSPrivacyAccessedAPIType"])')
# df reads free space and /proc/uptime reads kern.boottime.
for category in DiskSpace SystemBootTime; do
    echo "$declared" | grep -q "NSPrivacyAccessedAPICategory$category" || fail "the app doesn't declare why it uses $category"
done

# Every App Store device is 64-bit; armv7 is a leftover from iSH's oldest builds.
capabilities=$(plist "$app/Info.plist" UIRequiredDeviceCapabilities)
echo "$capabilities" | grep -q arm64 || fail "UIRequiredDeviceCapabilities doesn't ask for arm64: $capabilities"
echo "$capabilities" | grep -q armv7 && fail "UIRequiredDeviceCapabilities still asks for armv7"

# PhantOS starts at 1.0, not at iSH's version.
version=$(plist "$app/Info.plist" CFBundleShortVersionString)
[ "$version" = 1.0.0 ] || fail "version is $version, not 1.0.0"

# The bundled root is PhantOS's, with zsh and the banner, not iSH's.
grep -q "ish-app/roots" "$repo/app/iSH.xcconfig" && fail "ROOTFS_URL still downloads iSH's root"
listing=$(tar -tzf "$app/root.tar.gz" 2>/dev/null)
echo "$listing" | grep -q '^./etc/phantos/banner.zsh$' || fail "the bundled root has no PhantOS banner"
echo "$listing" | grep -q '^./usr/bin/nvim$' || fail "the bundled root has no Neovim"

# App Store Connect asks for a privacy policy and a support page.
[ -f "$repo/PRIVACY.md" ] || fail "no PRIVACY.md for the privacy policy URL"
[ -f "$repo/SUPPORT.md" ] || fail "no SUPPORT.md for the support URL"

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "ready for App Store review"
