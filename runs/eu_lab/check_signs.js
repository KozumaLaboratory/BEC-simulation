// euv4 が "+-" / "-+" を含む方程式文字列を作らないことを確かめる。
//
// grep では見つからない: 欠陥は連結の結果に現れるので、実際に負の振幅で
// 呼んでみる必要がある。方程式を返す関数を全部、上げ／下げ両方向で叩く。
var fs = require('fs');
var src = fs.readFileSync(process.argv[2] || 'euv4_transfer.js', 'utf8');

// 方程式生成関数の定義だけを取り出して評価する（DAQ に触らない）
function grab(name) {
  var re = new RegExp('var ' + name + '\\s*=\\s*function[\\s\\S]*?\\n\\}', 'm');
  var m = src.match(re);
  if (!m) { throw new Error('not found: ' + name); }
  return m[0];
}
var pre = [
  src.match(/var V687_V0[\s\S]*?var V687_FACTOR = [^;]+;/m)[0],
  grab('rampEquation'),
  grab('sinRamp'), grab('cosRamp'), grab('logRamp'),
  grab('v687PowSLinRamp'),
].join('\n');
(0, eval)(pre);   // 間接 eval でグローバルに置く（strict の直接 eval は外へ出ない）

var bad = 0, n = 0;
function check(label, s) {
  n++;
  var hit = /\+\-|\-\+/.test(s);
  if (hit) { bad++; }
  console.log((hit ? 'BAD  ' : 'ok   ') + label + '  ->  ' + s);
}
// 下げ / 上げ / ゼロ振幅の 3 方向。ゼロは "+0.0000" になるべきで "+-" は不可。
var pairs = [[1.615, 0.905], [0.905, 1.615], [1.0, 1.0]];
for (var i = 0; i < pairs.length; i++) {
  var a = pairs[i][0], b = pairs[i][1];
  check('sinRamp(' + a + ',' + b + ')', sinRamp(a, b));
  check('cosRamp(' + a + ',' + b + ')', cosRamp(a, b));
  check('logRamp(' + a + ',' + b + ')', logRamp(a, b));
}
// v687PowSLinRamp は飽和パラメータ。実シーケンスの値と、その逆向き。
check('v687PowSLinRamp(0.735,0.150)', v687PowSLinRamp(1.47 / 2, 0.030 * 5));
check('v687PowSLinRamp(0.150,0.735)', v687PowSLinRamp(0.030 * 5, 1.47 / 2));

// 陽性対照: 壊れた実装なら BAD が出ることを見せる。控除できない検査は検査でない。
function brokenRamp(v0, v1) { return v0.toFixed(4) + '+' + (v1 - v0).toFixed(4) + '*cos(x)'; }
var probe = brokenRamp(1.615, 0.905);
console.log('\ncontrol: the pre-fix form still trips the check: ' + /\+\-/.test(probe)
            + '   (' + probe + ')');
console.log('checked ' + n + ', bad ' + bad);
process.exit(bad === 0 ? 0 : 1);
