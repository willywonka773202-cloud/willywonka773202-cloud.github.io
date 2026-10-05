#!/usr/bin/env python3
"""Check generated links and prevent accidental private/stale publication."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit,unquote
import argparse,json,sys,xml.etree.ElementTree as ET
from site_files import ROOT,public_files
parser=argparse.ArgumentParser();parser.add_argument('--deployment',action='store_true');args=parser.parse_args()
base=ROOT/'dist/.vercel/output/static' if args.deployment else ROOT
allowed=set(public_files());errors=[]
class Page(HTMLParser):
 def __init__(self,text):
  super().__init__();self.links=[];self.ids=set();self.feed(text)
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if a.get('id'):self.ids.add(a['id'])
  for key in ['href','src']:
   if a.get(key):self.links.append(a[key])
parsed={}
for name in allowed:
 f=base/name
 if not f.is_file():errors.append('Missing: '+name);continue
 if f.suffix=='.html':parsed[name]=Page(f.read_text())
for name,page in parsed.items():
 for link in page.links:
  u=urlsplit(link)
  if u.scheme or u.netloc:continue
  target=(base/u.path.lstrip('/') if u.path.startswith('/') else (base/name).parent/u.path) if u.path else base/name
  if u.path.endswith('/'):target=target/'index.html'
  try:rel=target.resolve().relative_to(base.resolve()).as_posix()
  except ValueError:errors.append(name+': outside public root');continue
  if rel not in allowed:errors.append(name+': unlisted target '+rel)
  elif not target.is_file():errors.append(name+': missing '+rel)
  elif u.fragment and rel in parsed and unquote(u.fragment) not in parsed[rel].ids:errors.append(name+': missing anchor '+link)
for name in ['feed.xml','sitemap.xml']:ET.parse(base/name)
# Each catalog entry must appear once, under its intended project type.
class Collection(HTMLParser):
 def __init__(self,text):
  super().__init__();self.sections=[];self.groups={};self.entries=[];self.feed(text)
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='section':
   key=a.get('data-project-group');self.sections.append(key)
   if key:
    if key in self.groups:errors.append('Duplicate project type: '+key)
    self.groups[key]=[]
  if 'project-row' in a.get('class','').split():
   group=next((x for x in reversed(self.sections) if x),None)
   entry=(a.get('href'),a.get('data-category'));self.entries.append(entry)
   if group!=entry[1]:errors.append('Project placed under incorrect type: '+str(entry[0]))
   if group in self.groups:self.groups[group].append(entry)
 def handle_endtag(self,tag):
  if tag=='section' and self.sections:self.sections.pop()
collection=Collection((base/'archive.html').read_text())
projects=json.loads((ROOT/'data/projects.json').read_text())
categories=json.loads((ROOT/'data/categories.json').read_text())
expected=[('projects/'+p['id']+'.html',p['category']) for p in projects]
if sorted(collection.entries)!=sorted(expected):errors.append('Project collection has missing, duplicate, or unexpected entries')
if list(collection.groups)!=[c['key'] for c in categories]:errors.append('Project type order differs from the category index')
if not all(collection.groups.values()):errors.append('Empty project type section')
# Regressions for a removed company project and accidentally included private notes.
for name in allowed:
 if any(s in name for s in ['docs/','.env','data/']):errors.append('Private/stale publication path: '+name)
 f=base/name
 if f.is_file() and f.suffix in ['.html','.js','.css','.xml']:
  t=f.read_text()
  for phrase in ['/Users/','{{']:
   if phrase in t:errors.append(name+': forbidden content '+phrase)
for u in json.loads((ROOT/'data/updates.json').read_text()):
 if u.get('published') is not True and ('updates/'+u['id']+'.html' in allowed or (base/'updates'/f'{u["id"]}.html').exists()):errors.append('Draft is publicly reachable: '+u['id'])
if args.deployment:
 for p in base.rglob('*'):
  if p.is_file() and p.relative_to(base).as_posix() not in allowed|{'robots.txt'}:errors.append('Unexpected deployed file: '+p.relative_to(base).as_posix())
if errors:
 print('\n'.join(errors));sys.exit(1)
print(f'PASS: {len(parsed)} pages; {len(projects)} projects grouped into {len(categories)} types; all local links and anchors; RSS/sitemap; publication allowlist; draft and removed-project exclusions.')
