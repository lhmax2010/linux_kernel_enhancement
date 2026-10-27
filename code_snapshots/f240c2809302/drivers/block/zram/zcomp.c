/* Source: drivers/block/zram/zcomp.c; commit f240c28093027707f5e09f8a9cbbed16a43ebb1a; excerpts only, original line ranges below. */

/* Original lines 110-120 */
struct zcomp_strm *zcomp_stream_get(struct zcomp *comp)
{
	local_lock(&comp->stream->lock);
	return this_cpu_ptr(comp->stream);
}

void zcomp_stream_put(struct zcomp *comp)
{
	local_unlock(&comp->stream->lock);
}

