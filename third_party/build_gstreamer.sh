#!/bin/bash

# Script to download and build GStreamer locally
# This builds GStreamer core and gst-plugins-base

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
SRC_DIR="${SCRIPT_DIR}/src/gstreamer"
INSTALL_DIR="${SCRIPT_DIR}/install"

# GStreamer version
# Using 1.18.x for compatibility with Meson 0.48+
# For newer Meson (>= 1.1), you can use 1.24.x
GSTREAMER_VERSION="1.18.6"
GSTREAMER_BASE_URL="https://gstreamer.freedesktop.org/src"

# Components to build
declare -a COMPONENTS=(
    "gstreamer:gstreamer-${GSTREAMER_VERSION}.tar.xz"
    "gst-plugins-base:gst-plugins-base-${GSTREAMER_VERSION}.tar.xz"
    "gst-plugins-good:gst-plugins-good-${GSTREAMER_VERSION}.tar.xz"
    "gst-plugins-bad:gst-plugins-bad-${GSTREAMER_VERSION}.tar.xz"
)

print_info "Building GStreamer ${GSTREAMER_VERSION}..."
print_info "Source directory: ${SRC_DIR}"
print_info "Install directory: ${INSTALL_DIR}"

# Check for required build tools
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

check_dependency meson
check_dependency ninja
check_dependency pkg-config

# Check for required dependencies
print_info "Checking for required dependencies..."
MISSING_DEPS=""

# Check for GLib
if ! pkg-config --exists glib-2.0; then
    print_warning "GLib 2.0 not found. Required for GStreamer."
    MISSING_DEPS="${MISSING_DEPS} libglib2.0-dev"
fi

if [ -n "$MISSING_DEPS" ]; then
    print_error "Missing dependencies:${MISSING_DEPS}"
    print_info "Install with: sudo apt install${MISSING_DEPS}"
    exit 1
fi

# Create directories
mkdir -p "${SRC_DIR}"
mkdir -p "${INSTALL_DIR}"

# Determine number of CPU cores for parallel compilation
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Download and build each component
for COMPONENT in "${COMPONENTS[@]}"; do
    IFS=':' read -r COMP_NAME COMP_FILE <<< "$COMPONENT"
    COMP_DIR="${COMP_NAME}-${GSTREAMER_VERSION}"
    
    print_info "==========================================="
    print_info "Processing: ${COMP_NAME}"
    print_info "==========================================="
    
    # Download if not already downloaded
    if [ ! -f "${SRC_DIR}/${COMP_FILE}" ]; then
        print_info "Downloading ${COMP_NAME}..."
        cd "${SRC_DIR}"
        
        DOWNLOAD_URL="${GSTREAMER_BASE_URL}/${COMP_NAME}/${COMP_FILE}"
        
        if command -v wget &> /dev/null; then
            wget -O "${COMP_FILE}" "${DOWNLOAD_URL}"
        elif command -v curl &> /dev/null; then
            curl -L -o "${COMP_FILE}" "${DOWNLOAD_URL}"
        else
            print_error "Neither wget nor curl found. Please install one of them."
            exit 1
        fi
        
        print_info "Download complete"
    else
        print_info "${COMP_NAME} tarball already downloaded"
    fi
    
    # Extract if not already extracted
    if [ ! -d "${SRC_DIR}/${COMP_DIR}" ]; then
        print_info "Extracting ${COMP_NAME}..."
        cd "${SRC_DIR}"
        tar xf "${COMP_FILE}"
        print_info "Extraction complete"
    else
        print_info "${COMP_NAME} source already extracted"
    fi
    
    # Build
    cd "${SRC_DIR}/${COMP_DIR}"
    
    BUILD_DIR="build"
    
    # Check if already built
    if [ -d "${BUILD_DIR}" ] && [ -f "${BUILD_DIR}/build.ninja" ]; then
        print_info "${COMP_NAME} appears to be already configured"
    else
        print_info "Configuring ${COMP_NAME}..."
        
        # Set PKG_CONFIG_PATH to find previously built components
        export PKG_CONFIG_PATH="${INSTALL_DIR}/lib64/pkgconfig:${INSTALL_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"
        export LD_LIBRARY_PATH="${INSTALL_DIR}/lib64:${INSTALL_DIR}/lib:${LD_LIBRARY_PATH}"
        
        # Component-specific options
        EXTRA_OPTS=""
        INTROSPECTION_OPT=""
        case "${COMP_NAME}" in
            gstreamer|gst-plugins-base)
                # introspection option only available in core gstreamer and base plugins
                INTROSPECTION_OPT="-Dintrospection=disabled"
                ;;
            gst-plugins-good)
                # For gst-plugins-good: disable Qt5 plugin (avoid Qt dependency)
                EXTRA_OPTS="-Dqt5=disabled"
                ;;
            gst-plugins-bad)
                # For gst-plugins-bad: disable X11 and Wayland support to reduce dependencies
                EXTRA_OPTS="-Dwayland=disabled -Dx11=disabled"
                ;;
        esac
        
        # Configure with meson
        # Disable unnecessary features for faster build and fewer dependencies
        meson setup "${BUILD_DIR}" \
            --prefix="${INSTALL_DIR}" \
            --libdir=lib \
            -Dbuildtype=release \
            -Dtests=disabled \
            -Dexamples=disabled \
            -Ddoc=disabled \
            ${INTROSPECTION_OPT} \
            -Dnls=disabled \
            ${EXTRA_OPTS} \
            2>&1 | grep -v "WARNING: Running the setup command" || true
        
        print_info "Configuration complete"
    fi
    
    print_info "Building ${COMP_NAME} using ${NPROC} cores..."
    ninja -C "${BUILD_DIR}" -j${NPROC}
    
    print_info "Installing ${COMP_NAME}..."
    ninja -C "${BUILD_DIR}" install
    
    print_info "${COMP_NAME} installed successfully!"
done

print_info "==========================================="
print_info "GStreamer ${GSTREAMER_VERSION} built and installed successfully!"
print_info "Installation directory: ${INSTALL_DIR}"

# Verify installation (check both lib and lib64)
GSTREAMER_PC_PATH=""
if [ -f "${INSTALL_DIR}/lib64/pkgconfig/gstreamer-1.0.pc" ]; then
    GSTREAMER_PC_PATH="${INSTALL_DIR}/lib64/pkgconfig"
elif [ -f "${INSTALL_DIR}/lib/pkgconfig/gstreamer-1.0.pc" ]; then
    GSTREAMER_PC_PATH="${INSTALL_DIR}/lib/pkgconfig"
fi

if [ -n "${GSTREAMER_PC_PATH}" ]; then
    print_info "Verification: gstreamer-1.0.pc found in ${GSTREAMER_PC_PATH}"
    INSTALLED_VERSION=$(PKG_CONFIG_PATH="${GSTREAMER_PC_PATH}" pkg-config --modversion gstreamer-1.0)
    print_info "Installed GStreamer version: ${INSTALLED_VERSION}"
else
    print_error "Verification failed: gstreamer-1.0.pc not found in lib or lib64"
    exit 1
fi

print_info "Build complete!"
print_info ""
print_info "To use this GStreamer installation, set:"
if [ -d "${INSTALL_DIR}/lib64" ]; then
    print_info "  export PKG_CONFIG_PATH=${INSTALL_DIR}/lib64/pkgconfig:\$PKG_CONFIG_PATH"
    print_info "  export LD_LIBRARY_PATH=${INSTALL_DIR}/lib64:\$LD_LIBRARY_PATH"
else
    print_info "  export PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig:\$PKG_CONFIG_PATH"
    print_info "  export LD_LIBRARY_PATH=${INSTALL_DIR}/lib:\$LD_LIBRARY_PATH"
fi
print_info "  export PATH=${INSTALL_DIR}/bin:\$PATH"
