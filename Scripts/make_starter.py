"""Build the traditional front/back deck; preserve old IDs only for the same skill."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGACY = json.loads((ROOT/'Tests/Fixtures/v2-lessons-deck.json').read_text())
OLD = {c['id']: c for c in LEGACY['cards']}
ACTIVE = []

def keep(id, front, back):
    card = copy.deepcopy(OLD[id])
    card.update(prompt=front, answer=back, revision=5, change='wording', hint='')
    for key in ['answerBlocks', 'explanationSections', 'archived']: card.pop(key, None)
    ACTIVE.append(card)

def new(id, topic, front, back):
    ACTIVE.append(dict(id=id, conceptID=topic, objectiveID=id, revision=1,
                       kind='Recall', prompt=front, answer=back, hint='', change='explanation'))

keep('angles.sin',r'Complete: \(\sin(a+b)=\ ?\)',r'\[\sin a\cos b+\cos a\sin b\]')
keep('angles.cos',r'Complete: \(\cos(a+b)=\ ?\)',r'\[\cos a\cos b-\sin a\sin b\]')
new('angles.sin-difference','angles',r'Complete: \(\sin(a-b)=\ ?\)',r'\[\sin a\cos b-\cos a\sin b\]')
new('angles.cos-difference','angles',r'Complete: \(\cos(a-b)=\ ?\)',r'\[\cos a\cos b+\sin a\sin b\]')
new('angles.negative-sine','angles',r'Complete: \(\sin(-x)=\ ?\)',r'\[-\sin x\]')
new('angles.negative-cosine','angles',r'Complete: \(\cos(-x)=\ ?\)',r'\[\cos x\]')
new('angles.cos-double','angles',r'Write \(\cos(2x)\) using \(\sin^2x\) and \(\cos^2x\).',r'\[\cos^2x-\sin^2x\]')
new('angles.cos-double-cosine','angles',r'Write \(\cos(2x)\) using only \(\cos x\).',r'\[2\cos^2x-1\]')
new('angles.cos-double-sine','angles',r'Write \(\cos(2x)\) using only \(\sin x\).',r'\[1-2\sin^2x\]')
new('angles.sin-double','angles',r'Complete: \(\sin(2x)=\ ?\)',r'\[2\sin x\cos x\]')
keep('derivatives.sin',r'Differentiate \(\sin x\), with \(x\) in radians.',r'\[\cos x\]')
keep('derivatives.cos',r'Differentiate \(\cos x\), with \(x\) in radians.',r'\[-\sin x\]')
new('derivatives.product-rule','derivatives',r'For differentiable functions \(u(x)\) and \(v(x)\), complete: \(\displaystyle\frac{d}{dx}[uv]=\ ?\)',r'\[u\,v^{\prime}+v\,u^{\prime}\]')
new('derivatives.quotient-rule','derivatives',r'For differentiable functions \(u(x)\) and \(v(x)\), with \(v(x)\ne0\), complete: \(\displaystyle\frac{d}{dx}\!\left[\frac uv\right]=\ ?\)',r'\[\frac{v\,u^{\prime}-u\,v^{\prime}}{v^2}\]')
new('derivatives.product-example','derivatives',r'Differentiate \(x^2\sin x\), with \(x\) in radians.',r'\[2x\sin x+x^2\cos x\]')
new('derivatives.quotient-example','derivatives',r'Differentiate \(\displaystyle\frac{x}{x^2+1}\).',r'\[\frac{1-x^2}{(x^2+1)^2}\]')
new('derivatives.sine-limit','derivatives',r'Evaluate \(\displaystyle\lim_{h\to0}\frac{\sin h}{h}\), with \(h\) in radians.',r'\[1\]')
new('derivatives.cosine-limit','derivatives',r'Evaluate \(\displaystyle\lim_{h\to0}\frac{\cos h-1}{h}\).',r'\[0\]')
keep('derivatives.cycle',r'List the next four derivatives of \(\sin x\) in order.',r'\[\cos x,\quad-\sin x,\quad-\cos x,\quad\sin x\]')
keep('derivatives.notation',r'What does \(f^{(4)}(x)\) mean?',r'The fourth derivative of \(f\): differentiate four times.')
keep('derivatives.chain',r'Differentiate \(\sin(3x)\), with angles in radians.',r'\[3\cos(3x)\]')
keep('logs.fourth',r'Find \(f^{(4)}(x)\) for \(f(x)=\sin x+\ln x\), with \(x>0\).',r'\[\sin x-\frac6{x^4}\]')
keep('logs.power',r'Differentiate \(-x^{-2}\).',r'\[2x^{-3}\]')
keep('logs.general',r'What is the \(n\)th derivative of \(\ln x\), for \(n\ge1\) and \(x>0\)?',r'\[(-1)^{n-1}\frac{(n-1)!}{x^n}\]')
keep('sets.meaning',r'What does \(X\setminus Y\) mean?',r'The elements in \(X\) that are not in \(Y\).')
keep('sets.example',r'If \(X=\{1,2,3\}\) and \(Y=\{2,4\}\), find \(X\setminus Y\).',r'\[\{1,3\}\]')
keep('sets.reverse',r'If \(X=\{1,2,3\}\) and \(Y=\{2,4\}\), find \(Y\setminus X\).',r'\[\{4\}\]')
keep('sets.self',r'What is \(X\setminus X\)?',r'\(\varnothing\): the empty set.')
new('ellipse.circle-equation','ellipse',r'Give the equation of a circle with centre \((h,k)\) and radius \(r\).',r'\[(x-h)^2+(y-k)^2=r^2\]')
new('ellipse.standard-equation','ellipse',r'Give the equation of an origin-centred ellipse with horizontal half-axis \(a\) and vertical half-axis \(b\).',r'\[\frac{x^2}{a^2}+\frac{y^2}{b^2}=1\]')
keep('ellipse.screenshot',r'Find the full major and minor axis lengths of \(\displaystyle\frac{x^2}{4}+y^2=1\).',r'Major axis: \(4\). Minor axis: \(2\).')
keep('ellipse.transfer',r'Find the full axis lengths and directions for \(\displaystyle\frac{x^2}{9}+\frac{y^2}{25}=1\).',r'Major: vertical, \(10\). Minor: horizontal, \(6\).')
keep('ellipse.shift',r'Find the centre and radius of \((x-3)^2+(y+2)^2=16\).',r'Centre: \((3,-2)\). Radius: \(4\).')
keep('measure.circumference',r'Give the circumference of a circle of radius \(r\).',r'\[C=2\pi r\]')
new('measure.circle-area','measure',r'Give the area of a circle of radius \(r\).',r'\[A=\pi r^2\]')
new('measure.ellipse-area','measure',r'Give the area of an ellipse with half-axis lengths \(a\) and \(b\).',r'\[A=\pi ab\]')
new('conics.parabola-equation','conics',r'Give the equation of a parabola with focus \((0,p)\) and directrix \(y=-p\), where \(p\ne0\).',r'\[x^2=4py\]')
new('conics.hyperbola-vertices','conics',r'Give the vertices of \(\displaystyle\frac{x^2}{a^2}-\frac{y^2}{b^2}=1\), for \(a,b>0\).',r'\[(\pm a,0)\]')
new('conics.hyperbola-asymptotes','conics',r'Give the asymptotes of \(\displaystyle\frac{x^2}{a^2}-\frac{y^2}{b^2}=1\), for \(a,b>0\).',r'\[y=\pm\frac ba x\]')
new('conics.identify-ellipse','conics',r'Name the curve: \(\displaystyle\frac{x^2}{9}+\frac{y^2}{4}=1\).','Ellipse.')
new('conics.identify-hyperbola','conics',r'Name the curve: \(\displaystyle\frac{x^2}{9}-\frac{y^2}{4}=1\).','Hyperbola.')
new('conics.identify-parabola','conics',r'Name the curve: \(x^2=8y\).','Parabola.')
new('divisibility.meaning','divisibility',r'Read \(3\mid18\) in words.','Three divides eighteen.')
new('divisibility.truth','divisibility',r'Is \(3\mid18\) true or false?','True.')
keep('divisibility.definition',r'Express \(a\mid b\) using multiplication and an integer.',r'\[b=ak\text{ for some }k\in\mathbb Z.\]')
keep('divisibility.direction',r'Is \(18\mid3\) true or false?',r'False: \(3\) is not an integer multiple of \(18\).')
keep('divisibility.not',r'What does \(3\nmid19\) mean?','Three does not divide nineteen.')
keep('divisibility.slash',r'How do \(3\mid18\) and \(3/18\) differ?',r'\(3\mid18\) is a true-or-false claim. \(3/18=1/6\) is a number.')
keep('logic.or',r'Is “\(3\mid18\) or \(11\) is not prime” true or false?','True.')
keep('logic.both',r'When is \(P\lor Q\) false?','Only when both claims are false.')
keep('cubes.difference',r'Factor \(a^3-b^3\).',r'\[(a-b)(a^2+ab+b^2)\]')
keep('cubes.sum',r'Factor \(a^3+b^3\).',r'\[(a+b)(a^2-ab+b^2)\]')
keep('cubes.screenshot-factor',r'Factor \(x^3-27\).',r'\[(x-3)(x^2+3x+9)\]')
keep('cubes.transfer',r'Factor \(8x^3+125\).',r'\[(2x+5)(4x^2-10x+25)\]')
keep('cubes.simplify',r'Simplify \(\displaystyle\frac{(x+3)(x^3-27)}{x^2-9}\) and state the excluded values.',r'\[x^2+3x+9,\qquad x\ne\pm3\]')
keep('cubes.domain',r'Can cancelling \(x-3\) from a fraction make \(x=3\) allowed in the original expression?','No. The original domain restrictions remain.')
keep('cubes.distinguish',r'Are \(a^3+b^3\) and \((a+b)^3\) the same expression?',r'No. At \(a=b=1\), they give \(2\) and \(8\).')
new('cubes.expand-sum','cubes',r'Expand \((a+b)^3\).',r'\[a^3+3a^2b+3ab^2+b^3\]')
new('cubes.expand-difference','cubes',r'Expand \((a-b)^3\).',r'\[a^3-3a^2b+3ab^2-b^3\]')

# Retired questions remain readable and retain IDs for saved schedules and events.
kept = {c['id'] for c in ACTIVE}
archived=[]
for old in LEGACY['cards']:
    if old['id'] in kept: continue
    card=copy.deepcopy(old)
    card.update(revision=5, archived=True, hint='', change='wording')
    for key in ['answerBlocks','explanationSections']:card.pop(key,None)
    archived.append(card)
concepts=[]
for old in LEGACY['concepts']:
    # Keep the v2 grouping fields for exchange compatibility; there are no topic lessons.
    concepts.append(dict(id=old['id'],title=old['title'],summary='',explanation=old['title'],
                         pitfall='',sources=[],revision=5,sections=[],prerequisiteIDs=[]))
deck=dict(schemaVersion=2,title='Math foundations',concepts=concepts,cards=ACTIVE+archived,assets=[])
(ROOT/'App/Resources/starter.json').write_text(json.dumps(deck,indent=2,ensure_ascii=False)+'\n')
(ROOT/'Examples/math-foundations.json').write_text(json.dumps(deck,indent=2,ensure_ascii=False)+'\n')
for filename,title,ids in [('cube-identities.json','Cube identities',{'cubes'}),('divisibility-and-logic.json','Divisibility and logic',{'divisibility','logic'})]:
    subset=dict(deck,title=title,concepts=[c for c in concepts if c['id'] in ids],cards=[c for c in deck['cards'] if c['conceptID'] in ids])
    (ROOT/'Examples'/filename).write_text(json.dumps(subset,indent=2,ensure_ascii=False)+'\n')
print(f'{len(ACTIVE)} active cards, {len(archived)} archived questions; no lessons or decorative figures.')
