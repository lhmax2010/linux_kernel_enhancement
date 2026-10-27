/* Source: drivers/block/zram/zram_drv.c; commit f240c28093027707f5e09f8a9cbbed16a43ebb1a; excerpts only, original line ranges below. */

/* Original lines 294-366 */
	unsigned long nr_pages = zram->disksize >> PAGE_SHIFT;
	int index;

	for (index = 0; index < nr_pages; index++) {
		/*
		 * Do not mark ZRAM_UNDER_WB slot as ZRAM_IDLE to close race.
		 * See the comment in writeback_store.
		 *
		 * Also do not mark ZRAM_SAME slots as ZRAM_IDLE, because no
		 * post-processing (recompress, writeback) happens to the
		 * ZRAM_SAME slot.
		 *
		 * And ZRAM_WB slots simply cannot be ZRAM_IDLE.
		 */
		zram_slot_lock(zram, index);
		if (!zram_allocated(zram, index) ||
		    zram_test_flag(zram, index, ZRAM_WB) ||
		    zram_test_flag(zram, index, ZRAM_UNDER_WB) ||
		    zram_test_flag(zram, index, ZRAM_SAME)) {
			zram_slot_unlock(zram, index);
			continue;
		}

#ifdef CONFIG_ZRAM_TRACK_ENTRY_ACTIME
		is_idle = !cutoff ||
			ktime_after(cutoff, zram->table[index].ac_time);
#endif
		if (is_idle)
			zram_set_flag(zram, index, ZRAM_IDLE);
		else
			zram_clear_flag(zram, index, ZRAM_IDLE);
		zram_slot_unlock(zram, index);
	}
}

static ssize_t idle_store(struct device *dev,
		struct device_attribute *attr, const char *buf, size_t len)
{
	struct zram *zram = dev_to_zram(dev);
	ktime_t cutoff_time = 0;
	ssize_t rv = -EINVAL;

	if (!sysfs_streq(buf, "all")) {
		/*
		 * If it did not parse as 'all' try to treat it as an integer
		 * when we have memory tracking enabled.
		 */
		u64 age_sec;

		if (IS_ENABLED(CONFIG_ZRAM_TRACK_ENTRY_ACTIME) && !kstrtoull(buf, 0, &age_sec))
			cutoff_time = ktime_sub(ktime_get_boottime(),
					ns_to_ktime(age_sec * NSEC_PER_SEC));
		else
			goto out;
	}

	down_read(&zram->init_lock);
	if (!init_done(zram))
		goto out_unlock;

	/*
	 * A cutoff_time of 0 marks everything as idle, this is the
	 * "all" behavior.
	 */
	mark_idle(zram, cutoff_time);
	rv = len;

out_unlock:
	up_read(&zram->init_lock);
out:
	return rv;
}


/* Original lines 602-664 */
#define PAGE_WB_SIG "page_index="

#define PAGE_WRITEBACK			0
#define HUGE_WRITEBACK			(1<<0)
#define IDLE_WRITEBACK			(1<<1)
#define INCOMPRESSIBLE_WRITEBACK	(1<<2)

static ssize_t writeback_store(struct device *dev,
		struct device_attribute *attr, const char *buf, size_t len)
{
	struct zram *zram = dev_to_zram(dev);
	unsigned long nr_pages = zram->disksize >> PAGE_SHIFT;
	unsigned long index = 0;
	struct bio bio;
	struct bio_vec bio_vec;
	struct page *page;
	ssize_t ret = len;
	int mode, err;
	unsigned long blk_idx = 0;

	if (sysfs_streq(buf, "idle"))
		mode = IDLE_WRITEBACK;
	else if (sysfs_streq(buf, "huge"))
		mode = HUGE_WRITEBACK;
	else if (sysfs_streq(buf, "huge_idle"))
		mode = IDLE_WRITEBACK | HUGE_WRITEBACK;
	else if (sysfs_streq(buf, "incompressible"))
		mode = INCOMPRESSIBLE_WRITEBACK;
	else {
		if (strncmp(buf, PAGE_WB_SIG, sizeof(PAGE_WB_SIG) - 1))
			return -EINVAL;

		if (kstrtol(buf + sizeof(PAGE_WB_SIG) - 1, 10, &index) ||
				index >= nr_pages)
			return -EINVAL;

		nr_pages = 1;
		mode = PAGE_WRITEBACK;
	}

	down_read(&zram->init_lock);
	if (!init_done(zram)) {
		ret = -EINVAL;
		goto release_init_lock;
	}

	/* Do not permit concurrent post-processing actions. */
	if (atomic_xchg(&zram->pp_in_progress, 1)) {
		up_read(&zram->init_lock);
		return -EAGAIN;
	}

	if (!zram->backing_dev) {
		ret = -ENODEV;
		goto release_init_lock;
	}

	page = alloc_page(GFP_KERNEL);
	if (!page) {
		ret = -ENOMEM;
		goto release_init_lock;
	}


/* Original lines 1007-1123 */
	if (sz > 0 && compressor[sz - 1] == '\n')
		compressor[sz - 1] = 0x00;

	if (!zcomp_available_algorithm(compressor)) {
		kfree(compressor);
		return -EINVAL;
	}

	down_write(&zram->init_lock);
	if (init_done(zram)) {
		up_write(&zram->init_lock);
		kfree(compressor);
		pr_info("Can't change algorithm for initialized device\n");
		return -EBUSY;
	}

	comp_algorithm_set(zram, prio, compressor);
	up_write(&zram->init_lock);
	return 0;
}

static void comp_params_reset(struct zram *zram, u32 prio)
{
	struct zcomp_params *params = &zram->params[prio];

	vfree(params->dict);
	params->level = ZCOMP_PARAM_NO_LEVEL;
	params->dict_sz = 0;
	params->dict = NULL;
}

static int comp_params_store(struct zram *zram, u32 prio, s32 level,
			     const char *dict_path)
{
	ssize_t sz = 0;

	comp_params_reset(zram, prio);

	if (dict_path) {
		sz = kernel_read_file_from_path(dict_path, 0,
						&zram->params[prio].dict,
						INT_MAX,
						NULL,
						READING_POLICY);
		if (sz < 0)
			return -EINVAL;
	}

	zram->params[prio].dict_sz = sz;
	zram->params[prio].level = level;
	return 0;
}

static ssize_t algorithm_params_store(struct device *dev,
				      struct device_attribute *attr,
				      const char *buf,
				      size_t len)
{
	s32 prio = ZRAM_PRIMARY_COMP, level = ZCOMP_PARAM_NO_LEVEL;
	char *args, *param, *val, *algo = NULL, *dict_path = NULL;
	struct zram *zram = dev_to_zram(dev);
	int ret;

	args = skip_spaces(buf);
	while (*args) {
		args = next_arg(args, &param, &val);

		if (!val || !*val)
			return -EINVAL;

		if (!strcmp(param, "priority")) {
			ret = kstrtoint(val, 10, &prio);
			if (ret)
				return ret;
			continue;
		}

		if (!strcmp(param, "level")) {
			ret = kstrtoint(val, 10, &level);
			if (ret)
				return ret;
			continue;
		}

		if (!strcmp(param, "algo")) {
			algo = val;
			continue;
		}

		if (!strcmp(param, "dict")) {
			dict_path = val;
			continue;
		}
	}

	/* Lookup priority by algorithm name */
	if (algo) {
		s32 p;

		prio = -EINVAL;
		for (p = ZRAM_PRIMARY_COMP; p < ZRAM_MAX_COMPS; p++) {
			if (!zram->comp_algs[p])
				continue;

			if (!strcmp(zram->comp_algs[p], algo)) {
				prio = p;
				break;
			}
		}
	}

	if (prio < ZRAM_PRIMARY_COMP || prio >= ZRAM_MAX_COMPS)
		return -EINVAL;

	ret = comp_params_store(zram, prio, level, dict_path);
	return ret ? ret : len;
}

/* Original lines 1147-1207 */
static ssize_t recomp_algorithm_show(struct device *dev,
				     struct device_attribute *attr,
				     char *buf)
{
	struct zram *zram = dev_to_zram(dev);
	ssize_t sz = 0;
	u32 prio;

	for (prio = ZRAM_SECONDARY_COMP; prio < ZRAM_MAX_COMPS; prio++) {
		if (!zram->comp_algs[prio])
			continue;

		sz += scnprintf(buf + sz, PAGE_SIZE - sz - 2, "#%d: ", prio);
		sz += __comp_algorithm_show(zram, prio, buf + sz);
	}

	return sz;
}

static ssize_t recomp_algorithm_store(struct device *dev,
				      struct device_attribute *attr,
				      const char *buf,
				      size_t len)
{
	struct zram *zram = dev_to_zram(dev);
	int prio = ZRAM_SECONDARY_COMP;
	char *args, *param, *val;
	char *alg = NULL;
	int ret;

	args = skip_spaces(buf);
	while (*args) {
		args = next_arg(args, &param, &val);

		if (!val || !*val)
			return -EINVAL;

		if (!strcmp(param, "algo")) {
			alg = val;
			continue;
		}

		if (!strcmp(param, "priority")) {
			ret = kstrtoint(val, 10, &prio);
			if (ret)
				return ret;
			continue;
		}
	}

	if (!alg)
		return -EINVAL;

	if (prio < ZRAM_SECONDARY_COMP || prio >= ZRAM_MAX_COMPS)
		return -EINVAL;

	ret = __comp_algorithm_store(zram, prio, alg);
	return ret ? ret : len;
}
#endif


/* Original lines 1680-2000 */

#ifdef CONFIG_ZRAM_MULTI_COMP
/*
 * This function will decompress (unless it's ZRAM_HUGE) the page and then
 * attempt to compress it using provided compression algorithm priority
 * (which is potentially more effective).
 *
 * Corresponding ZRAM slot should be locked.
 */
static int zram_recompress(struct zram *zram, u32 index, struct page *page,
			   u64 *num_recomp_pages, u32 threshold, u32 prio,
			   u32 prio_max)
{
	struct zcomp_strm *zstrm = NULL;
	unsigned long handle_old;
	unsigned long handle_new;
	unsigned int comp_len_old;
	unsigned int comp_len_new;
	unsigned int class_index_old;
	unsigned int class_index_new;
	u32 num_recomps = 0;
	void *src, *dst;
	int ret;

	handle_old = zram_get_handle(zram, index);
	if (!handle_old)
		return -EINVAL;

	comp_len_old = zram_get_obj_size(zram, index);
	/*
	 * Do not recompress objects that are already "small enough".
	 */
	if (comp_len_old < threshold)
		return 0;

	ret = zram_read_from_zspool(zram, page, index);
	if (ret)
		return ret;

	/*
	 * We touched this entry so mark it as non-IDLE. This makes sure that
	 * we don't preserve IDLE flag and don't incorrectly pick this entry
	 * for different post-processing type (e.g. writeback).
	 */
	zram_clear_flag(zram, index, ZRAM_IDLE);

	class_index_old = zs_lookup_class_index(zram->mem_pool, comp_len_old);
	/*
	 * Iterate the secondary comp algorithms list (in order of priority)
	 * and try to recompress the page.
	 */
	for (; prio < prio_max; prio++) {
		if (!zram->comps[prio])
			continue;

		/*
		 * Skip if the object is already re-compressed with a higher
		 * priority algorithm (or same algorithm).
		 */
		if (prio <= zram_get_priority(zram, index))
			continue;

		num_recomps++;
		zstrm = zcomp_stream_get(zram->comps[prio]);
		src = kmap_local_page(page);
		ret = zcomp_compress(zram->comps[prio], zstrm,
				     src, &comp_len_new);
		kunmap_local(src);

		if (ret) {
			zcomp_stream_put(zram->comps[prio]);
			return ret;
		}

		class_index_new = zs_lookup_class_index(zram->mem_pool,
							comp_len_new);

		/* Continue until we make progress */
		if (class_index_new >= class_index_old ||
		    (threshold && comp_len_new >= threshold)) {
			zcomp_stream_put(zram->comps[prio]);
			continue;
		}

		/* Recompression was successful so break out */
		break;
	}

	/*
	 * We did not try to recompress, e.g. when we have only one
	 * secondary algorithm and the page is already recompressed
	 * using that algorithm
	 */
	if (!zstrm)
		return 0;

	/*
	 * Decrement the limit (if set) on pages we can recompress, even
	 * when current recompression was unsuccessful or did not compress
	 * the page below the threshold, because we still spent resources
	 * on it.
	 */
	if (*num_recomp_pages)
		*num_recomp_pages -= 1;

	if (class_index_new >= class_index_old) {
		/*
		 * Secondary algorithms failed to re-compress the page
		 * in a way that would save memory, mark the object as
		 * incompressible so that we will not try to compress
		 * it again.
		 *
		 * We need to make sure that all secondary algorithms have
		 * failed, so we test if the number of recompressions matches
		 * the number of active secondary algorithms.
		 */
		if (num_recomps == zram->num_active_comps - 1)
			zram_set_flag(zram, index, ZRAM_INCOMPRESSIBLE);
		return 0;
	}

	/* Successful recompression but above threshold */
	if (threshold && comp_len_new >= threshold)
		return 0;

	/*
	 * No direct reclaim (slow path) for handle allocation and no
	 * re-compression attempt (unlike in zram_write_bvec()) since
	 * we already have stored that object in zsmalloc. If we cannot
	 * alloc memory for recompressed object then we bail out and
	 * simply keep the old (existing) object in zsmalloc.
	 */
	handle_new = zs_malloc(zram->mem_pool, comp_len_new,
			       __GFP_KSWAPD_RECLAIM |
			       __GFP_NOWARN |
			       __GFP_HIGHMEM |
			       __GFP_MOVABLE);
	if (IS_ERR_VALUE(handle_new)) {
		zcomp_stream_put(zram->comps[prio]);
		return PTR_ERR((void *)handle_new);
	}

	dst = zs_map_object(zram->mem_pool, handle_new, ZS_MM_WO);
	memcpy(dst, zstrm->buffer, comp_len_new);
	zcomp_stream_put(zram->comps[prio]);

	zs_unmap_object(zram->mem_pool, handle_new);

	zram_free_page(zram, index);
	zram_set_handle(zram, index, handle_new);
	zram_set_obj_size(zram, index, comp_len_new);
	zram_set_priority(zram, index, prio);

	atomic64_add(comp_len_new, &zram->stats.compr_data_size);
	atomic64_inc(&zram->stats.pages_stored);

	return 0;
}

#define RECOMPRESS_IDLE		(1 << 0)
#define RECOMPRESS_HUGE		(1 << 1)

static ssize_t recompress_store(struct device *dev,
				struct device_attribute *attr,
				const char *buf, size_t len)
{
	u32 prio = ZRAM_SECONDARY_COMP, prio_max = ZRAM_MAX_COMPS;
	struct zram *zram = dev_to_zram(dev);
	unsigned long nr_pages = zram->disksize >> PAGE_SHIFT;
	char *args, *param, *val, *algo = NULL;
	u64 num_recomp_pages = ULLONG_MAX;
	u32 mode = 0, threshold = 0;
	unsigned long index;
	struct page *page;
	ssize_t ret;

	args = skip_spaces(buf);
	while (*args) {
		args = next_arg(args, &param, &val);

		if (!val || !*val)
			return -EINVAL;

		if (!strcmp(param, "type")) {
			if (!strcmp(val, "idle"))
				mode = RECOMPRESS_IDLE;
			if (!strcmp(val, "huge"))
				mode = RECOMPRESS_HUGE;
			if (!strcmp(val, "huge_idle"))
				mode = RECOMPRESS_IDLE | RECOMPRESS_HUGE;
			continue;
		}

		if (!strcmp(param, "max_pages")) {
			/*
			 * Limit the number of entries (pages) we attempt to
			 * recompress.
			 */
			ret = kstrtoull(val, 10, &num_recomp_pages);
			if (ret)
				return ret;
			continue;
		}

		if (!strcmp(param, "threshold")) {
			/*
			 * We will re-compress only idle objects equal or
			 * greater in size than watermark.
			 */
			ret = kstrtouint(val, 10, &threshold);
			if (ret)
				return ret;
			continue;
		}

		if (!strcmp(param, "algo")) {
			algo = val;
			continue;
		}

		if (!strcmp(param, "priority")) {
			ret = kstrtouint(val, 10, &prio);
			if (ret)
				return ret;

			if (prio == ZRAM_PRIMARY_COMP)
				prio = ZRAM_SECONDARY_COMP;

			prio_max = min(prio + 1, ZRAM_MAX_COMPS);
			continue;
		}
	}

	if (threshold >= huge_class_size)
		return -EINVAL;

	down_read(&zram->init_lock);
	if (!init_done(zram)) {
		ret = -EINVAL;
		goto release_init_lock;
	}

	/* Do not permit concurrent post-processing actions. */
	if (atomic_xchg(&zram->pp_in_progress, 1)) {
		up_read(&zram->init_lock);
		return -EAGAIN;
	}

	if (algo) {
		bool found = false;

		for (; prio < ZRAM_MAX_COMPS; prio++) {
			if (!zram->comp_algs[prio])
				continue;

			if (!strcmp(zram->comp_algs[prio], algo)) {
				prio_max = min(prio + 1, ZRAM_MAX_COMPS);
				found = true;
				break;
			}
		}

		if (!found) {
			ret = -EINVAL;
			goto release_init_lock;
		}
	}

	page = alloc_page(GFP_KERNEL);
	if (!page) {
		ret = -ENOMEM;
		goto release_init_lock;
	}

	ret = len;
	for (index = 0; index < nr_pages; index++) {
		int err = 0;

		if (!num_recomp_pages)
			break;

		zram_slot_lock(zram, index);

		if (!zram_allocated(zram, index))
			goto next;

		if (mode & RECOMPRESS_IDLE &&
		    !zram_test_flag(zram, index, ZRAM_IDLE))
			goto next;

		if (mode & RECOMPRESS_HUGE &&
		    !zram_test_flag(zram, index, ZRAM_HUGE))
			goto next;

		if (zram_test_flag(zram, index, ZRAM_WB) ||
		    zram_test_flag(zram, index, ZRAM_UNDER_WB) ||
		    zram_test_flag(zram, index, ZRAM_SAME) ||
		    zram_test_flag(zram, index, ZRAM_INCOMPRESSIBLE))
			goto next;

		err = zram_recompress(zram, index, page, &num_recomp_pages,
				      threshold, prio, prio_max);
next:
		zram_slot_unlock(zram, index);
		if (err) {
			ret = err;
			break;
		}

		cond_resched();
	}

	__free_page(page);

release_init_lock:
	atomic_set(&zram->pp_in_progress, 0);
	up_read(&zram->init_lock);
	return ret;
}
#endif


/* Original lines 2310-2360 */
static DEVICE_ATTR_RW(disksize);
static DEVICE_ATTR_RO(initstate);
static DEVICE_ATTR_WO(reset);
static DEVICE_ATTR_WO(mem_limit);
static DEVICE_ATTR_WO(mem_used_max);
static DEVICE_ATTR_WO(idle);
static DEVICE_ATTR_RW(max_comp_streams);
static DEVICE_ATTR_RW(comp_algorithm);
#ifdef CONFIG_ZRAM_WRITEBACK
static DEVICE_ATTR_RW(backing_dev);
static DEVICE_ATTR_WO(writeback);
static DEVICE_ATTR_RW(writeback_limit);
static DEVICE_ATTR_RW(writeback_limit_enable);
#endif
#ifdef CONFIG_ZRAM_MULTI_COMP
static DEVICE_ATTR_RW(recomp_algorithm);
static DEVICE_ATTR_WO(recompress);
#endif
static DEVICE_ATTR_WO(algorithm_params);

static struct attribute *zram_disk_attrs[] = {
	&dev_attr_disksize.attr,
	&dev_attr_initstate.attr,
	&dev_attr_reset.attr,
	&dev_attr_compact.attr,
	&dev_attr_mem_limit.attr,
	&dev_attr_mem_used_max.attr,
	&dev_attr_idle.attr,
	&dev_attr_max_comp_streams.attr,
	&dev_attr_comp_algorithm.attr,
#ifdef CONFIG_ZRAM_WRITEBACK
	&dev_attr_backing_dev.attr,
	&dev_attr_writeback.attr,
	&dev_attr_writeback_limit.attr,
	&dev_attr_writeback_limit_enable.attr,
#endif
	&dev_attr_io_stat.attr,
	&dev_attr_mm_stat.attr,
#ifdef CONFIG_ZRAM_WRITEBACK
	&dev_attr_bd_stat.attr,
#endif
	&dev_attr_debug_stat.attr,
#ifdef CONFIG_ZRAM_MULTI_COMP
	&dev_attr_recomp_algorithm.attr,
	&dev_attr_recompress.attr,
#endif
	&dev_attr_algorithm_params.attr,
	NULL,
};

ATTRIBUTE_GROUPS(zram_disk);
