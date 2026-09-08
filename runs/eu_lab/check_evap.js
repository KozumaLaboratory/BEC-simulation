// 蒸発最適化の 3 つの性質を確かめる。
//   (1) "off"/param<0 は基準表を厳密に再現する（= OFF が無影響であることの根拠）
//   (2) 摂動後の表が単調（各ビームが下げ方向のみ）で上限・下限の内側
//   (3) ctr → (param, sign) の割り当てが全パラメータを等しく覆い、± が隣接する
// 陽性対照つき: 単調射影を外した実装は (2) で落ちることを示す。
var fs = require('fs');
var src = fs.readFileSync(process.argv[2], 'utf8');
function grab(re) { var m = src.match(re); if (!m) { throw new Error('missing ' + re); } return m[0]; }
var pre = [
  grab(/var FORT_CAL = \{[\s\S]*?\};/m),
  grab(/var EVAP_OPT_MODE[\s\S]*?var EVAP_OBJ = \"psd\";[^\n]*/m),
  grab(/var EVAP_OPT_NPAR = \d+;/m),
  grab(/var EVAP_OPT_AXES = \[[^\]]*\];/m),
  grab(/var evapRep = function[\s\S]*?\n\};/m),
  grab(/var evapOptPlan = function[\s\S]*?\n\};/m),
  grab(/var evapPerturb = function[\s\S]*?\n\};/m),
].join('\n');
(0, eval)(pre);

// stepALL 内の表を実体としてコピーする（1 か所に書かれている値をそのまま読む）
var tbl = grab(/var EVAP_START = \[[\s\S]*?\n\t\];/m);
(0, eval)(tbl.replace(/\bvar EVAP_START\b/, 'var START').replace(/\bvar EVAP\b/, 'var BASE'));

var fail = [];

// (1) param < 0 は基準表を再現する
var copy = evapPerturb(START, BASE, null, -1, 0, 0.15);
var same = true;
for (var i = 0; i < BASE.length; i++) {
  for (var j = 0; j < 3; j++) { if (copy[i][j] !== BASE[i][j]) { same = false; } }
}
console.log('(1) param<0 が基準表を再現: ' + (same ? 'ok' : 'BAD'));
if (!same) { fail.push('base'); }
// 元の表を書き換えていないことも見る（不変性）
var untouched = (BASE[3][0] === 0.56 && BASE[3][1] === 1.5);
console.log('    元の表が無変更: ' + (untouched ? 'ok' : 'BAD'));
if (!untouched) { fail.push('mutated'); }

// (2) 全パラメータ × 両符号で単調性と範囲
function checkTable(t, label) {
  var beams = [[0, 'H', FORT_CAL['H'][2], 0], [1, 'V', FORT_CAL['V'][2], 1]];
  var bad = [];
  for (var b = 0; b < 2; b++) {
    var bi = beams[b][0], cap = beams[b][2], from = beams[b][3];
    var prev = (from === 0) ? START[bi] : t[0][bi];
    for (var k = from; k < t.length; k++) {
      var v = t[k][bi];
      if (v > cap + 1e-12) { bad.push(label + ' ' + beams[b][1] + '[' + k + ']=' + v + ' > cap'); }
      if (v < EVAP_OPT_FLOOR - 1e-12) { bad.push(label + ' ' + beams[b][1] + '[' + k + '] < floor'); }
      if (v > prev + 1e-12) { bad.push(label + ' ' + beams[b][1] + ' 非単調 ' + prev + ' -> ' + v); }
      prev = v;
    }
  }
  return bad;
}
var allBad = [];
for (var p = 0; p < EVAP_OPT_NPAR; p++) {
  for (var s = -1; s <= 1; s += 2) {
    allBad = allBad.concat(checkTable(evapPerturb(START, BASE, null, p, s, 0.15), 'p' + p + (s > 0 ? '+' : '-')));
  }
}
console.log('(2) 単調性・範囲の違反: ' + allBad.length + ' 件');
for (var q = 0; q < Math.min(allBad.length, 6); q++) { console.log('    ' + allBad[q]); }
if (allBad.length) { fail.push('monotone'); }

// 陽性対照: 単調クランプを外した実装なら違反が出る
function perturbNoClamp(start, table, param, sign, delta) {
  var out = [], i;
  for (i = 0; i < table.length; i++) { out[i] = table[i].slice(0); }
  if (param < 0 || param === 16) { return out; }
  var beam = (param < 8) ? 0 : 1, k = (param < 8) ? param : param - 8;
  out[k][beam] = out[k][beam] * (1 + sign * delta);
  return out;
}
var ctrlBad = 0;
for (var p2 = 0; p2 < 16; p2++) {
  ctrlBad += checkTable(perturbNoClamp(START, BASE, p2, +1, 0.15), 'c').length;
}
console.log('    対照（クランプ無し, +δ のみ）: ' + ctrlBad + ' 件の違反');

// (3) ctr の割り当て（3 ショット周期 [基準点, +δ, −δ]）
var REP = evapRep(), per = 3 * REP, N = EVAP_OPT_AXES.length * per;
var count = {}, signSum = {}, nRef = 0, adjacentOk = true, prevSign = null;
for (var c = 0; c < N; c++) {
  var pl = evapOptPlan('sens', c);
  if (pl[0] < 0) { nRef++; prevSign = null; continue; }
  count[pl[0]] = (count[pl[0]] || 0) + 1;
  signSum[pl[0]] = (signSum[pl[0]] || 0) + pl[1];
  // ± は基準点をまたがず隣接して交替すべき
  if (prevSign !== null && prevSign === pl[1]) { adjacentOk = false; }
  prevSign = pl[1];
}
var even = true, balanced = true;
for (var a = 0; a < EVAP_OPT_AXES.length; a++) {
  var ax = EVAP_OPT_AXES[a];
  if (count[ax] !== 2 * REP) { even = false; }
  if (signSum[ax] !== 0) { balanced = false; }
}
console.log('(3) ' + N + ' ショットで各軸 ' + (2 * REP) + ' 回ずつ: ' + (even ? 'ok' : 'BAD'));
console.log('    基準点が 1/3 (' + nRef + '/' + N + '): ' + (nRef === N / 3 ? 'ok' : 'BAD'));
console.log('    ± が同数（ドリフトが差で消える条件）: ' + (balanced ? 'ok' : 'BAD'));
console.log('    ± が隣接して交替: ' + (adjacentOk ? 'ok' : 'BAD'));
if (!even || !balanced || !adjacentOk || nRef !== N / 3) { fail.push('plan'); }
console.log('\n"sens" 1 batch = ' + N + ' ショット（軸 '
            + EVAP_OPT_AXES.length + ' 本、1 ショット 10 s なら '
            + (N * 10 / 60).toFixed(0) + ' 分）');
console.log(fail.length ? 'FAIL: ' + fail.join(',') : 'すべて ok');
process.exit(fail.length ? 1 : 0);
