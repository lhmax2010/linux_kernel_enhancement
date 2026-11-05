from pathlib import Path
import sys,json,copy,hashlib
W=Path('/home/linhao/Toolchain/development/linux_kernel_optimization');sys.path.insert(0,str(W/'scripts/deploy'))
from module_metadata import *
D=W/'temp/task23/artifacts/deploy_lko-base01-r2';ref=load_reference(W/'evidence/task23/sr_module_reference.json');release='6.12.80-arm-rpi4-v7l-lko-base01';prefix='lib/modules/'+release
rows=json.loads((D/'metadata.json').read_text())['entries'];tests=[]
r=verify_archive(D/'deploy_lko-base01-r2.tar.gz',rows,ref,release);tests.append({'case':'r2 full archive','expected':True,'actual':r['pass'],'detail':r})
old=W/'temp/task9/deploy_lko-base01/deploy_lko-base01.tar.gz';assert hashlib.sha256(old.read_bytes()).hexdigest()=='583fbb45389f3b98a8498c09f4acb9a2a73a4b074439bdae6df663cbeaeeb61c'
r=check(archive_rows(old),ref,release);tests.append({'case':'old archive permissions defect','expected':False,'actual':r['pass'],'detail':r})
for title,path,key,value in [('no directory search',prefix+'/extra','mode','0700'),('no file others read',prefix+'/extra/proc-tsm.ko','mode','0600'),('wrong owner',prefix+'/extra','uid',1000),('wrong symlink',prefix+'/build','link_target','/unexpected')]:
 x=copy.deepcopy(rows);x[path][key]=value;r=check(x,ref,release);tests.append({'case':title,'expected':False,'actual':r['pass'],'detail':r})
assert all(t['actual']==t['expected'] for t in tests)
result={'pass':True,'cases':tests};(W/'temp/task23/metadata_tests.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
