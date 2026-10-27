#!/usr/bin/env python3
"""Build the public portfolio from reviewed data. Python standard library only."""
from pathlib import Path
from html import escape
from datetime import date,datetime
from zoneinfo import ZoneInfo
from urllib.parse import urlparse, urlencode
import json,re
from project_maps import render_maps
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
SITE='https://will-lambert-portfolio.vercel.app'
VERSION='20261026-channel'
C=json.loads((ROOT/'data/categories.json').read_text())
CATEGORY={c['key']:c for c in C}
assert len(CATEGORY)==len(C) and len({c['id'] for c in C})==len(C)
def category_label(p):return CATEGORY[p['category']]['label']
P=json.loads((ROOT/'data/projects.json').read_text())
render_maps(P,ROOT)
CH=json.loads((ROOT/'data/channel.json').read_text())
METRICS=json.loads((ROOT/'data/social-metrics.json').read_text())
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
 links=[('Work','index.html#work'),('Projects','archive.html'),('Channel','channel.html'),('Updates','updates.html')]
 nav=''.join(f'<a href="{prefix}{href}"'+(' aria-current="page"' if name==active or (name=='All projects' and active=='Projects') else '')+f'>{name}</a>' for name,href in links)
 return f'''<header class="site-header"><a class="monogram" href="{prefix}index.html" aria-label="Will Lambert home">WL<span class="logo-dot"></span></a><div class="header-practice">WILL LAMBERT<br>PRODUCTS, TOOLS & GAMES</div><nav aria-label="Main navigation">{nav}</nav><button class="theme-toggle" type="button" aria-label="Switch to light theme" aria-pressed="false"><span aria-hidden="true">◐</span></button><a class="header-availability" href="{prefix}index.html#contact"><span><i class="status-dot"></i> OPEN TO OPPORTUNITIES</span><strong>San Diego / Remote <span aria-hidden="true">↗</span></strong></a></header>'''
def footer(prefix=''):
 return f'<footer><span>© 2026 WILL LAMBERT</span><a href="{prefix}updates.html">Updates</a><a href="{prefix}channel.html">The Daily Orb</a><a href="{prefix}feed.xml">RSS</a><a href="https://github.com/willywonka773202-cloud" target="_blank" rel="noopener noreferrer">GitHub ↗</a><a href="{e(CH["linkedin"])}" target="_blank" rel="noopener noreferrer">LinkedIn ↗</a><a href="{prefix}index.html#contact">Contact ↗</a></footer>'
def head(title,description,path,prefix=''):
 return f'''<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{e(title)} — Will Lambert</title><meta name="description" content="{e(description)}"><meta name="theme-color" content="#090909"><link rel="canonical" href="{SITE}/{path}"><meta property="og:type" content="website"><meta property="og:title" content="{e(title)} — Will Lambert"><meta property="og:description" content="{e(description)}"><meta property="og:url" content="{SITE}/{path}"><meta property="og:image" content="{SITE}/assets/portfolio-social.png"><meta name="twitter:card" content="summary_large_image"><link rel="icon" href="{prefix}favicon.png"><link rel="alternate" type="application/rss+xml" title="Will Lambert — Updates" href="{prefix}feed.xml"><link rel="stylesheet" href="{prefix}style.css?v={VERSION}"><script src="{prefix}app.js?v={VERSION}" defer></script>'''
def page(title,desc,path,body,active='',prefix=''):
 return f'<!doctype html><html lang="en"><head>{head(title,desc,path,prefix)}</head><body><a class="skip" href="#main">Skip to content</a>{header(active,prefix)}{body}{footer(prefix)}</body></html>'
for items in [P,U]:
 ids=[x['id'] for x in items];assert len(ids)==len(set(ids)) and all(valid_id(i) for i in ids)
for p in P:
 assert p['category'] in CATEGORY, f'Unknown project type: {p["category"]}'
 assert p['status'] in ['Built','In progress','Prototype','Research','Archived','Needs review']
 for key in ['repo','demo']:
  if p.get(key):assert p[key].startswith('https://');safe_url(p[key])
for u in U:
 date.fromisoformat(u['date']);assert u['type'] in ['Build log','Check-in','Notes','News']
 assert u['title'] and u['summary'] and u['body']
 for link in u.get('links',[]):safe_url(link['url'])
showcase_ids=['goodturn','pullr','sword-soul','bloomwake','cortex-studio','sylistly','bert-ai','after-hours']
showcase=[]
for n,i in enumerate(showcase_ids,1):
 p=next(p for p in P if p['id']==i)
 showcase.append(f'<a class="showcase-card" href="{url(p)}"><figure class="showcase-media"><img src="{e(p["image"])}" alt="{e(p["caption"])}" width="1280" height="720" loading="{"eager" if n<=3 else "lazy"}"><figcaption>{e(p["media_kind"])} · {len(p["gallery"])} {"views" if len(p["gallery"])!=1 else "view"}</figcaption></figure><div class="showcase-meta"><span>{e(category_label(p))}</span>{badge(p)}</div><div class="showcase-title"><h3>{e(p["name"])}</h3><span aria-hidden="true">↗</span></div><p>{e(p["summary"])}</p><span class="showcase-detail">See the build & my contribution <span aria-hidden="true">↗</span></span></a>')
rows={c['key']:[] for c in C}
# Put the most recently reviewed work first without altering its original review date.
for n,p in enumerate(sorted(P,key=lambda p:(p.get('media_kind')=='Project map',-date.fromisoformat(p['updated']).toordinal(),p['name'])),1):
 search=' '.join([p['name'],p['summary'],p['category'],category_label(p),*p['tags']]).lower()
 media=f'<div class="project-thumb"><img src="{e(p["image"])}" alt="{e(p["media_kind"])} of {e(p["name"])}" width="1280" height="720" loading="lazy"><span class="media-kind">{e(p["media_kind"])}</span></div>'
 access='Public preview' if p.get('demo') else 'Project notes'
 rows[p['category']].append(f'<a class="project-row" href="{url(p)}" data-category="{e(p["category"])}" data-media="{e(p["media_kind"])}" data-stage="{e(p["status"])}" data-search="{e(search)}" data-name="{e(p["name"].lower())}" data-updated="{e(p["updated"])}"><span class="row-number">{len(rows[p["category"]])+1:02d}</span>{media}<div class="project-description"><span class="project-category">{e(category_label(p))}</span><h3>{e(p["name"])}</h3><p>{e(p["summary"])}</p></div><span class="row-category">{e(category_label(p))}</span>{badge(p)}<span class="project-access">{access}</span><span class="row-arrow" aria-hidden="true">↗</span></a>')
groups=[]
type_links=[]
for n,c in enumerate(C,1):
 count=len(rows[c['key']]);assert count, f"Empty project type: {c['key']}"
 groups.append(f'<section class="project-group" data-project-group="{e(c["key"])}" aria-labelledby="{c["id"]}"><header class="project-group-heading"><div><span class="eyebrow">{n:02d} / PROJECT TYPE</span><h2 id="{c["id"]}">{e(c["label"])}</h2><p>{e(c["description"])}</p></div><span class="group-count">{count} {"project" if count==1 else "projects"}</span></header><div class="project-group-rows project-grid">{"".join(rows[c["key"]])}</div></section>')
 target='archive.html?'+urlencode({'category':c['key']})
 type_links.append(f'<a href="{e(target)}"><span>{e(c["label"])}</span><span class="type-link-count">{count:02d} <b aria-hidden="true">↗</b></span></a>')
filters=f'<button type="button" data-filter="All projects" aria-pressed="true">All projects <span>{len(P)}</span></button>'
filters+=''.join(f'<button type="button" data-filter="{e(c["key"])}" aria-pressed="false">{e(c["label"])} <span>{len(rows[c["key"]])}</span></button>' for c in C)
def update_card(u):
 search=' '.join([u['title'],u['summary'],*u['body']]).lower()
 return f'<article class="update-card" data-update-type="{e(u["type"])}" data-update-search="{e(search)}"><div class="update-meta"><time datetime="{u["date"]}">{pretty_date(u["date"])}</time><span>{e(u["type"])}</span></div><h2><a href="updates/{u["id"]}.html">{e(u["title"])}</a></h2><p>{e(u["summary"])}</p><a class="text-link" href="updates/{u["id"]}.html" aria-label="Read {e(u["title"])}">Read update ↗</a></article>'
def episode_card(ep):
 return f'<article class="episode-card"><a class="episode-poster" href="{e(ep["url"])}" target="_blank" rel="noopener noreferrer"><img src="https://i.ytimg.com/vi/{e(ep["id"])}/hqdefault.jpg" alt="{e(ep["title"])}" width="480" height="360" loading="lazy"><span class="play-symbol" aria-hidden="true">▶</span></a><div class="eyebrow">{e(ep["format"])} / THE DAILY ORB</div><h3><a href="{e(ep["url"])}" target="_blank" rel="noopener noreferrer">{e(ep["title"])}</a></h3><a class="text-link" href="{e(ep["url"])}" target="_blank" rel="noopener noreferrer">Watch on YouTube ↗</a></article>'
episodes=''.join(episode_card(ep) for ep in CH['episodes'])
latest=CH['episodes'][0]
def broadcast(compact=False):
 ep=latest
 return f'''<div class="orb-broadcast {'orb-compact' if compact else ''}" data-channel-broadcast data-video="{e(ep['id'])}" data-title="{e(ep['title'])}" data-format="{e(ep['format'])}"><div class="broadcast-topline"><a href="channel.html">THE DAILY ORB <span>↗</span></a><span class="feed-state">LATEST CHECKED UPLOAD</span></div><div class="broadcast-screen"><img class="broadcast-poster" src="https://i.ytimg.com/vi/{e(ep['id'])}/hqdefault.jpg" alt="{e(ep['title'])}" width="480" height="360"><div class="broadcast-mount"></div><button class="broadcast-start" type="button">Play latest story ↗</button></div><div class="broadcast-controls"><button class="broadcast-play" type="button" aria-label="Play video">Play</button><button class="broadcast-sound" type="button" aria-pressed="false">Sound off</button><a class="broadcast-watch" href="{e(ep['url'])}" target="_blank" rel="noopener noreferrer">YouTube ↗</a></div><div class="broadcast-caption"><span class="broadcast-date">{pretty_date(ep['published'][:10])} · {e(ep['format'])}</span><h3 class="broadcast-title">{e(ep['title'])}</h3></div></div>'''
channel_feature=f'<section class="channel-directory section" id="channel"><div><span class="eyebrow">BEYOND THE VIDEOS</span><h2>THE DAILY ORB<br><em>directory.</em></h2><p>The companion to my AI news channel: tools, models, and resources behind the stories.</p><a class="button" href="{CH["site"]}" target="_blank" rel="noopener noreferrer">Explore The Daily Orb ↗</a></div><a class="channel-site-preview" href="{CH["site"]}" target="_blank" rel="noopener noreferrer"><img src="assets/evidence/daily-orb.jpg" alt="The Daily Orb resource directory" width="1440" height="900" loading="lazy"><span>TOOLS, MODELS & RESOURCES <b>↗</b></span></a></section>'
values={'COUNT' :str(len(P)),'BROADCAST':broadcast(),'COMPACT_BROADCAST':broadcast(True),'CHANNEL_FEATURE':channel_feature,'EPISODES':episodes,'CHANNEL_REVIEWED':pretty_date(CH['reviewed']),'CATEGORY_COUNT':str(len(C)),'SHOWCASE':''.join(showcase),'GROUPS':''.join(groups),'TYPE_LINKS':''.join(type_links),'FILTERS':filters,'UPDATES':''.join(update_card(u) for u in U),'UPDATE_COUNT':str(len(U))}
# The home gallery uses original project evidence; decorative scenery is separate.
by_id={p['id']:p for p in P}
studio_ids=['cortex-studio','bloomwake','the-daily-orb']
studio_labels=['Creative tools · Private alpha','Roblox game · In progress','AI news & media · Published channel']
panels=[]
for n,(i,label) in enumerate(zip(studio_ids,studio_labels)):
 p=by_id[i]
 panels.append(f'<a class="studio-panel {"is-front" if n==0 else "is-next" if n==1 else "is-away"}" href="{url(p)}" data-studio-panel="{n}" data-name="{e(p["name"])}" data-category="{e(label)}" data-role="{e(p["role"])}" aria-label="Explore {e(p["name"])}" {"" if n<2 else "inert"}><img src="{e(p["image"])}" alt="{e(p["caption"])}" width="1440" height="1000" fetchpriority="{"high" if n==0 else "auto"}"><span class="studio-panel-label">{e(p["name"])} <span>View project</span></span></a>')
case_specs=[('bloomwake','A fishing-fleet game built around sailing, combat, and progression.','Developing the fishing loop, boat handling, progression, and pixel-style presentation.','scene-ocean'),('goodturn','An outing planner that connects places, people, and the route between them.','Product direction, interface decisions, and AI-assisted iteration of the planning experience.','scene-product')]
cases=[]
for n,(i,summary,role,kind) in enumerate(case_specs,1):
 p=by_id[i]
 cases.append(f'<article class="cinematic-case {kind}"><div class="case-scene"><a class="scene-image-link" href="{url(p)}" aria-label="Explore {e(p["name"])}"><img class="scene-image" src="{e(p["image"])}" alt="{e(p["caption"])}" loading="lazy" width="1481" height="1080"></a><div class="scene-heading"><span class="studio-kicker">{n:02d} / {e(category_label(p))} / {e(p["status"])}</span><h2>{e(p["name"])}</h2><p>{e(summary)}</p></div><span class="scene-evidence">Original project screenshot</span></div><div class="case-contribution"><div><h3>My contribution</h3><p>{e(role)}</p></div><a class="studio-button studio-button-secondary" href="{url(p)}">View project details</a></div></article>')
more=[]
for i in ['pullr','sword-soul','bert-ai','after-hours']:
 p=by_id[i]
 more.append(f'<a class="studio-more-project" href="{url(p)}"><figure><img src="{e(p["image"])}" alt="{e(p["caption"])}" loading="lazy" width="1280" height="800"></figure><div><span class="studio-kicker">{e(category_label(p))} · {e(p["status"])}</span><h3>{e(p["name"])}</h3><p>{e(p["summary"])}</p><span class="studio-more-cta">Explore the project</span></div></a>')
values.update(STUDIO_PANELS=''.join(panels),CINEMATIC_CASES=''.join(cases),STUDIO_MORE=''.join(more))
# Public social evidence. These are observed snapshots, never simulated counters.
snapshots=METRICS['snapshots'];snapshot=snapshots[-1]
def metric_date(value):return pretty_date(datetime.fromisoformat(value.replace('Z','+00:00')).astimezone(ZoneInfo('America/Los_Angeles')).date().isoformat())
checked=metric_date(snapshot['checkedAt'])
metric_cards=[]
specs=[('youtube','YouTube','@thedailyorb','subscribers','Subscribers', [('views','Total views'),('videos','Public videos')]),('tiktok','TikTok','@bertsbuild','followers','Followers',[('likes','Total likes')]),('x','X','@theDailyOrb_','followers','Followers',[('posts','Public posts')])]
for key,name,handle,primary,label,secondary in specs:
 data=snapshot[key]
 for field in [primary,*[f for f,_ in secondary]]:assert type(data[field]) is int and data[field]>=0
 details=''.join(f'<span><b>{e(data.get(field+"Display",format(data[field],",")))}</b> {e(title.lower())}{" (rounded)" if data.get(field+"Approximate") else ""}</span>' for field,title in secondary)
 growth=''
 if len(snapshots)>1:
  prior=snapshots[-2];delta=data[primary]-prior[key][primary]
  growth=f'<p class="metric-change">{delta:+,} since {metric_date(prior["checkedAt"])}</p>'
 metric_cards.append(f'<article class="social-metric"><a class="metric-account" href="{e(CH[key])}" target="_blank" rel="noopener noreferrer"><span>{name} <small>{handle}</small></span><span aria-hidden="true">↗</span></a><p class="metric-total">{data[primary]:,}<span>{label}</span></p><div class="metric-details">{details}</div>{growth}</article>')
metrics_html=f'<section class="social-proof" aria-label="The Daily Orb public audience statistics"><div class="social-proof-label"><span>THE CHANNEL IN NUMBERS</span><span>Public snapshot · <time datetime="{e(snapshot["checkedAt"])}">{checked}</time></span></div><div class="social-metrics-grid">{"".join(metric_cards)}</div><p class="metrics-note">Public profile totals, checked weekly. Each platform reports its own audience; counts may overlap. TikTok rounds its likes total. <a href="channel.html#metrics">Sources &amp; update history ↗</a></p></section>'
history_rows=''.join(f'<tr><th scope="row">{metric_date(s["checkedAt"])}</th><td>{s["youtube"]["subscribers"]:,}</td><td>{s["youtube"]["views"]:,}</td><td>{s["tiktok"]["followers"]:,}</td><td>{s["x"]["followers"]:,}</td></tr>' for s in reversed(snapshots[-12:]))
history=f'<details class="metrics-history"><summary>Sources &amp; snapshot history</summary><p>Counts are read from the linked public YouTube, TikTok, and X profiles. The latest video updates automatically from YouTube’s public feed. Audience totals are dated snapshots, not real-time analytics. Private watch time, impressions, and revenue are not included.</p><div class="metrics-table-scroll"><table><caption>Public audience snapshots</caption><thead><tr><th>Date</th><th>YouTube subscribers</th><th>YouTube views</th><th>TikTok followers</th><th>X followers</th></tr></thead><tbody>{history_rows}</tbody></table></div></details>'
roadmap=[]
for n,i in enumerate(['goodturn','bert-ai','the-daily-orb'],1):
 p=by_id[i]
 roadmap.append(f'<a class="roadmap-card" href="{url(p)}"><span class="studio-kicker">0{n} / {e(p["status"])} → NEXT</span><h3>{e(p["name"])}</h3><p>{e(p["next"])}</p><span class="roadmap-link">See what exists today ↗</span></a>')
values.update(SOCIAL_METRICS=metrics_html,METRIC_HISTORY=history,LINKEDIN=e(CH['linkedin']),ROADMAP=''.join(roadmap),HOME_EPISODES=''.join(episode_card(ep) for ep in CH['episodes'][:3]),RECENT_UPDATES=''.join(update_card(u) for u in U[:3]))
for view in ['grid','list']:
 collection=(ROOT/'templates/collection.html').read_text()
 cv=dict(values,DEFAULT_VIEW=view,GRID_ACTIVE=str(view=='grid').lower(),LIST_ACTIVE=str(view=='list').lower())
 if view=='list':cv['GROUPS']=cv['GROUPS'].replace('project-group-rows project-grid','project-group-rows')
 for key,value in cv.items():collection=collection.replace('{{'+key+'}}',value)
 values['COLLECTION_'+view.upper()]=collection
for template,output,title,desc,active in [('home.html','index.html','Products, tools & games','Will Lambert. SDSU entrepreneurship student building AI-assisted products, useful tools, and games. Explore projects and updates.',''),('archive.html','archive.html','Projects','Explore Will Lambert’s collection of products, tools, games, prototypes, and experiments.','Projects'),('channel.html','channel.html','The Daily Orb — AI channel','Watch selected episodes from Will Lambert’s AI channel and explore The Daily Orb directory.','Channel'),('updates.html','updates.html','Updates','Build logs, check-ins, ideas, interests, and notes from Will Lambert.','Updates')]:
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
 gallery=p['gallery']
 frames=''.join(f'<figure class="evidence-frame"><a href="../{e(g["src"])}" class="evidence-zoom" data-caption="{e(g["caption"])}" aria-label="Enlarge {e(p["name"])}: view {n}"><img src="../{e(g["src"])}" alt="{e(g["caption"])}" loading="{"eager" if n==1 else "lazy"}"><span aria-hidden="true">↗ Enlarge</span></a><figcaption><span>{n:02d} / {e(g["kind"])}</span>{e(g["caption"])}</figcaption></figure>' for n,g in enumerate(gallery,1))
 media=f'<section class="evidence-gallery" aria-labelledby="evidence-title"><div class="evidence-heading"><h2 id="evidence-title">{"Project map" if p["media_kind"]=="Project map" else "Inside the build"}</h2><span>{len(gallery)} {"views" if len(gallery)!=1 else "view"} · select to enlarge</span></div><div class="evidence-frames">{frames}</div></section>'
 links=''
 for key,label in [('demo',p.get('demo_label','Explore public preview ↗')),('repo','View source repository ↗')]:
  if p.get(key):links+=f'<a class="button dark" href="{e(p[key])}" target="_blank" rel="noopener noreferrer">{e(label)}</a>'
 for link in p.get('links',[]):links+=f'<a class="button dark" href="{e(safe_url(link["url"]))}" target="_blank" rel="noopener noreferrer">{e(link["label"])}</a>'
 demo_note=f'<p class="preview-note">{e(p.get("demo_note","Public preview. Availability and feature scope may differ from the documented local project."))}</p>' if p.get('demo') else ''
 body=f'''<main id="main" class="detail-main"><a class="back-link" href="../archive.html">← All projects</a><h1 class="detail-title">{e(p['name'])}</h1><p class="detail-summary">{e(p['summary'])}</p><div class="detail-meta">{badge(p)}<span>{e(category_label(p))}</span><span>Scope reviewed {e(p['updated'])}</span></div><div class="detail-top-actions">{links}</div>{media}<div class="detail-sections"><aside class="detail-sidebar"><h3>My role</h3><p>{e(p['role'])}</p><h3>Tools & focus</h3><p>{e(' · '.join(p['tags']) or p['category'])}</p></aside><div class="detail-body">{sections}<div class="detail-links">{links}<a class="button dark" href="mailto:wlambert3493@sdsu.edu?subject=Project%20enquiry%20-%20{p['id']}">Ask about this project ↗</a></div>{demo_note}</div></div><div class="detail-footer"><a class="text-link" href="../archive.html">Explore all projects ↗</a></div></main>'''
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
for path in ['index.html','archive.html','updates.html','channel.html',*[url(p) for p in P],*[f'updates/{u["id"]}.html' for u in U]]:
 item=ET.SubElement(site,'url');ET.SubElement(item,'loc').text=SITE+'/'+path
ET.ElementTree(site).write(ROOT/'sitemap.xml',encoding='utf-8',xml_declaration=True)
(ROOT/'404.html').write_text(page('Page not found','Find your way back to Will Lambert’s projects and updates.','404.html','<main id="main" class="section missing-page"><span class="eyebrow">404 / NOT FOUND</span><h1>This page has moved<br>or isn’t here.</h1><p>Explore the current collection of projects and updates.</p><a class="button" href="/archive.html">Explore projects ↗</a><a class="text-link" href="/updates.html">Read updates ↗</a></main>',prefix='/'))
print(f'Built {len(P)} project pages and {len(U)} published updates.')
