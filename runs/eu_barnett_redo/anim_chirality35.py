"""theta=35 の +Omega / -Omega を並べ、密度・磁化マップ・J_z F_z L_z |F| を同時に見る動画.

これが修論の主結果の図: 回転の向きで磁化の残り方が変わる。GS 修正後 (`conv`,
Fz(0) = -5.9987, m=-6 から断熱) の実測:

              注入 L_z(64ms)   dF_z    |F| 終値   -z からの角度
  +Omega        +14.68        +4.36     0.629      141 -> 105 deg  (離れる)
  -Omega         -9.32        +2.16     2.812      146 -> 175 deg  (寄る)

注入の大きさ自体が 1.58 倍違い、-Omega は偏極を 4.5 倍多く保つ。theta=90 では
R_x(pi) が厳密対称なので +-Omega は bit 一致する (FINDINGS.md M7)。非対称が出るのは
B_z != 0、すなわち theta != 90 のときだけ。

theta=90 では R_x(pi) が厳密対称なので +-Omega は bit 一致する (FINDINGS.md M7)。
非対称が出るのは theta != 90 のときだけ。

軸順: h5py は Julia の (nx,ny) を (ny,nx) で返すので配列は [y,x]。**imshow(A) が正しく
`.T` は鏡映 = 回転の向きが反転する。** 校正は四重極軸の回転率の符号を台帳 L_z と
比べる ([y,x] で +0.967、[x,y] で -0.967、真値は L_z>0)。anko が動画で発見。
FINDINGS.md §5 / issue #498 §5。

位相はここには入らない。柱密度マップ (n, f_z) しか持たないため。位相には中面の
全スピノルが要る -> 走行中の brslm/brslmir (SLICE_DT=2.0) と brdense (0.1)。
"""
import h5py, numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.animation import FFMpegWriter

import sys

# データセットは引数で選ぶ。`conv` が GS 修正後の本番、`ad35` は修正前の参考。
# Fz(0) で素性を assert するので、取り違えると図が生成されない。
DATASETS = {
    'conv': dict(tag='conv35_om{}', fz0=-5.9987, om=0.80,
                 note='adiabatic from $m=-6$  (post-GS-fix)'),
    'ad35': dict(tag='ad35_om{}', fz0=-4.8426, om=0.74,
                 note='PRE-GS-FIX: starts already tilted at 36$^\\circ$'),
}
WHICH = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in DATASETS else 'conv'
DS = DATASETS[WHICH]
ARMS = [('+$\\Omega$', f'colmaps_plus_{DS["tag"].format("p")}_prod_box35.jld2',
         f'ledger_plus_{DS["tag"].format("p")}_prod_box35.csv'),
        ('$-\\Omega$', f'colmaps_minus_{DS["tag"].format("m")}_prod_box35.jld2',
         f'ledger_minus_{DS["tag"].format("m")}_prod_box35.csv')]
CROP = 14.0
MS = 0.6283        # omega_ref^-1 -> ms  (omega_ref = 628.3 rad/s)
STRIDE = 2         # フレーム間引き。1804 枚は 30 fps で 60 s と遅すぎた
FG, BG, GRID = '#1a1a1f', '#ffffff', '#c8c8d0'
# 値 0 が純白の colormap。magma/inferno は 0 が黒なので白背景で雲と地が反転する。
DENS = matplotlib.colors.LinearSegmentedColormap.from_list(
    'white_to_ink', ['#ffffff', '#ffe08a', '#f08c3c', '#c2296b', '#5c1a6b', '#14061f'])
# 初期値からの差分で描く。生値だと F_z の -4.84 というオフセットが変換量を隠す。
# 差分にすると Delta F_z と -Delta L_z が重なり、Noether が目で見える。
TRACE = [(r'$\Delta L_z$', 'Lz', '#1f77d0'),
         (r'$\Delta F_z$  (magnetisation)', 'Fz', '#e03a3a'),
         (r'$\Delta J_z$', 'Jz', '#c9a227'),
         (r'$|\langle F\rangle|$', 'Fmag', '#6f5bd6')]


def trace(d, col):
    """初期値からの差分。F_z の -4.84 というオフセットが変換量を隠すので。"""
    return d[col] - d[col][0]

H = [h5py.File(a[1], 'r') for a in ARMS]
LD = [np.genfromtxt(a[2], delimiter=',', names=True) for a in ARMS]
for a, d in zip(ARMS, LD):
    assert abs(d['Fz'][0] - DS['fz0']) < 0.02, \
        f'{a[2]}: Fz(0)={d["Fz"][0]:.4f}, expected {DS["fz0"]:.4f} for dataset "{WHICH}"'
print(f'control OK: dataset "{WHICH}", both arms start at Fz(0) = {DS["fz0"]:+.4f}')
x = H[0]['x'][:]
t = H[0]['t'][:]
sel = np.abs(x) <= CROP
ext = [x[sel][0], x[sel][-1]] * 2
om = float(H[0]['omega'][()])
nmax = max(float(h['n_col'][0].max()) for h in H)
fzlim = max(float(np.abs(h['fz_col'][0]).max()) for h in H)

fig = plt.figure(figsize=(13.6, 10.6), dpi=100)
fig.patch.set_facecolor(BG)
# 3 段目の凡例を軸の外に置くので、地図と縦に離しておく。hspace を詰めると被る。
gs = fig.add_gridspec(3, 2, height_ratios=[1, 1, 1.05], hspace=0.30, wspace=0.06)

ims_n, ims_f, axs = [], [], []
for k, (lab, _, _) in enumerate(ARMS):
    A = fig.add_subplot(gs[0, k]); B = fig.add_subplot(gs[1, k])
    ims_n.append(A.imshow(H[k]['n_col'][0][np.ix_(sel, sel)] * 1e4, origin='lower',
                          extent=ext, cmap=DENS, vmin=0, vmax=nmax * 1e4))
    ims_f.append(B.imshow(H[k]['fz_col'][0][np.ix_(sel, sel)], origin='lower',
                          extent=ext, cmap='RdBu_r', vmin=-fzlim, vmax=fzlim))
    A.set_title(rf'{lab}   ($\Omega$ = {"+" if k == 0 else "-"}{om})',
                color=FG, fontsize=13, pad=7)
    for P, ttl in ((A, 'column density'), (B, r'$f_z$ column (magnetisation map)')):
        P.set_facecolor(BG); P.set_xticks([]); P.set_yticks([])
        for s in P.spines.values():
            s.set_color(GRID)
        if k == 0:
            P.set_ylabel(ttl, color=FG, fontsize=10)
    axs += [A, B]

C = fig.add_subplot(gs[2, :])
lines, cursors = {}, []
for k in (0, 1):
    for lab, col, c in TRACE:
        ls = '-' if k == 0 else '--'
        lw = 2.6 if col == 'Fz' else 2.0
        C.plot(LD[k]['t'] / MS, trace(LD[k], col), ls, color=c,
               lw=lw if k == 0 else lw * 0.8, alpha=1.0 if k == 0 else 0.6,
               label=lab if k == 0 else None)
# 主役の Delta F_z は線端に直接ラベルを打つ。凡例だけだと 8 本のどれか分からない。
for k, mk in ((0, r'$+\Omega$'), (1, r'$-\Omega$')):
    d = LD[k]
    C.annotate(mk, xy=(d['t'][-1] / MS, trace(d, 'Fz')[-1]),
               xytext=(6, 0), textcoords='offset points', color='#e03a3a',
               fontsize=12, weight='bold', va='center', clip_on=False)
cur = C.axvline(0, color='#1a1a1f', lw=1.6, alpha=0.9)
C.axhline(0, color='#9a9aa4', lw=0.8)
# T_QUENCH は継続時間であって時刻ではない。クエンチは T_TILT+T_SPINUP+T_STIR から
# 始まり、そこで B が切れる — 台帳の J_z が一定になる時刻がまさにそこ。50 を「B off」
# と書いていたのは duration を時刻と読んだ誤り。
for xs, lb in ((5, 'tilt'), (10, 'spin-up'), (40, 'stir ends / $B$ off')):
    C.axvline(xs / MS, color='#b0b0ba', lw=0.9, ls=':')
    C.text(xs / MS, 0.012, lb, transform=C.get_xaxis_transform(),
           color='#8a8a92', fontsize=8.5, ha='center', va='bottom', rotation=90)
C.set_xlabel(r'$t$  [ms]', color=FG, fontsize=12)
C.set_ylabel('change from $t=0$,  per atom  $[\\hbar]$', color=FG, fontsize=11)
C.set_xlim(t[0] / MS, t[-1] / MS)
# 凡例は軸の外。中に置くと 8 本の線と重なって読めない。
# 線種の意味 (+Omega / -Omega) も凡例に入れる。データの上に注記を置くと読めない。
from matplotlib.lines import Line2D
h, lb = C.get_legend_handles_labels()
h += [Line2D([], [], color='#55555f', lw=2.2, ls='-'),
      Line2D([], [], color='#55555f', lw=2.2, ls='--')]
lb += [r'$+\Omega$  (solid)', r'$-\Omega$  (dashed)']
C.legend(h, lb, frameon=False, labelcolor=FG, fontsize=11.5, ncol=6, loc='lower center',
         bbox_to_anchor=(0.5, 1.02), handlelength=2.4, columnspacing=1.7)
C.set_facecolor('#fafafc')
C.tick_params(colors='#55555f', labelsize=9)
C.grid(alpha=0.25, color='#b0b0ba')
for s in C.spines.values():
    s.set_color(GRID)

sup = fig.suptitle('', color=FG, fontsize=15)
note = fig.text(0.5, 0.012, '', ha='center', color='#55555f', fontsize=9)
fig.tight_layout(rect=[0, 0.03, 1, 0.945])


def draw(i):
    for k in (0, 1):
        ims_n[k].set_data(H[k]['n_col'][i][np.ix_(sel, sel)] * 1e4)
        ims_f[k].set_data(H[k]['fz_col'][i][np.ix_(sel, sel)])
    cur.set_xdata([t[i] / MS, t[i] / MS])
    sup.set_text(rf'$\theta = 35^\circ$,  $\Omega = \pm${DS["om"]},   $t$ = {t[i] / MS:6.1f} ms'
                 rf'    ({t[i]:5.1f} $\omega_{{ref}}^{{-1}}$)')
    j = [int(np.searchsorted(d['t'], t[i])) for d in LD]
    j = [min(a, len(d['t']) - 1) for a, d in zip(j, LD)]
    s = []
    for k in (0, 1):
        d, a = LD[k], j[k]
        s.append(f"{'+O' if k == 0 else '-O'}:  dFz={trace(d, 'Fz')[a]:+6.3f}  "
                 f"dLz={trace(d, 'Lz')[a]:+6.3f}  dJz={trace(d, 'Jz')[a]:+6.3f}  "
                 f"|F|={d['Fmag'][a]:5.3f}")
    # J_z が保存するのは B を切った時刻からであって t=0 からではない。だから
    # dFz = -dLz は成り立たない (t=0 起点の差分では). 見るべきは dJz が平坦になること。
    note.set_text('      '.join(s) +
                  '        ($\\Delta J_z$ goes flat once $B$ is off — that is Noether)')


if __name__ == '__main__':
    fps = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    out = sys.argv[3] if len(sys.argv) > 3 else f'chirality35_{WHICH}_{fps}fps.mp4'
    idx = list(range(0, len(t), STRIDE))
    w = FFMpegWriter(fps=fps, bitrate=8000,
                     metadata={'title': f'theta=35 chirality [{WHICH}], Omega=+-{om}'})
    with w.saving(fig, out, dpi=100):
        for n, i in enumerate(idx):
            draw(i)
            w.grab_frame()
            if n % 200 == 0:
                print(f'  {n}/{len(idx)}', flush=True)
    print(f'wrote {out}  ({len(idx)} frames of {len(t)} (stride {STRIDE}), '
          f'{fps} fps, {len(idx) / fps:.1f} s)')
