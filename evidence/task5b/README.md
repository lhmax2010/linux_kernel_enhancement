# 任务5b：QB分支核对停止证据

日期2026-10-30（Asia/Shanghai）。本轮没有访问开发板；按PM的来源核对停止条件收尾，不把尚未执行的配置/perf/BPF核对标为完成。

| 文件 | 内容 |
| --- | --- |
| [design_move.txt](design_move.txt) | 设计文件从Downloads移动、原位置不存在、字节数与SHA256 |
| [qb_1211696_page.txt](qb_1211696_page.txt) | 登录后页面的相关字段；移除登录用户/Triggered By，不保存凭据 |
| [provenance_gate.txt](provenance_gate.txt) | SHA匹配、PROJECT_BRANCH=tizen、时间时区限制、停止原因 |
| [browser_cleanup.txt](browser_cleanup.txt) | 有界面浏览器、用户自行登录、会话目录清理结果 |
| [local_manifest.tsv](local_manifest.tsv) | 本地文本/脚本/截图的大小及哈希；截图仅在temp，不上传 |
| [manifest.sha256](manifest.sha256) | 本目录发布文本的SHA256，不含清单自身 |

源码SHA匹配是正向证据；PROJECT_BRANCH是项目级变量，不能据此断言内核源码错误。此次未取得包级sandbox分支证明，PM要求分支必须相符，本轮不自行放行。两个RPM没有下载，因此不存在其文件大小、RPM哈希、最终.config或新的perf测试结果。

设计文档[10](../../docs/10_design_v1.md)保持PM原字节；更新情况见[09](../../docs/09_board_rpi4_readonly.md)及[STATUS](../../docs/STATUS.md)。
