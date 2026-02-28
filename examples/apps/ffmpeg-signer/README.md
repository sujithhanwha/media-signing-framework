*Copyright (c) 2025 ONVIF. All rights reserved.*

# FFmpeg-based Video Signer Application

A standalone video signing application using FFmpeg libraries and the ONVIF Media Signing Framework. This provides an alternative to the GStreamer-based signer.

## Prerequisites

This application requires:
- FFmpeg development libraries:
  - libavformat
  - libavcodec
  - libavutil
- ONVIF Media Signing Framework library

### Installing FFmpeg on Ubuntu/Debian
```bash
sudo apt-get install libavformat-dev libavcodec-dev libavutil-dev
```

### Installing FFmpeg on macOS
```bash
brew install ffmpeg
```

## Description

The FFmpeg-based signer processes video files NAL Unit by NAL Unit, adding cryptographic signatures in SEI (Supplemental Enhancement Information) NAL Units using the ONVIF Media Signing Framework.

**Features:**
- Direct packet-level processing using FFmpeg
- Supports H.264 and H.265 video codecs
- Supports MP4, MKV, and other container formats
- Automatically generates output filename with `signed_` prefix
- Progress reporting for GOP signing

**Output:** 
Input file `video.mp4` becomes `signed_video.mp4`

## Building

### Using the build script
```bash
./build.sh --ffmpeg-signer
```

Or build with all applications:
```bash
./build.sh -a
```

### Using meson directly
```bash
meson setup -Dffmpeg_signer=true . build
meson compile -C build
```

The executable will be located at `build/examples/apps/ffmpeg-signer/ffmpeg-signer`

### Install to custom location
```bash
meson setup --prefix $PWD/install -Dffmpeg_signer=true . build
meson install -C build
```

The executable will be at `install/bin/ffmpeg-signer`

## Usage

### Basic usage (H.264 video)
```bash
./ffmpeg-signer input.mp4
```

### Sign H.265 video
```bash
./ffmpeg-signer -c h265 input.mp4
```

### Full example with test files
```bash
# From the build directory
./examples/apps/ffmpeg-signer/ffmpeg-signer ../../examples/test-files/test_h264.mp4

# Or from installed location
./install/bin/ffmpeg-signer examples/test-files/test_h264.mp4
```

## Command Line Options

```
Usage: ffmpeg-signer [-h] [-c codec] input_file

Options:
  -h, --help    Show help message
  -c codec      Video codec: 'h264' (default) or 'h265'

Arguments:
  input_file    Input video file (MP4, MKV, etc.)

Output:
  signed_<input_file> - Signed video file
```

## Certificates and Keys

The application uses test EC (Elliptic Curve) certificates and keys from the `tests/` directory:
- `tests/ec_signing.key` - Private key for signing
- `tests/ec_cert_chain.pem` - Certificate chain

These test certificates are automatically generated when you build the framework. The application must be run from within the media-signing-framework directory structure to locate these files.

## Differences from GStreamer Signer

| Feature | FFmpeg Signer | GStreamer Signer |
|---------|---------------|------------------|
| Dependencies | FFmpeg libraries | GStreamer + GLib |
| Architecture | Direct packet processing | Plugin-based pipeline |
| Setup complexity | Simple | Requires plugin path setup |
| Performance | Good | Excellent (threaded) |
| Memory usage | Lower | Higher (pipeline overhead) |

## Example Output

```
=== FFmpeg-based ONVIF Media Signer ===
Input:  test.mp4
Output: signed_test.mp4

ONVIF Media Signing initialized successfully
Input file: test.mp4
Video codec: H.264
Resolution: 1920x1080
Output file: signed_test.mp4

Processing video...
GOP 1 signed
GOP 2 signed
GOP 3 signed
...
GOP 280 signed

Signing completed successfully!
Total GOPs signed: 280
Output file: signed_test.mp4
```

## Validation

To validate a signed video, use the validator application:
```bash
./validator -C examples/test-files/ca.pem -c h264 signed_video.mp4
```

## Troubleshooting

### "Failed to read test private key and certificate"
Make sure you're running from within the media-signing-framework directory. The application looks for certificate files in `tests/` relative to the framework root.

Solution:
```bash
cd /path/to/media-signing-framework
./build/examples/apps/ffmpeg-signer/ffmpeg-signer /full/path/to/input.mp4
```

### FFmpeg library version mismatch
If you encounter errors related to FFmpeg libraries, ensure you have compatible versions:
```bash
pkg-config --modversion libavformat libavcodec libavutil
```

Recommended: FFmpeg 4.0 or newer

### "Expected H.264/AVC codec but found different codec"
Verify your input file codec:
```bash
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 input.mp4
```

## Performance Notes

- The FFmpeg signer processes video sequentially
- Large files may take time depending on video bitrate and resolution
- Memory usage is proportional to GOP size
- Typical signing speed: ~50-100 fps on modern CPUs

## Known Limitations

- Currently processes entire file in one pass (no streaming mode)
- All streams are copied to output (audio, subtitles, etc.)
- Requires complete file access (not suitable for live streams)

## Contributing

When modifying this application:
1. Ensure compatibility with FFmpeg 4.0+
2. Test with both H.264 and H.265 videos
3. Verify signed output with the validator
4. Check for memory leaks with valgrind
