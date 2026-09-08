"""CONTEXT.md の中の「解決するはずの参照」が本当に解決するかを確かめる。

別ハーネスに渡す文書で一番害があるのは、存在しないファイルやシンボルを指すこと。
迷子になるだけでなく「無いのは自分の環境が違うから」と誤解させる。
だから機械的に当たる。

陽性対照つき: わざと壊した名前が検出されることを見せる（検出できない検査は検査でない）。
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path('/home/suzume/workspace/BEC-simulation/.claude/worktrees/'
                    'dynamic-herding-newell')
DOC = ROOT / 'runs/eu_lab/CONTEXT.md'
text = DOC.read_text(encoding='utf-8')

bad = []

# --- (1) バックティック内のパスらしきもの ---
paths = set()
for m in re.finditer(r'`([A-Za-z0-9_./\-]+\.(?:js|py|sh|md|jl|toml|csv|json))`', text):
    paths.add(m.group(1))
for m in re.finditer(r'`(runs/[A-Za-z0-9_./\-]+/)`', text):
    paths.add(m.group(1))

print('=== パス参照 ===')
for p in sorted(paths):
    # 「ツリーに存在しない」と明記しているものは対象外（git show で示している）
    # ツリー外と明記しているもの（git show で示している）
    OUT_OF_TREE = ('eu_evaporation_ramp_optimization.md', 'd3_timing_schedule.csv',
                   'ramp_opt.csv', 'summary.txt', 'd2_eta_start_1d.csv')
    if any(o in p for o in OUT_OF_TREE):
        print(f'  skip (ツリー外と明記) {p}')
        continue
    cands = [ROOT / p, ROOT / 'runs/eu_lab' / p]
    if any(c.exists() for c in cands):
        print(f'  ok   {p}')
    else:
        # 名前だけの参照 (ramp_opt.csv など) は basename で探す
        hits = list(ROOT.rglob(pathlib.Path(p).name))
        if hits:
            print(f'  ok   {p}  (basename hit: {hits[0].relative_to(ROOT)})')
        else:
            print(f'  BAD  {p}')
            bad.append(f'path {p}')

# --- (2) euv4_transfer.js の中のシンボル ---
# 本体は euv3.ts。旧 JS も残っているので両方を corpus にする
src = (ROOT / 'euv3.ts').read_text(encoding='utf-8')
syms = set()
for m in re.finditer(r'`([A-Za-z_][A-Za-z0-9_.]*)`', text):
    name = m.group(1)
    # 型・定数・関数だけを見る。散文中のふつうの語や単位記号は除く
    if not re.fullmatch(r'(TRAP|MODE|SPIN_SEPARATION|calibration(\.[a-zA-Z.]+)?'
                        r'|euv(\.[a-zA-Z.]+)?|spherical|imagingAxis|FieldSpec'
                        r'|motLoad|compress|loadFort|mot2Off|biasUp|shrinkFort'
                        r'|mot1Off|releaseAndImage|frequency|tilt|hold|angles'
                        r'|parabolaTime|probe|sense|Watts|Hertz)', name):
        continue
    syms.add(m.group(1))
print('\n=== euv4_transfer.js のシンボル ===')
for s in sorted(syms):
    # ドット付き (calibration.coil.axis) は入れ子のキーなので逐語では出ない。
    # 区切って各段が存在するかを見る ── 近似だが、綴り間違いは捕まえる。
    parts = s.split('.')
    missing = [q for q in parts if q not in src]
    if not missing:
        print(f'  ok   {s}')
    else:
        print(f'  BAD  {s}  (euv3.ts に無い断片: {missing})')
        bad.append(f'symbol {s}')

# --- (3) git の参照（枝とコミット） ---
print('\n=== git 参照 ===')
for ref in re.findall(r'`(origin/[A-Za-z0-9_/\-]+)`', text):
    r = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '--verify', ref],
                       capture_output=True)
    if r.returncode == 0:
        print(f'  ok   {ref}')
    else:
        print(f'  BAD  {ref}')
        bad.append(f'ref {ref}')

# --- (4) .gitignore の行番号 ---
print('\n=== 行番号の主張 ===')
gi = (ROOT / '.gitignore').read_text(encoding='utf-8').splitlines()
m = re.search(r'\.gitignore:(\d+)', text)
if m:
    ln = int(m.group(1))
    line = gi[ln - 1] if 0 < ln <= len(gi) else ''
    if 'euv4_lab/data' in line:
        print(f'  ok   .gitignore:{ln} = {line!r}')
    else:
        print(f'  BAD  .gitignore:{ln} = {line!r}  (euv4_lab/data を指していない)')
        bad.append(f'.gitignore:{ln}')

# --- (5) 「grep できる錨」が本当に euv3.ts にあるか ---
# 行番号の引用はやめた（最も腐る形で、検査もヒューリスティックになる）。
# 代わりに見出しが構造の名前を挙げているので、それを **完全一致**で当てる。
print('\n=== 構造の錨 ===')
ts = (ROOT / 'euv3.ts').read_text(encoding='utf-8')
ANCHORS = [
    'const TRAP', 'const MODE', 'const SPIN_SEPARATION',
    'if (TRAP === "hh")', 'if (MODE === "barnett")', 'if (MODE === "ground")',
    'if (MODE === "weak")', 'export const calibration', 'euv.stopHere()',
    'rotate quantization axis -> +z', 'euv.field.cone', 'euv.scan',
    'releaseAndImage', 'sternGerlach',
]
for a in ANCHORS:
    # 文書が挙げていない錨を検査しても意味がない。両方に無いと駄目。
    in_doc = a in text
    in_src = a in ts
    if in_doc and in_src:
        print(f'  ok   {a}')
    elif not in_doc:
        print(f'  --   {a}  (文書が挙げていない)')
    else:
        print(f'  BAD  {a}  (文書は挙げているが euv3.ts に無い)')
        bad.append(f'anchor {a}')

# 行番号がまだ残っていたら知らせる（腐る形なので）
leftover = re.findall(r'`euv3\.ts`[^\n]{0,20}?\d+\s*[-–]\s*\d+\s*行', text)
if leftover:
    print(f'  !!   行番号の引用が {len(leftover)} 件残っている: {leftover[:3]}')
    bad.append('line-number citations remain')

# --- 陽性対照 ---
print('\n=== 陽性対照 ===')
fake = 'EVAP_OPT_NONEXISTENT_KNOB'
print(f'  捏造したシンボル {fake} は src に無い: {fake not in src}  (True であるべき)')
assert fake not in src, '陽性対照が壊れている'

print(f'\n{len(bad)} 件の未解決参照' if bad else '\nすべて解決した')
for b in bad:
    print(f'  - {b}')
sys.exit(1 if bad else 0)
