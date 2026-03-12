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
LOCAL_OPENSSL=false  # Default to using system OpenSSL, fallback to local if not found
LOCAL_GSTREAMER=false  # Default to using system GStreamer, fallback to local if not found

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
    echo "  --local-openssl       Force use of local OpenSSL build"
    echo "  --system-openssl      Force use of system OpenSSL (fail if not found)"
    echo "  --local-gstreamer     Force use of local GStreamer build"
    echo "  --system-gstreamer    Force use of system GStreamer (fail if not found)"
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
        --local-openssl)
            LOCAL_OPENSSL=true
            shift
            ;;
        --system-openssl)
            LOCAL_OPENSSL=false
            shift
            ;;
        --local-gstreamer)
            LOCAL_GSTREAMER=true
            shift
            ;;
        --system-gstreamer)
            LOCAL_GSTREAMER=false
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
OPENSSL_FOUND=false
OPENSSL_VERSION_OK=false

if [ "$LOCAL_OPENSSL" = false ]; then
    if pkg-config --exists openssl; then
        OPENSSL_VERSION=$(pkg-config --modversion openssl)
        print_info "Found system OpenSSL version: $OPENSSL_VERSION"
        
        # Check if version is >= 3.0.0
        if pkg-config --atleast-version=3.0.0 openssl; then
            OPENSSL_FOUND=true
            OPENSSL_VERSION_OK=true
            print_info "System OpenSSL version is sufficient (>= 3.0.0)"
        else
            print_warning "System OpenSSL version is too old (need >= 3.0.0, found $OPENSSL_VERSION)"
            print_info "Will use local OpenSSL 3.4 instead"
            LOCAL_OPENSSL=true
        fi
    else
        print_warning "System OpenSSL not found"
        print_info "Will use local OpenSSL 3.4 instead"
        LOCAL_OPENSSL=true
    fi
fi

# Build or check local OpenSSL if needed
if [ "$LOCAL_OPENSSL" = true ]; then
    # Check for openssl.pc in both lib and lib64
    OPENSSL_PC_FOUND=false
    if [ -f "${SCRIPT_DIR}/third_party/install/lib64/pkgconfig/openssl.pc" ]; then
        OPENSSL_PC_FOUND=true
    elif [ -f "${SCRIPT_DIR}/third_party/install/lib/pkgconfig/openssl.pc" ]; then
        OPENSSL_PC_FOUND=true
    fi
    
    if [ "$OPENSSL_PC_FOUND" = false ]; then
        print_info "Local OpenSSL not found. Building OpenSSL 3.4..."
        bash "${SCRIPT_DIR}/third_party/build_openssl.sh"
        if [ $? -ne 0 ]; then
            print_error "Failed to build OpenSSL."
            exit 1
        fi
    else
        print_info "Using existing local OpenSSL installation."
    fi
    
    # Set PKG_CONFIG_PATH to use local OpenSSL (add both lib and lib64)
    if [ -d "${SCRIPT_DIR}/third_party/install/lib64/pkgconfig" ]; then
        export PKG_CONFIG_PATH="${SCRIPT_DIR}/third_party/install/lib64/pkgconfig:${PKG_CONFIG_PATH}"
    fi
    if [ -d "${SCRIPT_DIR}/third_party/install/lib/pkgconfig" ]; then
        export PKG_CONFIG_PATH="${SCRIPT_DIR}/third_party/install/lib/pkgconfig:${PKG_CONFIG_PATH}"
    fi
    
    # Set LIBRARY_PATH for linking during build
    if [ -d "${SCRIPT_DIR}/third_party/install/lib64" ]; then
        export LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib64:${LIBRARY_PATH}"
        export LD_LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib64:${LD_LIBRARY_PATH}"
    fi
    if [ -d "${SCRIPT_DIR}/third_party/install/lib" ]; then
        export LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib:${LIBRARY_PATH}"
        export LD_LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib:${LD_LIBRARY_PATH}"
    fi
    
    OPENSSL_FOUND=true
    OPENSSL_VERSION_OK=true
fi

if [ "$OPENSSL_FOUND" = false ] || [ "$OPENSSL_VERSION_OK" = false ]; then
    print_error "OpenSSL 3.0.0 or newer is required but not found."
    print_info "Install OpenSSL 3.0+ or use --local-openssl to build it locally."
    exit 1
fi

# Check for GStreamer (only if building GStreamer-based apps)
if [ "$BUILD_APPS" = true ] || [ "$BUILD_SIGNER" = true ] || [ "$BUILD_VALIDATOR" = true ]; then
    GSTREAMER_FOUND=false
    
    if [ "$LOCAL_GSTREAMER" = false ]; then
        if pkg-config --exists gstreamer-1.0; then
            GSTREAMER_VERSION=$(pkg-config --modversion gstreamer-1.0)
            print_info "Found system GStreamer version: $GSTREAMER_VERSION"
            GSTREAMER_FOUND=true
        else
            print_warning "System GStreamer not found"
            print_info "Will use local GStreamer instead"
            LOCAL_GSTREAMER=true
        fi
    fi
    
    # Build or check local GStreamer if needed
    if [ "$LOCAL_GSTREAMER" = true ]; then
        # Check for gstreamer-1.0.pc in both lib and lib64
        GSTREAMER_PC_FOUND=false
        if [ -f "${SCRIPT_DIR}/third_party/install/lib64/pkgconfig/gstreamer-1.0.pc" ]; then
            GSTREAMER_PC_FOUND=true
        elif [ -f "${SCRIPT_DIR}/third_party/install/lib/pkgconfig/gstreamer-1.0.pc" ]; then
            GSTREAMER_PC_FOUND=true
        fi
        
        if [ "$GSTREAMER_PC_FOUND" = false ]; then
            print_info "Local GStreamer not found. Building GStreamer..."
            bash "${SCRIPT_DIR}/third_party/build_gstreamer.sh"
            if [ $? -ne 0 ]; then
                print_error "Failed to build GStreamer."
                exit 1
            fi
        else
            print_info "Using existing local GStreamer installation."
        fi
        
        # Set PKG_CONFIG_PATH to use local GStreamer (add both lib and lib64)
        if [ -d "${SCRIPT_DIR}/third_party/install/lib64/pkgconfig" ]; then
            export PKG_CONFIG_PATH="${SCRIPT_DIR}/third_party/install/lib64/pkgconfig:${PKG_CONFIG_PATH}"
        fi
        if [ -d "${SCRIPT_DIR}/third_party/install/lib/pkgconfig" ]; then
            export PKG_CONFIG_PATH="${SCRIPT_DIR}/third_party/install/lib/pkgconfig:${PKG_CONFIG_PATH}"
        fi
        
        # Set LIBRARY_PATH for linking during build
        if [ -d "${SCRIPT_DIR}/third_party/install/lib64" ]; then
            export LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib64:${LIBRARY_PATH}"
            export LD_LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib64:${LD_LIBRARY_PATH}"
        fi
        if [ -d "${SCRIPT_DIR}/third_party/install/lib" ]; then
            export LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib:${LIBRARY_PATH}"
            export LD_LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib:${LD_LIBRARY_PATH}"
        fi
        
        GSTREAMER_FOUND=true
    fi
    
    if [ "$GSTREAMER_FOUND" = false ]; then
        print_error "GStreamer not found."
        print_info "Install GStreamer or use --local-gstreamer to build it locally."
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
        # Check for libavformat.pc in both lib and lib64
        FFMPEG_PC_FOUND=false
        if [ -f "${SCRIPT_DIR}/third_party/install/lib64/pkgconfig/libavformat.pc" ]; then
            FFMPEG_PC_FOUND=true
        elif [ -f "${SCRIPT_DIR}/third_party/install/lib/pkgconfig/libavformat.pc" ]; then
            FFMPEG_PC_FOUND=true
        fi
        
        if [ "$FFMPEG_PC_FOUND" = false ]; then
            print_info "Local FFmpeg not found. Building FFmpeg..."
            bash "${SCRIPT_DIR}/third_party/build_ffmpeg.sh"
            if [ $? -ne 0 ]; then
                print_error "Failed to build FFmpeg."
                exit 1
            fi
        else
            print_info "Using existing local FFmpeg installation."
        fi
        
        # Set PKG_CONFIG_PATH to use local FFmpeg (add both lib and lib64)
        if [ -d "${SCRIPT_DIR}/third_party/install/lib64/pkgconfig" ]; then
            export PKG_CONFIG_PATH="${SCRIPT_DIR}/third_party/install/lib64/pkgconfig:${PKG_CONFIG_PATH}"
        fi
        if [ -d "${SCRIPT_DIR}/third_party/install/lib/pkgconfig" ]; then
            export PKG_CONFIG_PATH="${SCRIPT_DIR}/third_party/install/lib/pkgconfig:${PKG_CONFIG_PATH}"
        fi
        
        # Set LIBRARY_PATH for linking during build
        if [ -d "${SCRIPT_DIR}/third_party/install/lib64" ]; then
            export LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib64:${LIBRARY_PATH}"
            export LD_LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib64:${LD_LIBRARY_PATH}"
        fi
        if [ -d "${SCRIPT_DIR}/third_party/install/lib" ]; then
            export LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib:${LIBRARY_PATH}"
            export LD_LIBRARY_PATH="${SCRIPT_DIR}/third_party/install/lib:${LD_LIBRARY_PATH}"
        fi
    fi
fi

print_info "All dependencies found."

# Clean if requested
if [ "$CLEAN" = true ]; then
    print_info "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    # Also clean third_party builds if using local builds
    if [ "$LOCAL_FFMPEG" = true ] || [ "$LOCAL_OPENSSL" = true ] || [ "$LOCAL_GSTREAMER" = true ]; then
        print_info "Cleaning local third_party builds..."
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

# Set local_openssl option
if [ "$LOCAL_OPENSSL" = true ]; then
    MESON_OPTS="$MESON_OPTS -Dlocal_openssl=true"
else
    MESON_OPTS="$MESON_OPTS -Dlocal_openssl=false"
fi

# Set local_gstreamer option
if [ "$LOCAL_GSTREAMER" = true ]; then
    MESON_OPTS="$MESON_OPTS -Dlocal_gstreamer=true"
else
    MESON_OPTS="$MESON_OPTS -Dlocal_gstreamer=false"
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
echo "Dependencies used:"
if [ "$LOCAL_OPENSSL" = true ]; then
    echo "  OpenSSL: Local build (third_party/install)"
else
    echo "  OpenSSL: System installation"
fi
if [ "$LOCAL_GSTREAMER" = true ]; then
    echo "  GStreamer: Local build (third_party/install)"
else
    echo "  GStreamer: System installation"
fi
if [ "$LOCAL_FFMPEG" = true ]; then
    echo "  FFmpeg: Local build (third_party/install)"
else
    echo "  FFmpeg: System installation"
fi

echo ""
echo "To run the GStreamer signer:"
# Build LD_LIBRARY_PATH with local libs if needed
LDLIBPATH="${BUILD_DIR}"
if [ "$LOCAL_OPENSSL" = true ] || [ "$LOCAL_GSTREAMER" = true ]; then
    # Determine lib or lib64
    LIB_DIR="lib"
    if [ -d "${SCRIPT_DIR}/third_party/install/lib64" ]; then
        LIB_DIR="lib64"
    fi
    LDLIBPATH="${LDLIBPATH}:${SCRIPT_DIR}/third_party/install/${LIB_DIR}"
fi
echo "  export LD_LIBRARY_PATH=${LDLIBPATH}:\$LD_LIBRARY_PATH"
if [ "$LOCAL_GSTREAMER" = true ]; then
    # Determine lib or lib64 for GST_PLUGIN_PATH
    LIB_DIR="lib"
    if [ -d "${SCRIPT_DIR}/third_party/install/lib64" ]; then
        LIB_DIR="lib64"
    fi
    echo "  export GST_PLUGIN_PATH=${SCRIPT_DIR}/third_party/install/${LIB_DIR}/gstreamer-1.0:${BUILD_DIR}/examples/apps/signer/gst-plugin:\$GST_PLUGIN_PATH"
else
    echo "  export GST_PLUGIN_PATH=${BUILD_DIR}/examples/apps/signer/gst-plugin:\$GST_PLUGIN_PATH"
fi
echo "  ${BUILD_DIR}/examples/apps/signer/signer -c h264 video.mp4"
echo ""
echo "To run the FFmpeg signer:"
# Build LD_LIBRARY_PATH with local libs if needed
LDLIBPATH="${BUILD_DIR}"
if [ "$LOCAL_OPENSSL" = true ] || [ "$LOCAL_FFMPEG" = true ]; then
    # Determine lib or lib64
    LIB_DIR="lib"
    if [ -d "${SCRIPT_DIR}/third_party/install/lib64" ]; then
        LIB_DIR="lib64"
    fi
    LDLIBPATH="${LDLIBPATH}:${SCRIPT_DIR}/third_party/install/${LIB_DIR}"
fi
echo "  export LD_LIBRARY_PATH=${LDLIBPATH}:\$LD_LIBRARY_PATH"
if [ "$LOCAL_FFMPEG" = true ]; then
    echo "  # (Uses local FFmpeg from third_party/install)"
fi
if [ "$LOCAL_OPENSSL" = true ]; then
    echo "  # (Uses local OpenSSL from third_party/install)"
fi
if [ "$LOCAL_GSTREAMER" = true ]; then
    echo "  # (Uses local GStreamer from third_party/install)"
fi
echo "  ${BUILD_DIR}/examples/apps/ffmpeg-signer/ffmpeg-signer video.mp4"
echo ""
print_info "To run the applications, set the following environment variables:"
echo ""
# Build LD_LIBRARY_PATH with local libs if needed
LDLIBPATH="${BUILD_DIR}"
if [ "$LOCAL_OPENSSL" = true ] || [ "$LOCAL_GSTREAMER" = true ] || [ "$LOCAL_FFMPEG" = true ]; then
    # Determine lib or lib64
    LIB_DIR="lib"
    if [ -d "${SCRIPT_DIR}/third_party/install/lib64" ]; then
        LIB_DIR="lib64"
    fi
    LDLIBPATH="${LDLIBPATH}:${SCRIPT_DIR}/third_party/install/${LIB_DIR}"
fi
echo "export LD_LIBRARY_PATH=${LDLIBPATH}:\$LD_LIBRARY_PATH"
if [ "$BUILD_APPS" = true ] || [ "$BUILD_SIGNER" = true ]; then
    if [ "$LOCAL_GSTREAMER" = true ]; then
        # Determine lib or lib64 for GST_PLUGIN_PATH
        LIB_DIR="lib"
        if [ -d "${SCRIPT_DIR}/third_party/install/lib64" ]; then
            LIB_DIR="lib64"
        fi
        echo "export GST_PLUGIN_PATH=${SCRIPT_DIR}/third_party/install/${LIB_DIR}/gstreamer-1.0:${BUILD_DIR}/examples/apps/signer/gst-plugin:\$GST_PLUGIN_PATH"
    else
        echo "export GST_PLUGIN_PATH=${BUILD_DIR}/examples/apps/signer/gst-plugin:\$GST_PLUGIN_PATH"
    fi
fi
echo ""

# Optionally install
if [ -n "$INSTALL_PREFIX" ]; then
    print_info "To install to $INSTALL_PREFIX, run:"
    echo "  meson install -C $BUILD_DIR"
fi
