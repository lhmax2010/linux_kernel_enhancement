from pathlib import Path
import os,json,sys
W=Path('/home/linhao/Toolchain/development/linux_kernel_optimization')
T=Path(os.environ.get('LKO_TASK_ROOT',W/'temp/task9'));D=T/'deploy_lko-base01-r2'
sys.path.insert(0,str(W/'scripts/deploy'))
from module_metadata import load_reference,verify_archive
ref=load_reference(W/'evidence/task23/sr_module_reference.json')
manifest=json.loads((D/'metadata.json').read_text())
r=verify_archive(D/'deploy_lko-base01-r2.tar.gz',manifest['entries'],ref,manifest['release'])
print(json.dumps(r,indent=2));assert r['pass'],r
