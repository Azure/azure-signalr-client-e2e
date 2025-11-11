#!/usr/bin/env bash
set -euo pipefail

# This script builds the SignalR-Client-Cpp submodule on Linux per its README.
# It will:
# 1) Ensure submodule exists and is initialized
# 2) Bootstrap vcpkg
# 3) Install required libraries via vcpkg
# 4) Configure & build the C++ client library
#
# Usage:
#   From repo root or any path: bash cpp/build-signalr-client-linux.sh
#
# Notes:
# - On first run it may require system packages: curl zip unzip tar
# - WebSockets are currently disabled upstream; see README for details

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE_DIR="${REPO_ROOT}/cpp/signalr-client-cpp"
VCPKG_DIR="${SUBMODULE_DIR}/submodules/vcpkg"
BUILD_DIR="${SUBMODULE_DIR}/build.release"
TOOLCHAIN_FILE="${VCPKG_DIR}/scripts/buildsystems/vcpkg.cmake"

echo "[1/6] Ensure submodule exists..."
if [[ ! -d "${SUBMODULE_DIR}/.git" ]]; then
  echo "Submodule not present. Adding submodule to cpp/signalr-client-cpp ..."
  git -C "${REPO_ROOT}" submodule add https://github.com/aspnet/SignalR-Client-Cpp cpp/signalr-client-cpp || true
fi

echo "[2/6] Initialize submodules (including nested)..."
git -C "${SUBMODULE_DIR}" submodule update --init

echo "[3/6] Check system prerequisites (curl zip unzip tar)..."
MISSING_PKGS=()
for pkg in curl zip unzip tar; do
  if ! command -v "${pkg}" >/dev/null 2>&1; then
    MISSING_PKGS+=("${pkg}")
  fi
done
if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
  echo "Missing system packages: ${MISSING_PKGS[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    echo "Attempting to install via apt-get (sudo required)..."
    sudo apt-get update
    sudo apt-get install -y "${MISSING_PKGS[@]}"
  else
    echo "Please install these packages using your distro's package manager, then re-run this script."
    exit 1
  fi
fi

echo "[4/6] Bootstrap vcpkg..."
pushd "${SUBMODULE_DIR}" >/dev/null
chmod +x "${VCPKG_DIR}/bootstrap-vcpkg.sh"
"${VCPKG_DIR}/bootstrap-vcpkg.sh"

echo "[5/6] Install libraries via vcpkg..."
export VCPKG_DEFAULT_BINARY_CACHE="${VCPKG_DIR}/binary_cache"
mkdir -p "$VCPKG_DEFAULT_BINARY_CACHE"
"${VCPKG_DIR}/vcpkg" install cpprestsdk boost-system boost-chrono boost-thread jsoncpp

echo "[6/6] Configure & build SignalR-Client-Cpp..."
mkdir -p "${BUILD_DIR}"
pushd "${BUILD_DIR}" >/dev/null
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_CPPRESTSDK=true \
  -DBUILD_SAMPLES=true \
  -DWERROR=false # do not convert warning as errors
cmake --build . --config Release
popd >/dev/null
popd >/dev/null

echo "Build completed."
echo "Artifacts:"
echo "  ${BUILD_DIR}/bin/"
echo "  ${BUILD_DIR}/lib/"
echo
echo "Upstream README (Linux steps) referenced:"
echo "  https://github.com/aspnet/SignalR-Client-Cpp"


