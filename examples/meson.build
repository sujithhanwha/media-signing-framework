prefix = get_option('prefix')

# Explicitly include media-signing-framework
oms_lib = 'media-signing-framework'
oms_lib_dir = get_option('prefix') / get_option('libdir')

# GStreamer is used by all applications
gst_req = '>= 1.0.0'
api_version = '1.0'
gst_dep = dependency(
  'gstreamer-@0@'.format(api_version),
  version : gst_req,
)

# FFmpeg dependencies (used by ffmpeg-signer application)
ffmpeg_dep = dependency('libavformat', required : false)
avcodec_dep = dependency('libavcodec', required : false)
avutil_dep = dependency('libavutil', required : false)

# Set FFmpeg rpath if using local FFmpeg
ffmpeg_rpath = ''
if get_option('local_ffmpeg')
  ffmpeg_install_dir = meson.source_root() / 'third_party' / 'install'
  ffmpeg_rpath = ffmpeg_install_dir / 'lib'
endif

subdir('apps')
