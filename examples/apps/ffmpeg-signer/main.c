/**
 * MIT License
 *
 * Copyright (c) 2025 ONVIF. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice (including the next paragraph)
 * shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 * CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
 * THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/**
 * FFmpeg-based video signer application.
 *
 * This application signs H.264/H.265 video files using FFmpeg libraries and the
 * ONVIF Media Signing Framework. The output file name is the input file name
 * prepended with 'signed_'.
 *
 * Example usage:
 *   $ ./ffmpeg-signer input.mp4
 *   $ ./ffmpeg-signer -c h265 input.mp4
 */

#include <libavcodec/avcodec.h>
#include <libavcodec/bsf.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "includes/onvif_media_signing_common.h"
#include "includes/onvif_media_signing_helpers.h"
#include "includes/onvif_media_signing_signer.h"

#define MAX_PATH 512
#define NALU_START_CODE_SIZE 4

typedef struct {
  char *private_key;
  size_t private_key_size;
  char *certificate_chain;
  size_t certificate_chain_size;
  onvif_media_signing_t *oms;
  AVFormatContext *input_ctx;
  AVFormatContext *output_ctx;
  AVCodecContext *decoder_ctx;
  AVCodecContext *encoder_ctx;
  AVBSFContext *bsf_ctx;
  int video_stream_index;
  bool is_h265;
  int gop_counter;
} SigningContext;

static void print_usage(const char *program_name) {
  printf("Usage: %s [-h] [-c codec] input_file\n\n", program_name);
  printf("Options:\n");
  printf("  -h, --help    Show this help message\n");
  printf("  -c codec      Video codec: 'h264' (default) or 'h265'\n\n");
  printf("Arguments:\n");
  printf("  input_file    Input video file (MP4, MKV, etc.)\n\n");
  printf("Output:\n");
  printf("  signed_<input_file> - Signed video file\n");
}

static bool init_signing_context(SigningContext *ctx, bool is_h265) {
  MediaSigningCodec codec = is_h265 ? OMS_CODEC_H265 : OMS_CODEC_H264;
  
  ctx->oms = onvif_media_signing_create(codec);
  if (!ctx->oms) {
    fprintf(stderr, "Failed to create ONVIF Media Signing object\n");
    return false;
  }

  // Read test EC key and certificate
  if (!oms_read_test_private_key_and_certificate(
          true, &ctx->private_key, &ctx->private_key_size,
          &ctx->certificate_chain, &ctx->certificate_chain_size)) {
    fprintf(stderr, "Failed to read test private key and certificate\n");
    fprintf(stderr, "Make sure you're running from within the media-signing-framework directory\n");
    return false;
  }

  // Set signing key pair
  if (onvif_media_signing_set_signing_key_pair(
          ctx->oms, ctx->private_key, ctx->private_key_size,
          ctx->certificate_chain, ctx->certificate_chain_size, false) != OMS_OK) {
    fprintf(stderr, "Failed to set signing key pair\n");
    return false;
  }

  // Set vendor info
  onvif_media_signing_vendor_info_t vendor_info = {0};
  snprintf(vendor_info.firmware_version, sizeof(vendor_info.firmware_version),
           "%s", onvif_media_signing_get_version());
  snprintf(vendor_info.serial_number, sizeof(vendor_info.serial_number), "N/A");
  snprintf(vendor_info.manufacturer, sizeof(vendor_info.manufacturer),
           "FFmpeg Media Signing");

  if (onvif_media_signing_set_vendor_info(ctx->oms, &vendor_info) != OMS_OK) {
    fprintf(stderr, "Failed to set vendor info\n");
    return false;
  }

  ctx->gop_counter = 0;
  printf("ONVIF Media Signing initialized successfully\n");
  return true;
}

// Helper function to find the next start code in Annex B format
// Returns the position of the start code, or -1 if not found
static int find_next_start_code(const uint8_t *data, int start_pos, int data_size) {
  for (int i = start_pos; i <= data_size - 4; i++) {
    // Check for 4-byte start code: 0x00 0x00 0x00 0x01
    if (data[i] == 0x00 && data[i+1] == 0x00 && data[i+2] == 0x00 && data[i+3] == 0x01) {
      return i;
    }
    // Check for 3-byte start code: 0x00 0x00 0x01
    if (data[i] == 0x00 && data[i+1] == 0x00 && data[i+2] == 0x01) {
      return i;
    }
  }
  return -1;
}

// Helper function to add all NALUs from an Annex B packet
static bool add_annexb_nalus_for_signing(SigningContext *ctx, const uint8_t *data, int data_size, int64_t timestamp) {
  int pos = 0;
  int nalus_added = 0;
  MediaSigningReturnCode rc;
  
  while (pos < data_size) {
    // Find current start code
    int current_start = find_next_start_code(data, pos, data_size);
    if (current_start == -1) {
      break;
    }
    
    // Determine start code length (3 or 4 bytes)
    int start_code_len = (data[current_start + 2] == 0x01) ? 3 : 4;
    
    // Find next start code
    int next_start = find_next_start_code(data, current_start + start_code_len, data_size);
    
    // Calculate NALU size (including start code)
    int nalu_size;
    if (next_start == -1) {
      // This is the last NALU
      nalu_size = data_size - current_start;
    } else {
      nalu_size = next_start - current_start;
    }
    
    // Add NALU to signing (including the start code)
    rc = onvif_media_signing_add_nalu_for_signing(
        ctx->oms, data + current_start, nalu_size, timestamp);
    
    if (rc != OMS_OK) {
      fprintf(stderr, "Error adding NALU: %d\n", rc);
      return false;
    }
    
    nalus_added++;
    
    // Move to next NALU
    pos = current_start + nalu_size;
  }
  
  return true;
}

static void cleanup_signing_context(SigningContext *ctx) {
  if (ctx->oms) {
    onvif_media_signing_free(ctx->oms);
  }
  free(ctx->private_key);
  free(ctx->certificate_chain);
  if (ctx->input_ctx) {
    avformat_close_input(&ctx->input_ctx);
  }
  if (ctx->output_ctx) {
    if (ctx->output_ctx->pb) {
      avio_closep(&ctx->output_ctx->pb);
    }
    avformat_free_context(ctx->output_ctx);
  }
  if (ctx->decoder_ctx) {
    avcodec_free_context(&ctx->decoder_ctx);
  }
  if (ctx->encoder_ctx) {
    avcodec_free_context(&ctx->encoder_ctx);
  }
  if (ctx->bsf_ctx) {
    av_bsf_free(&ctx->bsf_ctx);
  }
}

static bool open_input_file(SigningContext *ctx, const char *filename) {
  int ret = avformat_open_input(&ctx->input_ctx, filename, NULL, NULL);
  if (ret < 0) {
    char errbuf[AV_ERROR_MAX_STRING_SIZE];
    av_strerror(ret, errbuf, sizeof(errbuf));
    fprintf(stderr, "Could not open input file '%s': %s\n", filename, errbuf);
    return false;
  }

  ret = avformat_find_stream_info(ctx->input_ctx, NULL);
  if (ret < 0) {
    fprintf(stderr, "Could not find stream information\n");
    return false;
  }

  // Find video stream
  ctx->video_stream_index = -1;
  for (unsigned int i = 0; i < ctx->input_ctx->nb_streams; i++) {
    if (ctx->input_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
      ctx->video_stream_index = i;
      break;
    }
  }

  if (ctx->video_stream_index == -1) {
    fprintf(stderr, "Could not find video stream\n");
    return false;
  }

  AVCodecParameters *codecpar = ctx->input_ctx->streams[ctx->video_stream_index]->codecpar;
  
  // Check codec type
  if (ctx->is_h265 && codecpar->codec_id != AV_CODEC_ID_HEVC) {
    fprintf(stderr, "Expected H.265/HEVC codec but found different codec\n");
    return false;
  } else if (!ctx->is_h265 && codecpar->codec_id != AV_CODEC_ID_H264) {
    fprintf(stderr, "Expected H.264/AVC codec but found different codec\n");
    return false;
  }

  printf("Input file: %s\n", filename);
  printf("Video codec: %s\n", ctx->is_h265 ? "H.265" : "H.264");
  printf("Resolution: %dx%d\n", codecpar->width, codecpar->height);
  
  // Initialize bitstream filter to convert AVCC/HVCC to Annex B format
  const char *bsf_name = ctx->is_h265 ? "hevc_mp4toannexb" : "h264_mp4toannexb";
  const AVBitStreamFilter *bsf = av_bsf_get_by_name(bsf_name);
  if (!bsf) {
    fprintf(stderr, "Could not find bitstream filter '%s'\n", bsf_name);
    return false;
  }
  
  ret = av_bsf_alloc(bsf, &ctx->bsf_ctx);
  if (ret < 0) {
    fprintf(stderr, "Could not allocate bitstream filter context\n");
    return false;
  }
  
  ret = avcodec_parameters_copy(ctx->bsf_ctx->par_in, codecpar);
  if (ret < 0) {
    fprintf(stderr, "Could not copy codec parameters to bitstream filter\n");
    return false;
  }
  
  ret = av_bsf_init(ctx->bsf_ctx);
  if (ret < 0) {
    fprintf(stderr, "Could not initialize bitstream filter\n");
    return false;
  }
  
  printf("Bitstream filter '%s' initialized\n", bsf_name);
  
  return true;
}

static bool setup_output_file(SigningContext *ctx, const char *output_filename) {
  int ret = avformat_alloc_output_context2(&ctx->output_ctx, NULL, NULL, output_filename);
  if (ret < 0) {
    fprintf(stderr, "Could not create output context\n");
    return false;
  }

  // Copy streams from input to output
  for (unsigned int i = 0; i < ctx->input_ctx->nb_streams; i++) {
    AVStream *in_stream = ctx->input_ctx->streams[i];
    AVStream *out_stream = avformat_new_stream(ctx->output_ctx, NULL);
    if (!out_stream) {
      fprintf(stderr, "Failed to allocate output stream\n");
      return false;
    }

    ret = avcodec_parameters_copy(out_stream->codecpar, in_stream->codecpar);
    if (ret < 0) {
      fprintf(stderr, "Failed to copy codec parameters\n");
      return false;
    }
    out_stream->codecpar->codec_tag = 0;
    out_stream->time_base = in_stream->time_base;
  }

  // Open output file
  if (!(ctx->output_ctx->oformat->flags & AVFMT_NOFILE)) {
    ret = avio_open(&ctx->output_ctx->pb, output_filename, AVIO_FLAG_WRITE);
    if (ret < 0) {
      fprintf(stderr, "Could not open output file '%s'\n", output_filename);
      return false;
    }
  }

  ret = avformat_write_header(ctx->output_ctx, NULL);
  if (ret < 0) {
    fprintf(stderr, "Error writing output file header\n");
    return false;
  }

  printf("Output file: %s\n", output_filename);
  return true;
}

static bool process_packet(SigningContext *ctx, AVPacket *pkt) {
  if (pkt->stream_index != ctx->video_stream_index) {
    // Non-video packet, write as-is
    AVStream *in_stream = ctx->input_ctx->streams[pkt->stream_index];
    AVStream *out_stream = ctx->output_ctx->streams[pkt->stream_index];
    
    av_packet_rescale_ts(pkt, in_stream->time_base, out_stream->time_base);
    pkt->pos = -1;
    
    int ret = av_interleaved_write_frame(ctx->output_ctx, pkt);
    if (ret < 0) {
      fprintf(stderr, "Error writing packet\n");
      return false;
    }
    return true;
  }

  // Video packet - first check for SEIs to insert
  uint8_t *sei = NULL;
  size_t sei_size = 0;
  unsigned payload_offset = 0;
  unsigned num_pending = 0;
  
  // Collect all pending SEIs
  size_t total_sei_size = 0;
  uint8_t *all_seis = NULL;
  
  // Get any pending SEIs (pass NULL for peek_nalu to handle SEI insertion ourselves)
  MediaSigningReturnCode rc = onvif_media_signing_get_sei(
      ctx->oms, &sei, &sei_size, &payload_offset, NULL, 0, &num_pending);
  
  while (rc == OMS_OK && sei_size > 0) {
    // Convert SEI from Annex B to AVCC format: skip start code, write length prefix
    if (sei_size < 4 || sei[0] != 0x00 || sei[1] != 0x00 || sei[2] != 0x00 || sei[3] != 0x01) {
      fprintf(stderr, "SEI does not have expected Annex B start code\n");
      free(all_seis);
      return false;
    }
    
    uint32_t nalu_length = sei_size - 4;
    
    // Reallocate buffer to hold all SEIs
    uint8_t *new_buffer = realloc(all_seis, total_sei_size + 4 + nalu_length);
    if (!new_buffer) {
      fprintf(stderr, "Failed to allocate SEI buffer\n");
      free(all_seis);
      return false;
    }
    all_seis = new_buffer;
    
    // Write length prefix (big-endian)
    all_seis[total_sei_size + 0] = (nalu_length >> 24) & 0xFF;
    all_seis[total_sei_size + 1] = (nalu_length >> 16) & 0xFF;
    all_seis[total_sei_size + 2] = (nalu_length >> 8) & 0xFF;
    all_seis[total_sei_size + 3] = nalu_length & 0xFF;
    
    // Copy NALU data (skip start code from source)
    memcpy(all_seis + total_sei_size + 4, sei + 4, nalu_length);
    
    total_sei_size += 4 + nalu_length;
    
    // Track GOP signing
    ctx->gop_counter++;
    if (ctx->gop_counter % 50 == 0) {
      printf("GOP %d signed\n", ctx->gop_counter);
    }
    
    // Get next SEI
    rc = onvif_media_signing_get_sei(
        ctx->oms, &sei, &sei_size, &payload_offset, NULL, 0, &num_pending);
  }
  
  // Add NALU to signing session
  // Calculate timestamp in 100ns units (Windows FILETIME format)
  int64_t timestamp_100nsec = 0;
  if (pkt->pts != AV_NOPTS_VALUE) {
    AVStream *stream = ctx->input_ctx->streams[pkt->stream_index];
    // Convert PTS to 100ns units: pts * timebase * 10000000
    timestamp_100nsec = (pkt->pts * stream->time_base.num * 10000000) / stream->time_base.den;
    // Add offset from Unix epoch (1970) to Windows epoch (1601)
    // 11644473600 seconds * 10000000 = 116444736000000000
    timestamp_100nsec += 116444736000000000LL;
  }
  
  // Make a reference to the packet for BSF (BSF takes ownership of buffers)
  AVPacket *bsf_pkt = av_packet_alloc();
  if (!bsf_pkt) {
    fprintf(stderr, "Failed to allocate BSF packet\n");
    return false;
  }
  
  int ret = av_packet_ref(bsf_pkt, pkt);
  if (ret < 0) {
    fprintf(stderr, "Failed to reference packet for BSF\n");
    av_packet_free(&bsf_pkt);
    return false;
  }
  
  // Filter packet through bitstream filter to convert to Annex B format
  ret = av_bsf_send_packet(ctx->bsf_ctx, bsf_pkt);
  av_packet_free(&bsf_pkt);  // Free the packet struct (BSF kept the buffer refs)
  
  if (ret < 0) {
    fprintf(stderr, "Error sending packet to bitstream filter\n");
    return false;
  }
  
  // Process all filtered packets
  while (true) {
    AVPacket *filtered_pkt = av_packet_alloc();
    if (!filtered_pkt) {
      fprintf(stderr, "Failed to allocate filtered packet\n");
      return false;
    }
    
    ret = av_bsf_receive_packet(ctx->bsf_ctx, filtered_pkt);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
      av_packet_free(&filtered_pkt);
      break;
    } else if (ret < 0) {
      fprintf(stderr, "Error receiving packet from bitstream filter\n");
      av_packet_free(&filtered_pkt);
      return false;
    }
    
    // Parse and add all NALUs from the Annex B packet
    if (!add_annexb_nalus_for_signing(ctx, filtered_pkt->data, filtered_pkt->size, timestamp_100nsec)) {
      av_packet_free(&filtered_pkt);
      return false;
    }
    
    av_packet_free(&filtered_pkt);
  }
  
  // Write the video packet, prepending any collected SEIs
  AVStream *in_stream = ctx->input_ctx->streams[pkt->stream_index];
  AVStream *out_stream = ctx->output_ctx->streams[pkt->stream_index];
  
  av_packet_rescale_ts(pkt, in_stream->time_base, out_stream->time_base);
  pkt->pos = -1;
  
  int write_ret;
  
  // If we have SEI data, prepend it to the video packet
  if (total_sei_size > 0) {
    // Create a new packet with SEI + video data
    AVPacket *combined_pkt = av_packet_alloc();
    if (!combined_pkt) {
      fprintf(stderr, "Failed to allocate combined packet\n");
      free(all_seis);
      return false;
    }
    
    av_new_packet(combined_pkt, total_sei_size + pkt->size);
    
    // Copy SEI data first
    memcpy(combined_pkt->data, all_seis, total_sei_size);
    
    // Then copy video packet data
    memcpy(combined_pkt->data + total_sei_size, pkt->data, pkt->size);
    
    // Copy packet properties
    combined_pkt->stream_index = pkt->stream_index;
    combined_pkt->pts = pkt->pts;
    combined_pkt->dts = pkt->dts;
    combined_pkt->flags = pkt->flags;
    combined_pkt->duration = pkt->duration;
    combined_pkt->pos = -1;
    
    write_ret = av_interleaved_write_frame(ctx->output_ctx, combined_pkt);
    av_packet_free(&combined_pkt);
    free(all_seis);
  } else {
    write_ret = av_interleaved_write_frame(ctx->output_ctx, pkt);
  }
  
  if (write_ret < 0) {
    fprintf(stderr, "Error writing packet\n");
    return false;
  }
  
  return true;
}

static char *generate_output_filename(const char *input_filename) {
  char *output = malloc(MAX_PATH);
  if (!output) {
    return NULL;
  }

  // Find the last directory separator
  const char *basename = strrchr(input_filename, '/');
  if (!basename) {
    basename = strrchr(input_filename, '\\');
  }

  if (basename) {
    // Copy directory path
    size_t dir_len = basename - input_filename + 1;
    strncpy(output, input_filename, dir_len);
    output[dir_len] = '\0';
    strcat(output, "signed_");
    strcat(output, basename + 1);
  } else {
    // No directory in path
    strcpy(output, "signed_");
    strcat(output, input_filename);
  }

  return output;
}

int main(int argc, char *argv[]) {
  if (argc < 2) {
    print_usage(argv[0]);
    return 1;
  }

  const char *input_filename = NULL;
  bool is_h265 = false;

  // Parse command line arguments
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
      print_usage(argv[0]);
      return 0;
    } else if (strcmp(argv[i], "-c") == 0) {
      if (i + 1 >= argc) {
        fprintf(stderr, "Error: -c requires codec argument\n");
        print_usage(argv[0]);
        return 1;
      }
      i++;
      if (strcmp(argv[i], "h265") == 0 || strcmp(argv[i], "hevc") == 0) {
        is_h265 = true;
      } else if (strcmp(argv[i], "h264") == 0 || strcmp(argv[i], "avc") == 0) {
        is_h265 = false;
      } else {
        fprintf(stderr, "Error: Unknown codec '%s'\n", argv[i]);
        return 1;
      }
    } else if (argv[i][0] == '-') {
      fprintf(stderr, "Error: Unknown option '%s'\n", argv[i]);
      print_usage(argv[0]);
      return 1;
    } else {
      if (input_filename) {
        fprintf(stderr, "Error: Multiple input files specified\n");
        return 1;
      }
      input_filename = argv[i];
    }
  }

  if (!input_filename) {
    fprintf(stderr, "Error: No input file specified\n");
    print_usage(argv[0]);
    return 1;
  }

  char *output_filename = generate_output_filename(input_filename);
  if (!output_filename) {
    fprintf(stderr, "Error: Failed to generate output filename\n");
    return 1;
  }

  printf("\n=== FFmpeg-based ONVIF Media Signer ===\n");
  printf("Input:  %s\n", input_filename);
  printf("Output: %s\n\n", output_filename);

  SigningContext ctx = {0};
  ctx.is_h265 = is_h265;
  int exit_code = 1;

  // Initialize FFmpeg
  av_log_set_level(AV_LOG_WARNING);

  // Initialize signing context
  if (!init_signing_context(&ctx, is_h265)) {
    goto cleanup;
  }

  // Open input file
  if (!open_input_file(&ctx, input_filename)) {
    goto cleanup;
  }

  // Setup output file
  if (!setup_output_file(&ctx, output_filename)) {
    goto cleanup;
  }

  printf("\nProcessing video...\n");

  // Process all packets
  AVPacket *pkt = av_packet_alloc();
  if (!pkt) {
    fprintf(stderr, "Failed to allocate packet\n");
    goto cleanup;
  }

  while (av_read_frame(ctx.input_ctx, pkt) >= 0) {
    if (!process_packet(&ctx, pkt)) {
      av_packet_unref(pkt);
      av_packet_free(&pkt);
      goto cleanup;
    }
    av_packet_unref(pkt);
  }

  av_packet_free(&pkt);

  // Write trailer
  av_write_trailer(ctx.output_ctx);

  printf("\nSigning completed successfully!\n");
  printf("Total GOPs signed: %d\n", ctx.gop_counter);
  printf("Output file: %s\n", output_filename);

  exit_code = 0;

cleanup:
  cleanup_signing_context(&ctx);
  free(output_filename);
  return exit_code;
}
