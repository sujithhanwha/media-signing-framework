ffmpeg_dep = dependency('libavformat', required : false)
avcodec_dep = dependency('libavcodec', required : false)
avutil_dep = dependency('libavutil', required : false)

build_ffmpeg_signer = get_option('ffmpeg_signer') or get_option('build_all_apps')

if build_ffmpeg_signer
  if not ffmpeg_dep.found() or not avcodec_dep.found() or not avutil_dep.found()
    error('FFmpeg libraries (libavformat, libavcodec, libavutil) are required to build ffmpeg-signer')
  endif

  ffmpeg_signer = executable('ffmpeg-signer',
    'main.c',
    include_directories : [ configinc, omssrcinc ],
    build_rpath : oms_lib_dir,
    install_rpath : oms_lib_dir,
    dependencies : [
      ffmpeg_dep,
      avcodec_dep,
      avutil_dep
    ],
    link_with : mediasigningframework,
    install : true
  )
  
  message('Building ffmpeg-signer application')
endif
