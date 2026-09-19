#!/usr/bin/env bash
# Creates a fresh Flutter project and applies the Nearby Share sources on top.
# Usage: ./setup.sh [target-dir]   (default: ../nearby_share)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$HERE/../nearby_share}"
PKG_DIR="com/nearbyshare/nearby_share"

command -v flutter >/dev/null 2>&1 || { echo "flutter not found on PATH"; exit 1; }

flutter create --org com.nearbyshare --project-name nearby_share --platforms=android "$TARGET"

rm -rf "$TARGET/lib" "$TARGET/test"
cp -R "$HERE/lib" "$TARGET/lib"
cp "$HERE/pubspec.yaml" "$TARGET/pubspec.yaml"
cp "$HERE/android/app/src/main/AndroidManifest.xml" "$TARGET/android/app/src/main/AndroidManifest.xml"
mkdir -p "$TARGET/android/app/src/main/kotlin/$PKG_DIR"
cp "$HERE/android/app/src/main/kotlin/$PKG_DIR/MainActivity.kt" "$TARGET/android/app/src/main/kotlin/$PKG_DIR/MainActivity.kt"

# Nearby Connections needs minSdk 26 here
for f in "$TARGET/android/app/build.gradle" "$TARGET/android/app/build.gradle.kts"; do
  if [ -f "$f" ]; then
    sed -i.bak -E \
      -e 's/minSdkVersion flutter\.minSdkVersion/minSdkVersion 26/' \
      -e 's/minSdk = flutter\.minSdkVersion/minSdk = 26/' \
      -e 's/minSdkVersion\(flutter\.minSdkVersion\)/minSdkVersion(26)/' "$f"
    rm -f "$f.bak"
    grep -n "minSdk" "$f" || true
  fi
done

(cd "$TARGET" && flutter pub get)
echo "Done. Connect a physical phone, then: cd $TARGET && flutter run"
