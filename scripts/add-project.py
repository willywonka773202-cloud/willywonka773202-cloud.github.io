#!/usr/bin/env python3
"""Add a reviewed project without editing page layouts. Rebuild afterward."""
import argparse,json,re,datetime
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--name',required=True);p.add_argument('--summary',required=True)
p.add_argument('--category',required=True,choices=['AI systems','Web & commerce','Games','Everyday tools','Creative tools','Research','Experiments'])
p.add_argument('--status',default='In progress',choices=['Built','In progress','Prototype','Research','Archived','Needs review'])
p.add_argument('--source',required=True,help='Public-safe source description; no private paths')
p.add_argument('--repo');p.add_argument('--demo')
a=vars(p.parse_args());a['id']=re.sub('[^a-z0-9]+','-',a['name'].lower()).strip('-');a['updated']=str(datetime.date.today());a['tags']=[];a['role']='Product direction and AI-assisted development'
path=Path(__file__).resolve().parents[1]/'data/projects.json';data=json.loads(path.read_text())
if any(x['id']==a['id'] for x in data):p.error('Project exists. Update its existing JSON record instead.')
for key in ['repo','demo']:
 if a[key] and not a[key].startswith('https://'):p.error(key+' must start with https://')
data.append({k:v for k,v in a.items() if v is not None})
path.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n')
print('Added '+a['name']+'. Run python3 scripts/build.py to refresh the portfolio.')
