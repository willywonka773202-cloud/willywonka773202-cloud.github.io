#!/usr/bin/env python3
"""Record one verified public snapshot. Usage: record-social-metrics.py checked.json.
Read all three public profiles first. Input has checkedAt (ISO UTC), youtube
(subscribers/videos/views), tiktok (followers/likes/likesDisplay/likesApproximate),
and x (followers/posts). Never estimate a missing count or include private data.
"""
import json,sys
from pathlib import Path
from datetime import datetime,timezone,timedelta
ROOT=Path(__file__).resolve().parents[1]
def validate(s):
 assert set(s)=={'checkedAt','youtube','tiktok','x'},'Unexpected fields'
 checked=datetime.fromisoformat(s['checkedAt'].replace('Z','+00:00'))
 assert checked.tzinfo is not None,'Timestamp needs a timezone'
 assert checked<=datetime.now(timezone.utc)+timedelta(minutes=5),'Future observation'
 for platform,fields in {'youtube':{'subscribers','videos','views'},'tiktok':{'followers','likes','likesDisplay','likesApproximate'},'x':{'followers','posts'}}.items():
  assert set(s[platform])==fields,'Unexpected metric fields'
  for k,v in s[platform].items():
   if k in ['likesDisplay','likesApproximate']:continue
   assert type(v) is int and 0<=v<=10**12,'Count must be a nonnegative integer'
 assert type(s['tiktok']['likesApproximate']) is bool
 import re
 display=s['tiktok']['likesDisplay']
 assert isinstance(display,str) and re.fullmatch(r'\d+(?:\.\d+)?[KMB]?',display),'Invalid public likes display'
 unit=display[-1] if display[-1] in 'KMB' else ''
 value=float(display[:-1] if unit else display)*{'':1,'K':1000,'M':1000000,'B':1000000000}[unit]
 assert int(value)==s['tiktok']['likes'],'Likes display disagrees with numeric value'
 assert bool(unit)==s['tiktok']['likesApproximate'],'Rounded-display flag disagrees'
 return checked
if __name__=='__main__':
 assert len(sys.argv)==2,__doc__
 observation=json.loads(Path(sys.argv[1]).read_text());checked=validate(observation)
 path=ROOT/'data/social-metrics.json';data=json.loads(path.read_text())
 previous=data['snapshots'][-1]
 assert checked>=validate(previous),'Cannot replace a newer observation'
 # Keep one observation per UTC date; preserve weekly history across deployments.
 history=[s for s in data['snapshots'] if s['checkedAt'][:10]!=observation['checkedAt'][:10]]
 history.append(observation);data['snapshots']=history[-104:]
 tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(data,indent=2)+'\n');tmp.replace(path)
 print('Saved verified public social snapshot:',observation['checkedAt'])
