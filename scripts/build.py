#!/usr/bin/env python3
"""Build the public portfolio from reviewed data. Python standard library only."""
from pathlib import Path
from html import escape
from datetime import date
from urllib.parse import urlparse
import json,re
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
SITE='https://will-lambert-portfolio.vercel.app'
VERSION='20261004'
P=json.loads((ROOT/'data/projects.json').read_text())
U=[u for u in json.loads((ROOT/'data/updates.json').read_text()) if u.get('published') is True]
U.sort(key=lambda u:(u['date'],u['id']),reverse=True)
def e(x):return escape(str(x),quote=True)
def valid_id(i):return bool(re.fullmatch(r'[a-z0-9-]+',i))
def safe_url(s):
 u=urlparse(s)
 assert (u.scheme == 'https' and u.netloc) or (not u.scheme and not u.netloc), 'Invalid public URL'
 assert not u.username and not u.password, 'Credentials cannot appear in links'
 assert not s.startswith('//') and '..' not in u.path.split('/')
 return s
def badge(p):return f'<span class="badge {e(p["status"].lower().replace(" ","-"))}">{e(p["status"])}</span>'
def url(p):return f'projects/{p["id"]}.html'
def pretty_date(value):return date.fromisoformat(value).strftime('%b %d, %Y').replace(' 0',' ')
def header(active='',prefix=''):
 links=[('Projects','archive.html'),('Updates','updates.html'),('About','index.html#about')]
 nav=''.join(f'<a href="{prefix}{href}"'+(' aria-current="page"' if name==active else '')+f'>{name}</a>' for name,href in links)
 return f'''<header class="site-header"><a class="monogram" href="{prefix}index.html" aria-label="Will Lambert home">WL<span class="logo-dot"></span></a><div class="header-practice">CURIOUS BY NATURE<br>BUILDING WITH AI<br>LEARNING BY DOING</div><nav aria-label="Main navigation">{nav}</nav><button class="theme-toggle" type="button" aria-label="Switch to light theme" aria-pressed="false"><span aria-hidden="true">◐</span></button><a class="header-availability" href="{prefix}index.html#contact"><span><i class="status-dot"></i> OPEN TO OPPORTUNITIES</span><strong>San Diego / Remote <span aria-hidden="true">↗</span></strong></a></header>'''
def footer(prefix=''):
 return f'<footer><span>© 2026 WILL LAMBERT</span><a href="{prefix}updates.html">Updates</a><a href="{prefix}feed.xml">RSS</a><a href="https://github.com/willywonka773202-cloud" target="_blank" rel="noopener noreferrer">GitHub ↗</a><a href="{prefix}index.html#contact">Contact ↗</a></footer>'
def head(title,description,path,prefix=''):
 return f'''<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{e(title)} — Will Lambert</title><meta name="description" content="{e(description)}"><meta name="theme-color" content="#090909"><link rel="canonical" href="{SITE}/{path}"><meta property="og:type" content="website"><meta property="og:title" content="{e(title)} — Will Lambert"><meta property="og:description" content="{e(description)}"><meta property="og:url" content="{SITE}/{path}"><meta property="og:image" content="{SITE}/assets/portfolio-social.png"><meta name="twitter:card" content="summary_large_image"><link rel="icon" href="{prefix}favicon.png"><link rel="alternate" type="application/rss+xml" title="Will Lambert — Updates" href="{prefix}feed.xml"><link rel="stylesheet" href="{prefix}style.css?v={VERSION}"><script src="{prefix}app.js?v={VERSION}" defer></script>'''
def page(title,desc,path,body,active='',prefix=''):
 return f'<!doctype html><html lang="en"><head>{head(title,desc,path,prefix)}</head><body><a class="skip" href="#main">Skip to content</a>{header(active,prefix)}{body}{footer(prefix)}</body></html>'
for items in [P,U]:
 ids=[x['id'] for x in items];assert len(ids)==len(set(ids)) and all(valid_id(i) for i in ids)
for p in P:
 assert p['status'] in ['Built','In progress','Prototype','Research','Archived','Needs review']
 for key in ['repo','demo']:
  if p.get(key):assert p[key].startswith('https://');safe_url(p[key])
for u in U:
 date.fromisoformat(u['date']);assert u['type'] in ['Build log','Check-in','Notes','News']
 assert u['title'] and u['summary'] and u['body']
 for link in u.get('links',[]):safe_url(link['url'])
order=['goodturn','sylistly','bert-ai']
featured=[next(p for p in P if p['id']==i) for i in order]
cards=[]
for n,p in enumerate(featured,1):
 media=f'<figure class="feature-media"><img src="{e(p["image"])}" alt="{e(p["caption"])}" loading="lazy" width="1280" height="720"><figcaption>{e(p["caption"])}</figcaption></figure>' if p.get('image') else ''
 cards.append(f'<article class="feature"><div class="feature-copy"><div class="feature-top"><span class="eyebrow">0{n} / {e(p["category"])}</span>{badge(p)}</div><h3>{e(p["name"])}</h3><p>{e(p["summary"])}</p><a class="text-link" href="{url(p)}">Explore the case study <span aria-hidden="true">↗</span></a></div><a class="feature-picture" href="{url(p)}" aria-label="View {e(p["name"])} case study">{media}</a></article>')
rows=[]
# Put the most recently reviewed work first without altering its original review date.
for n,p in enumerate(sorted(P,key=lambda p:(p['updated'],p['name']),reverse=True),1):
 search=' '.join([p['name'],p['summary'],p['category'],*p['tags']]).lower()
 media=f'<div class="project-thumb"><img src="{e(p["image"])}" alt="" width="1280" height="720" loading="lazy"></div>' if p.get('image') else ''
 access='Public preview' if p.get('demo') else 'Project notes'
 rows.append(f'<a class="project-row" href="{url(p)}" data-category="{e(p["category"])}" data-stage="{e(p["status"])}" data-search="{e(search)}" data-name="{e(p["name"].lower())}" data-updated="{e(p["updated"])}"><span class="row-number">{n:02d}</span>{media}<div class="project-description"><span class="project-category">{e(p["category"])}</span><h3>{e(p["name"])}</h3><p>{e(p["summary"])}</p></div><span class="row-category">{e(p["category"])}</span>{badge(p)}<span class="project-access">{access}</span><span class="row-arrow" aria-hidden="true">↗</span></a>')
categories=['All projects','AI systems','Web & commerce','Games','Everyday tools','Creative tools','Research','Experiments']
filters=''.join(f'<button type="button" data-filter="{e(c)}" aria-pressed="{str(i==0).lower()}">{e(c)}</button>' for i,c in enumerate(categories))
gallery=[]
for n,p in enumerate([x for x in P if x.get('image')]):
 gallery.append(f'<a class="gallery-card" href="{url(p)}" data-name="{e(p["name"])}" style="--i:{n}"><div class="gallery-card-top"><span>PROJECT / {n+1:02d}</span>{badge(p)}</div><img src="{e(p["image"])}" alt="{e(p["caption"])}" width="1280" height="720" loading="lazy"><div class="gallery-card-copy"><span>{e(p["category"])}</span><h3>{e(p["name"])}</h3><span class="gallery-case">VIEW CASE STUDY ↗</span></div></a>')
def update_card(u):
 search=' '.join([u['title'],u['summary'],*u['body']]).lower()
 return f'<article class="update-card" data-update-type="{e(u["type"])}" data-update-search="{e(search)}"><div class="update-meta"><time datetime="{u["date"]}">{pretty_date(u["date"])}</time><span>{e(u["type"])}</span></div><h2><a href="updates/{u["id"]}.html">{e(u["title"])}</a></h2><p>{e(u["summary"])}</p><a class="text-link" href="updates/{u["id"]}.html" aria-label="Read {e(u["title"])}">Read update ↗</a></article>'
values={'COUNT':str(len(P)),'GALLERY_COUNT':f'{len(gallery):02d}','FEATURED':''.join(cards),'ROWS':''.join(rows),'FILTERS':filters,'GALLERY':''.join(gallery),'UPDATES':''.join(update_card(u) for u in U),'LATEST_UPDATES':''.join(update_card(u) for u in U[:2]),'UPDATE_COUNT':str(len(U))}
for template,output,title,desc,active in [('home.html','index.html','Ideas into reality','Will Lambert. SDSU entrepreneurship student building AI-assisted products, useful tools, and games. Explore projects and updates.',''),('archive.html','archive.html','Projects','Explore Will Lambert’s collection of products, tools, games, prototypes, and experiments.','Projects'),('updates.html','updates.html','Updates','Build logs, check-ins, ideas, interests, and notes from Will Lambert.','Updates')]:
 h=(ROOT/'templates'/template).read_text();v=dict(values,HEADER=header(active),FOOTER=footer(),HEAD=head(title,desc,output))
 for k,value in v.items():h=h.replace('{{'+k+'}}',value)
 assert '{{' not in h,f'Unresolved token in {template}'
 (ROOT/output).write_text(h)
for folder,items in [('projects',P),('updates',U)]:
 d=ROOT/folder;d.mkdir(exist_ok=True);expected={p['id']+'.html' for p in items}
 for old in d.glob('*.html'):
  if old.name not in expected:old.unlink()
for p in P:
 sections=''
 for key,title in [('problem','The idea'),('approach','My approach'),('outcome','What exists'),('next','Next steps')]:
  if p.get(key):sections+=f'<section><h2>{title}</h2><p>{e(p[key])}</p></section>'
 if not sections:sections=f'<section><h2>Project overview</h2><p>{e(p["summary"])}</p></section><section><h2>Project stage</h2><p>{e(p["status"])}. This is a record of the documented project; the review date above shows when its scope was last recorded.</p></section>'
 boundary=p.get('boundary') or ('Research and simulation only. No real-money execution or investment performance is claimed.' if p['category']=='Research' else 'A documented build or prototype is not necessarily a public release. This entry preserves the scope of the work at its last review.')
 sections+=f'<section class="detail-boundary"><h2>Scope & status</h2><p>{e(boundary)}</p></section>'
 media=f'<figure class="detail-image"><img src="../{e(p["image"])}" alt="{e(p["caption"])}"><figcaption>{e(p["caption"])}</figcaption></figure>' if p.get('image') else ''
 links=''
 for key,label in [('demo',p.get('demo_label','Explore public preview ↗')),('repo','View source repository ↗')]:
  if p.get(key):links+=f'<a class="button dark" href="{e(p[key])}" target="_blank" rel="noopener noreferrer">{e(label)}</a>'
 demo_note=f'<p class="preview-note">{e(p.get("demo_note","Public preview. Availability and feature scope may differ from the documented local project."))}</p>' if p.get('demo') else ''
 body=f'''<main id="main" class="detail-main"><a class="back-link" href="../archive.html">← All projects</a><h1 class="detail-title">{e(p['name'])}</h1><p class="detail-summary">{e(p['summary'])}</p><div class="detail-meta">{badge(p)}<span>{e(p['category'])}</span><span>Scope reviewed {e(p['updated'])}</span></div>{media}<div class="detail-sections"><aside class="detail-sidebar"><h3>My role</h3><p>{e(p['role'])}</p><h3>Tools & focus</h3><p>{e(' · '.join(p['tags']) or p['category'])}</p></aside><div class="detail-body">{sections}<div class="detail-links">{links}<a class="button dark" href="mailto:wlambert3493@sdsu.edu?subject=Project%20enquiry%20-%20{p['id']}">Ask about this project ↗</a></div>{demo_note}</div></div><div class="detail-footer"><a class="text-link" href="../archive.html">Explore all projects ↗</a></div></main>'''
 (ROOT/'projects'/f'{p["id"]}.html').write_text(page(p['name'],p['summary'],url(p),body,'Projects','../'))
for u in U:
 paras=''.join(f'<p>{e(t)}</p>' for t in u['body'])
 links=''.join(f'<a class="text-link" href="{e(l["url"] if l["url"].startswith("https://") else "../"+l["url"])}">{e(l["label"])} ↗</a>' for l in u.get('links',[]))
 body=f'<main id="main" class="update-article section"><a class="back-link" href="../updates.html">← All updates</a><div class="update-meta"><time datetime="{u["date"]}">{pretty_date(u["date"])}</time><span>{e(u["type"])}</span></div><h1>{e(u["title"])}</h1><p class="update-deck">{e(u["summary"])}</p><div class="update-body">{paras}</div><div class="update-links">{links}</div><div class="article-footer"><span>WILL LAMBERT</span><a class="text-link" href="../feed.xml">Follow via RSS ↗</a></div></main>'
 (ROOT/'updates'/f'{u["id"]}.html').write_text(page(u['title'],u['summary'],f'updates/{u["id"]}.html',body,'Updates','../'))
rss=ET.Element('rss',version='2.0');channel=ET.SubElement(rss,'channel')
for tag,text in [('title','Will Lambert — Updates'),('link',SITE+'/updates.html'),('description','Build logs, check-ins, and notes from Will Lambert.'),('language','en-us')]:ET.SubElement(channel,tag).text=text
for u in U:
 item=ET.SubElement(channel,'item')
 for tag,text in [('title',u['title']),('link',SITE+'/updates/'+u['id']+'.html'),('guid',SITE+'/updates/'+u['id']+'.html'),('description',u['summary']),('category',u['type']),('pubDate',date.fromisoformat(u['date']).strftime('%a, %d %b %Y 12:00:00 GMT'))]:ET.SubElement(item,tag).text=text
ET.ElementTree(rss).write(ROOT/'feed.xml',encoding='utf-8',xml_declaration=True)
site=ET.Element('urlset',xmlns='http://www.sitemaps.org/schemas/sitemap/0.9')
for path in ['index.html','archive.html','updates.html',*[url(p) for p in P],*[f'updates/{u["id"]}.html' for u in U]]:
 item=ET.SubElement(site,'url');ET.SubElement(item,'loc').text=SITE+'/'+path
ET.ElementTree(site).write(ROOT/'sitemap.xml',encoding='utf-8',xml_declaration=True)
(ROOT/'404.html').write_text(page('Page not found','Find your way back to Will Lambert’s projects and updates.','404.html','<main id="main" class="section missing-page"><span class="eyebrow">404 / NOT FOUND</span><h1>This page has moved<br>or isn’t here.</h1><p>Explore the current collection of projects and updates.</p><a class="button" href="/archive.html">Explore projects ↗</a><a class="text-link" href="/updates.html">Read updates ↗</a></main>',prefix='/'))
print(f'Built {len(P)} project pages and {len(U)} published updates.')
