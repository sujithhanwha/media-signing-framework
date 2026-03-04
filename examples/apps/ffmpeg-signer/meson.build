build_ffmpeg_signer = get_option('ffmpeg_signer') or get_option('build_all_apps')

if build_ffmpeg_signer
  if not ffmpeg_dep.found() or not avcodec_dep.found() or not avutil_dep.found()
    error('FFmpeg libraries (libavformat, libavcodec, libavutil) are required to build ffmpeg-signer')
  endif

  # Set up rpath for both media-signing-framework and FFmpeg libraries
  ffmpeg_signer_rpath = oms_lib_dir
  if get_option('local_ffmpeg')
    ffmpeg_signer_rpath = ':'.join([oms_lib_dir, ffmpeg_rpath])
  endif

  ffmpeg_signer = executable('ffmpeg-signer',
    'main.c',
    include_directories : [ configinc, omssrcinc ],
    build_rpath : ffmpeg_signer_rpath,
    install_rpath : ffmpeg_signer_rpath,
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
