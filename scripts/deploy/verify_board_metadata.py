from pathlib import Path
import sys,json,re,stat,hashlib
W=Path('/home/linhao/Toolchain/development/linux_kernel_optimization');sys.path.insert(0,str(W/'scripts/deploy'))
from module_metadata import kind,check,load_reference
source=Path(sys.argv[1]);output=Path(sys.argv[2]);release='6.12.80-arm-rpi4-v7l-lko-base01';rows={};s=source.read_text();prefix='/usr/'
for line in s.splitlines():
 if line.startswith('META|'):
  _,rawmode,uid,gid,mode,size,name=line.split('|',6);typ=kind(int(rawmode,16));rows[name.removeprefix(prefix)]={'type':typ,'uid':int(uid),'gid':int(gid),'mode':mode.zfill(4),'bytes':int(size) if typ=='file' else None,'link_target':None,'sha256':None}
for h,n in re.findall(r'(?m)^([0-9a-f]{64})  (.+)$',s):rows[n.removeprefix(prefix)]['sha256']=h
for n,target in re.findall(r'(?m)^LINK\|([^|]+)\|(.+)$',s):
 row=rows[n.removeprefix(prefix)];row['link_target']=target;row['sha256']=hashlib.sha256(target.encode()).hexdigest()
manifest=json.loads((W/'temp/task23/artifacts/deploy_lko-base01-r2/metadata.json').read_text())['entries'];expected={k:v for k,v in manifest.items() if k.startswith('lib/modules/'+release)}
result=check(rows,load_reference(W/'evidence/task23/sr_module_reference.json'),release)
result['manifest_mismatches']=[k for k in sorted(rows.keys()|expected.keys()) if rows.get(k)!=expected.get(k)];result['pass']=result['pass'] and not result['manifest_mismatches'];result['rows']=rows
output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='rows'},indent=2));assert result['pass']
