# Third-party dependencies meson build file
# This handles local builds of third-party dependencies

# Handle local OpenSSL build
local_openssl = get_option('local_openssl')
if local_openssl
  message('Using local OpenSSL build')
  
  # Check if local OpenSSL is built (handle both lib and lib64)
  openssl_install_dir = meson.source_root() / 'third_party' / 'install'
  openssl_pc_file_lib64 = openssl_install_dir / 'lib64' / 'pkgconfig' / 'openssl.pc'
  openssl_pc_file_lib = openssl_install_dir / 'lib' / 'pkgconfig' / 'openssl.pc'
  
  if not fs.is_file(openssl_pc_file_lib64) and not fs.is_file(openssl_pc_file_lib)
    error('Local OpenSSL not found. Please run: ./third_party/build_openssl.sh')
  endif
  
  message('Local OpenSSL installation found at: ' + openssl_install_dir)
endif

# Handle local GStreamer build
local_gstreamer = get_option('local_gstreamer')
if local_gstreamer
  message('Using local GStreamer build')
  
  # Check if local GStreamer is built (handle both lib and lib64)
  gstreamer_install_dir = meson.source_root() / 'third_party' / 'install'
  gstreamer_pc_file_lib64 = gstreamer_install_dir / 'lib64' / 'pkgconfig' / 'gstreamer-1.0.pc'
  gstreamer_pc_file_lib = gstreamer_install_dir / 'lib' / 'pkgconfig' / 'gstreamer-1.0.pc'
  
  if not fs.is_file(gstreamer_pc_file_lib64) and not fs.is_file(gstreamer_pc_file_lib)
    error('Local GStreamer not found. Please run: ./third_party/build_gstreamer.sh')
  endif
  
  message('Local GStreamer installation found at: ' + gstreamer_install_dir)
endif

# Handle local FFmpeg build  
local_ffmpeg = get_option('local_ffmpeg')
if local_ffmpeg
  message('Using local FFmpeg build')
  
  # Check if local FFmpeg is built
  ffmpeg_install_dir = meson.source_root() / 'third_party' / 'install'
  ffmpeg_pc_file = ffmpeg_install_dir / 'lib' / 'pkgconfig' / 'libavformat.pc'
  
  if not fs.is_file(ffmpeg_pc_file)
    # Only error if FFmpeg signer is being built
    if get_option('ffmpeg_signer') or get_option('build_all_apps')
      error('Local FFmpeg not found. Please run: ./third_party/build_ffmpeg.sh')
    endif
  else
    message('Local FFmpeg installation found at: ' + ffmpeg_install_dir)
  endif
endif
