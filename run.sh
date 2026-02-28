#!/bin/bash

# ONVIF Media Signing Framework - Application Runner Script
# This script sets up the environment and runs the signing/validation applications

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="${SCRIPT_DIR}/build"

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory not found. Please run ./build.sh first."
    exit 1
fi

# Set environment variables
export LD_LIBRARY_PATH="${BUILD_DIR}:${LD_LIBRARY_PATH}"
export GST_PLUGIN_PATH="${BUILD_DIR}/examples/apps/signer/gst-plugin:${GST_PLUGIN_PATH}"

# Show usage
usage() {
    echo "Usage: $0 <application> [arguments...]"
    echo ""
    echo "Applications:"
    echo "  signer           Run GStreamer-based signer"
    echo "  ffmpeg-signer    Run FFmpeg-based signer"
    echo "  validator        Run validator"
    echo ""
    echo "Examples:"
    echo "  $0 signer -c h264 video.mp4"
    echo "  $0 ffmpeg-signer video.mp4"
    echo "  $0 validator -C ca.pem -c h264 signed_video.mp4"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

APP="$1"
shift

case "$APP" in
    signer)
        APP_PATH="${BUILD_DIR}/examples/apps/signer/signer"
        ;;
    ffmpeg-signer)
        APP_PATH="${BUILD_DIR}/examples/apps/ffmpeg-signer/ffmpeg-signer"
        ;;
    validator)
        APP_PATH="${BUILD_DIR}/examples/apps/validator/validator"
        ;;
    -h|--help)
        usage
        ;;
    *)
        echo "Error: Unknown application '$APP'"
        usage
        ;;
esac

# Check if application exists
if [ ! -f "$APP_PATH" ]; then
    echo "Error: Application not found: $APP_PATH"
    echo "Please build it first with ./build.sh"
    exit 1
fi

# Run the application with provided arguments
exec "$APP_PATH" "$@"
