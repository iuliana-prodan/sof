#
# Capture pipeline for Test Loop component testing
#
# Author: Giuliano Zannetti <giuliano.zannetti@artgroup-spa.com>
#
# Compatible with SOF imx-stable-1.6 <https://github.com/thesofproject/sof/tree/imx-stable-v1.6>
#
# [Host PCM_C] <-- [B0] <-- [Test Loop 0] <-- [B1] <-- [Source DAI0]
#

include(`utils.m4')
include(`buffer.m4')
include(`pcm.m4')
include(`dai.m4')
include(`pipeline.m4')
include(`test_loop.m4')

#
#
# Components and Buffers
#
#

#
# [Host PCM_P] - Host PCM Capture
#

# W_PCM_CAPTURE(
#     pcm,
#     stream,
#     periods_sink,
#     periods_source,
#     core
# )

W_PCM_CAPTURE(PCM_ID,
	      Test Loop Capture,
	      0,
	      2,
	      SCHEDULE_CORE)

#
# [Test Loop 0] - It has 2 sink periods and 2 source periods
#

# W_TEST_LOOP(
#     name,
#     format,
#     periods_sink,
#     periods_source,
# )

W_TEST_LOOP(0,
	   PIPELINE_FORMAT,
	   2,
	   2,
	   SCHEDULE_CORE)

#
# [B0] - Capture buffer between [PCM_P] and [Test Loop 0]
#

# W_BUFFER(
#     name,
#     size,
#     capabilities,
#     core
# )
#
# COMP_BUFFER_SIZE(
#     num_periods,
#     sample_size,
#     channels,
#     frames
# )

W_BUFFER(0,
	 COMP_BUFFER_SIZE(2,
			  COMP_SAMPLE_SIZE(PIPELINE_FORMAT),
			  PIPELINE_CHANNELS,
			  COMP_PERIOD_FRAMES(PCM_MAX_RATE, SCHEDULE_PERIOD)),
	 PLATFORM_HOST_MEM_CAP,
	 SCHEDULE_CORE)

#
# [B1] - Capture buffer between [Test Loop 0] and [Source DAI0]
#

W_BUFFER(1,
	 COMP_BUFFER_SIZE(DAI_PERIODS,
			  COMP_SAMPLE_SIZE(PIPELINE_FORMAT),
			  PIPELINE_CHANNELS,
			  COMP_PERIOD_FRAMES(PCM_MAX_RATE, SCHEDULE_PERIOD)),
	 PLATFORM_DAI_MEM_CAP,
	 SCHEDULE_CORE)

#
# [B2] - Capture buffer between [Test Loop 0] and [Loopback Endpoint]
#

W_BUFFER(2,
	 COMP_BUFFER_SIZE(DAI_PERIODS,
			  COMP_SAMPLE_SIZE(PIPELINE_FORMAT),
			  PIPELINE_CHANNELS,
			  COMP_PERIOD_FRAMES(PCM_MAX_RATE, SCHEDULE_PERIOD)),
	 PLATFORM_DAI_MEM_CAP,
	 SCHEDULE_CORE)

#
#
# Pipeline Graph
#
#

# [Host PCM_C] <-- [B0] <-- [Test Loop 0] <-- [B1] <-- [Sink DAI0]

# P_GRAPH(
#     name,
#     pipeline_id,
#     connections
# )

# [Host PCM_C]   <--  [B0]
# [B0]           <--  [Test Loop 0]
# [Test Loop 0]   <--  [B1]

P_GRAPH(pipe-testloop-capture-PIPELINE_ID,
	PIPELINE_ID,
	LIST(` ',
	     `dapm(N_PCMC(PCM_ID), N_BUFFER(0))',
	     `dapm(N_BUFFER(0), N_TEST_LOOP(0))',
	     `dapm(N_TEST_LOOP(0), N_BUFFER(1))'))

#
#
# PCM Configuration
#
#

# PCM_CAPABILITIES(
#     name,
#     formats,
#     rate_min,
#     rate_max,
#     channels_min,
#     channels_max,
#     periods_min,
#     periods_max,
#     period_size_min,
#     period_size_max,
#     buffer_size_min,
#     buffer_size_max
# )

PCM_CAPABILITIES(Test Loop Capture PCM_ID,
		 CAPABILITY_FORMAT_NAME(PIPELINE_FORMAT),
		 PCM_MIN_RATE,
		 PCM_MAX_RATE,
		 2,
		 PIPELINE_CHANNELS,
		 2,
		 16,
		 192,
		 16384,
		 65536,
		 65536)

#
#
# Pipeline Source and Sinks
#
#

indir(`define', concat(`PIPELINE_SINK_', PIPELINE_ID), N_BUFFER(1))
indir(`define', concat(`PIPELINE_LOOPBACK_IN_', PIPELINE_ID), N_TEST_LOOP(0))
indir(`define', concat(`PIPELINE_LOOPBACK_IN_BUFFER_', PIPELINE_ID), N_BUFFER(2))
indir(`define', concat(`PIPELINE_PCM_', PIPELINE_ID), Test Loop Capture PCM_ID)
