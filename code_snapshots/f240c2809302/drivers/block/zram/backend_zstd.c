/* Source: drivers/block/zram/backend_zstd.c; commit f240c28093027707f5e09f8a9cbbed16a43ebb1a; excerpts only, original line ranges below. */

/* Original lines 60-94 */
static int zstd_setup_params(struct zcomp_params *params)
{
	zstd_compression_parameters prm;
	struct zstd_params *zp;

	zp = kzalloc(sizeof(*zp), GFP_KERNEL);
	if (!zp)
		return -ENOMEM;

	params->drv_data = zp;
	if (params->level == ZCOMP_PARAM_NO_LEVEL)
		params->level = zstd_default_clevel();

	zp->cprm = zstd_get_params(params->level, PAGE_SIZE);

	zp->custom_mem.customAlloc = zstd_custom_alloc;
	zp->custom_mem.customFree = zstd_custom_free;

	prm = zstd_get_cparams(params->level, PAGE_SIZE,
			       params->dict_sz);

	zp->cdict = zstd_create_cdict_byreference(params->dict,
						  params->dict_sz,
						  prm,
						  zp->custom_mem);
	if (!zp->cdict)
		goto error;

	zp->ddict = zstd_create_ddict_byreference(params->dict,
						  params->dict_sz,
						  zp->custom_mem);
	if (!zp->ddict)
		goto error;

	return 0;

/* Original lines 178-215 */
static int zstd_compress(struct zcomp_params *params, struct zcomp_ctx *ctx,
			 struct zcomp_req *req)
{
	struct zstd_params *zp = params->drv_data;
	struct zstd_ctx *zctx = ctx->context;
	size_t ret;

	if (params->dict_sz == 0)
		ret = zstd_compress_cctx(zctx->cctx, req->dst, req->dst_len,
					 req->src, req->src_len, &zp->cprm);
	else
		ret = zstd_compress_using_cdict(zctx->cctx, req->dst,
						req->dst_len, req->src,
						req->src_len,
						zp->cdict);
	if (zstd_is_error(ret))
		return -EINVAL;
	req->dst_len = ret;
	return 0;
}

static int zstd_decompress(struct zcomp_params *params, struct zcomp_ctx *ctx,
			   struct zcomp_req *req)
{
	struct zstd_params *zp = params->drv_data;
	struct zstd_ctx *zctx = ctx->context;
	size_t ret;

	if (params->dict_sz == 0)
		ret = zstd_decompress_dctx(zctx->dctx, req->dst, req->dst_len,
					   req->src, req->src_len);
	else
		ret = zstd_decompress_using_ddict(zctx->dctx, req->dst,
						  req->dst_len, req->src,
						  req->src_len, zp->ddict);
	if (zstd_is_error(ret))
		return -EINVAL;
	return 0;
