const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const katex = require(path.join(root, 'App/Resources/Math/katex.min.js'));
const deck = JSON.parse(fs.readFileSync(path.join(root, 'App/Resources/starter.json')));
let count = 0;
function check(value) {
  if (Array.isArray(value)) { value.forEach(check); return; }
  if (value && typeof value === 'object') {
    if (value.kind === 'equation') {
      katex.renderToString(value.text, {throwOnError: true, strict: 'error'});
      count++;
    }
    for (const [key, child] of Object.entries(value)) {
      if (!['data', 'darkData', 'latexSource'].includes(key)) check(child);
    }
    return;
  }
  if (typeof value !== 'string') return;
  for (const match of value.matchAll(/\\\(([\s\S]*?)\\\)|\\\[([\s\S]*?)\\\]/g)) {
    katex.renderToString(match[1] ?? match[2], {throwOnError: true, strict: 'error'});
    count++;
  }
}
check(deck);
console.log(`${count} formula blocks rendered without errors.`);
