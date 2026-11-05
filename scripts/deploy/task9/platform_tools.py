from pathlib import Path
import os,subprocess,shlex,json
W=Path('/home/linhao/Toolchain/development/linux_kernel_optimization')
T=Path(os.environ.get('LKO_TASK_ROOT', W/'temp/task9')); V=T/'verify'; R=W/'temp/task9/GBS-ROOT-LKO-BASE01/local/BUILD-ROOTS/scratch.armv7l.0'; N=V/'namespace_home'
for p in [N/'abuild',N/T.relative_to('/home'),V/'tmp']:
 p.mkdir(parents=True,exist_ok=True)
def argv(tool,*args,cwd=None):
 return ['/usr/bin/bwrap','--unshare-user','--unshare-pid','--uid','0','--gid','0','--ro-bind',str(R),'/','--bind',str(N),'/home','--ro-bind',str(R/'home/abuild'),'/home/abuild','--ro-bind',str(W),str(W),'--bind',str(T),str(T),'--proc','/proc','--dev','/dev','--chdir',str(cwd or V),'--clearenv','--setenv','HOME',str(V),'--setenv','TMPDIR',str(V/'tmp'),'--setenv','PYTHONDONTWRITEBYTECODE','1','--setenv','PATH','/usr/bin:/bin:/usr/sbin:/sbin','--setenv','LC_ALL','C','--','/usr/bin/qemu-arm','-L','/',str(tool),*map(str,args)]
def run(label,tool,*args,cwd=None,extra_env=None):
 cmd=argv(tool,*args,cwd=cwd)
 for key,value in (extra_env or {}).items():
  i=cmd.index('--');cmd[i:i]=['--setenv',key,str(value)]
 p=subprocess.run(cmd,capture_output=True,text=True,env=dict(os.environ,TMPDIR=str(T/'verify/tmp'),PYTHONDONTWRITEBYTECODE='1'))
 (V/(label+'.txt')).write_text('$ '+shlex.join(cmd)+'\n'+p.stdout+p.stderr+'\nEXIT='+str(p.returncode)+'\n')
 print(label,'EXIT',p.returncode,p.stdout[:1500],p.stderr[:500],flush=True)
 return p

def py_run(label,*args):
 pyhome=W/'temp/task9/verify/platform-python/usr'
 return run(label,pyhome/'bin/python3.14',*args,extra_env={'PYTHONHOME':pyhome,'LD_LIBRARY_PATH':pyhome/'lib','LKO_TASK_ROOT':T})
