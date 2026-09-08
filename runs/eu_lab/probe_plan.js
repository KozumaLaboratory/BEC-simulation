// evapOptPlan が ctr にわたって本当に軸を切り替えるかを見る。
// 実データでは param が 78 ショットすべて 0 だった。コードの側かデータの側か。
var fs = require('fs');
var src = fs.readFileSync(process.argv[2], 'utf8');
function grab(re) { var m = src.match(re); if (!m) { throw new Error('missing ' + re); } return m[0]; }
var G = globalThis;
G.console = { log: function () {} };
G.global = { getPoints: function () { return []; }, addPoint: function () {} };
(0, eval)([
  grab(/var EVAP_OPT_BATCH = \d+;/m),
  grab(/var evapRepWarned = false;[^\n]*\n/m),
  grab(/var evapRep = function[\s\S]*?\n\};/m),
  grab(/var EVAP_OPT_NPAR = \d+;/m),
  grab(/var EVAP_OPT_AXES = \[[^\]]*\];/m),
  grab(/var evapGet = function[\s\S]*?\n\};/m),
  grab(/var evapGetAt = function[\s\S]*?\n\};/m),
  grab(/var EVAP_OPT_DELTA = [^;]+;/m),
  grab(/(?:var EV_[A-Z]+ *= *\d+;[^\n]*\n)+/m),
  grab(/var evapOptPlan = function[\s\S]*?\n\};/m),
].join('\n'));

console.log = function (s) { process.stdout.write(s + '\n'); };
console.log('EVAP_OPT_BATCH = ' + EVAP_OPT_BATCH
            + ', AXES = [' + EVAP_OPT_AXES.join(',') + ']'
            + ', rep = ' + evapRep() + ', per = ' + (3 * evapRep()));
var seen = {}, i, pl;
for (i = 0; i < 117; i++) {
  pl = evapOptPlan('sens', i);
  var k = pl[0] + '/' + pl[1];
  seen[k] = (seen[k] || 0) + 1;
}
console.log('(param/sign) の出現数:');
for (var k in seen) { console.log('  ' + k + ' -> ' + seen[k]); }
console.log('ctr 30..38 の param: '
            + [30, 31, 32, 33, 34, 35, 36, 37, 38]
              .map(function (c) { return c + ':' + evapOptPlan('sens', c)[0]; }).join(' '));
