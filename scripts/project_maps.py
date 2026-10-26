"""Render labeled explanatory diagrams; never represent these as product captures."""
from html import escape
import textwrap

COLORS={'AI systems':'#b8b1ef','Web & commerce':'#ddbe91','Games':'#a6cdb5','Creative tools':'#e5adc5','Everyday tools':'#9ccdd3','Research':'#aabfe7','Experiments':'#dfc8a3'}

def render_maps(projects,root):
 for p in projects:
  if p.get('media_kind')!='Project map':continue
  accent=COLORS[p['category']]
  title=textwrap.wrap(p['name'],width=34)[:3]
  lines=''.join(f'<text x="64" y="{148+n*59}" font-size="48" font-weight="600">{escape(t)}</text>' for n,t in enumerate(title))
  nodes=''
  for n,label in enumerate(p['workflow']):
   x=64+n*393
   nodes+=f'<rect x="{x}" y="353" width="363" height="152" rx="6" fill="#161d25" stroke="#39434e"/><text x="{x+25}" y="393" font-size="14" fill="{accent}">0{n+1}</text>'
   for j,line in enumerate(textwrap.wrap(label,22)):
    nodes+=f'<text x="{x+25}" y="{435+j*32}" font-size="25">{escape(line)}</text>'
   if n<2:nodes+=f'<path d="M{x+363} 428h30m-9-7 9 7-9 7" fill="none" stroke="{accent}" stroke-width="2"/>'
  tags=' / '.join(p.get('tags',[])[:3])
  svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720" role="img" aria-label="{escape(p['name'])}: explanatory project map">
<rect width="1280" height="720" fill="#0e141c"/><g fill="none" stroke="#29323d" opacity=".45"><path d="M0 320h1280M0 540h1280M1248 0v720"/></g>
<g font-family="Arial,Helvetica,sans-serif" fill="#e9edf2"><text x="64" y="64" font-size="15" letter-spacing="2" fill="{accent}">PROJECT MAP / {escape(p['status'].upper())}</text>{lines}{nodes}<text x="64" y="592" font-size="18" fill="#a6b3c3">{escape(tags[:95])}</text><text x="64" y="660" font-size="15" fill="#a6b3c3">EXPLANATORY DIAGRAM · NOT A PRODUCT SCREENSHOT</text><text x="1196" y="660" text-anchor="end" font-size="19" fill="{accent}">WL.</text></g></svg>'''
  dest=root/p['image'];dest.parent.mkdir(exist_ok=True,parents=True);dest.write_text(svg)
