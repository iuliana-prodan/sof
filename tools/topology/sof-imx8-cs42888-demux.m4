#
# Demux topology for i.MX8QM / i.MX8QXP boards with cs42888 codec
#
# PCM0 ----> demux -----> ESAI (cs42888)
# PCM4 <---- demux
#

# Include topology builder
include(`utils.m4')
include(`dai.m4')
include(`pipeline.m4')
include(`esai.m4')
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
# PCM0 -----> volume -----> demux -----> ESAI0 (cs42888)
# PCM1 <----- demux
#

dnl PIPELINE_PCM_ADD(pipeline,
dnl     pipe id, pcm, max channels, format,
dnl     period, priority, core,
dnl     pcm_min_rate, pcm_max_rate, pipeline_rate,
dnl     time_domain, sched_comp)

# Demux pipeline 1 on PCM 0 using max 2 channels of s24le.
# Set 1000us deadline on core 0 with priority 0
PIPELINE_PCM_ADD(sof/pipe-volume-demux-playback.m4,
	1, 0, 2, s24le,
	1000, 0, 0,
	48000, 48000, 48000)

#
# DAIs configuration
#

dnl DAI_ADD(pipeline,
dnl     pipe id, dai type, dai_index, dai_be,
dnl     buffer, periods, format,
dnl     deadline, priority, core, time_domain)

# playback DAI is ESAI0 using 2 periods
# Buffers use s24le format, 1000us deadline on core 0 with priority 0
DAI_ADD(sof/pipe-dai-playback.m4,
	1, ESAI, 0, esai0-cs42888,
	PIPELINE_SOURCE_1, 2, s24le,
	1000, 0, 0, SCHEDULE_TIME_DOMAIN_DMA)

# currently this dai is here as "virtual" capture backend
W_DAI_IN(ESAI, 0, esai0-cs42888, s24le, 3, 0)

# Capture pipeline 2 from demux on PCM 1 using max 2 channels of s24le.
PIPELINE_PCM_ADD(sof/pipe-passthrough-capture-sched.m4,
	2, 1, 2, s24le,
	1000, 1, 0,
	48000, 48000, 48000,
	SCHEDULE_TIME_DOMAIN_DMA,
	PIPELINE_PLAYBACK_SCHED_COMP_1)

# Connect demux to capture
SectionGraph."PIPE_CAP" {
	index "0"

	lines [
		# mux to capture
		dapm(PIPELINE_SINK_2, PIPELINE_DEMUX_1)
	]
}

# Connect virtual capture to dai
SectionGraph."PIPE_CAP_VIRT" {
	index "2"

	lines [
		# mux to capture
		dapm(ECHO REF 2, ESAI0.IN)
	]
}

# PCM Low Latency, id 0
dnl PCM_PLAYBACK_ADD(name, pcm_id, playback)
PCM_PLAYBACK_ADD(Playback, 0, PIPELINE_PCM_1)
PCM_CAPTURE_ADD(EchoRef, 1, PIPELINE_PCM_2)

#
# BE configurations
#
DAI_CONFIG(ESAI, 0, 0, esai0-cs42888,
	   ESAI_CONFIG(I2S, ESAI_CLOCK(mclk, 49152000, codec_mclk_in),
		       ESAI_CLOCK(bclk, 3072000, codec_slave),
		       ESAI_CLOCK(fsync, 48000, codec_slave),
		       ESAI_TDM(2, 32, 3, 3),
		       ESAI_CONFIG_DATA(ESAI, 0, 0)))
