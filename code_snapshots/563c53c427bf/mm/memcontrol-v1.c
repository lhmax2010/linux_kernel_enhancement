/* Source: mm/memcontrol-v1.c; commit: 563c53c427bff4d685d18544a8f4f6db14be9368; original lines 2405-2486.
 * Excerpt only: mem_cgroup_force_reclaim plus 20 lines before/after.
 */
		if (!try_to_free_mem_cgroup_pages(memcg, 1, GFP_KERNEL,
						  MEMCG_RECLAIM_MAY_SWAP, NULL))
			nr_retries--;
	}

	return 0;
}

static ssize_t mem_cgroup_force_empty_write(struct kernfs_open_file *of,
					    char *buf, size_t nbytes,
					    loff_t off)
{
	struct mem_cgroup *memcg = mem_cgroup_from_css(of_css(of));

	if (mem_cgroup_is_root(memcg))
		return -EINVAL;
	return mem_cgroup_force_empty(memcg) ?: nbytes;
}

#if defined(CONFIG_MEMCG_V1) && defined(CONFIG_SWAP)
static int mem_cgroup_force_reclaim(struct cgroup_subsys_state *css,
				struct cftype *cft, u64 val)
{
	struct mem_cgroup *memcg = mem_cgroup_from_css(css);
	unsigned long nr_to_reclaim;
	unsigned long total = 0;
	unsigned int no_progress = 0;
	int loop;

	if (val > ULONG_MAX)
		return -ERANGE;
	nr_to_reclaim = val;

	if (!nr_to_reclaim)
		return 0;

	for (loop = 0; loop < MEM_CGROUP_MAX_RECLAIM_LOOPS; loop++) {
		unsigned long reclaimed;

		reclaimed = try_to_free_mem_cgroup_pages(memcg, nr_to_reclaim - total,
						GFP_KERNEL, MEMCG_RECLAIM_MAY_SWAP, NULL);
		total += reclaimed;
		if (reclaimed)
			no_progress = 0;
		else
			no_progress++;

		/*
		 * If two consecutive attempts reclaimed nothing, there
		 * may be no reclaimable pages in this hierarchy.
		 * If at least nr_to_reclaim pages were already reclaimed,
		 * finish force reclaim.
		 */
		if (total >= nr_to_reclaim || no_progress >= 2)
			break;
	}

	pr_info("%s: [Mem_reclaim] Loop: %d - Total_reclaimed: %lu - nr_to_reclaim: %lu\n",
		__func__, loop, total, nr_to_reclaim);

	return 0;
}
#endif

static u64 mem_cgroup_hierarchy_read(struct cgroup_subsys_state *css,
				     struct cftype *cft)
{
	return 1;
}

static int mem_cgroup_hierarchy_write(struct cgroup_subsys_state *css,
				      struct cftype *cft, u64 val)
{
	if (val == 1)
		return 0;

	pr_warn_once("Non-hierarchical mode is deprecated. "
		     "Please report your usecase to linux-mm@kvack.org if you "
		     "depend on this functionality.\n");

	return -EINVAL;
}
