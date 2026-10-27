# 源码核对快照

仅包含 PM 请求的相关文件或片段，不是整棵源码树。片段文件不可直接作为完整源文件编译。

| 文件 | 内核 commit | 原始行号 | 上传原因 |
| --- | --- | --- | --- |
| [563c53c427bf/mm/memcontrol-v1.c](563c53c427bf/mm/memcontrol-v1.c) | `563c53c427bff4d685d18544a8f4f6db14be9368` | 2405–2486 | 任务2：已拆入的 mem_cgroup_force_reclaim 函数及前后各20行，供PM核对。 |

任务2续：base仅amend标题至 `f240c28093027707f5e09f8a9cbbed16a43ebb1a`，与上述563c53c4的tree相同，快照片段仍适用；不重复上传相同源码。验证见[base_amend_r2.txt](../evidence/task2/base_amend_r2.txt)。
