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
p.add_argument('--image',help='Reviewed image path inside assets/')
p.add_argument('--caption',help='Describe what the image actually shows')
p.add_argument('--media-kind',choices=['Screenshot','Marketing artwork'],default='Screenshot')
p.add_argument('--step',action='append',help='A documented workflow step; supply three when there is no screenshot')
a=vars(p.parse_args());a['id']=re.sub('[^a-z0-9]+','-',a['name'].lower()).strip('-');a['updated']=str(datetime.date.today());a['tags']=[];a['role']='Product direction and AI-assisted development'
path=Path(__file__).resolve().parents[1]/'data/projects.json';data=json.loads(path.read_text())
if any(x['id']==a['id'] for x in data):p.error('Project exists. Update its existing JSON record instead.')
steps=a.pop('step')
if a['image']:
 if not a['image'].startswith('assets/') or '..' in Path(a['image']).parts or not (path.parent.parent/a['image']).is_file():p.error('Image must be an existing file inside assets/')
 if not a['caption']:p.error('Describe the image with --caption')
else:
 if not steps or len(steps)!=3:p.error('Supply an image and caption, or three documented --step values for a labeled project map')
 a.update(image='assets/maps/'+a['id']+'.svg',media_kind='Project map',workflow=steps,caption='Project map of the documented idea and intended workflow. This is an explanatory diagram, not a screenshot of the product.')
a['gallery']=[{'src':a['image'],'caption':a['caption'],'kind':a['media_kind']}]
for key in ['repo','demo']:
 if a[key] and not a[key].startswith('https://'):p.error(key+' must start with https://')
data.append({k:v for k,v in a.items() if v is not None})
path.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n')
print('Added '+a['name']+'. Run python3 scripts/build.py to refresh the portfolio.')
