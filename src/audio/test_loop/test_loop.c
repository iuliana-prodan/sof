// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright(c) 2020 Art Spa. All rights reserved.
//
// Author: Giuliano Zannetti <giuliano.zannetti@artgroup-spa.com>

#include <sof/audio/component.h>
#include <sof/lib/uuid.h>
#include <ipc/stream.h>

/*
 * It defines the component name that will be printed by the logger tool. UUID value and its name is
 * stored in the ldc file deployed on the target system and is used by the logger to resolve and
 * print the name of the component.
 * UUID: 559b1251-2de5-48fa-81ec-5e7776769919
 */
DECLARE_SOF_RT_UUID("test_loop", test_loop_uuid, 0x559b1251, 0x2de5, 0x48fa,
		    0x81, 0xec, 0x5e, 0x77, 0x76, 0x76, 0x99, 0x19);

/* It defines the component trace context and the tracing level. */
DECLARE_TR_CTX(test_loop_tr, SOF_UUID(test_loop_uuid), LOG_LEVEL_INFO);

/* The number of sink buffers: one for the forward path and another for the loopback. */
#define NUM_SOURCE_BUFFERS 2

/* The number of sink buffers: one for the forward path and another for the loopback. */
#define NUM_SINK_BUFFERS 2

/* It registers component. */
static void sys_comp_test_loop_init(void);

/* It creates Test Loop component. */
static struct comp_dev *test_loop_new(const struct comp_driver *drv, struct sof_ipc_comp *comp);

/* It frees Test Loop component. */
static void test_loop_free(struct comp_dev *dev);

/* It sets the Test Loop component state. */
static int test_loop_trigger(struct comp_dev *dev, int cmd);

/* It configures the Test Loop component for stream parameters */
static int test_loop_prepare(struct comp_dev *dev);

/* It resets the Test Loop component. */
static int test_loop_reset(struct comp_dev *dev);

/* It copies and processes stream data. */
static int test_loop_copy(struct comp_dev *dev);

/* Audio component private data. */
struct test_loop_comp_data {
	int data;
};

/* Audio component driver. */
static struct comp_driver comp_test_loop = {
	.type = SOF_COMP_TEST_LOOP,
	.uid = SOF_RT_UUID(test_loop_uuid),
	.tctx = &test_loop_tr,
	.ops = {
		.create = test_loop_new,
		.free = test_loop_free,
		.params = NULL,
		.cmd = NULL,
		.trigger = test_loop_trigger,
		.prepare = test_loop_prepare,
		.reset = test_loop_reset,
		.copy = test_loop_copy,
	},
};

/* Audio component driver info. */
static SHARED_DATA struct comp_driver_info comp_test_loop_info = {
	.drv = &comp_test_loop,
};

static void sys_comp_test_loop_init(void)
{
	comp_register(platform_shared_get(&comp_test_loop_info, sizeof(comp_test_loop_info)));
}

static struct comp_dev *test_loop_new(const struct comp_driver *drv, struct sof_ipc_comp *comp)
{
	comp_cl_info(&comp_test_loop, "test_loop_new");

	/* Declare variables. */
	struct comp_dev *dev;
	struct sof_ipc_comp_process *test_loop;
	struct sof_ipc_comp_process *ipc_test_loop = (struct sof_ipc_comp_process *)comp;
	struct test_loop_comp_data *cd;
	int ret;

	/* Alloc and init component device. */
	dev = comp_alloc(drv, COMP_SIZE(struct sof_ipc_comp_process));
	if (!dev) {
		comp_cl_err(&comp_test_loop, "test_loop_new | alloc and init component device");
		return NULL;
	}

	/* Alloc and init component private data. */
	cd = rzalloc(SOF_MEM_ZONE_RUNTIME, 0, SOF_MEM_CAPS_RAM, sizeof(*cd));
	if (!cd) {
		comp_cl_err(&comp_test_loop, "test_loop_new | alloc and init component private data");
		rfree(dev);
		return NULL;
	}

	test_loop = COMP_GET_IPC(dev, sof_ipc_comp_process);
	ret = memcpy_s(test_loop,
		       sizeof(*test_loop),
		       ipc_test_loop,
		       sizeof(struct sof_ipc_comp_process));
	assert(!ret);

	/* Attach private data to component device. */
	comp_set_drvdata(dev, cd);

	/* Set component device state to ready. */
	dev->state = COMP_STATE_READY;

	comp_info(dev, "test_loop_new | created");

	return dev;
}

static void test_loop_free(struct comp_dev *dev)
{
	comp_info(dev, "test_loop_free");

	/* Retrieve private data from component device. */
	struct comp_data *cd = comp_get_drvdata(dev);

	/* Free private data. */
	rfree(cd);

	/* Free component device. */
	rfree(dev);
}

static int test_loop_trigger(struct comp_dev *dev, int cmd)
{
	comp_info(dev, "test_loop_trigger | cmd=%d", cmd);

	/* Declare variables. */
	int ret;

	/* Set component device state. */
	ret = comp_set_state(dev, cmd);
	if (ret != 0)
		comp_err(dev, "test_loop_trigger | ret=%d", ret);

	return ret;
}

static int test_loop_prepare(struct comp_dev *dev)
{
	comp_info(dev, "test_loop_prepare");

	/* Declare variables.  */
	int ret;
	struct list_item *source_buffer_list_item;
	int num_sources = 0;
	struct list_item *sink_buffer_list_item;
	int num_sinks = 0;

	/* Set component device state. */
	ret = comp_set_state(dev, COMP_TRIGGER_PREPARE);
	if (ret < 0)
		return ret;

	/* Return if another 'prepare' call was previously issued. */
	if (ret == COMP_STATUS_STATE_ALREADY_SET)
		return PPL_STATUS_PATH_STOP;

	/* Get sink and source component buffers. */
	list_for_item(source_buffer_list_item, &dev->bsource_list) {
		container_of(source_buffer_list_item, struct comp_buffer, sink_list);
		num_sources++;
	}

	list_for_item(sink_buffer_list_item, &dev->bsink_list) {
		container_of(sink_buffer_list_item, struct comp_buffer, source_list);
		num_sinks++;
	}

	/* Check that there is at least one source buffer. */
	if (num_sources == 0) {
		comp_err(dev, "test_loop_prepare | no source buffer");
		return -ENOMEM;
	}

	/* Check that there is at least one sink buffer. */
	if (num_sinks == 0) {
		comp_err(dev, "test_loop_prepare | no sink buffer");
		return -ENOMEM;
	}

	comp_info(dev, "test_loop_prepare | type=%d, sinks=%d, sources=%d",
		 dev->direction, num_sinks, num_sources);

	comp_info(dev, "test_loop_prepare | prepared");

	return 0;
}

static int test_loop_reset(struct comp_dev *dev)
{
	comp_info(dev, "test_loop_reset");

	/* Declare variables.  */
	int ret;

	/* Set component device state to 'reset'. */
	ret = comp_set_state(dev, COMP_TRIGGER_RESET);
	if (ret != 0)
		comp_err(dev, "test_loop_reset | ret=%d", ret);

	return ret;
}

static int test_loop_copy(struct comp_dev *dev)
{
	/* Declare variables. */
	struct comp_buffer *sources[NUM_SOURCE_BUFFERS] = {NULL};
	struct comp_buffer *source;
	struct comp_buffer *sinks[NUM_SINK_BUFFERS] = {NULL};
	struct comp_buffer *sink;
	int num_sources = 0;
	int num_sinks = 0;
	int i = 0;
	int j = 0;
	struct list_item *source_list_item;
	struct list_item *sink_list_item;
	int16_t *src;
	int16_t *dst;
	uint32_t source_flags = 0;
	uint32_t sink_flags = 0;
	uint32_t avail_frames = INT32_MAX;
	uint32_t avail_source_bytes = 0;
	uint32_t avail_sink_bytes = 0;
	int frame = 0;
	int channel = 0;
	uint32_t buff_frag = 0;

	comp_dbg(dev, "test_loop_copy");

	/* Get sources. */
	list_for_item(source_list_item, &dev->bsource_list) {
		source = container_of(source_list_item, struct comp_buffer, sink_list);
		comp_dbg(dev, "test_loop_copy | source=%d, state=%d", num_sources, dev->state);
		if (source->source->state == dev->state)
			sources[num_sources] = source;
		num_sources++;
	}

	/* Get sinks. */
	list_for_item(sink_list_item, &dev->bsink_list) {
		sink = container_of(sink_list_item, struct comp_buffer, source_list);
		comp_dbg(dev, "test_loop_copy | sink=%d, state=%d", num_sinks, dev->state);
		if (sink->sink->state == dev->state)
			sinks[num_sinks] = sink;
		num_sinks++;
	}

	/* Lock buffers. */
	for (i = 0; i < num_sources; i++)
		buffer_lock(sources[i], &source_flags);

	for (i = 0; i < num_sinks; i++)
		buffer_lock(sinks[i], &sink_flags);

	/* Get available frames. */
	for (i = 0; i < num_sources; i++)
		for (j = 0; j < num_sinks; j++)
			avail_frames = MIN(audio_stream_avail_frames(&sources[i]->stream,
								     &sinks[j]->stream),
					   avail_frames);

	/* Unlock buffers. */
	for (i = 0; i < num_sources; i++)
		buffer_unlock(sources[i], source_flags);

	for (i = 0; i < num_sinks; i++)
		buffer_unlock(sinks[i], sink_flags);

	/* Calculate available frames in bytes. */
	/* Source and sink can have different format and channels. */
	/* Every source has the same format, so calculate bytes based on the first one. */
	/* Every sink has the same format, so calculate bytes based on the first one. */
	avail_source_bytes = avail_frames * audio_stream_frame_bytes(&sources[0]->stream);
	avail_sink_bytes = avail_frames * audio_stream_frame_bytes(&sinks[0]->stream);

	/* Copy from source to sink. */
	for (i = 0; i < num_sources; i++)
		buffer_invalidate(sources[i], avail_source_bytes);

	if (dev->direction == SOF_IPC_STREAM_PLAYBACK) {
		for (frame = 0; frame < avail_frames; frame++) {
			for (channel = 0; channel < sources[0]->stream.channels; channel++) {
				/* Get src sample. */
				/* Assume that for playback scenario there is only one source. */
				src = audio_stream_read_frag_s16(&sources[0]->stream, buff_frag);

				for (i = 0; i < num_sinks; i++) {
					/* Get dst sample. */
					dst = audio_stream_write_frag_s16(&sinks[i]->stream,
									  buff_frag);

					/* Process sample. */
					*dst = *src;
				}

				buff_frag++;
			}
		}

	} else {
		for (frame = 0; frame < avail_frames; frame++) {
			for (channel = 0; channel < sources[0]->stream.channels; channel++) {
				/* Get dst sample. */
				/* Assume that for capture scenario there is only one sink. */
				dst = audio_stream_write_frag_s16(&sinks[0]->stream, buff_frag);

				/* Get src sample. */
				/* TODO It should copy from all sources; just for test reasons */
				/*      copy only from source 0. */
				src = audio_stream_read_frag_s16(&sources[0]->stream, buff_frag);

				/* Process sample. */
				*dst = *src;

				buff_frag++;
			}
		}
	}

	for (i = 0; i < num_sinks; i++)
		buffer_writeback(sinks[i], avail_sink_bytes);

	/* Update source and sink buffer pointers. */
	for (i = 0; i < num_sources; i++)
		comp_update_buffer_consume(sources[i], avail_source_bytes);

	for (i = 0; i < num_sinks; i++)
		comp_update_buffer_produce(sinks[i], avail_sink_bytes);

	return 0;
}

DECLARE_MODULE(sys_comp_test_loop_init);
