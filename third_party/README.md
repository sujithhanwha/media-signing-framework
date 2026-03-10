# Third-Party Dependencies

This directory contains scripts for building third-party dependencies locally when they are not available on the system or when specific versions are required.

## Overview

The media-signing-framework can automatically download, compile, and use local installations of its dependencies. This provides:

- **Flexibility**: Build without system package dependencies
- **Version Control**: Use specific versions of dependencies
- **Isolation**: Local builds don't interfere with system packages
- **Portability**: Easier to build on different systems

## Dependencies

### OpenSSL 3.4

**Required**: Yes (version >= 3.0.0)  
**Build Script**: `build_openssl.sh`  
**Default Behavior**: Uses system OpenSSL if version >= 3.0.0, otherwise builds locally

#### Building OpenSSL Locally

To force a local OpenSSL build:

```bash
# Using build.sh
./build.sh --local-openssl -f

# Or manually
cd third_party
./build_openssl.sh
```

#### Directory Structure

After building OpenSSL locally:

```
third_party/
├── src/
│   ├── openssl/          # OpenSSL source code
│   └── openssl-3.4.0.tar.gz
└── install/
    ├── bin/              # OpenSSL executables
    ├── include/          # OpenSSL headers
    ├── lib/              # Shared libraries
    │   └── pkgconfig/    # pkg-config files
    └── ssl/              # SSL configuration
```

#### Configuration Options

The OpenSSL build uses the following configuration:
- **Shared libraries**: Enabled for runtime linking
- **Optimizations**: Default optimizations enabled
- **RPATH**: Set to use local lib directory
- **Tests**: Disabled for faster builds

#### Requirements

To build OpenSSL, you need:
- C compiler (gcc or clang)
- make
- perl (for OpenSSL's Configure script)
- wget or curl (for downloading)

### GStreamer 1.18

**Required**: Only for GStreamer-based signer and validator applications  
**Build Script**: `build_gstreamer.sh`  
**Default Behavior**: Uses system GStreamer if available, otherwise builds locally
**Note**: Using GStreamer 1.18.x for compatibility with older Meson versions (>= 0.48)

#### Building GStreamer Locally

To force a local GStreamer build:

```bash
# Using build.sh
./build.sh --local-gstreamer -a

# Or manually
cd third_party
./build_gstreamer.sh
```

#### What Gets Built

The script builds:
- **GStreamer core**: The main GStreamer framework
- **gst-plugins-base**: Essential plugins including video/audio processing
- **gst-plugins-good**: Good quality plugins including qtdemux (MP4 support)
- **gst-plugins-bad**: Plugins for H.264/H.265 parsing (h264parse, h265parse)

#### Directory Structure

After building GStreamer locally:

```
third_party/
├── src/
│   └── gstreamer/
│       ├── gstreamer-1.18.6/
│       ├── gst-plugins-base-1.18.6/
│       ├── gstreamer-1.18.6.tar.xz
│       └── gst-plugins-base-1.18.6.tar.xz
└── install/
    ├── bin/              # GStreamer tools (gst-launch-1.0, etc.)
    ├── include/          # GStreamer headers
    ├── lib/              # Shared libraries and plugins
    │   ├── pkgconfig/    # pkg-config files
    │   └── gstreamer-1.0/  # Plugin directory
    └── share/            # Data files
```

#### Configuration Options

The GStreamer build uses:
- **Build type**: Release (optimized)
- **Disabled features**: X11, GL, ALSA, examples, tests (for faster builds and fewer dependencies)
- **Only essential plugins**: Video/audio processing, no GUI components

#### Requirements

To build GStreamer, you need:
- C compiler (gcc or clang)
- meson (>= 0.49.0)
- ninja
- pkg-config
- GLib 2.0 development files (`libglib2.0-dev` on Ubuntu/Debian)
- wget or curl (for downloading)

### FFmpeg 6.1

**Required**: Only for FFmpeg-based signer application  
**Build Script**: `build_ffmpeg.sh`  
**Default Behavior**: Uses local FFmpeg by default (automatically built when needed)

#### Building FFmpeg Locally

To manually build FFmpeg:

```bash
# Using build.sh
./build.sh --local-ffmpeg -f

# Or manually
cd third_party
./build_ffmpeg.sh
```

#### What Gets Built

The script builds a minimal FFmpeg with:
- **H.264 and HEVC/H.265 support**: Essential codecs for video signing
- **MP4 container support**: For input/output files
- **No network protocols**: Reduced dependencies
- **Shared libraries only**: For dynamic linking

#### Directory Structure

After building FFmpeg locally:

```
third_party/
├── src/
│   └── ffmpeg/
│       ├── ffmpeg-6.1.1/    # FFmpeg source
│       └── ffmpeg-6.1.1.tar.xz
└── install/
    ├── include/              # FFmpeg headers
    ├── lib/                  # Shared libraries
    │   ├── libavformat.so
    │   ├── libavcodec.so
    │   ├── libavutil.so
    │   └── pkgconfig/        # pkg-config files
    └── share/                # Data files
```

#### Configuration Options

The FFmpeg build uses:
- **Minimal codecs**: Only H.264, HEVC decoders/encoders
- **Minimal muxers/demuxers**: Only MP4, H.264, HEVC formats
- **No programs**: Doesn't build ffmpeg/ffplay/ffprobe executables (only libraries)
- **Shared libraries**: For dynamic linking

#### Requirements

To build FFmpeg, you need:
- C compiler (gcc or clang)
- make
- yasm or nasm (assembly optimizer)
- wget or curl (for downloading)

Install on Ubuntu/Debian:
```bash
sudo apt install build-essential yasm
```

## Usage in build.sh

The main `build.sh` script automatically handles local dependencies:

```bash
# Use system packages (default for OpenSSL and GStreamer)
./build.sh -a --system-openssl --system-gstreamer --system-ffmpeg

# Use local builds
./build.sh -a --local-openssl --local-gstreamer --local-ffmpeg

# Let build.sh decide (recommended)
./build.sh -a  # Uses system packages if available, local if not
```

## Cleaning

To remove all local builds:

```bash
# Clean everything including third-party builds
./build.sh --clean -f

# Or manually
rm -rf third_party/src third_party/install
```

## Troubleshooting

### OpenSSL Build Fails

1. **Check dependencies**: Ensure you have gcc, make, and perl installed
2. **Check disk space**: OpenSSL build requires ~100MB
3. **Check logs**: Build output shows detailed error messages
4. **Manual build**: Try running `./build_openssl.sh` directly for more details

### GStreamer Build Fails

1. **Check dependencies**: Ensure you have meson, ninja, and libglib2.0-dev installed
   ```bash
   sudo apt install meson ninja-build libglib2.0-dev pkg-config
   ```
2. **Check disk space**: GStreamer build requires ~500MB
3. **Check logs**: Build output shows detailed error messages
4. **Manual build**: Try running `./build_gstreamer.sh` directly for more details
5. **GLib not found**: Install GLib development package:
   ```bash
   # Ubuntu/Debian
   sudo apt install libglib2.0-dev
   
   # Fedora/RHEL
   sudo dnf install glib2-devel
   ```

### Version Issues

To check the installed versions:

```bash
# System OpenSSL
openssl version

# Local OpenSSL
./third_party/install/bin/openssl version

# Via pkg-config (system)
pkg-config --modversion openssl
pkg-config --modversion gstreamer-1.0

# Via pkg-config (local)
PKG_CONFIG_PATH=./third_party/install/lib/pkgconfig pkg-config --modversion openssl
PKG_CONFIG_PATH=./third_party/install/lib/pkgconfig pkg-config --modversion gstreamer-1.0
```

### Linking Issues

If you encounter linking issues with local builds:

1. **OpenSSL**:
   - Verify installation: `ls third_party/install/lib/libssl*`
   - Check pkg-config file: `cat third_party/install/lib/pkgconfig/openssl.pc`
   - Set PKG_CONFIG_PATH: `export PKG_CONFIG_PATH=$PWD/third_party/install/lib/pkgconfig:$PKG_CONFIG_PATH`
   - Rebuild: `./build.sh --clean -f --local-openssl`

2. **GStreamer**:
   - Verify installation: `ls third_party/install/lib/libgstreamer*`
   - Check pkg-config file: `cat third_party/install/lib/pkgconfig/gstreamer-1.0.pc`
   - Set PKG_CONFIG_PATH: `export PKG_CONFIG_PATH=$PWD/third_party/install/lib/pkgconfig:$PKG_CONFIG_PATH`
   - Rebuild: `./build.sh --clean -a --local-gstreamer`

3. **lib vs lib64**: On 64-bit systems, libraries may install to `lib64/` instead of `lib/`. The build scripts handle both automatically.

## Environment Variables

When using local builds, the following environment variables are set:

- `PKG_CONFIG_PATH`: Points to local library pkg-config files
- `LD_LIBRARY_PATH`: May need to include `third_party/install/lib` at runtime

## Notes

- Local builds are stored in `third_party/src/` and installed to `third_party/install/`
- The `third_party/` directory is excluded from git (via .gitignore)
- Downloaded tarballs are cached in `third_party/src/` for faster rebuilds
- Build scripts are idempotent - safe to run multiple times
