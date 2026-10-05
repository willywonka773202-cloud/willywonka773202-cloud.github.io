"""One explicit publication allowlist shared by local packaging and Vercel."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def public_files():
 files={'index.html','archive.html','updates.html','404.html','feed.xml','sitemap.xml','style.css','app.js','favicon.png','apple-touch-icon.png','resume/Will-Lambert-Resume.pdf','assets/portfolio-social.png'}
 for p in json.loads((ROOT/'data/projects.json').read_text()):
  files.add('projects/'+p['id']+'.html')
  if p.get('image'):files.add(p['image'])
 for u in json.loads((ROOT/'data/updates.json').read_text()):
  if u.get('published') is True:files.add('updates/'+u['id']+'.html')
 files.update(str(p.relative_to(ROOT)) for p in (ROOT/'assets/fonts').glob('*') if p.is_file())
 assert all(not p.startswith(('/', '.')) and '..' not in p.split('/') for p in files)
 return sorted(files)
