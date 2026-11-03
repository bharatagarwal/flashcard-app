"""Card-specific teaching and TikZ artwork. No topic lesson is copied into a card."""
from pathlib import Path
import base64, hashlib, json

LESSONS = {}
def add(id, title, idea, steps, pitfall, drawing, alt):
    assert id not in LESSONS
    LESSONS[id] = dict(title=title, idea=idea, steps=steps, pitfall=pitfall, drawing=drawing, alt=alt)

# Reusable drawing primitives; each card supplies its own construction and labels.
def axes(x=3, y=2):
    return rf'\draw[axis,->] (-{x},0)--({x},0) node[right] {{$x$}};\draw[axis,->] (0,-{y})--(0,{y}) node[above] {{$y$}};'
def tangent(which):
    if which == 'sin':
        return axes(3.3,1.5)+r'\draw[main,domain=-3.1:3.1,samples=90] plot(\x,{sin(\x r)});\draw[accent,domain=-1.2:1.2] plot(\x,\x) node[right] {slope $1$};\fill[ink] (0,0) circle(2pt);\node[ink,above] at (-1.8,1) {$y=\sin x$};'
    return axes(3.3,1.5)+r'\draw[main,domain=-3.1:3.1,samples=90] plot(\x,{cos(\x r)});\draw[accent,domain=.35:2.75] plot(\x,{1.5708-\x}) node[right] {$-1$};\fill[ink] (1.5708,0) circle(2pt);\node[below left] at (1.57,0) {$\frac\pi2$};\node[ink,above] at (-1.8,1) {$y=\cos x$};'
def flow(rows):
    # Vertical steps stay legible on the 13 mini, unlike a long horizontal equation.
    out=[]
    for i,(formula,label) in enumerate(rows):
        yy=-1.65*i
        out.append(rf'\node[box] (n{i}) at (0,{yy}) {{${formula}$}};')
        if i:
            out.append(rf'\draw[->,axis] (n{i-1})--(n{i}) node[midway,right=10pt,font=\small] {{{label}}};')
    return ''.join(out)
def venn(side='left', numbers=False):
    code=r'\draw[axis] (-2.5,-1.45) rectangle (2.5,1.65);'
    if side == 'left': code+=r'\begin{scope}\clip (-.75,0) circle(1.15);\fill[figurefill,even odd rule] (-2.5,-1.5) rectangle(2.5,1.7) (.75,0) circle(1.15);\end{scope}'
    elif side == 'right': code+=r'\begin{scope}\clip (.75,0) circle(1.15);\fill[figurefill,even odd rule] (-2.5,-1.5) rectangle(2.5,1.7) (-.75,0) circle(1.15);\end{scope}'
    code+=r'\draw[main] (-.75,0) circle(1.15);\draw[main] (.75,0) circle(1.15);\node at (-1.25,1.35) {$X$};\node at (1.25,1.35) {$Y$};'
    if numbers:code+=r'\node at (-1.2,.35) {$1$};\node at (-1.2,-.35) {$3$};\node at (0,0) {$2$};\node at (1.2,0) {$4$};'
    return code

def ellipse_plot(a,b,full=True):
    # All coordinates scale together; circles and ellipses keep their true shape.
    scale=2/max(a,b)
    A,B=a*scale,b*scale
    code=axes(2.65,2.65)+rf'\draw[main] (0,0) ellipse ({A} and {B});'
    code+=rf'\fill[ink] (-{A},0) circle(2pt) ({A},0) circle(2pt) (0,-{B}) circle(2pt) (0,{B}) circle(2pt);'
    code+=rf'\node[below left] at (-{A},0) {{$-{a}$}};\node[below right] at ({A},0) {{${a}$}};\node[above left] at (0,{B}) {{${b}$}};\node[below left] at (0,-{B}) {{$-{b}$}};'
    if full:
        code+=rf'\draw[accent,<->] (-{A},-{B+.5})--({A},-{B+.5}) node[midway,below] {{width ${2*a}$}};'
        code+=rf'\draw[accent,<->] ({A+.5},-{B})--({A+.5},{B}) node[midway,right,yshift=14pt] {{${2*b}$}};'
    return code

def groups(total, remainder=0):
    code=''
    for g in range(total):
        x=(g%3)*1.75; y=-(g//3)*1.35
        code+=rf'\draw[main,rounded corners=5pt] ({x-.45},{y-.45}) rectangle({x+.95},{y+.45});'
        for j in range(3):code+=rf'\fill[ink] ({x+j*.4-.15},{y}) circle(3pt);'
    if remainder:
        code+=r'\fill[accentink] (5.1,-1.35) circle(3pt);\node[below] at (5.1,-1.7) {left over};'
    return code

# Angles: resolve each rotated component, rather than reusing a generic circle.
rotation_base = r'''\draw[axis,->] (-1.3,0)--(3.2,0) node[right] {$x$};\draw[axis,->] (0,-.3)--(0,3) node[above] {$y$};
\coordinate(O) at(0,0);\coordinate(U) at(2.45,1.15);\coordinate(V) at(-.65,1.38);\coordinate(P) at(1.8,2.53);
\draw[main,->] (O)--(U) node[midway,below right] {$\cos a$};\draw[accent,->] (U)--(P);
\draw[axis,dashed] (O)--(V);\draw[axis,dashed] (V)--(P);\draw[main,->] (O)--(P);\draw[axis] (.5,0) arc(0:25:.5);\node at(.72,.16) {$b$};'''
add('angles.sin','Resolve the vertical parts',r'''After rotating through \(b\), the original horizontal component \(\cos a\) contributes \(\cos a\sin b\) vertically. The original vertical component \(\sin a\) contributes \(\sin a\cos b\). Add the two vertical contributions.''',[
('Rotate the two components',r'\[ (\cos a,0)\mapsto(\cos a\cos b,\cos a\sin b) \]\[ (0,\sin a)\mapsto(-\sin a\sin b,\sin a\cos b) \]'),
('Read the new height',r'The total angle is \(a+b\), so its height is \(\sin(a+b)\).\[\sin(a+b)=\sin a\cos b+\cos a\sin b.\] Setting \(b=0\) returns \(\sin a\).')],r'Adding angles does not add heights directly: the old horizontal component also contributes to the new height.',rotation_base+r'\draw[accent,<->] (2.95,0)--(2.95,1.15) node[midway,right] {$\cos a\sin b$};\draw[accent,<->] (2.95,1.15)--(2.95,2.53) node[midway,right] {$\sin a\cos b$};', 'A vector is split into two rotated components. The two vertical contributions stack to form the sine of the total angle.')
add('angles.cos','One horizontal contribution points left',r'''The rotated horizontal component ends at horizontal position \(\cos a\cos b\). The rotated vertical component then moves left by \(\sin a\sin b\). The final horizontal position is their difference.''',[
('Resolve along the horizontal axis',r'\[x=\cos a\cos b+\sin a(-\sin b).\] The negative sign comes from direction, not from a separate sign rule.'),
('Identify the final coordinate',r'\[\cos(a+b)=\cos a\cos b-\sin a\sin b.\] At \(a=b=\pi/4\), the two contributions cancel, as \(\cos(\pi/2)=0\).')],r'Two positive angles can produce a negative cosine. Coordinates have signs.',rotation_base+r'\draw[axis,dashed] (U)--(2.45,0);\draw[axis,dashed] (P)--(1.8,0);\draw[accent,->] (0,-.55)--(2.45,-.55) node[midway,below] {$\cos a\cos b$};\draw[accent,->] (2.45,-1.55)--(1.8,-1.55) node[left] {$-\sin a\sin b$};','The first rotated component moves right; the second moves left. Their signed horizontal displacements give cosine of the sum.')
add('angles.rotation','Rotate the upward unit vector',r'''The vector \((0,1)\) starts at angle \(\pi/2\). Rotating it counterclockwise by \(b\) puts it at angle \(\pi/2+b\). For acute positive \(b\), it lies to the left of the vertical axis.''',[
('Read its coordinates',r'\[R_b(0,1)=(-\sin b,\cos b).\] The horizontal coordinate is negative; the vertical coordinate remains positive.'),
('Scale by the original height',r'The original vector has vertical component \(\sin a\), so this part contributes \(-\sin a\sin b\) to the final horizontal coordinate. This is the minus sign in the cosine addition formula.')],r'The drawing uses acute \(b\) to show the direction clearly. Signed sine and cosine extend the same rotation rule to every angle.',axes(1.6,1.7)+r'\draw[axis,dashed] (0,0) circle(1.2);\draw[main,->] (0,0)--(0,1.2) node[above right] {$(0,1)$};\draw[accent,->] (0,0)--(-.77,.92) node[above left] {$(-\sin b,\cos b)$};\draw[axis,dashed] (-.77,.92)--(-.77,0);\draw[accent,->] (0,-.35)--(-.77,-.35) node[midway,below] {$-\sin b$};\draw[main,->] (0,.55) arc(90:130:.55);\node at(-.38,.9) {$b$};','Rotating the upward vector counterclockwise moves its tip left. Its horizontal component is minus sine b.')
add('angles.subtract','Use a clockwise rotation',r'''Subtracting \(b\) means rotating by \(-b\). Reflection across the horizontal axis leaves the horizontal coordinate unchanged and reverses the vertical coordinate.''',[
('Use even and odd symmetry',r'\[\cos(-b)=\cos b,\qquad\sin(-b)=-\sin b.\]'),
('Substitute into the sum formula',r'\[\begin{aligned}\sin(a-b)&=\sin a\cos(-b)\\&\quad+\cos a\sin(-b)\\&=\sin a\cos b-\cos a\sin b.\end{aligned}\] Check \(a=b\): the right side is zero, as it must be.')],r'Only sine changes sign when you replace an angle by its negative.',axes(1.6,1.6)+r'\draw[main] (0,0) circle(1.2);\draw[main,->] (0,0)--(.92,.77);\draw[accent,->] (0,0)--(.92,-.77);\draw[axis,dashed] (.92,.77)--(.92,-.77);\node[right] at(.92,.77) {$(\cos b,\sin b)$};\node[right] at(.92,-.77) {$(\cos b,-\sin b)$};\node[above] at(.92,0) {$\cos b$};', 'Points at b and minus b reflect across the horizontal axis: cosine stays the same and sine changes sign.')
add('angles.double','Make both angles equal',r'''A double angle is a sum of two equal angles. No new identity is needed: insert \(a=b=x\) into the cosine addition formula.''',[
('Replace both angles by x',r'\[\cos(2x)=\cos x\cos x-\sin x\sin x=\cos^2x-\sin^2x.\]'),
('Eliminate either square',r'On the unit circle, \(\sin^2x+\cos^2x=1\). Thus\[\cos(2x)=2\cos^2x-1=1-2\sin^2x.\] Choose the form that uses the quantity you know.')],r'\(\cos^2x\) means \((\cos x)^2\); it does not mean \(\cos(x^2)\).',r'\draw[axis,->] (0,0)--(3,0);\draw[axis,dashed] (2,0) arc(0:75:2);\draw[main,->] (0,0)--(30:2.5);\draw[accent,->] (0,0)--(60:2.5);\draw[main,->] (.7,0) arc(0:30:.7);\draw[accent,->] (30:1.15) arc(30:60:1.15);\node at(15:1) {$x$};\node at(45:1.45) {$x$};\node[above] at(60:2.5) {$2x=x+x$};', 'Two successive rotations by x produce a total rotation of two x.')

# Derivatives: geometry, limit, notation, and chain rule each get a different figure.
add('derivatives.sin','The slope of sine comes from horizontal position',r'''On the unit circle, a small change in angle moves the point almost along its tangent. The tangent vector at angle \(x\) points in direction \((-\sin x,\cos x)\). Its vertical component is \(\cos x\), so that is the rate of change of the sine coordinate.''',[
('Use the definition to make this exact',r'\[\frac{\sin(x+h)-\sin x}{h}=\sin x\frac{\cos h-1}{h}+\cos x\frac{\sin h}{h}.\]'),
('Take the two limits',r'In radians, the two ratios tend to \(0\) and \(1\). Therefore \((\sin x)\prime=\cos x\). At \(x=0\), the slope is \(1\), matching the drawn tangent.')],r'The geometric speed is one only when the angle uses radians. Degrees introduce a factor of \(\pi/180\).',tangent('sin'),'Graph of sine with its tangent at zero. The tangent rises one unit for each unit to the right, matching cosine zero equals one.')
add('derivatives.cos','Cosine decreases as the point moves left',r'''Cosine is the horizontal coordinate on the unit circle. The tangent vector \((-\sin x,\cos x)\) has horizontal component \(-\sin x\). At \(x=\pi/2\), the point moves left at unit speed; cosine has slope \(-1\).''',[
('Expand the difference quotient',r'\[\frac{\cos(x+h)-\cos x}{h}=\cos x\frac{\cos h-1}{h}-\sin x\frac{\sin h}{h}.\]'),
('Take the limits',r'The ratios tend to \(0\) and \(1\), giving\[\frac{d}{dx}\cos x=-\sin x.\] At \(x=0\), the derivative is zero: cosine starts at a flat maximum.')],r'The minus sign matters. For small positive \(x\), cosine decreases, so its derivative must be negative.',tangent('cos'),'Graph of cosine with tangent slope minus one at pi over two; cosine crosses zero while decreasing.')
add('derivatives.limits','Compare the triangle, sector, and outer triangle',r'''For \(0<h<\pi/2\), a unit-circle sector sits between two triangles. Their areas are \(\sin h/2\), \(h/2\), and \(\tan h/2\). The sector formula uses radians.''',[
('Squeeze the sine ratio',r'\[\sin h<h<\tan h\quad\Rightarrow\quad\cos h<\frac{\sin h}{h}<1.\] As \(h\to0^+\), both bounds approach \(1\). The ratio is even, so the two-sided limit is also \(1\).'),
('Rewrite the cosine ratio',r'\[\frac{\cos h-1}{h}=-\sin(h/2)\frac{\sin(h/2)}{h/2}\to0\cdot1=0.\] This avoids assuming a derivative rule while proving it.')],r'In degrees the sector area is not \(h/2\), so the first limit would not be \(1\).',r'\coordinate(O) at(0,0);\coordinate(A) at(2,0);\coordinate(P) at(40:2);\coordinate(T) at(2,1.678);\fill[figurefill] (O)--(A)--(T)--cycle;\fill[accentink,opacity=.18] (O)--(A) arc(0:40:2)--cycle;\draw[axis] (A)--(T);\draw[main] (O)--(A)--(P)--cycle;\draw[main] (A) arc(0:40:2);\draw[accent] (O)--(T);\node[below] at(1,0) {$1$};\node at(.55,.17) {$h$};\node[right] at(2,.85) {$\tan h$};\node[below] at(1,-.55) {$\frac12\sin h<\frac12h<\frac12\tan h$};','The inner triangle lies inside the unit circle sector, which lies inside the triangle formed by the tangent at one zero. Their areas squeeze sine h over h.')
add('derivatives.derive','Turn a secant slope into a derivative',r'''The difference quotient is the slope of the line joining two points of the sine graph. To find the tangent slope, let their horizontal separation \(h\) shrink to zero. The addition formula separates the fixed angle \(x\) from the shrinking angle \(h\).''',[
('Expand only the shifted sine',r'\[\sin(x+h)=\sin x\cos h+\cos x\sin h.\] Subtract \(\sin x\), collect its terms, and divide by \(h\).'),
('Separate what changes from what stays fixed',r'\[\frac{\Delta y}{h}=\sin x\frac{\cos h-1}{h}+\cos x\frac{\sin h}{h}.\] Here \(x\) stays fixed while \(h\) changes.'),
('Take the limit',r'The two ratios tend to \(0\) and \(1\), so\[\lim_{h\to0}\frac{\Delta y}{h}=\cos x.\]')],r'Do not replace \(h\) by zero before taking the limit: the quotient is undefined at \(h=0\).',axes(2.8,1.6)+r'\draw[main,domain=-2.5:2.5,samples=80] plot(\x,{sin(\x r)});\coordinate(A) at(.35,.343);\coordinate(B) at(1.25,.949);\draw[accent] (-.3,-.095)--(2,1.454);\draw[axis,dashed] (A)--(1.25,.343)--(B);\fill[ink] (A) circle(2pt) (B) circle(2pt);\node[below] at(.8,.343) {$h$};\node[right] at(1.25,.65) {$\Delta y$};\node[below] at(.35,0) {$x$};\node[below right] at(1.25,0) {$x+h$};','Two points on sine define a secant. A right triangle marks horizontal change h and vertical change delta y; their ratio approaches the tangent slope.')
add('derivatives.cycle','Follow the signs through one complete cycle',r'''Differentiating sine produces cosine. Differentiating cosine introduces a minus sign. A minus sign already outside a function stays outside when you differentiate.''',[
('Differentiate each result, not the original again',r'\[\sin x\to\cos x\to-\sin x\to-\cos x\to\sin x.\] In the fourth step, \((-\cos x)\prime=-(-\sin x)=\sin x\).'),
('Use the period of four',r'Every four derivatives return to the start. For example, the sixth derivative is the same as the second: \(-\sin x\). Reduce a large derivative order modulo \(4\).')],r'The first derivative is the first arrow. The starting function is derivative order zero.',r'\node[box] (s) at(0,1.3) {$\sin x$};\node[box] (c) at(2,0) {$\cos x$};\node[box] (ns) at(0,-1.3) {$-\sin x$};\node[box] (nc) at(-2,0) {$-\cos x$};\draw[main,->] (s)--(c) node[midway,above right] {$D$};\draw[main,->] (c)--(ns) node[midway,below right] {$D$};\draw[main,->] (ns)--(nc) node[midway,below left] {$D$};\draw[main,->] (nc)--(s) node[midway,above left] {$D$};','Four derivative arrows form a cycle: sine, cosine, negative sine, negative cosine, then sine again.')
add('derivatives.notation','The superscript counts operations',r'''The parentheses in \(f^{(4)}\) tell you to take the fourth derivative. An exponent without these parentheses means a power. These instructions give different results even for a simple function.''',[
('Read the derivative chain',r'\[f^{(0)}=f,\quad f^{(1)}=f\prime,\quad f^{(2)}=f\prime\prime.\] Each increase in the parenthesised number adds one differentiation.'),
('Test the distinction with a polynomial',r'For \(f(x)=x^2\):\[f^{(4)}(x)=0,\qquad[f(x)]^4=x^8.\] Four derivatives give zero; raising a value to a power does not differentiate it.')],r'\(f^{(4)}(x)\) does not mean \(f(4x)\), \(f(x^4)\), or \([f(x)]^4\).',flow([(r'x^2',''),(r'2x',r'$D$'),(r'2',r'$D$'),(r'0',r'$D$'),(r'0=f^{(4)}(x)',r'$D$')]),'A chain differentiates x squared four times: two x, two, zero, zero. It shows the superscript four counting operations.')
add('derivatives.chain','Track the angle as well as the sine',r'''The sine derivative gives change per unit of angle. In \(\sin(3x)\), the angle itself changes three times as fast as \(x\). Multiply those two rates.''',[
('Name the inside variable',r'Let \(u=3x\). Then \(y=\sin u\), \(dy/du=\cos u\), and \(du/dx=3\).'),
('Multiply the rates',r'\[\frac{dy}{dx}=\frac{dy}{du}\frac{du}{dx}=3\cos(3x).\] At \(x=0\), the slope is \(3\), not \(1\): compressing the sine wave horizontally makes it steeper.')],r'Keep the inside angle \(3x\) inside cosine. Multiply by \(3\) outside; do not replace \(\cos(3x)\) by \(\cos x\).',flow([(r'x',''),(r'u=3x',r'rate $3$'),(r'y=\sin u',r'rate $\cos u$')]) ,'Two linked changes: x to three x, with rate three, then the angle to its sine, with rate cosine. The rates multiply.')

# Repeated logarithm derivatives.
add('logs.fourth','Differentiate the two terms in parallel',r'''Differentiation distributes over addition. Keep the sine cycle and the logarithm power rule in separate columns; combine them only after four steps.''',[
('Track the sine term',r'\[\sin x\to\cos x\to-\sin x\to-\cos x\to\sin x.\]'),
('Track the logarithm term',r'\[\ln x\to x^{-1}\to-x^{-2}\to2x^{-3}\to-6x^{-4}.\] The successive multipliers after \(1/x\) are \(-1,-2,-3\).'),
('Add the fourth derivatives',r'\[f^{(4)}(x)=\sin x-\frac6{x^4},\qquad x>0.\] The domain comes from the original real-valued logarithm.')],r'The fourth logarithm derivative has coefficient \(-6\), not \(-24\). You apply the power rule only three times after the first logarithm derivative.',r'\node at(0,.55) {order};\node at(1.5,.55) {sine};\node at(3.5,.55) {logarithm};\foreach \n/\s/\l in {0/\sin x/\ln x,1/\cos x/x^{-1},2/-\sin x/-x^{-2},3/-\cos x/2x^{-3},4/\sin x/-6x^{-4}}{\node at(0,-.75*\n) {$\n$};\node at(1.5,-.75*\n) {$\s$};\node at(3.5,-.75*\n) {$\l$};}\draw[accent,rounded corners=3pt] (-.45,-3.35) rectangle(4.35,-2.65);','Two columns show all four derivatives. The final highlighted row contains sine x and minus six x to the minus four.')
add('logs.power','Apply the exponent to the coefficient and power',r'''The power rule has two jobs: multiply by the old exponent, then reduce that exponent by one. The minus sign in front is a coefficient, so it multiplies the negative exponent.''',[
('Multiply the coefficient',r'\[(-1)\cdot(-2)=2.\]'),
('Reduce the exponent',r'\[-2-1=-3,\qquad\frac{d}{dx}(-x^{-2})=2x^{-3}=\frac2{x^3}.\] At \(x=1\), the derivative is positive: \(-1/x^2\) increases toward zero as positive \(x\) grows.')],r'Subtracting one from a negative exponent makes it more negative. It does not give \(-1\).',r'\node[box] (a) at(0,1) {$-1\cdot x^{-2}$};\node[box] (b) at(-1.5,-.5) {$(-1)(-2)=2$};\node[box] (c) at(1.5,-.5) {$-2-1=-3$};\draw[main,->] (a)--(b);\draw[accent,->] (a)--(c);\node[box] (d) at(0,-2) {$2x^{-3}$};\draw[main,->] (b)--(d);\draw[accent,->] (c)--(d);','The coefficient and exponent follow separate branches: minus one times minus two gives two, while minus two minus one gives minus three.')
add('logs.general','Count the power-rule steps after the first derivative',r'''The first derivative turns \(\ln x\) into \(x^{-1}\). To reach derivative order \(n\), only \(n-1\) power-rule steps remain. Those steps supply both the alternating signs and the factorial.''',[
('Multiply the successive exponents',r'The coefficient is\[(-1)(-2)\cdots(-(n-1))=(-1)^{n-1}(n-1)!.\] For \(n=1\), the empty product equals \(1\).'),
('Track the exponent and check two cases',r'After \(n-1\) reductions, \(-1\) becomes \(-n\). Thus\[D^n\ln x=(-1)^{n-1}(n-1)!x^{-n}.\] For \(n=1\) this is \(1/x\); for \(n=4\) it is \(-6/x^4\).')],r'The formula starts at \(n=1\) and assumes \(x>0\). The factorial is \((n-1)!\).',flow([(r'\ln x',''),(r'x^{-1}',r'first derivative'),(r'(-1)x^{-2}',r'$\times(-1)$'),(r'(-1)(-2)x^{-3}',r'$\times(-2)$'),(r'(-1)(-2)(-3)x^{-4}',r'$\times(-3)$')]),'The first logarithm derivative produces x to the minus one. Each further step adds the next negative integer factor, explaining the factorial and alternating signs.')

# Sets: keep the chosen side visible and distinguish empty output from an empty input.
add('sets.meaning','Keep only the left-only region',r'''A set is a collection of elements. The symbol \(\setminus\) asks for a new collection: begin with the left-hand set, then reject every element that also belongs to the right-hand set.''',[
('Test one element at a time',r'\[z\in X\setminus Y\iff z\in X\text{ and }z\notin Y.\] An element must pass both tests.'),
('Read the shaded region',r'The overlap fails the second test. The right-only region fails the first. Only the left-only region remains. Reversing the set order generally gives a different result.')],r'The slash is set difference, not division. Shared elements are removed, not kept.',venn(), 'Only the part of X outside Y is shaded. The overlap and the right-only part are unshaded.')
add('sets.example','Remove the shared element from X',r'''Start from \(X=\{1,2,3\}\). The only element of \(X\) that is also in \(Y=\{2,4\}\) is \(2\). The element \(4\) never enters the result because it was not in the starting set.''',[
('Test the three candidates',r'\(1\notin Y\), so keep \(1\). \(2\in Y\), so remove \(2\). \(3\notin Y\), so keep \(3\).'),
('Collect what survives',r'\[X\setminus Y=\{1,3\}.\] Every answer element must belong to \(X\).')],r'Do not add \(4\). That would mix in an element from the wrong starting set.',venn(numbers=True),'X contains one and three in its left-only region and two in the overlap. Y contains four in its right-only region. Only one and three are shaded.')
add('sets.reverse','This time begin with Y',r'''The order of the operands tells you which elements can be candidates. In \(Y\setminus X\), begin with \(2\) and \(4\), not with the elements of \(X\).''',[
('Reject the overlap',r'\(2\) belongs to \(X\), so remove it from \(Y\). \(4\) does not belong to \(X\), so keep it.'),
('Compare the two directions',r'\[Y\setminus X=\{4\},\qquad X\setminus Y=\{1,3\}.\] Set difference is not commutative.')],r'The sets have not changed; only their order has. That alone changes which region you keep.',venn('right',True),'The same sets are shown, but only the right-only region of Y, containing four, is shaded.')
add('sets.self','Every candidate fails the second test',r'''You may start with a large, nonempty set \(X\). But subtracting that same set removes every element you started with. An empty result does not mean the original set was empty.''',[
('Try to keep an element',r'For an element \(z\) to survive, it would need\[z\in X\quad\text{and}\quad z\notin X.\] These claims cannot both be true.'),
('Name the result',r'No element survives, so \(X\setminus X=\varnothing\). This also holds when \(X\) is already empty.')],r'\(\varnothing\) is the empty set. \(\{\varnothing\}\) is a different set containing one element.',r'\draw[main] (0,0) circle(1.2);\node at(0,.65) {$X$};\foreach \x/\y in {-.45/0,.45/0,0/-.55}{\fill[ink] (\x,\y) circle(3pt);\draw[accent] (\x-.14,\y-.14)--(\x+.14,\y+.14);\draw[accent] (\x-.14,\y+.14)--(\x+.14,\y-.14);}\draw[axis,->] (1.5,0)--(2.4,0);\node[box] at(3,0) {$\varnothing$};','All three sample elements in X are crossed out when X is removed from itself. The output is the empty set.')

# Circle and ellipse geometry.
add('ellipse.circle','A radius is the hypotenuse',r'''Take any point \((x,y)\) on the circle and join it to the centre \((h,k)\). A horizontal step followed by a vertical step forms a right triangle. Their lengths are \(|x-h|\) and \(|y-k|\); the hypotenuse has length \(r\).''',[
('Use the distance rule',r'Pythagoras gives\[(x-h)^2+(y-k)^2=r^2.\] Squaring removes the need for absolute values.'),
('Read the equation as a condition',r'Every point satisfying this equation is at distance \(r\) from \((h,k)\), so the equation describes exactly the circle. At \((0,0)\) as centre, it reduces to \(x^2+y^2=r^2\).')],r'The right side is \(r^2\), not \(r\). Horizontal and vertical distances must be squared before adding.',r'\draw[main] (0,0) circle(2);\coordinate(P) at(40:2);\fill[figurefill] (0,0)--(1.532,0)--(P)--cycle;\draw[main] (0,0)--(P) node[midway,above left] {$r$};\draw[accent] (0,0)--(1.532,0) node[midway,below] {$|x-h|$};\draw[accent] (1.532,0)--(P) node[midway,right] {$|y-k|$};\draw[axis] (1.35,0)--(1.35,.18)--(1.532,.18);\node[below left] at(0,-.55) {$(h,k)$};\node[above right] at(P) {$(x,y)$};','A radius from the centre h k to a point x y forms a right triangle with horizontal distance x minus h and vertical distance y minus k.')
add('ellipse.screenshot','Find both endpoints of each axis',r'''The denominator \(4\) is a squared half-width. The ellipse crosses the horizontal axis where \(y=0\), and the vertical axis where \(x=0\). Finding these crossings avoids relying on a memorised rule.''',[
('Set the vertical coordinate to zero',r'\[\frac{x^2}{4}=1\Rightarrow x=\pm2.\] The horizontal length is \(2-(-2)=4\).'),
('Set the horizontal coordinate to zero',r'\[y^2=1\Rightarrow y=\pm1.\] The vertical length is \(1-(-1)=2\). Thus the major axis is horizontal with length \(4\), and the minor axis has length \(2\).')],r'A semi-axis goes from the centre to an endpoint. A full axis joins opposite endpoints, so it is twice as long.',ellipse_plot(2,1),'The ellipse has horizontal intercepts minus two and two, vertical intercepts minus one and one, and dimension arrows marking full width four and height two.')
add('ellipse.transfer','The larger denominator is under y',r'''For \(x^2/9+y^2/25=1\), the horizontal and vertical roles differ from your earlier example. Let the intercepts determine the direction of the major axis.''',[
('Find the horizontal length',r'With \(y=0\), \(x^2=9\), so the endpoints are \((-3,0)\) and \((3,0)\). Their distance is \(6\).'),
('Find the vertical length',r'With \(x=0\), \(y^2=25\), so the endpoints are \((0,-5)\) and \((0,5)\). Their distance is \(10\). The major axis is vertical because \(10>6\).')],r'The major axis does not always lie along x. Its direction follows the longer half-axis.',ellipse_plot(3,5),'A tall ellipse has horizontal intercepts plus and minus three and vertical intercepts plus and minus five. Dimension arrows show six across and ten vertically.')
add('ellipse.recover','Reduce the curve to two one-variable equations',r'''An intercept is a point where the curve meets an axis. On the horizontal axis, every point has \(y=0\). On the vertical axis, every point has \(x=0\). These facts let you recover the lengths directly from the equation.''',[
('Recover the horizontal endpoints',r'For \(x^2/a^2+y^2/b^2=1\), put \(y=0\): \(x=\pm a\). The endpoint distance is \(a-(-a)=2a\).'),
('Recover the vertical endpoints',r'Put \(x=0\): \(y=\pm b\). The distance is \(2b\). With \(a,b>0\), the full major length is \(2\max(a,b)\), and the minor length is \(2\min(a,b)\).')],r'This argument assumes an origin-centred ellipse aligned with the axes. Shift the coordinates first for a translated ellipse.',axes(2.8,1.8)+r'\draw[main] (0,0) ellipse(2 and 1.1);\fill[accentink] (-2,0) circle(2pt) (2,0) circle(2pt) (0,-1.1) circle(2pt) (0,1.1) circle(2pt);\node[below left] at(-2,0) {$(-a,0)$};\node[below right] at(2,0) {$(a,0)$};\node[above left] at(0,1.1) {$(0,b)$};\node[below right] at(0,-1.1) {$(0,-b)$};','The four axis intercepts of a general ellipse are labelled minus a zero, a zero, zero b, and zero minus b.')
add('ellipse.shift','Read the zero offsets before the radius',r'''The centre makes both squared offsets zero. In \((x-3)^2+(y+2)^2=16\), that happens at \(x=3\), \(y=-2\). The right side then tells you the squared radius.''',[
('Match the shifted-circle form',r'\[(x-h)^2+(y-k)^2=r^2.\] Since \(y+2=y-(-2)\), the centre is \((3,-2)\).'),
('Take the positive square root',r'\[r=\sqrt{16}=4.\] A quick check: the point four units to the right of the centre is \((7,-2)\); substituting gives \(16+0=16\).')],r'The signs inside the parentheses oppose the centre coordinates. The radius is \(4\), not \(16\).',r'\draw[axis,->] (-1,0)--(5,0) node[right] {$x$};\draw[axis,->] (0,-4)--(0,1) node[above] {$y$};\draw[main] (1.8,-1.2) circle(2.4);\draw[axis,dashed] (1.8,0)--(1.8,-1.2)--(0,-1.2);\draw[accent,->] (1.8,-1.2)--(4.2,-1.2) node[midway,above] {$4$};\fill[ink] (1.8,-1.2) circle(2pt);\node[below] at(1.8,-1.2) {$(3,-2)$};\node[right] at(4.2,-1.2) {$(7,-2)$};','A shifted circle is centred at three minus two. A horizontal radius of four reaches seven minus two. Dashed projections locate the centre.')

# Measurement: show the definition or the dissection, not another ellipse outline.
add('measure.circumference','The factor two converts radius to diameter',r'''For every circle, the ratio of circumference to diameter is the same number, \(\pi\). That definition already gives the circumference once you know the diameter.''',[
('Start with the ratio',r'\[\pi=\frac{C}{d}\Rightarrow C=\pi d.\]'),
('Replace diameter by two radii',r'A diameter crosses the centre and contains two radii, so \(d=2r\). Hence \(C=2\pi r\). Doubling the radius doubles this length.')],r'Circumference is a length, so its units are not squared. The area formula uses \(r^2\); this one uses \(r\).',r'\draw[main] (0,0) circle(1.6);\fill[ink] (0,0) circle(2pt);\draw[accent,<->] (-1.6,0)--(1.6,0);\node[above] at(-.8,0) {$r$};\node[above] at(.8,0) {$r$};\node at(0,-2.1) {$d=2r$};\draw[axis,->] (2.05,0)--(3,0);\node[box] at(3.9,0) {$C=\pi d$};','A circle diameter is split at the centre into two equal radii. An arrow leads to circumference equals pi times diameter.')
# Finite sectors, not rectangles: the curved edges remain visible until the limiting argument.
sector_code=r'\draw[main] (0,2.65) circle(1.05);\foreach \a in {0,30,...,330}{\draw[axis] (0,2.65)--++(\a:1.05);}\draw[axis,->] (0,1.4)--(0,.85);'
for i in range(6):
    x=-1.5+i*.54352
    sector_code+=rf'\begin{{scope}}[shift={{({x},-.55)}}]\filldraw[fill=figurefill,draw=ink] (0,0)--(75:1.05) arc(75:105:1.05)--cycle;\end{{scope}}'
    sector_code+=rf'\begin{{scope}}[shift={{({x+.27176},.46422)}}]\filldraw[fill=figurefill,draw=accentink] (0,0)--(255:1.05) arc(255:285:1.05)--cycle;\end{{scope}}'
sector_code+=r'\draw[accent,<->] (-1.8,-.85)--(1.8,-.85) node[midway,below] {base $\longrightarrow\pi r$};\node[right] at(1.9,0) {height $\longrightarrow r$};'
add('measure.area','Rearrange sectors without changing the area',r'''Cut the circle into equal thin sectors and alternate their directions. The curved tops and bottoms approach straight edges as the sectors get thinner. The rearranged area stays the same because the pieces do not stretch.''',[
('Find the limiting height and base',r'The height tends to the radius \(r\). Half the original circumference lies along each long edge, so the base tends to \(C/2=\pi r\).'),
('Multiply the limiting dimensions',r'\[A=(\pi r)r=\pi r^2.\] At a finite number of sectors, the outline is still curved; the rectangle argument becomes exact in the limit.')],r'Use half the circumference for the base. Using all of \(2\pi r\) would double-count the area.',sector_code,'A circle is cut into twelve sectors. Alternating upward and downward sectors form a strip with curved edges; in the limit its base tends to pi r and its height to r.')
add('measure.ellipse','A stretch multiplies every small area',r'''Begin with a unit circle, whose area is \(\pi\). Stretch horizontal distances by \(a\) and vertical distances by \(b\). A tiny rectangle of area \(\Delta x\Delta y\) becomes one of area \((a\Delta x)(b\Delta y)\).''',[
('Find the area scale factor',r'Each tiny rectangle grows by the same factor \(ab\). Adding all these pieces multiplies the total area by \(ab\).'),
('Apply the factor to the circle',r'\[A_{\text{ellipse}}=ab\cdot\pi=\pi ab.\] If \(a=b=r\), this becomes \(\pi r^2\). If you know full axis lengths \(L,W\), use \(a=L/2\), \(b=W/2\).')],r'Full axis lengths would give \(\pi LW/4\), not \(\pi LW\). The stretch factors are half-axis lengths.',r'\begin{scope}[shift={(-2,0)}]\draw[axis,step=.5] (-1,-1) grid(1,1);\draw[main] (0,0) circle(1);\filldraw[fill=figurefill,draw=accentink] (0,0) rectangle(.5,.5);\node[below] at(0,-1.2) {area $\pi$};\end{scope}\draw[axis,->] (-.65,0)--(.3,0);\begin{scope}[shift={(2.2,0)}]\draw[axis,xstep=.9,ystep=.35] (-1.8,-.7) grid(1.8,.7);\draw[main] (0,0) ellipse(1.8 and .7);\filldraw[fill=figurefill,draw=accentink] (0,0) rectangle(.9,.35);\node[below] at(0,-1.2) {area $\pi ab$};\end{scope}', 'A unit circle on a square grid is stretched into an ellipse on a rectangular grid. A highlighted grid cell shows horizontal and vertical scale factors multiplying area.')

# Conics: define each shape through its distance or asymptote construction.
add('conics.parabola','Equal distances define the curve',r'''A parabola is the set of points equally far from a fixed point, the focus, and a fixed line, the directrix. A point \((x,y)\) is at perpendicular distance \(|y+p|\) from the line \(y=-p\).''',[
('Write the two squared distances',r'The squared distance to \((0,p)\) is \(x^2+(y-p)^2\). The squared distance to the directrix is \((y+p)^2\). Thus\[x^2+(y-p)^2=(y+p)^2.\]'),
('Expand and cancel',r'\[x^2+y^2-2py+p^2=y^2+2py+p^2.\] Cancel the matching squares to get \(x^2=4py\). The vertex \((0,0)\) lies halfway between the focus and directrix.')],r'The picture takes \(p>0\). The algebra also allows \(p<0\), which opens downward. The standard form requires \(p\ne0\).',r'\draw[axis,->] (-2.4,0)--(2.6,0) node[right] {$x$};\draw[axis,->] (0,-1.5)--(0,2.5) node[above] {$y$};\draw[accent] (-2.4,-.65)--(2.4,-.65) node[right] {$y=-p$};\draw[main,domain=-2.15:2.15,samples=70] plot(\x,{\x*\x/2.6});\coordinate(P) at(1.7,1.1115);\fill[ink] (0,.65) circle(2pt) node[left] {$(0,p)$};\draw[main] (0,.65)--(P) node[midway,above] {$d$};\draw[accent] (P)--(1.7,-.65) node[midway,right] {$d$};\fill[ink] (P) circle(2pt) node[above right] {$(x,y)$};\draw[axis] (1.5,-.65)--(1.5,-.45)--(1.7,-.45);', 'An upward parabola has focus above the origin and a horizontal directrix below it. A point on the curve has two equal marked distances: to the focus and straight down to the directrix.')
add('conics.hyperbola','Vertices come from an exact slice; asymptotes from a limit',r'''At \(y=0\), the horizontal hyperbola meets the x-axis at two vertices. Far away, the constant term becomes small compared with the squared coordinates, so the branches approach two straight lines.''',[
('Find the vertices',r'\[\frac{x^2}{a^2}=1\Rightarrow x=\pm a.\] Thus the vertices are \((\pm a,0)\).'),
('Find the limiting slopes',r'Rearrange as \(y^2=(b^2/a^2)x^2-b^2\). Dividing by \(x^2\) gives\[\left(\frac yx\right)^2=\frac{b^2}{a^2}-\frac{b^2}{x^2}\to\frac{b^2}{a^2}.\] Hence the asymptotes are \(y=\pm(b/a)x\).')],r'Asymptotes describe limiting lines; they are not the hyperbola itself. The vertices are not at \(\pm b\).',axes(3,2.3)+r'\draw[axis,dashed] (-2.7,-1.8)--(2.7,1.8);\draw[axis,dashed] (-2.7,1.8)--(2.7,-1.8);\draw[axis,dotted] (-1.2,-.8) rectangle(1.2,.8);\foreach \sgn in {-1,1}{\draw[main,domain=-1.45:1.45,samples=80] plot({\sgn*1.2*cosh(\x)},{.8*sinh(\x)});}\fill[ink] (-1.2,0) circle(2pt) (1.2,0) circle(2pt);\node[above left] at(-1.2,0) {$-a$};\node[above right] at(1.2,0) {$a$};\node[right] at(1.2,.8) {$b$};\node[above] at(2.1,1.4) {$\frac ba$};','The two hyperbola branches open left and right from vertices plus and minus a. Diagonals through a rectangle of half-width a and half-height b show the asymptote slopes.')
add('conics.classify','Look for boundedness and the squared terms',r'''In nondegenerate standard forms, the signs of the squared terms tell you whether both coordinates are bounded. A parabola has only one squared coordinate, with the other coordinate appearing linearly.''',[
('Two positive squares bound the coordinates',r'For \(x^2/a^2+y^2/b^2=1\), each nonnegative term is at most \(1\). Thus \(|x|\le a\) and \(|y|\le b\): an ellipse.'),
('A subtraction permits unbounded branches',r'For \(x^2/a^2-y^2/b^2=1\), large squared terms can balance. This gives a hyperbola. For \(x^2=4py\), choosing any \(x\) determines one \(y\): a parabola.')],r'These tests apply after putting a nondegenerate, axis-aligned equation into standard form. A rotated equation may include an \(xy\) term.',r'\begin{scope}[shift={(-2.6,0)},scale=.65]\draw[main] (0,0) ellipse(1.3 and .8);\node[below] at(0,-1.6) {$+x^2,+y^2$};\node[above] at(0,1.4) {ellipse};\end{scope}\begin{scope}[scale=.65]\foreach \s in {-1,1}{\draw[main,domain=-1:1,samples=40] plot({\s*.6*cosh(\x)},{.7*sinh(\x)});}\node[below] at(0,-1.6) {$+x^2,-y^2$};\node[above] at(0,1.4) {hyperbola};\end{scope}\begin{scope}[shift={(2.6,0)},scale=.65]\draw[main,domain=-1.2:1.2,samples=40] plot(\x,{\x*\x-.7});\node[below] at(0,-1.6) {$x^2,\ y$};\node[above] at(0,1.4) {parabola};\end{scope}', 'Three standard conics are compared: a closed ellipse from a sum of squares, a two-branch hyperbola from a difference of squares, and a parabola from one squared and one linear coordinate.')

# Divisibility: exact groups, integer multiples, direction, remainder, and type.
add('divisibility.read','Can eighteen objects form groups of three?',r'''The notation \(3\mid18\) is a claim about whole-number groups. If eighteen objects split into groups of three with none left over, the claim is true.''',[
('Find an integer multiplier',r'\[18=3\cdot6.\] Six complete groups of three account for all eighteen objects.'),
('Read the notation in its written order',r'The left number is the divisor and the right number is the total. Read \(3\mid18\) as “three divides eighteen”.')],r'This symbol does not ask you to calculate \(3/18\). Its result is true or false.',groups(6),'Eighteen dots form six complete boxes of three, with no leftover dot. This witnesses three divides eighteen.')
add('divisibility.definition','An integer multiple is the whole definition',r'''For integers \(a,b\), saying \(a\mid b\) means that multiplying \(a\) by some integer reaches \(b\). The multiplier may be positive, zero, or negative.''',[
('Translate the notation',r'\[a\mid b\iff\text{there exists }k\in\mathbb Z\text{ such that }b=ak.\]'),
('Check the role of the integer condition',r'For instance, \(4\mid(-12)\) because \(-12=4(-3)\). But \(4\nmid6\), because the required multiplier \(3/2\) is not an integer. Also \(a\mid0\) for every integer \(a\), using \(k=0\).')],r'Under this multiplication definition, \(0\mid0\) is true, but \(0\nmid b\) for \(b\ne0\). A no-remainder division test requires a nonzero divisor.',r'\draw[axis,->] (-3,0)--(3.3,0);\foreach \x/\lab in {-2.4/-3a,-1.6/-2a,-.8/-a,0/0,.8/a,1.6/2a,2.4/3a}{\fill[ink] (\x,0) circle(2pt);\node[below] at(\x,0) {$\lab$};}\draw[accent,->] (0,.6)--(2.4,.6) node[midway,above] {three steps of $a$};\node at(0,-1) {$b=ak,\quad k\in\mathbb Z$};','Multiples of a appear at equally spaced marked positions on a number line, illustrating that an integer number of steps of size a reaches a divisible number. The sketch assumes positive a.')
add('divisibility.direction','A group of eighteen cannot fit into three',r'''Read \(18\mid3\) from left to right: is three an integer multiple of eighteen? Reversing the order of a true divisibility statement need not preserve its truth.''',[
('Solve for the required multiplier',r'\[3=18k\Rightarrow k=\frac16.\] Since \(1/6\notin\mathbb Z\), the required integer does not exist.'),
('State the conclusion',r'\[18\nmid3.\] In contrast, \(3\mid18\) is true because its multiplier is \(6\).')],r'An ordinary real-valued quotient always exists for a nonzero divisor. Divisibility asks whether that quotient is an integer.',r'\draw[axis,->] (-.3,0)--(5.2,0);\foreach \x/\lab in {0/0,.75/3,4.5/18}{\draw[axis] (\x,-.1)--(\x,.1);\node[below] at(\x,-.1) {$\lab$};}\draw[main,->] (0,.5)--(4.5,.5) node[midway,above] {one whole step of $18$};\fill[accentink] (.75,0) circle(3pt);\node at(2.5,-1) {$3=18\cdot\frac16$};', 'On a number line, three lies only one sixth of the way from zero to eighteen. It cannot be reached by an integer number of eighteen-unit steps.')
add('divisibility.not','One leftover object disproves exact grouping',r'''The crossed bar \(\nmid\) negates divisibility. Nineteen does not split into whole groups of three: six such groups use eighteen objects and leave one object.''',[
('Write division with a remainder',r'\[19=3\cdot6+1,\qquad0<1<3.\]'),
('Explain why another integer cannot fix it',r'The neighbouring multiples are \(18\) and \(21\). Since \(19\) lies strictly between them, it is not a multiple of \(3\). Therefore \(3\nmid19\).')],r'The crossed bar negates the claim “divides”. It is not a request for a negative quotient.',groups(6,1),'Six boxes contain three dots each, accounting for eighteen dots. A separate highlighted nineteenth dot remains outside the boxes.')
add('divisibility.slash','A claim and a number are different kinds of answer',r'''The vertical bar connects integers in a true-or-false statement. A fraction bar creates a number by division. Similar-looking marks can therefore ask entirely different questions.''',[
('Interpret the vertical bar',r'\[3\mid18\iff18=3k\text{ for some }k\in\mathbb Z.\] Here \(k=6\), so the statement is true.'),
('Interpret the fraction',r'\[\frac3{18}=\frac16.\] This is a numerical value. Notice that testing \(3\mid18\) would inspect \(18/3\), with the total divided by the proposed divisor.')],r'Do not infer divisibility by taking the written numbers as the fraction \(3/18\). The order in the quotient test is reversed.',r'\node[box] (a) at(-1.6,1) {$3\mid18$};\node[box] (b) at(1.6,1) {$\frac3{18}$};\node[box] (c) at(-1.6,-.7) {true};\node[box] (d) at(1.6,-.7) {$\frac16$};\draw[main,->] (a)--(c) node[midway,left] {claim};\draw[accent,->] (b)--(d) node[midway,right] {number};','Two branches distinguish notation: three divides eighteen evaluates to true, while the fraction three over eighteen evaluates to one sixth.')

add('logic.or','One true part is enough',r'''Separate the sentence into two claims before combining them. Let \(P\) mean \(3\mid18\), and let \(Q\) mean “eleven is not prime”. Mathematical “or” includes the case where both claims are true.''',[
('Evaluate each claim',r'\(P\) is true because \(18=3\cdot6\). \(Q\) is false because the only positive divisors of \(11\) are \(1\) and \(11\), so \(11\) is prime.'),
('Apply inclusive or',r'\[P\lor Q=\text{true}\lor\text{false}=\text{true}.\] An “and” between these same claims would give false.')],r'“Or” does not require the second claim to be true once the first is true.',r'\node[box] (p) at(-1.55,1) {$3\mid18:\ \mathrm{T}$};\node[box] (q) at(1.55,1) {$11\text{ not prime}:\ \mathrm{F}$};\node[box] (o) at(0,-.5) {$\mathrm{OR}$};\draw[main,->] (p)--(o);\draw[axis,->] (q)--(o);\node[box] (t) at(0,-1.9) {$\mathrm{T}$};\draw[main,->] (o)--(t);','The true divisibility claim and false claim that eleven is not prime feed an OR operation, whose output is true.')
add('logic.both','Enumerate the four possibilities',r'''Each claim can be true or false, so there are exactly four pairs to check. Inclusive “or” accepts every pair with at least one true entry.''',[
('Check the pairs containing a true claim',r'\[\mathrm{T}\lor\mathrm{T}=\mathrm{T},\quad\mathrm{T}\lor\mathrm{F}=\mathrm{T},\quad\mathrm{F}\lor\mathrm{T}=\mathrm{T}.\]'),
('Find the only failing pair',r'\[\mathrm{F}\lor\mathrm{F}=\mathrm{F}.\] Equivalently, \(\neg(P\lor Q)\) means \((\neg P)\land(\neg Q)\): both claims must fail.')],r'Exclusive or rejects the true-true row. Ordinary mathematical or accepts it.',r'\node at(-1,1.3) {$P$};\node at(0,1.3) {$Q$};\node at(1.3,1.3) {$P\lor Q$};\draw[axis] (-1.5,.95)--(2,.95);\foreach \y/\p/\q/\r in {.55/T/T/T,-.2/T/F/T,-.95/F/T/T,-1.7/F/F/F}{\node at(-1,\y) {$\mathrm{\p}$};\node at(0,\y) {$\mathrm{\q}$};\node at(1.3,\y) {$\mathrm{\r}$};}\draw[accent,rounded corners=3pt] (-1.5,-2.02) rectangle(2,-1.38);','A four-row truth table for inclusive OR highlights the false-false row, the only row whose result is false.')

# Cubes: cancellation diagrams keep the mechanism distinct from a mnemonic.
def cancellation(sign='-', A='a', B='b'):
    # Products are aligned in columns so the cancellation is visible.
    if sign=='-':
        top=[r'a^3',r'+a^2b',r'+ab^2',''];bot=['',r'-a^2b',r'-ab^2',r'-b^3'];result=r'a^3-b^3'
    else:
        top=[r'a^3',r'-a^2b',r'+ab^2',''];bot=['',r'+a^2b',r'-ab^2',r'+b^3'];result=r'a^3+b^3'
    code=''
    for i,t in enumerate(top): code+=rf'\node at({1.35*i},.5) {{${t}$}};'
    for i,t in enumerate(bot): code+=rf'\node at({1.35*i},-.5) {{${t}$}};'
    code+=r'\draw[axis] (-.65,-1.1)--(4.7,-1.1);'
    for i in (1,2):code+=rf'\draw[accent,rounded corners=4pt] ({1.35*i-.6},-.85) rectangle({1.35*i+.6},.85);'
    code+=rf'\node at(2,-1.55) {{${result}$}};'
    return code
add('cubes.difference','Choose the quadratic so the middle terms cancel',r'''A difference of cubes has a factor \(a-b\): the expression becomes zero at \(a=b\). To discover the other factor, start with \(a^2\), then choose terms that cancel the mixed products.''',[
('Build the cancellation',r'\(a\cdot a^2=a^3\). Multiplying \(a^2\) by \(-b\) creates \(-a^2b\), so add \(+ab\) to the quadratic. That creates \(-ab^2\), so also add \(+b^2\).'),
('Check the remaining endpoint',r'The final product contributes \(-b\cdot b^2=-b^3\). All mixed terms cancel:\[a^3-b^3=(a-b)(a^2+ab+b^2).\]')],r'The quadratic contains \(+ab\) and \(+b^2\). A difference of cubes is not \((a-b)^3\).',cancellation('-'),'Two product rows align positive and negative mixed terms. Highlighted pairs cancel, leaving a cubed minus b cubed.')
add('cubes.sum','The plus factor needs an opposite middle sign',r'''A sum of cubes has a factor \(a+b\), since putting \(a=-b\) makes the sum zero. The quadratic must cancel mixed terms created by multiplying with \(+b\).''',[
('Choose the middle coefficient',r'In \((a+b)(a^2+Cab+b^2)\), the \(a^2b\) coefficient is \(C+1\). To make it zero, choose \(C=-1\).'),
('Check both cancellations',r'\[\begin{aligned}(a+b)(a^2-ab+b^2)&=a^3-a^2b+ab^2\\&\quad+a^2b-ab^2+b^3\\&=a^3+b^3.\end{aligned}\]')],r'The last term stays \(+b^2\). Only the mixed term changes sign between the two cube-factor identities.',cancellation('+'),'Aligned product rows for the sum of cubes cancel the opposite mixed terms and leave positive endpoint cubes.')
add('cubes.derive-difference','Distribute first, then combine like terms',r'''A proof of the factorisation must account for all six products. Treat multiplication by \(a\) and multiplication by \(-b\) as separate rows, then combine the matching columns.''',[
('Multiply by a',r'\[a(a^2+ab+b^2)=a^3+a^2b+ab^2.\]'),
('Multiply by negative b',r'\[-b(a^2+ab+b^2)=-a^2b-ab^2-b^3.\]'),
('Add the rows',r'\(+a^2b\) cancels \(-a^2b\), and \(+ab^2\) cancels \(-ab^2\). The only surviving terms are \(a^3-b^3\).')],r'Distribute the negative sign to all three terms in the second row, not just the first.',cancellation('-')+r'\node[left] at(-.8,.5) {$a\times$};\node[left] at(-.8,-.5) {$-b\times$};','Rows labelled multiplication by a and by negative b show all six products. Opposite mixed terms cancel in matched columns.')
add('cubes.derive-sum','Substitute a negative value into the difference identity',r'''An identity holds for every allowed input, so you may replace \(b\) by \(-b\) throughout it. Odd powers reverse sign; even powers do not.''',[
('Make the substitution everywhere',r'\[a^3-(-b)^3=(a-(-b))(a^2+a(-b)+(-b)^2).\]'),
('Simplify each sign separately',r'\((-b)^3=-b^3\), \(a-(-b)=a+b\), \(a(-b)=-ab\), and \((-b)^2=b^2\). Therefore\[a^3+b^3=(a+b)(a^2-ab+b^2).\]')],r'Replace every occurrence of \(b\), including the one inside \(b^2\). Squaring a negative does not leave a negative square.',flow([(r'a^3-b^3=(a-b)(a^2+ab+b^2)',''),(r'b\mapsto-b',r'substitute'),(r'a^3+b^3=(a+b)(a^2-ab+b^2)',r'odd and even powers')]),'A substitution diagram changes b to negative b in the difference identity, then simplifies to the sum-of-cubes factors.')
add('cubes.screenshot-factor','Recognise twenty-seven as a cube',r'''The difference-of-cubes identity applies to whole cubes. Here \(x^3\) is the cube of \(x\), and \(27\) is the cube of \(3\). Match the bases before forming the factors.''',[
('Identify the two bases',r'\[x^3-27=x^3-3^3,\qquad a=x,\quad b=3.\]'),
('Substitute into both factors',r'\[x^3-27=(x-3)(x^2+3x+9).\] The last term is \(3^2=9\), not \(27\). At \(x=4\), both sides equal \(37\), a useful arithmetic check.')],r'The factor \(x-3\) alone is not the answer; the quadratic factor is also required.',flow([(r'x^3-3^3',''),(r'(x-3)(x^2+x\cdot3+3^2)',r'match $a=x,\ b=3$'),(r'(x-3)(x^2+3x+9)',r'simplify')]),'A vertical substitution diagram rewrites twenty-seven as three cubed, inserts x and three into the identity, and simplifies the quadratic terms.')
add('cubes.transfer','Cube roots identify the full bases',r'''The first base is \(2x\), because \((2x)^3=8x^3\). The second is \(5\), because \(5^3=125\). Use the sum identity, keeping the complete expression \(2x\) together when squaring it.''',[
('Match the identity',r'\[a^3+b^3=(a+b)(a^2-ab+b^2),\quad a=2x,\ b=5.\]'),
('Calculate the quadratic terms',r'\[(2x)^2=4x^2,\quad(2x)(5)=10x,\quad5^2=25.\] Hence\[8x^3+125=(2x+5)(4x^2-10x+25).\]')],r'\((2x)^2\) is \(4x^2\), not \(2x^2\). The middle quadratic term is negative for the sum identity.',flow([(r'(2x)^3+5^3',''),(r'(2x+5)((2x)^2-(2x)5+5^2)',r'use the sum identity'),(r'(2x+5)(4x^2-10x+25)',r'evaluate each product')]),'The bases two x and five are substituted into the sum-of-cubes identity. Each squared and mixed term is evaluated explicitly.')
add('cubes.simplify','Cancel whole factors on the original domain',r'''Before simplifying a fraction, record where its original denominator is zero. Then factor both numerator and denominator into products. Cancellation is justified only when the shared factors are nonzero.''',[
('Record the excluded values',r'\[x^2-9=(x-3)(x+3),\quad x\ne3,-3.\]'),
('Factor the cube and cancel products',r'\[\frac{(x+3)(x-3)(x^2+3x+9)}{(x-3)(x+3)}=x^2+3x+9.\] Each cancellation divides by a nonzero whole factor.'),
('Keep the restrictions',r'The simplified expression represents the original only for \(x\ne\pm3\). Its polynomial formula has values there, but the original fraction does not.')],r'You cannot cancel isolated terms across addition. Turn sums into products before cancelling.',r'\node at(0,1) {$\displaystyle\frac{\underbrace{(x+3)(x-3)}_{\text{common product}}(x^2+3x+9)}{\underbrace{(x-3)(x+3)}_{\text{same product}}}$};\draw[main,->] (0,-.1)--(0,-.7);\node[box] at(0,-1.2) {$x^2+3x+9,\quad x\ne\pm3$};','The factorised fraction marks the same product in numerator and denominator. The result retains the exclusions x not equal to plus or minus three.')
add('cubes.domain','A cancellation does not fill a hole',r'''Consider the simplest example: \((x-3)/(x-3)\). It equals \(1\) whenever \(x\ne3\), but at \(x=3\) the original expression asks for \(0/0\), which is undefined.''',[
('State what cancellation actually proves',r'\[\frac{x-3}{x-3}=1\quad\text{for }x\ne3.\] The condition is part of the equality.'),
('Distinguish a simplification from an extension',r'Defining a new function with value \(1\) at \(3\) would fill the hole, but it would be a new definition. Algebraic cancellation alone does not change the original domain.')],r'A finite limit at an excluded point does not make the original function defined at that point.',r'\draw[axis,->] (-.4,0)--(4.7,0) node[right] {$x$};\draw[axis,->] (0,-.3)--(0,2) node[above] {$y$};\draw[main] (-.3,1)--(4.4,1);\fill[figurefill] (2.4,1) circle(5pt);\draw[accent,very thick] (2.4,1) circle(5pt);\draw[axis,dashed] (2.4,0)--(2.4,.85);\node[below] at(2.4,0) {$3$};\node[left] at(0,1) {$1$};\node[above] at(2.4,1.3) {undefined};\node at(2.4,-.8) {$y=\frac{x-3}{x-3}$};','The graph is a horizontal line at height one with an open circle at x equals three. The missing point shows the domain restriction survives cancellation.')
# A genuine geometric comparison: two cubes versus all eight pieces of a larger cube.
cube_draw=r'\begin{scope}[x={(.75cm,0cm)},y={(.3cm,.25cm)},z={(0cm,.75cm)}]'
def cuboid(x,y,z,dx,dy,dz,fill='figurefill'):
    return rf'\filldraw[fill={fill},draw=ink] ({x},{y},{z})--({x+dx},{y},{z})--({x+dx},{y},{z+dz})--({x},{y},{z+dz})--cycle;\filldraw[fill={fill},draw=ink] ({x},{y},{z+dz})--({x+dx},{y},{z+dz})--({x+dx},{y+dy},{z+dz})--({x},{y+dy},{z+dz})--cycle;\filldraw[fill={fill},draw=ink] ({x+dx},{y},{z})--({x+dx},{y+dy},{z})--({x+dx},{y+dy},{z+dz})--({x+dx},{y},{z+dz})--cycle;'
cube_draw+=cuboid(0,0,0,1,1,1)+cuboid(1.8,0,0,1,1,1)+r'\node at(.5,0,-.45) {$1$};\node at(2.3,0,-.45) {$1$};\node at(1.4,0,-1) {$1^3+1^3=2$};'
cube_draw+=cuboid(5,0,0,2,2,2)
for t in [1]:
    cube_draw+=r'\draw[accent] (6,0,0)--(6,0,2)--(6,2,2);\draw[accent] (5,0,1)--(7,0,1)--(7,2,1);\draw[accent] (5,1,2)--(7,1,2)--(7,1,0);'
cube_draw+=r'\node at(6,0,-.45) {$2$};\node at(6,0,-1) {$(1+1)^3=8$};\end{scope}'
add('cubes.distinguish','Parentheses decide what gets cubed',r'''Adding two cube volumes is not the same as making one cube whose side is the sum of the old side lengths. The larger cube contains extra rectangular pieces as well as the two original cubes.''',[
('Expand the cube of the sum',r'\[\begin{aligned}(a+b)^3&=(a+b)(a^2+2ab+b^2)\\&=a^3+3a^2b+3ab^2+b^3.\end{aligned}\] The six mixed pieces supply the extra terms.'),
('Use the smallest numerical check',r'At \(a=b=1\), two unit cubes have volume \(2\). A cube with side \(1+1=2\) has volume \(8\). The six extra unit cubes account for the difference.')],r'The sum-of-cubes factorisation applies to \(a^3+b^3\), not to \((a+b)^3\).',cube_draw,'Two separate unit cubes have total volume two. Beside them, a cube of side two is divided by three midplanes into eight unit cubes, showing the extra volume when the sum is cubed.')

PREAMBLE = r'''\documentclass[tikz,multi=tikzpicture,border=9pt]{standalone}
\usepackage{amsmath,amssymb}
\usetikzlibrary{arrows.meta,calc}
\ifdefined\RecurDark
\definecolor{ink}{RGB}{130,205,169}
\definecolor{textink}{RGB}{229,235,230}
\definecolor{axisink}{RGB}{138,156,145}
\definecolor{accentink}{RGB}{232,184,118}
\definecolor{figurefill}{RGB}{43,75,58}
\else
\definecolor{ink}{RGB}{36,99,74}
\definecolor{textink}{RGB}{34,42,37}
\definecolor{axisink}{RGB}{125,136,128}
\definecolor{accentink}{RGB}{162,91,29}
\definecolor{figurefill}{RGB}{211,233,220}
\fi
\tikzset{main/.style={ink,line width=1.1pt},axis/.style={axisink,line width=.55pt},accent/.style={accentink,line width=1pt},box/.style={draw=ink,rounded corners=5pt,fill=figurefill,inner sep=8pt},every node/.style={text=textink}}
\begin{document}
'''

def write_sources(root):
    folder=root/'Diagrams/card-lessons'
    (folder/'figures').mkdir(parents=True,exist_ok=True)
    main=PREAMBLE
    for id, lesson in LESSONS.items():
        file=id+'.tex'
        (folder/'figures'/file).write_text('\\begin{tikzpicture}[>=Stealth,font=\\normalsize]\n'+lesson['drawing']+'\n\\end{tikzpicture}\n')
        main+=r'\input{figures/'+file+'}\n'
    (folder/'main.tex').write_text(main+'\\end{document}\n')
    (folder/'dark.tex').write_text('\\def\\RecurDark{1}\n\\input{main.tex}\n')
    (folder/'manifest.json').write_text(json.dumps([dict(id=id,alt=l['alt']) for id,l in LESSONS.items()],indent=2)+'\n')

def attach_lessons(root, cards, assets, blocks, section):
    assert {c['id'] for c in cards} == set(LESSONS), 'Every card needs an authored lesson'
    for card in cards:
        id=card['id']; lesson=LESSONS[id]
        data=(root/f'output/pdf/cards/{id}.pdf').read_bytes()
        dark=(root/f'output/pdf/cards/{id}-dark.pdf').read_bytes()
        digest=hashlib.sha256(b'recur-pdf-pair-v1\0'+len(data).to_bytes(8,'big')+data+dark).hexdigest()
        assetID='sha256:'+digest
        assets.append(dict(id=assetID,mediaType='application/pdf',data=base64.b64encode(data).decode(),darkData=base64.b64encode(dark).decode(),altText=lesson['alt']))
        card['revision']=4
        if card['change'] != 'wording': card['change']='explanation'
        card['answerBlocks'].append(dict(id=id+'.visual',kind='diagram',assetID=assetID))
        card['explanationSections']=[
            section(id+'.reason','intuition',lesson['title'],lesson['idea']),
            section(id+'.work','derivation','Derivation',steps=lesson['steps']),
            section(id+'.check','pitfall','Common mistake',lesson['pitfall'])]

if __name__=='__main__':
    root=Path(__file__).resolve().parents[2]
    write_sources(root)
    print(f'Wrote {len(LESSONS)} card-specific TikZ constructions.')
