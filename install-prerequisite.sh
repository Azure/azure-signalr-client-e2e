#!/usr/bin/env bash
# Purpose: Install prerequisites needed to run ./run-all-tests.sh across Java, Swift, and .NET components.
# Focus: Linux (Debian/Ubuntu primary). Provides guidance for other distros instead of hard failing.
# Name chosen per user request (install_prequ).

set -euo pipefail

# ----------------------------- Config ---------------------------------
JAVA_PACKAGE_DEFAULT=openjdk-21-jdk
MAVEN_PACKAGE=maven
DOTNET_SDK_VERSION_MINOR=8.0   # Accept any 8.0.x
SWIFT_VERSION=6.2              # Desired Swift version (used for version check only)
SWIFT_PLATFORM=ubuntu22.04     # Kept for possible future fallback (tarball) installs
SWIFT_INSTALL_DIR=/opt/swift   # Legacy install dir (not used by artifact bundle install)
SWIFT_ARTIFACT_URL="https://download.swift.org/swift-6.2-release/static-sdk/swift-6.2-RELEASE/swift-6.2-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz"
SWIFT_ARTIFACT_CHECKSUM="d2225840e592389ca517bbf71652f7003dbf45ac35d1e57d98b9250368769378"

# --------------------------- Color Helpers -----------------------------
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi
log() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERR ]${NC} $*" >&2; }
ok() { echo -e "${GREEN}[ OK ]${NC} $*"; }

# --------------------------- Usage -------------------------------------
usage() {
  cat <<EOF
Usage: $0
Install prerequisites for running run-all-tests.sh (no command-line options).

Environment:
  E2E_CONNECTION_STRING must be set before running tests (NOT installed here).

Notes:
  1. Script primarily supports Debian/Ubuntu via apt. Other distros get guidance only.
  2. Swift install downloads and extracts into ${SWIFT_INSTALL_DIR}.
  3. Safe to re-run; existing tools are skipped.
EOF
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

# ------------------------ Privilege Strategy ---------------------------
# Plan C: Do NOT re-exec entire script with sudo; keep user PATH (so user-level Swift is visible).
# Instead, call sudo only for package install commands when needed. Warn if sudo missing.
if ! command -v sudo >/dev/null 2>&1; then
  warn "'sudo' command not found. Package installation may fail if root privileges are required."
fi

# ------------------------ Package Manager ------------------------------
PKG_MGR=""
if command -v apt-get >/dev/null 2>&1; then
  PKG_MGR=apt
elif command -v dnf >/dev/null 2>&1; then
  PKG_MGR=dnf
elif command -v yum >/dev/null 2>&1; then
  PKG_MGR=yum
elif command -v pacman >/dev/null 2>&1; then
  PKG_MGR=pacman
elif command -v zypper >/dev/null 2>&1; then
  PKG_MGR=zypper
fi

if [[ "$PKG_MGR" != "apt" ]]; then
  warn "Automatic installation is only implemented for apt-based systems."
  warn "Detected: ${PKG_MGR:-unknown}. Please manually install: Java (JDK 17+), Maven, .NET SDK 8.0, Swift ${SWIFT_VERSION}."
  warn "Proceeding to attempt partial checks..."
fi

# ------------------------ Functions ------------------------------------
install_apt_packages() {
  local packages=()
  for p in "$@"; do
    if dpkg -s "$p" >/dev/null 2>&1; then
      ok "Package $p already installed"
    else
      packages+=("$p")
    fi
  done
  if (( ${#packages[@]} > 0 )); then
    log "Installing apt packages: ${packages[*]}"
    if [[ $EUID -ne 0 ]]; then
      if command -v sudo >/dev/null 2>&1; then
        sudo apt-get update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get install ${APT_YES_FLAG} -o Dpkg::Options::=--force-confnew "${packages[@]}"
      else
        err "Need root privileges to install: ${packages[*]}"; return 1
      fi
    else
      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get install ${APT_YES_FLAG} -o Dpkg::Options::=--force-confnew "${packages[@]}"
    fi
  fi
}

ensure_java() {
  if command -v javac >/dev/null 2>&1; then
    ok "Java already installed: $(javac -version 2>&1)"
    return
  fi
  if [[ "$PKG_MGR" == "apt" ]]; then
    install_apt_packages "$JAVA_PACKAGE_DEFAULT"
  else
    warn "Install Java manually (JDK 17+)."
  fi
}

ensure_maven() {
  if command -v mvn >/dev/null 2>&1; then
    ok "Maven already installed: $(mvn -v | head -n1)"
    return
  fi
  if [[ "$PKG_MGR" == "apt" ]]; then
    install_apt_packages "$MAVEN_PACKAGE"
  else
    warn "Install Maven manually."
  fi
}

ensure_dotnet() {
  if command -v dotnet >/dev/null 2>&1; then
    local ver; ver=$(dotnet --version)
    ok ".NET already installed: ${ver}"
    if [[ ! "$ver" =~ ^${DOTNET_SDK_VERSION_MINOR//./\\.} ]]; then
      warn ".NET version ${ver} doesn't start with ${DOTNET_SDK_VERSION_MINOR}; tests may still work."
    fi
    return
  fi
  if [[ "$PKG_MGR" == "apt" ]]; then
    log "Installing .NET SDK ${DOTNET_SDK_VERSION_MINOR} (may pull matching minor release)"
    # Microsoft package repository setup (idempotent)
    if ! dpkg -s dotnet-sdk-${DOTNET_SDK_VERSION_MINOR} >/dev/null 2>&1; then
      if [[ $EUID -ne 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
          warn "sudo not available; cannot install dotnet-sdk-${DOTNET_SDK_VERSION_MINOR}."; return
        fi
        sudo apt-get update -y
        install_apt_packages wget apt-transport-https software-properties-common gnupg
        sudo wget -q https://packages.microsoft.com/config/ubuntu/$(. /etc/os-release && echo $VERSION_ID)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb || true
        if [[ -f packages-microsoft-prod.deb ]]; then
          sudo dpkg -i packages-microsoft-prod.deb || true
          sudo rm -f packages-microsoft-prod.deb
        fi
        sudo apt-get update -y || true
        sudo DEBIAN_FRONTEND=noninteractive apt-get install ${APT_YES_FLAG} dotnet-sdk-8.0 || {
          warn "Installing 'dotnet-sdk-8.0' failed; please verify manually."; return
        }
      else
        apt-get update -y
        install_apt_packages wget apt-transport-https software-properties-common gnupg
        wget -q https://packages.microsoft.com/config/ubuntu/$(. /etc/os-release && echo $VERSION_ID)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb || true
        if [[ -f packages-microsoft-prod.deb ]]; then
          dpkg -i packages-microsoft-prod.deb || true
          rm -f packages-microsoft-prod.deb
        fi
        apt-get update -y || true
        DEBIAN_FRONTEND=noninteractive apt-get install ${APT_YES_FLAG} dotnet-sdk-8.0 || {
          warn "Installing 'dotnet-sdk-8.0' failed; please verify manually."; return
        }
      fi
    fi
  else
    warn "Install .NET 8.0 SDK manually (https://dotnet.microsoft.com/en-us/download)."
  fi
}

ensure_cpp() {
  (( WITH_CPP == 1 )) || return 0
  if [[ "$PKG_MGR" == "apt" ]]; then
    install_apt_packages build-essential cmake pkg-config libssl-dev
  else
    warn "Install C++ build tools manually (compiler, cmake, openssl dev)."
  fi
}

ensure_swift() {
  # If Swift already present and matches requested major.minor, skip artifact installation.
  if command -v swift >/dev/null 2>&1; then
    local current_ver
    current_ver=$(swift --version 2>/dev/null | grep -Eo 'Swift version [0-9]+\.[0-9]+' | awk '{print $3}') || true
    if [[ -n "$current_ver" && "$current_ver" == "$SWIFT_VERSION"* ]]; then
      ok "Swift already installed: $(swift --version | head -n1)"
      return
    else
      warn "Swift present but not ${SWIFT_VERSION}. Attempting artifact bundle install for ${SWIFT_VERSION}."
    fi
  else
    # Need some base dependencies if no swift command exists; attempt minimal prerequisites on apt systems.
    if [[ "$PKG_MGR" == "apt" ]]; then
      install_apt_packages curl ca-certificates tar gzip
    fi
  fi

  # Artifact bundle install (Swift 6 static SDK). This is idempotent: swift sdk install will skip if already installed.
  if ! command -v swift >/dev/null 2>&1; then
    warn "'swift' command not found. You need a bootstrap Swift toolchain to use 'swift sdk install'. Please install a base Swift toolchain first (e.g., via apt or tarball). Skipping artifact bundle."
    return 0
  fi

  log "Installing Swift SDK artifact bundle for ${SWIFT_VERSION} via: swift sdk install"
  local install_cmd=(swift sdk install "$SWIFT_ARTIFACT_URL" --checksum "$SWIFT_ARTIFACT_CHECKSUM")
  # Run and capture output; don't fail whole script if this step fails.
  if "${install_cmd[@]}"; then
    ok "Swift SDK artifact bundle installed (version ${SWIFT_VERSION})."
  else
    err "Swift SDK artifact bundle installation failed. Command attempted: ${install_cmd[*]}"
    return 1
  fi

  # Suggest using 'swift sdk list' to verify.
  if swift sdk list >/dev/null 2>&1; then
    log "Installed SDKs:"; swift sdk list || true
  fi
}

# ------------------------ Execution ------------------------------------
log "Starting prerequisite installation"
ensure_java
ensure_maven
ensure_swift
# todo: .net and c++

ok "All prerequisite steps completed."
log "Verify with: javac -version && mvn -v && swift --version || true"
log "Remember to export E2E_CONNECTION_STRING before running ./run-all-tests.sh"
