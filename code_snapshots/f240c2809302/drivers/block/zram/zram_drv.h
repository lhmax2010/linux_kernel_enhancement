/* Source: drivers/block/zram/zram_drv.h; commit f240c28093027707f5e09f8a9cbbed16a43ebb1a; excerpts only, original line ranges below. */

/* Original lines 60-75 */

/*-- Data structures */

/* Allocated for each disk page */
struct zram_table_entry {
	union {
		unsigned long handle;
		unsigned long element;
	};
	unsigned int flags;
	spinlock_t lock;
#ifdef CONFIG_ZRAM_TRACK_ENTRY_ACTIME
	ktime_t ac_time;
#endif
};


/* Original lines 94-103 */

#ifdef CONFIG_ZRAM_MULTI_COMP
#define ZRAM_PRIMARY_COMP	0U
#define ZRAM_SECONDARY_COMP	1U
#define ZRAM_MAX_COMPS	4U
#else
#define ZRAM_PRIMARY_COMP	0U
#define ZRAM_SECONDARY_COMP	0U
#define ZRAM_MAX_COMPS	1U
#endif
