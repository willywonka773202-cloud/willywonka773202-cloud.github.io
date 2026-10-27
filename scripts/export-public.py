#!/usr/bin/env python3
"""Copy reviewed source to the dedicated public checkout; never stage the root."""
import json,shutil,subprocess
from pathlib import Path
from site_files import ROOT,public_files
DEST=ROOT/'docs/audit-20261004/portfolio-public'
assert DEST.is_dir(),'Public checkout missing'
assert subprocess.check_output(['git','status','--porcelain'],cwd=DEST,text=True).strip()=='','Public checkout has unreviewed changes'
files=set(public_files())|{'README.md','PUBLICATION.md','.gitattributes','.gitignore','.nojekyll','data/projects.json','data/categories.json','data/updates.json','data/channel.json','data/social-metrics.json'}
for directory in ['scripts','templates','api']:
 files.update(str(p.relative_to(ROOT)) for p in (ROOT/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
tracked=set(subprocess.check_output(['git','ls-files'],cwd=DEST,text=True).splitlines())
assert not tracked-files,f'Review removed public files before export: {sorted(tracked-files)}'
for name in files:
 target=DEST/name;target.parent.mkdir(parents=True,exist_ok=True)
 if name=='data/projects.json':
  data=json.loads((ROOT/name).read_text())
  for project in data:project.pop('source',None)
  target.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 elif name=='data/updates.json':
  data=[u for u in json.loads((ROOT/name).read_text()) if u.get('published') is True]
  target.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 elif name=='.nojekyll':target.touch()
 else:shutil.copy2(ROOT/name,target)
print(f'Exported {len(files)} reviewed public files. Review diff and secret scan before commit.')
