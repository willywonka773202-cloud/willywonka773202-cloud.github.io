from pathlib import Path
import shutil,sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from site_files import ROOT,public_files
out=ROOT/'dist';out.mkdir(exist_ok=True);files=public_files()
# Dist is generated. Preserve Vercel linkage/config, remove obsolete public content.
for old in out.rglob('*'):
 rel=old.relative_to(out)
 if '.vercel' in rel.parts or old.name.startswith('.env'):continue
 if old.is_file() and str(rel) not in files and old.name!='.nojekyll':old.unlink()
for f in files:
 dest=out/f;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/f,dest)
(out/'.nojekyll').touch()
print('Prepared allowlisted public files in dist/.')
