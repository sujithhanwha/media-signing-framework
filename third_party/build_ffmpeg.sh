#!/bin/bash

# Script to download and build FFmpeg locally
# This is used for the FFmpeg-based signer application

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
SRC_DIR="${SCRIPT_DIR}/src/ffmpeg"
INSTALL_DIR="${SCRIPT_DIR}/install"

# FFmpeg version
FFMPEG_VERSION="6.1.1"
FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
FFMPEG_TAR="ffmpeg-${FFMPEG_VERSION}.tar.xz"

print_info "Building FFmpeg ${FFMPEG_VERSION}..."
print_info "Source directory: ${SRC_DIR}"
print_info "Install directory: ${INSTALL_DIR}"

# Check for required build tools
print_info "Checking build dependencies..."
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        return 1
    fi
}

DEPS_OK=true
check_dependency make || DEPS_OK=false

if [ "$DEPS_OK" = false ]; then
    print_error "Missing dependencies. Please install:"
    print_error "  Ubuntu/Debian: sudo apt install build-essential"
    print_error "  Fedora: sudo dnf install @development-tools"
    print_error ""
    print_error "Optional (for better performance):"
    print_error "  Ubuntu/Debian: sudo apt install yasm"
    exit 1
fi

# Create directories
mkdir -p "${SCRIPT_DIR}/src"
mkdir -p "${INSTALL_DIR}"

# Download FFmpeg if not already downloaded
if [ ! -f "${SCRIPT_DIR}/src/${FFMPEG_TAR}" ]; then
    print_info "Downloading FFmpeg ${FFMPEG_VERSION}..."
    cd "${SCRIPT_DIR}/src"
    
    if command -v wget &> /dev/null; then
        wget -O "${FFMPEG_TAR}" "${FFMPEG_URL}"
    elif command -v curl &> /dev/null; then
        curl -L -o "${FFMPEG_TAR}" "${FFMPEG_URL}"
    else
        print_error "Neither wget nor curl found. Please install one of them."
        exit 1
    fi
    
    print_info "Download complete"
else
    print_info "FFmpeg tarball already downloaded"
fi

# Extract FFmpeg
if [ ! -d "${SRC_DIR}" ]; then
    print_info "Extracting FFmpeg..."
    cd "${SCRIPT_DIR}/src"
    tar xf "${FFMPEG_TAR}"
    mv "ffmpeg-${FFMPEG_VERSION}" ffmpeg
    print_info "Extraction complete"
else
    print_info "FFmpeg source already extracted"
fi

# Build FFmpeg
cd "${SRC_DIR}"

# Check if already built
if [ -f "${INSTALL_DIR}/lib/pkgconfig/libavformat.pc" ]; then
    print_info "FFmpeg appears to be already built"
    print_info "To rebuild, remove ${INSTALL_DIR} and ${SRC_DIR}"
    exit 0
fi

print_info "Configuring FFmpeg..."

# Determine number of CPU cores for parallel compilation
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Check if yasm or nasm is available
X86ASM_OPT=""
if ! command -v yasm &> /dev/null && ! command -v nasm &> /dev/null; then
    print_warning "yasm/nasm not found - disabling x86 assembly optimizations"
    print_info "For better performance, install yasm: sudo apt install yasm"
    X86ASM_OPT="--disable-x86asm"
fi

# Configure FFmpeg with minimal features for faster build
# --disable-* options reduce build time and dependencies
./configure \
    --prefix="${INSTALL_DIR}" \
    --enable-shared \
    --disable-static \
    --disable-doc \
    --disable-htmlpages \
    --disable-manpages \
    --disable-podpages \
    --disable-txtpages \
    --disable-network \
    --disable-autodetect \
    --enable-protocol=file \
    --enable-demuxer=h264,hevc,mpegts,mpegtsraw,mpegps,mpegvideo,rawvideo,mov,mp4 \
    --enable-decoder=h264,hevc \
    --enable-muxer=h264,hevc,mp4,rawvideo \
    --enable-encoder=wrapped_avframe \
    --enable-parser=h264,hevc \
    --enable-bsf=h264_mp4toannexb,hevc_mp4toannexb \
    --disable-programs \
    --disable-ffmpeg \
    --disable-ffplay \
    --disable-ffprobe \
    ${X86ASM_OPT}

print_info "Configuration complete"

print_info "Building FFmpeg using ${NPROC} cores..."

# Build
make -j${NPROC}

print_info "Installing FFmpeg..."

# Install
make install

print_info "FFmpeg ${FFMPEG_VERSION} built and installed successfully!"
print_info "Installation directory: ${INSTALL_DIR}"

# Verify installation
FFMPEG_PC_PATH=""
if [ -f "${INSTALL_DIR}/lib/pkgconfig/libavformat.pc" ]; then
    FFMPEG_PC_PATH="${INSTALL_DIR}/lib/pkgconfig"
fi

if [ -n "${FFMPEG_PC_PATH}" ]; then
    print_info "Verification: libavformat.pc found in ${FFMPEG_PC_PATH}"
    INSTALLED_VERSION=$(PKG_CONFIG_PATH="${FFMPEG_PC_PATH}" pkg-config --modversion libavformat)
    print_info "Installed libavformat version: ${INSTALLED_VERSION}"
else
    print_error "Verification failed: libavformat.pc not found"
    exit 1
fi

print_info "Build complete!"
print_info ""
print_info "To use this FFmpeg installation, set:"
print_info "  export PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig:\$PKG_CONFIG_PATH"
print_info "  export LD_LIBRARY_PATH=${INSTALL_DIR}/lib:\$LD_LIBRARY_PATH"
