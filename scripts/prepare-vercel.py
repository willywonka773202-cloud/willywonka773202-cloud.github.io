"""Prepare a strictly allowlisted Vercel Build Output API deployment."""
from pathlib import Path
import json,shutil,runpy,sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from site_files import ROOT,public_files
runpy.run_path(str(ROOT/'scripts/build.py'))
runpy.run_path(str(ROOT/'scripts/package-site.py'))
out=ROOT/'dist/.vercel/output';static=out/'static';static.mkdir(parents=True,exist_ok=True)
files=public_files();allowed=set(files)|{'robots.txt'}
for old in static.rglob('*'):
 if old.is_file() and old.relative_to(static).as_posix() not in allowed:old.unlink()
for name in files:
 dest=static/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dest)
(static/'robots.txt').write_text('User-agent: *\nAllow: /\nSitemap: https://will-lambert-portfolio.vercel.app/sitemap.xml\n')
(out/'config.json').write_text(json.dumps({'version':3,'routes':[{'handle':'filesystem'},{'src':'/.*','status':404,'dest':'/404.html'}]})+'\n')
function=out/'functions/api/channel.func'
(function/'api').mkdir(parents=True,exist_ok=True)
(function/'data').mkdir(exist_ok=True)
shutil.copy2(ROOT/'api/channel.cjs',function/'api/channel.cjs')
shutil.copy2(ROOT/'data/channel.json',function/'data/channel.json')
(function/'.vc-config.json').write_text(json.dumps({'runtime':'nodejs22.x','handler':'api/channel.cjs','launcherType':'Nodejs','maxDuration':10})+'\n')
assert not list(static.rglob('.env*'))
print('Prepared Vercel output; private documentation and draft posts excluded.')
