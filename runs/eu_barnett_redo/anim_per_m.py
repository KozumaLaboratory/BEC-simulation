"""m 成分ごとの中面密度と位相。梯子の下端 m = -6 .. -2 を見る.

F=6、psi[x,y,c] で c=1 -> m=+6、c=13 -> m=-6 (CLAUDE.md の配置規約)。
基底状態は m=-6 に全部入っているので、そこから梯子を上がる過程が見たい範囲。

読み方の要点:
  * theta へ傾けると z 基底では二項分布に散る (スピンコヒーレント状態)。だから
    「散っていること自体」は脱磁ではない。脱磁は |<F>| が落ちること。
  * 各成分を **自分の最大値** で規格化する。人口が桁で違うので共通スケールでは
    ほとんどが真っ白になる。人口比はタイトルに数値で出す。
  * 位相は成分ごとに独立。全体位相因子は物理でないので、各成分の密度重み付き
    平均位相を引いてある。

軸順: 配列は [y,x]。**imshow(A) が正しく `.T` は鏡映で回転が逆になる。**
校正は四重極軸の回転率と台帳 L_z の符号 (FINDINGS.md §5 / issue #498 §5)。

渦の判定には使わないこと: 巻き数と密度コアの共局在が必要 (FINDINGS.md M17)。
"""
import h5py, numpy as np, matplotlib, sys
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.animation import FFMpegWriter

SRC = sys.argv[1] if len(sys.argv) > 1 else 'slices_plus_pk_s30_om092_prod_box35.jld2'
CROP = 12.0
F = 6
MS = [-6, -5, -4, -3, -2]          # 見る成分
FG, BG, GRID = '#1a1a1f', '#ffffff', '#c8c8d0'
# 値 0 が純白の colormap。magma_r は 0 が #fcfdbf (淡黄) なので背景が白にならない。
DENS = matplotlib.colors.LinearSegmentedColormap.from_list(
    'white_to_ink', ['#ffffff', '#ffe08a', '#f08c3c', '#c2296b', '#5c1a6b', '#14061f'])
PHAS = matplotlib.colormaps['twilight'].copy()
PHAS.set_bad(BG)


def frames_of(h):
    for i in range(1, int(h['n_slices'][()]) + 1):
        g = h[f'slice_{i:03d}']
        a = g['psi'][:]
        yield float(g['t'][()]), a['re'] + 1j * a['im']


h = h5py.File(SRC, 'r')
x = h['x'][:]
sel = np.abs(x) <= CROP
ext = [x[sel][0], x[sel][-1]] * 2
th, om = float(h['theta_deg'][()]), float(h['omega'][()])
frames = list(frames_of(h))
D = frames[0][1].shape[0]
COLS = [F - m for m in MS]         # m -> 配列の成分番号

fig, ax = plt.subplots(2, len(MS), figsize=(4.0 * len(MS), 8.6), dpi=100)
fig.patch.set_facecolor(BG)
ims_n, ims_p, ttl = [], [], []
for k, m in enumerate(MS):
    A, B = ax[0, k], ax[1, k]
    ims_n.append(A.imshow(np.zeros((sel.sum(), sel.sum())), origin='lower', extent=ext,
                          cmap=DENS, vmin=0, vmax=1.02))
    ims_p.append(B.imshow(np.zeros((sel.sum(), sel.sum())), origin='lower', extent=ext,
                          cmap=PHAS, vmin=-np.pi, vmax=np.pi))
    ttl.append(A.set_title('', color=FG, fontsize=13, pad=6))
    for P in (A, B):
        P.set_facecolor(BG)
        P.set_xticks([]); P.set_yticks([])
        for s in P.spines.values():
            s.set_color(GRID)
ax[0, 0].set_ylabel('density  (each to own max)', color=FG, fontsize=11)
ax[1, 0].set_ylabel('phase', color=FG, fontsize=11)

sup = fig.suptitle('', color=FG, fontsize=15)
note = fig.text(0.5, 0.015, '', ha='center', color='#66666f', fontsize=9)
fig.tight_layout(rect=[0, 0.045, 1, 0.925])


def draw(k):
    t, psi = frames[k]
    tot = float((np.abs(psi) ** 2).sum())
    fz = sum((F - c) * float((np.abs(psi[c]) ** 2).sum()) for c in range(D)) / tot
    for j, (m, c) in enumerate(zip(MS, COLS)):
        z = psi[c][np.ix_(sel, sel)]
        n = np.abs(z) ** 2
        pop = float((np.abs(psi[c]) ** 2).sum()) / tot
        ims_n[j].set_data(n / max(n.max(), 1e-300))
        ref = np.angle(complex((z * n).sum()))            # 密度重み付き平均位相
        ph = np.angle(z * np.exp(-1j * ref))
        ims_p[j].set_data(np.where(n > 1e-3 * max(n.max(), 1e-300), ph, np.nan))
        ttl[j].set_text(f'$m = {m:+d}$     {pop * 100:5.2f} %')
    sup.set_text(rf'per-$m$ mid-plane,  $\theta={th:.0f}^\circ$,  $\Omega$={om},  '
                 rf'$t$={t:.1f} $\omega_{{ref}}^{{-1}}$ ({t / 0.6283:.1f} ms),   '
                 rf'$\langle F_z\rangle$={fz:+.3f}')
    note.set_text('each density panel is scaled to its own maximum; the percentage is the '
                  'population.  A tilted spin is spread over $m$ by geometry — '
                  'demagnetisation is $|\\langle F\\rangle|$ falling, not the spread.')


if __name__ == '__main__':
    mode = sys.argv[2] if len(sys.argv) > 2 else 'still'
    if mode == 'still':
        for k in (0, len(frames) // 2, len(frames) - 1):
            draw(k)
            out = f'per_m_t{frames[k][0]:05.1f}.png'
            fig.savefig(out, facecolor=BG, bbox_inches='tight')
            print(f'  t={frames[k][0]:6.2f} -> {out}')
    else:
        fps = int(sys.argv[3]) if len(sys.argv) > 3 else 12
        out = sys.argv[4] if len(sys.argv) > 4 else f'per_m_{int(th)}deg_{fps}fps.mp4'
        w = FFMpegWriter(fps=fps, bitrate=9000,
                         metadata={'title': f'per-m density+phase, theta={th}'})
        with w.saving(fig, out, dpi=100):
            for k in range(len(frames)):
                draw(k)
                w.grab_frame()
        print(f'wrote {out}  ({len(frames)} frames, {fps} fps, {len(frames)/fps:.1f} s)')
