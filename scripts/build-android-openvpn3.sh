#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENVPN3_COMMIT="0abc8313b8fe5f63dbebc10d53094952957845d9"
OPENVPN3_SOURCE_DIR="${OPENVPN3_SOURCE_DIR:-${RUNNER_TEMP:-/tmp}/freeroute-openvpn3-${OPENVPN3_COMMIT}}"
BUILD_DIR="${ROOT_DIR}/app/build/native-openvpn3"
JNI_OUTPUT_DIR="${ROOT_DIR}/app/build/generated/openvpn3/jniLibs/arm64-v8a"

fail() { echo "ERROR: $*" >&2; exit 1; }
for cmd in git cmake ninja pkg-config; do command -v "$cmd" >/dev/null 2>&1 || fail "Missing command: $cmd"; done
: "${VCPKG_ROOT:?VCPKG_ROOT must point to a bootstrapped vcpkg checkout}"
: "${ANDROID_HOME:?ANDROID_HOME must point to the Android SDK}"
ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_HOME}/ndk/27.2.12479018}"
[[ -f "${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" ]] || fail "NDK toolchain not found at ${ANDROID_NDK_HOME}"
[[ -x "${VCPKG_ROOT}/vcpkg" ]] || fail "vcpkg executable not found"

echo "Fetching pinned OpenVPN 3 Core source"
if [[ ! -d "${OPENVPN3_SOURCE_DIR}/.git" ]]; then
  rm -rf "${OPENVPN3_SOURCE_DIR}"
  mkdir -p "$(dirname "${OPENVPN3_SOURCE_DIR}")"
  git clone --filter=blob:none --no-checkout https://github.com/OpenVPN/openvpn3.git "${OPENVPN3_SOURCE_DIR}"
fi
git -C "${OPENVPN3_SOURCE_DIR}" fetch --depth 1 origin "${OPENVPN3_COMMIT}"
git -C "${OPENVPN3_SOURCE_DIR}" checkout --detach --force "${OPENVPN3_COMMIT}"
ACTUAL_COMMIT="$(git -C "${OPENVPN3_SOURCE_DIR}" rev-parse HEAD)"
[[ "$ACTUAL_COMMIT" == "$OPENVPN3_COMMIT" ]] || fail "Unexpected OpenVPN 3 source commit: ${ACTUAL_COMMIT}"

VCPKG_MANIFEST_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/freeroute-vcpkg-manifest.XXXXXX")"
trap 'rm -rf "${VCPKG_MANIFEST_DIR}"' EXIT
cat > "${VCPKG_MANIFEST_DIR}/vcpkg.json" <<JSON
{
  "name": "freeroute-openvpn3-android",
  "version-string": "0.1.0",
  "dependencies": ["asio", "fmt", "lz4", "openssl"]
}
JSON
"${VCPKG_ROOT}/vcpkg" install --triplet arm64-android --x-manifest-root="${VCPKG_MANIFEST_DIR}" --x-install-root="${VCPKG_ROOT}/installed" --disable-metrics

export ANDROID_NDK_HOME VCPKG_ROOT
export VCPKG_TARGET_TRIPLET=arm64-android
export PKG_CONFIG_PATH="${VCPKG_ROOT}/installed/arm64-android/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"

cmake -S "${ROOT_DIR}/app/src/main/cpp" -B "${BUILD_DIR}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" \
  -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" \
  -DVCPKG_TARGET_TRIPLET=arm64-android \
  -DVCPKG_INSTALLED_DIR="${VCPKG_ROOT}/installed" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DANDROID_STL=c++_static \
  -DOPENVPN3_SOURCE_DIR="${OPENVPN3_SOURCE_DIR}"

cmake --build "${BUILD_DIR}" --target freeroute_openvpn3 --parallel 2
LIBRARY_PATH="${BUILD_DIR}/libfreeroute_openvpn3.so"
[[ -s "${LIBRARY_PATH}" ]] || fail "Native library not produced: ${LIBRARY_PATH}"
mkdir -p "${JNI_OUTPUT_DIR}"
install -m 0644 "${LIBRARY_PATH}" "${JNI_OUTPUT_DIR}/libfreeroute_openvpn3.so"
file "${JNI_OUTPUT_DIR}/libfreeroute_openvpn3.so"
