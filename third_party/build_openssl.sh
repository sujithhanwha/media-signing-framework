#!/bin/bash

# Script to download and build OpenSSL 3.4 locally
# This is used when system OpenSSL is not available or too old

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Directories
SRC_DIR="${SCRIPT_DIR}/src/openssl"
INSTALL_DIR="${SCRIPT_DIR}/install"

# OpenSSL version
OPENSSL_VERSION="3.4.0"
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_TAR="openssl-${OPENSSL_VERSION}.tar.gz"

print_info "Building OpenSSL ${OPENSSL_VERSION}..."
print_info "Source directory: ${SRC_DIR}"
print_info "Install directory: ${INSTALL_DIR}"

# Create directories
mkdir -p "${SCRIPT_DIR}/src"
mkdir -p "${INSTALL_DIR}"

# Download OpenSSL if not already downloaded
if [ ! -f "${SCRIPT_DIR}/src/${OPENSSL_TAR}" ]; then
    print_info "Downloading OpenSSL ${OPENSSL_VERSION}..."
    cd "${SCRIPT_DIR}/src"
    
    if command -v wget &> /dev/null; then
        wget -O "${OPENSSL_TAR}" "${OPENSSL_URL}"
    elif command -v curl &> /dev/null; then
        curl -L -o "${OPENSSL_TAR}" "${OPENSSL_URL}"
    else
        print_error "Neither wget nor curl found. Please install one of them."
        exit 1
    fi
    
    print_info "Download complete"
else
    print_info "OpenSSL tarball already downloaded"
fi

# Extract OpenSSL
if [ ! -d "${SRC_DIR}" ]; then
    print_info "Extracting OpenSSL..."
    cd "${SCRIPT_DIR}/src"
    tar xzf "${OPENSSL_TAR}"
    mv "openssl-${OPENSSL_VERSION}" openssl
    print_info "Extraction complete"
else
    print_info "OpenSSL source already extracted"
fi

# Build OpenSSL
cd "${SRC_DIR}"

# Check if already built
if [ -f "${INSTALL_DIR}/lib/libssl.so" ] || [ -f "${INSTALL_DIR}/lib/libssl.a" ]; then
    print_info "OpenSSL appears to be already built"
    print_info "To rebuild, remove ${INSTALL_DIR} and ${SRC_DIR}"
    exit 0
fi

print_info "Configuring OpenSSL..."

# Configure OpenSSL
# --prefix: Installation directory
# --openssldir: Configuration directory
# no-shared: Build static libraries only (smaller footprint)
# no-tests: Don't build test suite (faster build)
./config \
    --prefix="${INSTALL_DIR}" \
    --openssldir="${INSTALL_DIR}/ssl" \
    shared \
    no-tests \
    -Wl,-rpath,${INSTALL_DIR}/lib

print_info "Configuration complete"

# Determine number of CPU cores for parallel compilation
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
print_info "Building OpenSSL using ${NPROC} cores..."

# Build
make -j${NPROC}

print_info "Installing OpenSSL..."

# Install
make install_sw install_ssldirs

print_info "OpenSSL ${OPENSSL_VERSION} built and installed successfully!"
print_info "Installation directory: ${INSTALL_DIR}"

# Verify installation (check both lib and lib64)
OPENSSL_PC_PATH=""
if [ -f "${INSTALL_DIR}/lib64/pkgconfig/openssl.pc" ]; then
    OPENSSL_PC_PATH="${INSTALL_DIR}/lib64/pkgconfig"
elif [ -f "${INSTALL_DIR}/lib/pkgconfig/openssl.pc" ]; then
    OPENSSL_PC_PATH="${INSTALL_DIR}/lib/pkgconfig"
fi

if [ -n "${OPENSSL_PC_PATH}" ]; then
    print_info "Verification: openssl.pc found in ${OPENSSL_PC_PATH}"
    INSTALLED_VERSION=$(PKG_CONFIG_PATH="${OPENSSL_PC_PATH}" pkg-config --modversion openssl)
    print_info "Installed version: ${INSTALLED_VERSION}"
else
    print_error "Verification failed: openssl.pc not found in lib or lib64"
    exit 1
fi

print_info "Build complete!"
