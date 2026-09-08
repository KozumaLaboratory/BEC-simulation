// rotEquation の 2 つの性質を φ0 全周・θ 数点で確かめる。
//   (1) 文字列が先頭単項マイナスにならない（全項負の場合を除く。そのときは警告が出る）
//   (2) 項を並べ替えても値が変わらない = x=0 と x=1 で barnettPoint と一致する
// 検算は文字列を LabVIEW ではなく JS で評価して行う（cos/sin/log は同じ意味）。
var fs = require('fs');
var src = fs.readFileSync(process.argv[2], 'utf8');

function grab(re) { var m = src.match(re); if (!m) { throw new Error('missing: ' + re); } return m[0]; }
var warned = 0;
global.console_real = console.log;
var pre = [
  'var COIL2_A_PER_V = 11;',
  grab(/var COIL2_CAL = \{[\s\S]*?\};/m),
  grab(/var vCoil2 = function[\s\S]*?\n\}/m),
  grab(/var vCoil2Xp = function[^\n]*\n/m),
  grab(/var vCoil2Yp = function[^\n]*\n/m),
  grab(/var vCoil2Z  = function[^\n]*\n/m),
  grab(/var bXpYp = function[\s\S]*?\n\}/m),
  grab(/var barnettPoint = function[\s\S]*?\n\}/m),
  grab(/var rotEquation = function[\s\S]*?\n\}/m),
  'var V_B2X0 = -0.0009; var V_B2Y0 = -0.0021; var V_B2Z0 = -0.0012;',
].join('\n');
(0, eval)(pre);
console.log = function (s) { warned++; console_real('  警告: ' + s); };

// 文字列を JS の式として評価する。x を与えて値を出す。
function evalEq(eq, x) {
  var js = eq.replace(/cos\(/g, 'Math.cos(').replace(/sin\(/g, 'Math.sin(')
             .replace(/\*x/g, '*(' + x + ')');
  return (0, eval)(js);
}

var leadNeg = 0, doubleSign = 0, worst = 0, n = 0, worstAt = null;
var thetas = [10, 35, 60, 89];
for (var ti = 0; ti < thetas.length; ti++) {
  for (var phi = 0; phi < 360; phi += 5) {
    global.BR_B_STIR = 3.0;
    global.BR_THETA = thetas[ti];
    var th = thetas[ti] / 180 * Math.PI;
    var bPerp = 3.0 * Math.sin(th);
    var k0 = bXpYp(phi / 180 * Math.PI), k90 = bXpYp(phi / 180 * Math.PI + Math.PI / 2);
    var omega = 2 * Math.PI * 10;
    var axes = [
      ['X', V_B2X0, vCoil2Xp(bPerp * k0[0]), vCoil2Xp(bPerp * k90[0]), 0],
      ['Y', V_B2Y0, vCoil2Yp(bPerp * k0[1]), vCoil2Yp(bPerp * k90[1]), 1]
    ];
    for (var a = 0; a < 2; a++) {
      var eq = rotEquation(axes[a][1], axes[a][2], axes[a][3], omega);
      n++;
      if (eq.charAt(0) === '-') { leadNeg++; }
      if (/\+\-|\-\+/.test(eq)) { doubleSign++; }
      // x=0 と x=1 はどちらも方位 phi の点。barnettPoint と一致すべき。
      var want = barnettPoint(thetas[ti], phi)[axes[a][4]];
      var e = Math.max(Math.abs(evalEq(eq, 0) - want), Math.abs(evalEq(eq, 1) - want));
      if (e > worst) { worst = e; worstAt = axes[a][0] + ' theta=' + thetas[ti] + ' phi=' + phi; }
    }
  }
}
console_real('検査 ' + n + ' 本');
console_real('二重符号 "+-" を含む文字列: ' + doubleSign + ' 本');
console_real('先頭が負の文字列: ' + leadNeg + ' 本（警告 ' + warned + ' 回）');
console_real('barnettPoint との最大差 (x=0,1): ' + worst.toExponential(3) + ' V  at ' + worstAt);
// 電圧の丸め (1e-4 V) が磁場方向に効く量。Xp は 2.4 G/A * 1/11 A/V なので
// 1e-4 V = 2.2e-5 G。3 G に対して 7e-6 rad = 4e-4 度。丸めの床はここ。
console_real('  参考: 1e-4 V の丸めは 3 G に対して ' + (1e-4/11*2.4/3.0*180/Math.PI).toExponential(2) + ' 度');

// 陽性対照: 並べ替えを外した素朴な実装なら先頭が負になる本数が出ることを見せる。
function naive(v0, aCos, aSin, omega) {
  return v0.toFixed(4) + (aCos < 0 ? '-' : '+') + Math.abs(aCos).toFixed(4)
       + '*cos(' + omega.toFixed(4) + '*x)';
}
var naiveNeg = 0;
for (var p2 = 0; p2 < 360; p2 += 5) {
  if (naive(V_B2X0, 1, 1, 1).charAt(0) === '-') { naiveNeg++; }
}
console_real('対照（素朴実装、オフセットを先頭に固定）: ' + naiveNeg + '/72 本が先頭負');
// 許容は丸めの床 3*1e-4 V（3 項ぶん）。それを超えたら丸めでは説明できない。
process.exit((leadNeg === 0 && doubleSign === 0 && warned === 0 && worst < 3.1e-4) ? 0 : 1);
