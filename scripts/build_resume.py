from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, HRFlowable
from reportlab.lib.pagesizes import letter

OUT = Path(__file__).resolve().parents[1] / 'resume/Will-Lambert-Resume.pdf'
styles = {
    'name': ParagraphStyle('name', fontName='Helvetica-Bold', fontSize=23, leading=27, spaceAfter=5),
    'contact': ParagraphStyle('contact', fontName='Helvetica', fontSize=9.5, leading=13, spaceAfter=9),
    'section': ParagraphStyle('section', fontName='Helvetica-Bold', fontSize=10, leading=13, spaceBefore=11, spaceAfter=4),
    'body': ParagraphStyle('body', fontName='Helvetica', fontSize=10, leading=13.5, spaceAfter=5),
    'title': ParagraphStyle('title', fontName='Helvetica-Bold', fontSize=10, leading=13.5, spaceBefore=4, spaceAfter=3),
    'bullet': ParagraphStyle('bullet', fontName='Helvetica', fontSize=10, leading=13.5, leftIndent=11, firstLineIndent=-9, spaceAfter=4),
}
story=[]
def p(text, style='body'): story.append(Paragraph(text, styles[style]))
def section(text):
    p(text, 'section')
    story.append(HRFlowable(width='100%', thickness=.45, color=colors.HexColor('#888888'), spaceAfter=5))
def bullet(text): p('&#8226; '+text, 'bullet')

p('Will Lambert','name')
p('San Diego, CA | wlambert3493@sdsu.edu | will-lambert-portfolio.vercel.app','contact')
p('Business Administration student at San Diego State University studying entrepreneurship. Builds web apps and personal software projects with AI-assisted development; brings four summers of aquatics experience, staff training, and team leadership.')
section('EDUCATION')
p('San Diego State University | Expected May 2030','title')
p('B.S. Business Administration, Entrepreneurship | San Diego, CA')
section('SELECTED PROJECTS')
p('Goodturn | Personal prototype','title')
bullet('Exploring a place-first outing planner that connects place discovery, multiple stops, and route planning in one interface.')
bullet('Used AI-assisted development to iterate on product direction, interface design, and local prototypes; public landing page available through my portfolio.')
p('BERT AI | Personal project in development','title')
bullet('Developing a personal AI workspace with AI-assisted development, focused on bringing conversations, project files, terminals, and shared context into one interface.')
section('EXPERIENCE')
p('Deerfield Park District | Deerfield, IL | Summers 2023-2026','title')
p('<b>Head Guard (promoted)</b> | Summer 2026')
bullet('Promoted after three seasons. Opened and closed two pools on the 5:00 a.m. shift, ran facility safety checks, and supervised guard rotations and incident reports.')
bullet('Led in-service training for 100+ new and returning guards, including scanning audits, shadow tests, and individual coaching.')
bullet('Started a mentorship program and mentored 20 first-year guards from onboarding through independent chair duty.')
p('<b>Lifeguard</b> | Summers 2023-2026')
bullet('Guarded four indoor and outdoor facilities across four summers, with additional winter indoor coverage; enforced rules and de-escalated conflicts for hundreds of patrons daily.')
p('<b>Cashier &amp; Concessions Attendant</b> | Concurrent role')
bullet('Handled admissions, point-of-sale transactions, and cash; served food during peak summer crowds while following food-safety standards.')
section('SKILLS & CERTIFICATIONS')
p('<b>Skills:</b> AI-assisted prototyping, staff training and supervision, mentoring, customer service, conflict resolution, cash handling and POS.')
p('<b>Certifications:</b> American Red Cross Lifeguarding (Deep Water; valid through August 2027), CPR/AED for Professional Rescuers, First Aid, Administering Emergency Oxygen.')

SimpleDocTemplate(str(OUT), pagesize=letter, rightMargin=47, leftMargin=47, topMargin=37, bottomMargin=36, title='Will Lambert - Business and Product Resume', author='Will Lambert').build(story)
print(OUT)
