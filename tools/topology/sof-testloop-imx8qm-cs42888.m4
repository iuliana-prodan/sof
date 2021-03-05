#
# Topology for i.MX8QM board with cs42888 codec
#
# Author: Giuliano Zannetti <giuliano.zannetti@artgroup-spa.com>
#
# Compatible with SOF imx-stable-1.6 <https://github.com/thesofproject/sof/tree/imx-stable-v1.6>
#
# [PCM0] --> [Test Loop Playback] --> [ESAI0 (cs42888)]
# [PCM1] <-- [Test Loop Capture] <-- [ESAI0 (cs42888)]
#

# Include topology builder
include(`utils.m4')
include(`dai.m4')
include(`pipeline.m4')
include(`esai.m4')
include(`pcm.m4')
include(`buffer.m4')

# Include TLV library
include(`common/tlv.m4')

# Include Token library
include(`sof/tokens.m4')

# Include DSP configuration
include(`platform/imx/imx8qxp.m4')

#
#
# PIPELINES
#
#

# PIPELINE_PCM_ADD(
#     pipeline,         name of the predefined pipeline
#     pipe id,          pipeline ID; this should be a unique ID identifying the pipeline
#     pcm,              PCM ID; this will be used to bind to the corrent front end DAI link
#     max channels,     max number of audio channels
#     format,           audio format for the pipeline
#     period,           deadline for pipeline schedule in us
#     priority,         pipeline priority
#     core,             core ID
#     pcm_min_rate,     minimum sample rate
#     pcm_max_rate,     maximum sample rate
#     pipeline_rate,    pipeline sample rate
# )

# Pipeline Test Loop Playback
# [PCM0] --> [Test Loop Playback] --> [ESAI0 (cs42888)]

PIPELINE_PCM_ADD(sof/pipe-testloop-playback.m4,
		 1,
		 0,
		 2,
		 s16le,
		 1000,
		 0,
		 0,
		 48000,
		 48000,
		 48000,
		 SCHEDULE_TIME_DOMAIN_DMA)

# Pipeline Test Loop Capture
# [PCM1] <-- [Test Loop Capture] <-- [ESAI0 (cs42888)]

PIPELINE_PCM_ADD(sof/pipe-testloop-capture.m4,
		 2,
		 1,
		 2,
		 s16le,
		 1000,
		 0,
		 0,
		 48000,
		 48000,
		 48000,
		 SCHEDULE_TIME_DOMAIN_DMA)

#
#
# DAI
#
#

# DAI_ADD(
#     pipeline,      the name of the DAI pipeline (e.g. pipe-dai-playback.m4, pipe-dai-capture.m4)
#     pipe id,       the pipeline id with which the DAI is associated
#     dai type,      the type of DAI (e.g. SSP, DMIC, HDA, ESAI, SAI, ALH)
#     dai_index,     index of the dai in the firmware; note that the DAI’s of different types can
#                    have the same dai_index; the dai_index information can be found by looking in
#                    platform-specific dai array definitions in the firmware, for example, for
#                    apollolake these are defined in src/platform/apollolake/dai.c
#     dai_be,        name of CPU DAI as defined in DAI array in the platform driver
#                    (e.g. esai0-cs42888)
#     buffer,        source/sink buffer the DAI is connected to; this completes the pipeline graph
#                    connections
#     periods,       number of periods
#     format,        DAI audio format
#     period,        pipeline deadline in us
#     priority,      priority that needs to be allocated for the dai pipeline
#     core,          core number to run the pipeline
#     time_domain,
#     channels,      the number of channels
#     rate           the sample rate
# )

DAI_ADD(sof/pipe-dai-playback.m4,
	1,
	ESAI,
	0,
	esai0-cs42888,
	PIPELINE_SOURCE_1,
	2,
	s24le,
	1000,
	1,
	0,
	SCHEDULE_TIME_DOMAIN_DMA,
	2,
	48000)

DAI_ADD(sof/pipe-dai-capture.m4,
	2,
	ESAI,
	0,
	esai0-cs42888,
	PIPELINE_SINK_2,
	2,
	s24le,
	1000,
	1,
	0,
	SCHEDULE_TIME_DOMAIN_DMA,
	2,
	48000)

#
#
# LINK PIPELINES
#
#

SectionGraph."PIPE_LOOP" {
	index "0"

	lines [
		dapm(PIPELINE_LOOPBACK_IN_BUFFER_2, PIPELINE_LOOPBACK_OUT_1)
		dapm(PIPELINE_LOOPBACK_IN_2, PIPELINE_LOOPBACK_IN_BUFFER_2)
	]
}

# DAI_CONFIG(
#     type,       type of DAI (e.g. SSP, DMIC, HDA, ESAI, SAI, ALH)
#     idx,        index of the DAI as defined in the firmware
#     link_id,    ID of the CPU DAI for the link as defined in the SOF driver;
#                 note that the link ID is a linearly incrementing number starting at 0
#                 irrespective of DAI type
#     name,       CPU DAI name as defined in the SOF driver
#     config      configuration details depending on the type of DAI
# )

# ESAI_TDM(
#     slots,
#     width,
#     tx_mask,
#     rx_mask
# )

DAI_CONFIG(ESAI,
	   0,
	   0,
	   esai0-cs42888,
	   ESAI_CONFIG(I2S,
	   ESAI_CLOCK(mclk, 49152000, codec_mclk_in),
	   ESAI_CLOCK(bclk, 3072000, codec_slave),
	   ESAI_CLOCK(fsync, 48000, codec_slave),
	   ESAI_TDM(2, 32, 3, 3),
	   ESAI_CONFIG_DATA(ESAI, 0, 0)))

#
#
# PCM
#
#

# PCM_PLAYBACK_ADD(
#     name,       the PCM name (e.g. media)
#     pcm_id,     the PCM ID (e.g. 0)
#     playback    PIPEPINE_PCM_X identifies the pipeline with the ID X to bind the PCM
#                 (e.g. PIPELINE_PCM_1)
# )

# Pipeline Test Loop Playback
# PCM0 --> [Test Loop Playback] --> ESAI0 (cs42888)

PCM_PLAYBACK_ADD(pcm_out,
		 0,
		 PIPELINE_PCM_1)

# Pipeline Test Loop Capture
# PCM1 <-- [Test Loop Capture] <-- ESAI0 (cs42888)

PCM_CAPTURE_ADD(pcm_in,
		1,
		PIPELINE_PCM_2)