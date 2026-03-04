#!/bin/bash

# ONVIF Media Signing Framework Build Script
# This script builds the library and example applications

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

# Default build directory
BUILD_DIR="${SCRIPT_DIR}/build"

# Parse command line arguments
BUILD_APPS=false
BUILD_SIGNER=false
BUILD_VALIDATOR=false
BUILD_FFMPEG_SIGNER=false
DEBUG_PRINTS=false
CLEAN=false
INSTALL_PREFIX=""
LOCAL_FFMPEG=true  # Default to using local FFmpeg

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -a, --all-apps        Build all example applications"
    echo "  -s, --signer          Build GStreamer signer application"
    echo "  -v, --validator       Build validator application"
    echo "  -f, --ffmpeg-signer   Build FFmpeg-based signer application"
    echo "  -d, --debug           Enable debug prints"
    echo "  -c, --clean           Clean build directory before building"
    echo "  -p, --prefix PATH     Installation prefix (default: none)"
    echo "  --local-ffmpeg        Use local FFmpeg build (default)"
    echo "  --system-ffmpeg       Use system FFmpeg instead of local build"
    echo "  -h, --help            Show this help message"
    echo ""
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all-apps)
            BUILD_APPS=true
            shift
            ;;
        -s|--signer)
            BUILD_SIGNER=true
            shift
            ;;
        -v|--validator)
            BUILD_VALIDATOR=true
            shift
            ;;
        -f|--ffmpeg-signer)
            BUILD_FFMPEG_SIGNER=true
            shift
            ;;
        -d|--debug)
            DEBUG_PRINTS=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -p|--prefix)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --local-ffmpeg)
            LOCAL_FFMPEG=true
            shift
            ;;
        --system-ffmpeg)
            LOCAL_FFMPEG=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check for required dependencies
print_info "Checking dependencies..."

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

check_dependency meson
check_dependency ninja
check_dependency pkg-config

# Check for OpenSSL
if ! pkg-config --exists openssl; then
    print_error "OpenSSL not found. Please install OpenSSL 3.0.0 or newer."
    exit 1
fi

# Check for GStreamer (only if building GStreamer-based apps)
if [ "$BUILD_APPS" = true ] || [ "$BUILD_SIGNER" = true ] || [ "$BUILD_VALIDATOR" = true ]; then
    if ! pkg-config --exists gstreamer-1.0; then
        print_error "GStreamer not found. Please install GStreamer to build GStreamer-based applications."
        exit 1
    fi
fi

# Check for FFmpeg (only if building FFmpeg signer)
if [ "$BUILD_APPS" = true ] || [ "$BUILD_FFMPEG_SIGNER" = true ]; then
    if [ "$LOCAL_FFMPEG" = false ]; then
        # Using system FFmpeg - check if it's available
        if ! pkg-config --exists libavformat libavcodec libavutil; then
            print_error "System FFmpeg libraries not found."
            print_info "Either install FFmpeg packages or use --local-ffmpeg to build locally."
            print_info "  Install: libavformat-dev libavcodec-dev libavutil-dev"
            exit 1
        fi
    else
        # Using local FFmpeg - check if it needs to be built
        if [ ! -d "${SCRIPT_DIR}/third_party/install" ]; then
            print_info "Local FFmpeg not found. Building FFmpeg..."
            bash "${SCRIPT_DIR}/third_party/build_ffmpeg.sh"
            if [ $? -ne 0 ]; then
                print_error "Failed to build FFmpeg."
                exit 1
            fi
        else
            print_info "Using existing local FFmpeg installation."
        fi
    fi
fi

print_info "All dependencies found."

# Clean if requested
if [ "$CLEAN" = true ]; then
    print_info "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    # Also clean FFmpeg if using local build
    if [ "$LOCAL_FFMPEG" = true ]; then
        print_info "Cleaning local FFmpeg build..."
        rm -rf "${SCRIPT_DIR}/third_party/src" "${SCRIPT_DIR}/third_party/install"
    fi
fi

# Build meson options
MESON_OPTS=""

if [ "$BUILD_APPS" = true ]; then
    MESON_OPTS="$MESON_OPTS -Dbuild_all_apps=true"
else
    if [ "$BUILD_SIGNER" = true ]; then
        MESON_OPTS="$MESON_OPTS -Dsigner=true"
    fi
    if [ "$BUILD_VALIDATOR" = true ]; then
        MESON_OPTS="$MESON_OPTS -Dvalidator=true"
    fi
    if [ "$BUILD_FFMPEG_SIGNER" = true ]; then
        MESON_OPTS="$MESON_OPTS -Dffmpeg_signer=true"
    fi
fi

if [ "$DEBUG_PRINTS" = true ]; then
    MESON_OPTS="$MESON_OPTS -Ddebugprints=true"
fi

if [ -n "$INSTALL_PREFIX" ]; then
    MESON_OPTS="$MESON_OPTS --prefix=$INSTALL_PREFIX"
fi

# Set local_ffmpeg option
if [ "$LOCAL_FFMPEG" = true ]; then
    MESON_OPTS="$MESON_OPTS -Dlocal_ffmpeg=true"
else
    MESON_OPTS="$MESON_OPTS -Dlocal_ffmpeg=false"
fi

# Configure with meson
print_info "Configuring build with meson..."
if [ -d "$BUILD_DIR" ]; then
    print_info "Build directory exists, reconfiguring..."
    meson setup --reconfigure $MESON_OPTS "$BUILD_DIR"
else
    print_info "Creating new build directory..."
    meson setup $MESON_OPTS "$BUILD_DIR"
fi

# Build with ninja
print_info "Building with ninja..."
ninja -C "$BUILD_DIR"

# Success message
print_info "Build completed successfully!"
echo ""
echo "Build artifacts:"
echo "  Library: ${BUILD_DIR}/libmedia-signing-framework.so*"

if [ "$BUILD_APPS" = true ] || [ "$BUILD_SIGNER" = true ]; then
    echo "  GStreamer Signer: ${BUILD_DIR}/examples/apps/signer/signer"
fi

if [ "$BUILD_APPS" = true ] || [ "$BUILD_VALIDATOR" = true ]; then
    echo "  Validator: ${BUILD_DIR}/examples/apps/validator/validator"
fi

if [ "$BUILD_APPS" = true ] || [ "$BUILD_FFMPEG_SIGNER" = true ]; then
    echo "  FFmpeg Signer: ${BUILD_DIR}/examples/apps/ffmpeg-signer/ffmpeg-signer"
fi

echo ""
echo "To run the GStreamer signer:"
echo "  export LD_LIBRARY_PATH=${BUILD_DIR}:\$LD_LIBRARY_PATH"
echo "  export GST_PLUGIN_PATH=${BUILD_DIR}/examples/apps/signer/gst-plugin:\$GST_PLUGIN_PATH"
echo "  ${BUILD_DIR}/examples/apps/signer/signer -c h264 video.mp4"
echo ""
echo "To run the FFmpeg signer:"
echo "  export LD_LIBRARY_PATH=${BUILD_DIR}:\$LD_LIBRARY_PATH"
if [ "$LOCAL_FFMPEG" = true ]; then
    echo "  # (Uses local FFmpeg from third_party/install - no additional setup needed)"
fi
echo "  ${BUILD_DIR}/examples/apps/ffmpeg-signer/ffmpeg-signer video.mp4"
echo ""
print_info "To run the applications, set the following environment variables:"
echo ""
echo "export LD_LIBRARY_PATH=${BUILD_DIR}:\$LD_LIBRARY_PATH"
if [ "$BUILD_APPS" = true ] || [ "$BUILD_SIGNER" = true ]; then
    echo "export GST_PLUGIN_PATH=${BUILD_DIR}/examples/apps/signer/gst-plugin:\$GST_PLUGIN_PATH"
fi
echo ""

# Optionally install
if [ -n "$INSTALL_PREFIX" ]; then
    print_info "To install to $INSTALL_PREFIX, run:"
    echo "  meson install -C $BUILD_DIR"
fi
