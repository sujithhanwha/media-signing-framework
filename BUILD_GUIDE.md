# ONVIF Media Signing Framework - Build Guide

This guide provides step-by-step instructions for building the ONVIF Media Signing Framework library and example applications.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
  - [Using the Build Script (Recommended)](#using-the-build-script-recommended)
  - [Manual Build](#manual-build)
  - [Build Script vs Manual Meson](#build-script-vs-manual-meson)
- [Detailed Build Instructions](#detailed-build-instructions)
- [Build Options](#build-options)
- [Local FFmpeg Build](#local-ffmpeg-build)
- [Running the Applications](#running-the-applications)
- [Troubleshooting](#troubleshooting)
- [Building for Production](#building-for-production)
- [Cross-Compilation](#cross-compilation)
- [Quick Reference](#quick-reference)
- [Next Steps](#next-steps)

---

## Prerequisites

### Required Dependencies
- **Meson** (>= 0.49.0) - Build system
- **Ninja** - Build tool
- **OpenSSL** (>= 3.0.0) - Cryptographic operations
- **pkg-config** - Dependency management

### Optional Dependencies (for example applications)
- **GStreamer** (>= 1.20) - Required for GStreamer-based signer and validator applications
  - gstreamer-1.0
  - gstreamer-base-1.0
  - gstreamer-app-1.0
- **FFmpeg** (>= 4.0) - Required for FFmpeg-based signer application
  - libavformat
  - libavcodec
  - libavutil
  - **Note**: FFmpeg can be automatically downloaded and built locally (see [Local FFmpeg Build](#local-ffmpeg-build))
- **libcheck** - For running unit tests
- **GLib 2.0** - For threaded signing plugin

### Installing Dependencies

#### Ubuntu/Debian
```bash
# Required dependencies
sudo apt-get update
sudo apt-get install -y meson ninja-build pkg-config libssl-dev

# Optional dependencies for GStreamer applications
sudo apt-get install -y \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    check \
    libglib2.0-dev

# Optional dependencies for FFmpeg signer
sudo apt-get install -y \
    libavformat-dev \
    libavcodec-dev \
    libavutil-dev
```

#### Fedora/RHEL
```bash
# Required dependencies
sudo dnf install -y meson ninja-build pkg-config openssl-devel

# Optional dependencies for GStreamer applications
sudo dnf install -y \
    gstreamer1-devel \
    gstreamer1-plugins-base-devel \
    check-devel \
    glib2-devel

# Optional dependencies for FFmpeg signer
sudo dnf install -y \
    ffmpeg-devel
```

---

## Quick Start

### Using the Build Script (Recommended)

The easiest way to build the project is using the provided build script:

```bash
# Build library and all applications (with local FFmpeg by default)
./build.sh --all-apps

# Build FFmpeg signer only (with local FFmpeg)
./build.sh --ffmpeg-signer

# Build with system FFmpeg instead
./build.sh --ffmpeg-signer --system-ffmpeg

# Build library only
./build.sh

# Build with debug output
./build.sh --all-apps --debug

# Clean build (also cleans local FFmpeg if using it)
./build.sh --all-apps --clean
```

**Note**: By default, the FFmpeg signer is built with local FFmpeg (automatically downloaded and compiled). Use `--system-ffmpeg` to use system FFmpeg packages instead.

### Manual Build

```bash
# Configure and build library and applications
meson setup -Dbuild_all_apps=true build
ninja -C build
```

### Build Script vs Manual Meson

**When to use `build.sh`:**
- ✅ Quick builds with sensible defaults
- ✅ Automatic dependency checking
- ✅ Automatic local FFmpeg build for ffmpeg-signer
- ✅ Simplified command-line options
- ✅ Better error messages and guidance

**When to use meson directly:**
- Advanced configuration (e.g., `signingplugin=threaded`)
- Cross-compilation
- Integration with other build systems
- Custom build configurations

---

## Detailed Build Instructions

### Step 1: Clone the Repository
```bash
git clone <repository-url>
cd media-signing-framework
```

### Step 2: Configure the Build

Choose one of the following configurations based on your needs:

#### Build Library Only
```bash
meson setup build
```

#### Build Library with Example Applications
```bash
# Build all applications (signer + validator)
meson setup -Dbuild_all_apps=true build

# OR build specific applications
meson setup -Dsigner=true build           # Signer only
meson setup -Dvalidator=true build        # Validator only
```

#### Build with Additional Options
```bash
# Enable debug prints
meson setup -Dbuild_all_apps=true -Ddebugprints=true build

# Use threaded signing plugin
meson setup -Dsigner=true -Dsigningplugin=threaded build

# Set installation prefix
meson setup --prefix=/usr/local -Dbuild_all_apps=true build

# Build FFmpeg signer with local FFmpeg (default)
meson setup -Dffmpeg_signer=true -Dlocal_ffmpeg=true build

# Build FFmpeg signer with system FFmpeg
meson setup -Dffmpeg_signer=true -Dlocal_ffmpeg=false build
```

**Using build.sh (simpler):**
```bash
# Debug prints
./build.sh --all-apps --debug

# FFmpeg signer with local FFmpeg
./build.sh --ffmpeg-signer

# FFmpeg signer with system FFmpeg
./build.sh --ffmpeg-signer --system-ffmpeg

# Custom install prefix
./build.sh --all-apps --prefix /usr/local

# GStreamer signer only
./build.sh --signer

# Validator only
./build.sh --validator
```

### Step 3: Compile
```bash
ninja -C build
```

### Step 4: (Optional) Install
```bash
# Install to configured prefix
meson install -C build

# Or install to custom location
DESTDIR=/opt/media-signing meson install -C build
```

---

## Build Options

The following meson options are available:

### Library Options
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `debugprints` | boolean | false | Enable debug output |
| `signingplugin` | string | unthreaded | Signing plugin: `unthreaded`, `threaded`, or `threaded_unless_check_dep` |

### Application Options
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `signer` | boolean | false | Build GStreamer-based signer application |
| `validator` | boolean | false | Build validator application |
| `ffmpeg_signer` | boolean | false | Build FFmpeg-based signer application |
| `build_all_apps` | boolean | false | Build all applications |
| `parsesei` | boolean | false | Enable SEI parsing and display |
| `local_ffmpeg` | boolean | true | Build and use local FFmpeg instead of system FFmpeg |

### Example Configurations

**Using build.sh (recommended):**
```bash
# Development build with debug output
./build.sh --all-apps --debug

# Production build with GStreamer signer and threaded plugin
./build.sh --signer
# Note: For threaded plugin, use meson directly: meson setup -Dsigner=true -Dsigningplugin=threaded build

# FFmpeg signer only (with local FFmpeg)
./build.sh --ffmpeg-signer

# FFmpeg signer with system FFmpeg
./build.sh --ffmpeg-signer --system-ffmpeg

# Validator only for testing
./build.sh --validator

# Clean rebuild of everything
./build.sh --all-apps --clean
```

**Using meson directly:**
```bash
# Development build with debug output
meson setup -Dbuild_all_apps=true -Ddebugprints=true -Dparsesei=true build

# Production build with threaded plugin and GStreamer signer
meson setup -Dsigner=true -Dsigningplugin=threaded build

# FFmpeg signer only
meson setup -Dffmpeg_signer=true build

# Validator only for testing
meson setup -Dvalidator=true build
```

---

## Local FFmpeg Build

The FFmpeg signer application can automatically download, compile, and use a local FFmpeg installation. This is useful when:
- System FFmpeg packages are missing or incomplete
- You need a specific FFmpeg version
- FFmpeg development headers are not available

### Features
- **Automatic**: FFmpeg is built automatically during project configuration
- **Isolated**: Local FFmpeg doesn't interfere with system FFmpeg
- **Optimized**: Minimal build with only H.264/H.265 support (~5 minute build)
- **Complete**: All required headers including `libavcodec/bsf.h` are present

### Using Local FFmpeg (Default)

```bash
# Method 1: Use the build script (easiest)
./build.sh --ffmpeg-signer

# Method 2: Manual meson configuration
meson setup build -Dffmpeg_signer=true -Dlocal_ffmpeg=true
ninja -C build
```

### Pre-building FFmpeg

You can build FFmpeg separately before running meson:

```bash
cd third_party
./build_ffmpeg.sh
cd ..
meson setup build -Dffmpeg_signer=true
ninja -C build
```

### Using System FFmpeg

If you have FFmpeg development packages installed and prefer to use them:

```bash
# Using build script
./build.sh --ffmpeg-signer --system-ffmpeg

# Or with meson directly
meson setup build -Dffmpeg_signer=true -Dlocal_ffmpeg=false
ninja -C build
```

### Local FFmpeg Details

When `local_ffmpeg=true` (default):
- **Downloads**: FFmpeg 6.1.1 source (~10 MB)
- **Builds**: Minimal configuration with H.264/H.265 only
- **Installs**: To `third_party/install/` directory
- **Links**: Automatically sets proper library paths (rpath)

The FFmpeg build includes:
- H.264 decoder, parser, and bitstream filter
- H.265 (HEVC) decoder, parser, and bitstream filter  
- MP4/MOV demuxer for reading video files
- MP4/MOV muxer for writing signed video files
- Shared libraries only

For more details, see [third_party/README.md](third_party/README.md).

---

## Running the Applications

### Set Environment Variables

Before running the applications, set the required environment variables:

```bash
# Add library to library path (required for all applications)
export LD_LIBRARY_PATH=/path/to/media-signing-framework/build:$LD_LIBRARY_PATH

# Add GStreamer plugin path (required for GStreamer signer only)
export GST_PLUGIN_PATH=/path/to/media-signing-framework/build/examples/apps/signer/gst-plugin:$GST_PLUGIN_PATH
```

Or use absolute paths:

```bash
export LD_LIBRARY_PATH=/home/user/media-signing-framework/build:$LD_LIBRARY_PATH
export GST_PLUGIN_PATH=/home/user/media-signing-framework/build/examples/apps/signer/gst-plugin:$GST_PLUGIN_PATH
```

### Run the GStreamer Signer

Sign a video file (MP4 or MKV container):

```bash
cd build/examples/apps/signer

# Sign H.264 video
./signer -c h264 input_video.mp4

# Sign H.265 video
./signer -c h265 input_video.mp4
```

The signed output will be created as `signed_input_video.mp4` in the same directory.

### Run the FFmpeg Signer

The FFmpeg signer is simpler and doesn't require GST_PLUGIN_PATH:

```bash
cd build/examples/apps/ffmpeg-signer

# Sign H.264 video
./ffmpeg-signer input_video.mp4

# Sign H.265 video
./ffmpeg-signer -c h265 input_video.mp4
```

**Note**: 
- Both signers require test certificates in `tests/` directory:
  - `ec_signing.key` - Private key
  - `ec_cert_chain.pem` - Certificate chain
- If built with `local_ffmpeg=true` (default), the FFmpeg signer automatically uses the locally built FFmpeg libraries - no additional setup needed!

### Run the Validator

Validate a signed video:

```bash
cd build/examples/apps/validator

# Validate with trusted CA certificate
./validator -C /path/to/ca.pem -c h264 signed_video.mp4

# Validate in batch mode
./validator -b -C /path/to/ca.pem -c h264 signed_video.mp4

# Validate without CA certificate (signatures only)
./validator -c h264 signed_video.mp4
```

Validation results are printed to console and saved to `validation_results.txt`.

### Test Files

The repository includes test files in `examples/test-files/`:
- `test_h264.mp4` - Unsigned H.264 video
- `test_h265.mp4` - Unsigned H.265 video
- `test_signed_h264.mp4` - Pre-signed H.264 video
- `test_signed_h265.mp4` - Pre-signed H.265 video
- `ca.pem` - Trusted CA certificate for test files

Example workflow:
```bash
# Sign a test video
./build/examples/apps/signer/signer -c h264 examples/test-files/test_h264.mp4

# Validate the signed video
./build/examples/apps/validator/validator -C examples/test-files/ca.pem -c h264 \
    examples/test-files/signed_test_h264.mp4
```

---

## Troubleshooting

### Common Issues

#### 1. GStreamer Plugin Not Found
```
ERROR: The gstsigning element could not be found
```

**Solution**: Set the `GST_PLUGIN_PATH` environment variable:
```bash
export GST_PLUGIN_PATH=/path/to/build/examples/apps/signer/gst-plugin:$GST_PLUGIN_PATH
```

#### 2. Library Not Found
```
error while loading shared libraries: libmedia-signing-framework.so
```

**Solution**: Set the `LD_LIBRARY_PATH`:
```bash
export LD_LIBRARY_PATH=/path/to/build:$LD_LIBRARY_PATH
```

#### 3. OpenSSL Version Mismatch
```
ERROR: Problem encountered: OpenSSL version 3.0.0 or newer is required
```

**Solution**: Install OpenSSL 3.x or build from source:
```bash
# Check current version
openssl version

# Install newer version (Ubuntu 22.04+)
sudo apt-get install libssl3 libssl-dev
```

#### 4. Meson Version Too Old
```
ERROR: Meson version is X.Y.Z but project requires >= 0.49.0
```

**Solution**: Install newer meson via pip:
```bash
pip3 install --user meson --upgrade
```

#### 5. Certificate Files Not Found (Signer)
```
failed to read key and certificate files
```

**Solution**: Ensure you're running from the correct directory or generate test certificates:
```bash
cd tests/
./generate-cert.sh
```

#### 6. Compilation Error: `warn_unused_result`
```
error: ignoring return value of 'fread' declared with attribute 'warn_unused_result'
```

**Solution**: This has been fixed in the source. If you encounter this, check that you have the latest code or apply the fix in `examples/apps/validator/main.c`.

#### 7. Failed to Link Demux and Parser
```
Failed to link demux and parser
```

**Note**: This is a warning and doesn't prevent signing from working. The signing process will continue and complete successfully.

#### 8. FFmpeg Headers Not Found
```
fatal error: libavcodec/bsf.h: No such file or directory
```

**Solution**: Use local FFmpeg build (default):
```bash
# Clean rebuild with local FFmpeg
./build.sh --ffmpeg-signer --clean
```

Or install complete FFmpeg development packages:
```bash
# Ubuntu/Debian
sudo apt-get install libavformat-dev libavcodec-dev libavutil-dev

# Then build with system FFmpeg
./build.sh --ffmpeg-signer --system-ffmpeg
```

#### 9. FFmpeg Build Fails (nasm/yasm warning)
```
nasm/yasm not found or too old
```

**Solution**: This is just a warning. The build continues without x86 assembly optimizations. If you want to install nasm:
```bash
sudo apt-get install nasm
```

### Verify Installation

```bash
# Check library
ls -la build/libmedia-signing-framework.so*

# Check signer
ls -la build/examples/apps/signer/signer

# Check FFmpeg signer
ls -la build/examples/apps/ffmpeg-signer/ffmpeg-signer

# Check validator
ls -la build/examples/apps/validator/validator

# Verify GStreamer plugin
GST_PLUGIN_PATH=build/examples/apps/signer/gst-plugin gst-inspect-1.0 signing

# Verify FFmpeg signer uses local FFmpeg (if built with local_ffmpeg=true)
ldd build/examples/apps/ffmpeg-signer/ffmpeg-signer | grep -E "(avcodec|avformat|avutil)"
# Should show paths to third_party/install/lib/
```

### Getting Help

If you encounter issues not covered here:
1. Check the main [README.md](README.md)
2. Review application-specific READMEs:
   - [Signer README](examples/apps/signer/README.md)
   - [Validator README](examples/apps/validator/README.md)
   - [FFmpeg Signer README](examples/apps/ffmpeg-signer/README.md)
3. Check GitHub Issues
4. Enable debug output: 
   - With build.sh: `./build.sh --all-apps --debug`
   - With meson: `-Ddebugprints=true`
5. Check the [third_party/README.md](third_party/README.md) for FFmpeg build issues

---

## Building for Production

For production deployments:

1. **Build with optimizations** (default):
   ```bash
   # Using build.sh
   ./build.sh --all-apps
   
   # Or with meson
   meson setup --buildtype=release build
   ninja -C build
   ```

2. **Install to system**:
   ```bash
   # Using build.sh with install prefix
   ./build.sh --all-apps --prefix /usr
   meson install -C build
   
   # Or with meson directly
   meson setup --prefix=/usr --buildtype=release build
   ninja -C build
   sudo meson install -C build
   ```

3. **Update library cache**:
   ```bash
   sudo ldconfig
   ```

4. **Verify installation**:
   ```bash
   pkg-config --modversion media-signing-framework
   ```

---

## Cross-Compilation

For cross-compilation (e.g., for ARM devices):

```bash
# Create a cross-file (arm-cross.ini)
cat > arm-cross.ini << EOF
[binaries]
c = 'arm-linux-gnueabihf-gcc'
cpp = 'arm-linux-gnueabihf-g++'
ar = 'arm-linux-gnueabihf-ar'
strip = 'arm-linux-gnueabihf-strip'
pkg-config = 'arm-linux-gnueabihf-pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'armv7l'
endian = 'little'
EOF

# Configure with cross-file
meson setup --cross-file arm-cross.ini build-arm
ninja -C build-arm
```

---

## Quick Reference

### Common Build Commands

```bash
# Most common: Build FFmpeg signer with local FFmpeg
./build.sh --ffmpeg-signer

# Build everything
./build.sh --all-apps

# Build with system FFmpeg
./build.sh --ffmpeg-signer --system-ffmpeg

# Clean rebuild
./build.sh --ffmpeg-signer --clean

# Build for production
./build.sh --all-apps --prefix /usr/local

# Just the library
./build.sh

# GStreamer signer only
./build.sh --signer

# Validator only
./build.sh --validator
```

### Checking Your Build

```bash
# Verify library
ls -la build/libmedia-signing-framework.so*

# Verify FFmpeg signer
ls -la build/examples/apps/ffmpeg-signer/ffmpeg-signer

# Check FFmpeg linkage (should show third_party/install/lib)
ldd build/examples/apps/ffmpeg-signer/ffmpeg-signer | grep av

# Run FFmpeg signer
export LD_LIBRARY_PATH=build:$LD_LIBRARY_PATH
./build/examples/apps/ffmpeg-signer/ffmpeg-signer video.mp4
```

### Troubleshooting Quick Fixes

```bash
# Missing FFmpeg headers
./build.sh --ffmpeg-signer --clean

# Reconfigure build
rm -rf build && ./build.sh --ffmpeg-signer

# Use system FFmpeg instead
./build.sh --ffmpeg-signer --system-ffmpeg

# Check build options
./build.sh --help
```

---

## Next Steps

- Read the [ONVIF Media Signing Specification](https://www.onvif.org/specs/stream/ONVIF-MediaSigning-Spec.pdf)
- Explore the [API documentation](lib/README.md)
- Review example code in `examples/`
- Run unit tests (if built with libcheck)

---

*Last updated: March 2026*
