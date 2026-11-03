"""Explicit notation edits for authored prose; existing LaTeX stays untouched."""
import re

# Keep whole expressions together, so prose does not mix plain superscripts and TeX.
NOTATION = {
    '(cos a, sin a)': r'(\cos a,\sin a)',
    '(cos b, sin b)': r'(\cos b,\sin b)',
    '(−sin b, cos b)': r'(-\sin b,\cos b)',
    '−sin a sin b': r'-\sin a\sin b',
    'sin h < h < tan h': r'\sin h<h<\tan h',
    'cos h < sin h/h < 1': r'\cos h<\frac{\sin h}{h}<1',
    '0<h<π/2': r'0<h<\frac{\pi}{2}',
    'cos h−1=−2sin²(h/2)': r'\cos h-1=-2\sin^2(h/2)',
    '(cos h−1)/h': r'\frac{\cos h-1}{h}',
    'sin h/h': r'\frac{\sin h}{h}',
    'sin²x+cos²x=1': r'\sin^2x+\cos^2x=1',
    '2cos²x−1': r'2\cos^2x-1', '1−2sin²x': r'1-2\sin^2x',
    'sin a + sin b': r'\sin a+\sin b', 'sin(a+b)': r'\sin(a+b)',
    'sin(x+h)': r'\sin(x+h)', 'cos x': r'\cos x', '−sin x': r'-\sin x',
    'sin x': r'\sin x', 'cos a': r'\cos a', 'sin a': r'\sin a',
    '−sin b': r'-\sin b', 'sin b': r'\sin b', 'cos h': r'\cos h',
    'a=b=45°': r'a=b=45^\circ', '90°': r'90^\circ',
    'd(xⁿ)/dx = nxⁿ⁻¹': r'\frac{d}{dx}x^n=nx^{n-1}',
    'f(x)=sin x+ln x': r'f(x)=\sin x+\ln x',
    '(n−1)!': r'(n-1)!', 'x>0': r'x>0', 'n≥1': r'n\ge1', 'n=1': r'n=1',
    'π/180': r'\frac{\pi}{180}', 'ln x': r'\ln x', '1/x': r'\frac1x',
    'X∖Y': r'X\setminus Y', 'Y∖X': r'Y\setminus X', 'X∩Y': r'X\cap Y', 'X∪Y': r'X\cup Y',
    '(h,k)': r'(h,k)', '(x−h)²=4p(y−k)': r'(x-h)^2=4p(y-k)',
    'x²/4+y²/1=1': r'\frac{x^2}{4}+\frac{y^2}{1}=1',
    'x²−9=(x−3)(x+3)': r'x^2-9=(x-3)(x+3)',
    'x²−9': r'x^2-9', 'x³−27': r'x^3-27', 'x²': r'x^2', 'y²': r'y^2',
    'x/a': r'\frac{x}{a}', 'y/b': r'\frac{y}{b}', 'r²': r'r^2',
    'y=0': r'y=0', 'x=0': r'x=0', 'x=±2': r'x=\pm2', 'y=±1': r'y=\pm1',
    'x=±a': r'x=\pm a', 'x=−3': r'x=-3', 'x=3': r'x=3',
    'x−h': r'x-h', 'y−k': r'y-k', 'x−3': r'x-3', 'x+3': r'x+3',
    '√4=2': r'\sqrt4=2', '√1=1': r'\sqrt1=1', '√4': r'\sqrt4', '√1': r'\sqrt1',
    'centre (3, −2)': r'\text{centre }(3,-2)',
    'Centre (3, −2)': r'\text{Centre }(3,-2)',
    'a=b=r': r'a=b=r', 'a=b=1': r'a=b=1', 'a=b': r'a=b',
    'a=x': r'a=x', 'b=3': r'b=3', 'a=2x': r'a=2x', 'b=5': r'b=5',
    '27=3³': r'27=3^3', '3³': r'3^3', '8x³': r'8x^3',
    'p≠0': r'p\ne0', '(0,p)': r'(0,p)', 'y=−p': r'y=-p',
    'x²=4py': r'x^2=4py',
    'πr²': r'\pi r^2', 'πr': r'\pi r', 'πab': r'\pi ab', 'cm²': r'\mathrm{cm}^2',
    'a∣b': r'a\mid b', '3∣18': r'3\mid18', '18∣3': r'18\mid3',
    '18=3×6': r'18=3\times6', '3=18k': r'3=18k', '19=3×6+1': r'19=3\times6+1',
    '3/18=1/6': r'\frac3{18}=\frac16', '3/18': r'\frac3{18}', '19/3': r'\frac{19}3',
    'a³−b³': r'a^3-b^3', 'a³+b³': r'a^3+b^3', '(a+b)³': r'(a+b)^3', '(a−b)³': r'(a-b)^3',
    '(a±b)³': r'(a\pm b)^3', '(a−b)(a²+ab+b²)': r'(a-b)(a^2+ab+b^2)',
    'a²b': r'a^2b', 'ab²': r'ab^2', 'a²': r'a^2', 'b²': r'b^2',
    '(−b)³=−b³': r'(-b)^3=-b^3', '(−b)²=b²': r'(-b)^2=b^2',
    '(n−1)!': r'(n-1)!',
    'a=b=x': r'a=b=x', 'a+b': r'a+b', 'π': r'\pi', '∣': r'\mid', '∨': r'\lor', '3∣19': r'3\mid19', '−b': r'-b',
    '+b²': r'+b^2', '−b²': r'-b^2', '+ab': r'+ab', '−ab': r'-ab',
    'a³': r'a^3', 'b³': r'b^3', 'p²': r'p^2',
    '(x−3)': r'(x-3)', '(x+3)': r'(x+3)',
    '−24': r'-24', '−6': r'-6', '−2': r'-2', '−1': r'-1',
}
# Token replacements use boundaries so a formula such as "πr" does not eat prose.
_PATTERN = re.compile('|'.join(re.escape(x) for x in sorted(NOTATION, key=len, reverse=True)))
_PROTECTED = re.compile(r'(\\\([\s\S]*?\\\)|\\\[[\s\S]*?\\\])')

_TOKENS = re.compile(r"(?<![A-Za-z0-9’'\\])(?:ab|2r|x|y|X|Y|P|Q|h|k|n|p|r|b)(?![A-Za-z0-9’'])")

def _convert(text):
    fragments = _PATTERN.sub(lambda m: r'\(' + NOTATION[m.group()] + r'\)', text)
    return ''.join(part if i % 2 else _TOKENS.sub(lambda m: r'\(' + m.group() + r'\)', part)
                   for i, part in enumerate(_PROTECTED.split(fragments)))

def latex_prose(text):
    return ''.join(part if i % 2 else _convert(part)
                   for i, part in enumerate(_PROTECTED.split(text)))
