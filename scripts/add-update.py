#!/usr/bin/env python3
"""Create a private draft. Publication is an explicit separate review step."""
import argparse,json,re
from datetime import date
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--title',required=True);parser.add_argument('--summary',required=True)
parser.add_argument('--type',choices=['Build log','Check-in','Notes','News'],default='Check-in')
parser.add_argument('--date',default=date.today().isoformat(),help='Publication date, YYYY-MM-DD')
parser.add_argument('--paragraph',action='append',required=True,help='Repeat for each paragraph')
a=parser.parse_args();date.fromisoformat(a.date)
path=Path(__file__).resolve().parents[1]/'data/updates.json';posts=json.loads(path.read_text())
slug=re.sub(r'[^a-z0-9]+','-',a.title.lower()).strip('-');assert slug and slug not in [p['id'] for p in posts],'Use a unique title'
posts.append(dict(id=slug,date=a.date,type=a.type,title=a.title,summary=a.summary,body=a.paragraph,links=[],published=False))
path.write_text(json.dumps(posts,ensure_ascii=False,indent=2)+'\n')
print('Draft saved. Review it, set published to true, then rebuild and deploy. Nothing uploaded.')
