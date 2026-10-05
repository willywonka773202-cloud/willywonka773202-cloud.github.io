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
print(f'PASS: {len(parsed)} pages; all local links and anchors; RSS/sitemap; publication allowlist; draft and removed-project exclusions.')
