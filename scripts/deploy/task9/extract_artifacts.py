from platform_tools import *
import hashlib,shutil
repo=W/'temp/task9/GBS-ROOT-LKO-BASE01/local/repos/tizen_unified_standard/armv7l/RPMS'
packages=[
 ('kernel','arm-rpi4-linux-kernel',V/'extract-kernel',['./boot/zImage']),
 ('kernel_rt','arm-rpi4-rt-linux-kernel',V/'extract-kernel-rt',['./boot/zImage_rt']),
 ('kernel_modules','arm-rpi4-linux-kernel-modules',T/'stage',[]),
 ('external_modules','linux-tizen-modules-rpi4',V/'extract-extra',[]),
 ('devel','arm-rpi4-linux-kernel-devel',V/'extract-devel',['*/.config','*/Module.symvers','*/include/generated/compile.h','*/include/config/kernel.release','*/include/generated/utsrelease.h']),
 ('devel_rt','arm-rpi4-rt-linux-kernel-devel',V/'extract-devel-rt',['*/.config','*/Module.symvers','*/include/generated/compile.h','*/include/config/kernel.release','*/include/generated/utsrelease.h'])]
if os.environ.get('LKO_DEPLOY_ONLY') == '1':
 packages=[x for x in packages if x[0] in ('kernel','kernel_modules','external_modules')]
for label,name,dest,patterns in packages:
 f=list(repo.glob(name+'-[0-9]*.armv7l.rpm'));assert len(f)==1,f
 assert not dest.exists(),dest;dest.mkdir()
 p=run(label+'_rpm_files','/usr/bin/rpm','-qpl',f[0]);assert p.returncode==0
 cpio=V/(label+'.cpio');assert not cpio.exists()
 cmd=argv('/usr/bin/rpm2cpio',f[0])
 with cpio.open('wb') as out:r=subprocess.run(cmd,stdout=out,stderr=subprocess.PIPE)
 (V/(label+'_rpm2cpio.txt')).write_text('$ '+shlex.join(cmd)+'\n'+r.stderr.decode(errors='replace')+'\nEXIT='+str(r.returncode)+'\n');assert r.returncode==0
 cmd=argv('/usr/bin/cpio','-id','--no-absolute-filenames','--no-preserve-owner',*patterns,cwd=dest)
 with cpio.open('rb') as inp:r=subprocess.run(cmd,stdin=inp,capture_output=True)
 (V/(label+'_extract.txt')).write_text('$ '+shlex.join(cmd)+'\n'+r.stdout.decode(errors='replace')+r.stderr.decode(errors='replace')+'\nEXIT='+str(r.returncode)+'\n');assert r.returncode==0
 if label in ('kernel_modules','external_modules'):
  module_root=dest/'lib/modules/6.12.80-arm-rpi4-v7l-lko-base01'
  p=py_run(label+'_normalize',W/'scripts/deploy/module_metadata.py','normalize',module_root,'--reference',W/'evidence/task23/sr_module_reference.json','--output',V/(label+'_metadata_normalized.json'));assert p.returncode==0
 print('EXTRACTED',label,flush=True)
