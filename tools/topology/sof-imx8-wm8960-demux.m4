#
# Demux topology for i.MX8QM / i.MX8QXP boards with wm8960 codec
#

# Include topology builder
include(`utils.m4')
include(`dai.m4')
include(`pipeline.m4')
include(`sai.m4')
include(`muxdemux.m4')

# Include TLV library
include(`common/tlv.m4')

# Include Token library
include(`sof/tokens.m4')

# Include IMX8 DSP configuration
include(`platform/imx/imx8qxp.m4')

dnl Configure demux
dnl name, pipeline_id, routing_matrix_rows
dnl Diagonal 1's in routing matrix mean that every input channel is
dnl copied to corresponding output channels in all output streams.
dnl I.e. row index is the input channel, 1 means it is copied to
dnl corresponding output channel (column index), 0 means it is discarded.
dnl There's a separate matrix for all outputs.
define(matrix1, `ROUTE_MATRIX(1,
			     `BITS_TO_BYTE(1, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 1, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 1 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,1 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,1 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,1 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,1 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,1)')')

define(matrix2, `ROUTE_MATRIX(2,
			     `BITS_TO_BYTE(1, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 1, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 1 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,1 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,1 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,1 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,1 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,1)')')

dnl name, num_streams, route_matrix list
MUXDEMUX_CONFIG(demux_priv_1, 2, LIST(`	', `matrix1,', `matrix2'))

#
# Define the pipelines
#
# PCM0 -----> volume -------v
#                            demux ----> volume ----> SAI1 (wm8960)
# PCM1 -----> volume -------^
# PCM0 <---- Volume <---- SAI1

# Low Latency capture pipeline 2 on PCM 0 using max 2 channels of s32le.
# 1000us deadline on core 0 with priority 0
PIPELINE_PCM_ADD(sof/pipe-low-latency-capture.m4,
	2, 0, 2, s32le,
	1000, 0, 0,
	48000, 48000, 48000)

#
# DAI configuration
#
# SAI port 1 is our only pipeline DAI
#
# playback DAI is SAI1 using 2 periods
# Buffers use s32le format, 1000us deadline on core 0 with priority 1
# this defines pipeline 1. The 'NOT_USED_IGNORED' is due to dependencies
# and is adjusted later with an explicit dapm line.
DAI_ADD(sof/pipe-demux-dai-playback.m4,
	1, SAI, 1, sai1-wm8960-hifi,
	NOT_USED_IGNORED, 2, s32le,
	1000, 1, 0, SCHEDULE_TIME_DOMAIN_DMA,
	2, 48000)

# PCM Playback pipeline 3 on PCM 0 using max 2 channels of s32le.
# 1000us deadline on core 0 with priority 0
# this is connected to pipeline DAI 1
PIPELINE_PCM_ADD(sof/pipe-host-volume-playback.m4,
	3, 0, 2, s32le,
	1000, 0, 0,
	48000, 48000, 48000,
	SCHEDULE_TIME_DOMAIN_DMA,
	PIPELINE_PLAYBACK_SCHED_COMP_1)

# PCM Playback pipeline 4 on PCM 1 using max 2 channels of s32le.
# 5ms deadline on core 0 with priority 0
# this is connected to pipeline DAI 1
PIPELINE_PCM_ADD(sof/pipe-host-volume-playback.m4,
	4, 1, 2, s32le,
	5000, 0, 0,
	48000, 48000, 48000,
	SCHEDULE_TIME_DOMAIN_DMA,
	PIPELINE_PLAYBACK_SCHED_COMP_1)

# Connect pipelines together
SectionGraph."PIPE_NAME" {
	index "0"

	lines [
		# PCM pipeline 3 to DAI pipeline 1
		dapm(PIPELINE_DEMUX_1, PIPELINE_SOURCE_3)
		# PCM pipeline 4 to DAI pipeline 1
		dapm(PIPELINE_DEMUX_1, PIPELINE_SOURCE_4)

	]
}
# capture DAI is SAI1 using 2 periods
# Buffers use s32le format, 1000us deadline on core 0 with priority 0
# this is part of pipeline 2
DAI_ADD(sof/pipe-dai-capture.m4,
	2, SAI, 1, sai1-wm8960-hifi,
	PIPELINE_SINK_2, 2, s32le,
	1000, 0, 0, SCHEDULE_TIME_DOMAIN_DMA)
#
# BE configurations
#
DAI_CONFIG(SAI, 1, 0, sai1-wm8960-hifi,
	   SAI_CONFIG(I2S, SAI_CLOCK(mclk, 12288000, codec_mclk_in),
		      SAI_CLOCK(bclk, 3072000, codec_master),
		      SAI_CLOCK(fsync, 48000, codec_master),
		      SAI_TDM(2, 16, 3, 3),
		      SAI_CONFIG_DATA(SAI, 1, 0)))
