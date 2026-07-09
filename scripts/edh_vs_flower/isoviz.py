#!/usr/bin/env python3
"""isoviz — universal m-resolved density-isosurface + relative-phase renderer.

A GLOBAL replacement for the Goto-specific
scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py.
Works for ANY spinor-BEC run (EdH quench, Flower/adiabatic, any ramp) as long as
it is bridged to the `goto.h5` format (make_goto_tsubame.py) — call it as an API.

WHAT WAS WRONG WITH THE OLD ONE (fixed here):
  1. Per-component, per-frame NORMALIZED isosurface: iso = 0.30 * max(n_m(t)).
     -> a nearly-empty m component (e.g. m=-4 at 0.001% of the peak) was drawn
        as a FULL surface at 30% of its own tiny peak, looking populated.
        You could not tell whether m, or the m=-4 amount, or the probability
        was decreasing — the self-normalization erased all absolute magnitude.
  2. Goto-hardcoded titles / cryptic English ("Goto 10 mG | iso=(30%/30%/30%)").
  3. Axes labelled "μm" but the values are INTERNAL units (a_ho), not microns.

WHAT THIS DOES:
  * ABSOLUTE, SHARED isosurface level  iso = ISO_FRAC * (global peak density of
    the frame)  — the SAME physical density level for every m. Empty components
    therefore show nothing (truthful); m=-6 shows a big surface, m=-5/-4 show
    surfaces only where they truly exceed that level.
  * Each panel is annotated with the ACTUAL quantities: population fraction
    N_m/N_total and peak density relative to the global peak — so "how much of
    each m is there / is it decreasing" is directly readable.
  * Colour = relative phase arg(ψ_m) - arg(ψ_-6) (the meaningful inter-component
    winding; the m=-6 reference panel is 0). NO normalization of phase.
  * Correct axis units: internal harmonic-oscillator length ℓ₀ = a_ho, with the
    µm value stated in the caption (a_ho computed from ω_ref + atom mass).
  * Japanese labels when a CJK font is available, else clear English.

API:
  render_isosurfaces(h5path, frame='last', out='iso.png', m_list=(-6,-5,-4),
                     iso_frac=0.12, phase_mode='rel', lang='ja', title=None)
CLI/env: GOTO_H5, OUT, FRAME (int or 'last'), ISO_FRAC, M_LIST, V8_LANG, TITLE
"""
import io, os, sys
import numpy as np
import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

HBAR = 1.054571817e-34
AMU = 1.66053906660e-27
EU_MASS = 150.919857 * AMU

# ----------------------------------------------------------------- font / labels
def setup_font(lang):
    if lang != "ja":
        return "en"
    import matplotlib.font_manager as fm
    cands = ["Hiragino Sans", "Hiragino Maru Gothic Pro", "YuGothic", "Yu Gothic",
             "Noto Sans CJK JP", "Noto Sans JP", "IPAexGothic", "IPAGothic",
             "TakaoGothic", "VL Gothic", "Source Han Sans JP"]
    avail = {f.name for f in fm.fontManager.ttflist}
    for c in cands:
        if c in avail:
            plt.rcParams["font.family"] = c
            plt.rcParams["axes.unicode_minus"] = False
            return "ja"
    for p in ["/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
              "/System/Library/Fonts/Hiragino Sans GB.ttc",
              "/System/Library/Fonts/AquaKana.ttc",
              "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
              "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"]:
        if os.path.exists(p):
            try:
                fm.fontManager.addfont(p)
                plt.rcParams["font.family"] = fm.FontProperties(fname=p).get_name()
                plt.rcParams["axes.unicode_minus"] = False
                return "ja"
            except Exception:
                pass
    print("[isoviz] no CJK font found -> English labels", flush=True)
    return "en"

L = {
 "ja": {"pop": "占有率", "pkr": "ピーク比", "empty": "占有ほぼ0（面なし）",
        "ref": "位相基準 (=0)", "relcbar": "相対位相 arg(ψ_m) − arg(ψ_{-6})  [rad]",
        "iso": "等値面", "of_peak": "× 全体ピーク密度", "t": "時刻", "B": "磁場",
        "suptitle": "スピンテクスチャ 等値面（m 分解・絶対密度）",
        "note": "等値面は全 m で同一の絶対密度レベル。色=成分間の相対位相。空の m は描かれない。"},
 "en": {"pop": "population", "pkr": "peak/global", "empty": "≈empty (no surface)",
        "ref": "phase ref (=0)", "relcbar": "relative phase arg(ψ_m) − arg(ψ_{-6})  [rad]",
        "iso": "isosurface", "of_peak": "× global peak density", "t": "t", "B": "B",
        "suptitle": "spin-texture isosurfaces (m-resolved, ABSOLUTE density)",
        "note": "single absolute density level for all m; colour=inter-component phase; empty m not drawn."},
}

# --------------------------------------------------- marching tetrahedra (no deps)
TETS = [(0,1,3,7),(0,3,2,7),(0,2,6,7),(0,6,4,7),(0,4,5,7),(0,5,1,7)]
TET_EDGES = [(0,1),(0,2),(0,3),(1,2),(1,3),(2,3)]
_OFF = [(0,0,0),(1,0,0),(0,1,0),(1,1,0),(0,0,1),(1,0,1),(0,1,1),(1,1,1)]

def _interp_pt(p0,p1,v0,v1,iso):
    if abs(v1-v0) < 1e-30: return 0.5*(p0+p1), 0.5
    s=(iso-v0)/(v1-v0); return p0+s*(p1-p0), s

def _sort_poly(pts, phs):
    pts=np.asarray(pts,float); phs=np.asarray(phs,float); c=pts.mean(0); n=None
    for i in range(len(pts)-2):
        cr=np.cross(pts[i+1]-pts[0], pts[i+2]-pts[0])
        if np.linalg.norm(cr)>1e-12: n=cr/np.linalg.norm(cr); break
    if n is None: return pts, phs
    ref=pts[0]-c; ref=ref-np.dot(ref,n)*n
    if np.linalg.norm(ref)<1e-12:
        ref=np.array([1.,0.,0.]);
        if abs(np.dot(ref,n))>0.9: ref=np.array([0.,1.,0.])
        ref=ref-np.dot(ref,n)*n
    u=ref/np.linalg.norm(ref); v=np.cross(n,u)
    ang=np.arctan2((pts-c)@v,(pts-c)@u); o=np.argsort(ang)
    return pts[o], phs[o]

def marching_tetrahedra(density, phase, coords, iso):
    tris, tphase = [], []
    pu=np.exp(1j*phase); nx,ny,nz=density.shape
    for i in range(nx-1):
        for j in range(ny-1):
            for k in range(nz-1):
                cv=np.array([density[i+a,j+b,k+c] for a,b,c in _OFF])
                if np.all(cv<iso) or np.all(cv>=iso): continue
                cp=np.array([coords[i+a,j+b,k+c] for a,b,c in _OFF])
                cu=np.array([pu[i+a,j+b,k+c] for a,b,c in _OFF])
                for tet in TETS:
                    p=cp[list(tet)]; v=cv[list(tet)]; u=cu[list(tet)]
                    ins=v>=iso
                    if np.all(ins) or not np.any(ins): continue
                    pts,phs=[],[]
                    for a,b in TET_EDGES:
                        if (v[a]>=iso)==(v[b]>=iso): continue
                        pt,s=_interp_pt(p[a],p[b],v[a],v[b],iso)
                        uu=(1-s)*u[a]+s*u[b]
                        pts.append(pt); phs.append(np.angle(uu) if abs(uu)>1e-30 else np.angle(u[a]))
                    if len(pts)<3: continue
                    pts,phs=_sort_poly(pts,phs)
                    if len(pts)==3:
                        tris.append(pts); tphase.append(np.angle(np.mean(np.exp(1j*phs))))
                    else:
                        tris.append(np.array([pts[0],pts[1],pts[2]]))
                        tris.append(np.array([pts[0],pts[2],pts[3]]))
                        tphase.append(np.angle(np.mean(np.exp(1j*phs[:3]))))
                        tphase.append(np.angle(np.mean(np.exp(1j*np.array([phs[0],phs[2],phs[3]])))))
    return tris, np.asarray(tphase)

# --------------------------------------------------------------- data + rendering
def _load(h5path, m_list):
    with h5py.File(h5path, "r") as f:
        meta = {k: np.asarray(f["meta"][k]).item() for k in f["meta"]}
        t = np.asarray(f["t"]); B = np.asarray(f["B_gauss"]) if "B_gauss" in f else None
        T = lambda k: np.transpose(np.asarray(f[k]), (3,2,1,0))     # -> (nf,x,y,z)
        n_tot = T("n_total_3d")
        comp = {}
        for m in m_list:
            mm = abs(m)
            comp[m] = (T(f"n_m{mm}_3d"), T(f"arg_psi_m{mm}_3d"))
    return comp, n_tot, t, B, meta

def _coords(shape, Lbox, NX, vol_stride):
    dx = Lbox/NX*vol_stride
    xs = -Lbox/2 + dx*np.arange(shape[0]) + dx/2
    g0,g1,g2 = np.meshgrid(xs,xs,xs, indexing="ij")
    return np.stack([g0,g1,g2], -1)

def _draw_frame(fig, ctx, k):
    """Redraw `fig` in place for frame k using the ABSOLUTE iso level ctx['iso_abs']
    and peak-ratio reference ctx['gpk_norm']. Shared by the still and the movie."""
    fig.clf()
    m_list=ctx["m_list"]; T=ctx["T"]; comp=ctx["comp"]; n_tot=ctx["n_tot"]
    cmap=ctx["cmap"]; norm=ctx["norm"]; Lbox=ctx["Lbox"]; coords=ctx["coords"]
    iso_abs=ctx["iso_abs"]; gpk_norm=ctx["gpk_norm"]; dV=ctx["dV"]
    gs=GridSpec(1, len(m_list)+1, figure=fig, width_ratios=[1.0]*len(m_list)+[0.05],
                left=0.03, right=0.94, bottom=0.10, top=0.82, wspace=0.08)
    Ntot=float(n_tot[k].sum()*dV)
    ref_phase=comp[-6][1][k] if -6 in comp else comp[m_list[0]][1][k]
    for i,m in enumerate(m_list):
        ax=fig.add_subplot(gs[0,i], projection="3d")
        dens=comp[m][0][k]; ph=comp[m][1][k]
        if ctx["phase_mode"]=="rel":
            ph=np.angle(np.exp(1j*(ph-ref_phase)))
        frac=100*float(dens.sum()*dV)/Ntot if Ntot>0 else 0.0
        pkr=float(dens.max())/gpk_norm if gpk_norm>0 else 0.0
        if dens.max()>=iso_abs:
            tris,tph=marching_tetrahedra(dens, ph, coords, iso_abs)
            if tris:
                ax.add_collection3d(Poly3DCollection(
                    tris, facecolors=cmap(norm(tph)), edgecolors="none", alpha=0.95))
        else:
            ax.text2D(0.5,0.5,T["empty"], transform=ax.transAxes,
                      ha="center", va="center", fontsize=12, color="0.4")
        for setter in (ax.set_xlim, ax.set_ylim, ax.set_zlim):
            setter(-Lbox/2, Lbox/2)
        ax.set_box_aspect((1,1,1)); ax.view_init(elev=ctx["elev"], azim=ctx["azim"])
        ax.set_xlabel("x [ℓ₀]", labelpad=2); ax.set_ylabel("y [ℓ₀]", labelpad=2)
        ax.set_zlabel("z [ℓ₀]", labelpad=2); ax.tick_params(labelsize=8, pad=0)
        tag=T["ref"] if (m==-6 and ctx["phase_mode"]=="rel") else ""
        ax.set_title(f"m = {m}    {tag}\n{T['pop']} {frac:4.1f}%    {T['pkr']} {pkr:.3f}",
                     fontsize=12, pad=4)
    cax=fig.add_subplot(gs[0,-1])
    sm=plt.cm.ScalarMappable(norm=norm, cmap=cmap); sm.set_array([])
    cb=fig.colorbar(sm, cax=cax); cb.set_label(T["relcbar"], fontsize=10)
    cb.set_ticks([-np.pi,0,np.pi]); cb.set_ticklabels(["−π","0","π"])
    t_ms=float(ctx["t"][k])/ctx["om"]*1000.0
    B_uG=float(ctx["B"][k])*1e6 if ctx["B"] is not None else float("nan")
    fig.suptitle(
        f"{ctx['ttl']}\n{T['t']} = {t_ms:5.0f} ms   {T['B']} = {B_uG:6.1f} µG   "
        f"{T['iso']}: |ψ_m|² = {ctx['iso_frac']:.0%} {T['of_peak']}   "
        f"(ℓ₀ = a_ho ≈ {ctx['a_ho']:.2f} µm,  box {Lbox:.0f} ℓ₀ ≈ {Lbox*ctx['a_ho']:.1f} µm)",
        fontsize=13, y=0.97)
    fig.text(0.03, 0.02, T["note"], fontsize=9, color="0.35")

def _build_ctx(h5path, m_list, iso_frac, phase_mode, lang, title, elev, azim):
    lang=setup_font(lang); T=L[lang]
    comp, n_tot, t, B, meta = _load(h5path, m_list)
    Lbox=float(meta["L_box"]); NX=int(meta["NX"]); vs=int(meta.get("vol_stride",1))
    om=float(meta.get("omega_ref",691.15))
    a_ho=np.sqrt(HBAR/(EU_MASS*om))*1e6
    dx=Lbox/NX*vs
    return dict(comp=comp, n_tot=n_tot, t=t, B=B, m_list=list(m_list), T=T,
                Lbox=Lbox, om=om, a_ho=a_ho, dV=dx**3,
                coords=_coords(comp[m_list[0]][0].shape[1:], Lbox, NX, vs),
                cmap=plt.cm.hsv, norm=plt.Normalize(-np.pi,np.pi),
                phase_mode=phase_mode, iso_frac=iso_frac, elev=elev, azim=azim,
                ttl=title if title else T["suptitle"])

def render_isosurfaces(h5path, frame="last", out="iso.png", m_list=(-6,-5,-4),
                       iso_frac=0.12, phase_mode="rel", lang="ja", title=None,
                       elev=22, azim=232, dpi=140):
    ctx=_build_ctx(h5path, m_list, iso_frac, phase_mode, lang, title, elev, azim)
    nf=ctx["n_tot"].shape[0]
    k=nf-1 if frame in ("last","-1",-1) else int(frame)
    gpk=float(ctx["n_tot"][k].max())            # still: this-frame global peak
    ctx["iso_abs"]=iso_frac*gpk; ctx["gpk_norm"]=gpk
    pw=min(6.0, 34.0/len(m_list))               # per-panel width (shrinks for many m)
    fig=plt.figure(figsize=(pw*len(m_list)+1.2, 6.6), facecolor="white")
    _draw_frame(fig, ctx, k)
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
    fig.savefig(out, dpi=dpi); plt.close(fig)
    print(f"[isoviz] still {out} frame={k}/{nf-1} iso={ctx['iso_abs']:.3e}", flush=True)
    return out

def render_movie(h5path, out="iso.mp4", m_list=(-6,-5,-4), iso_frac=0.12,
                 phase_mode="rel", lang="ja", title=None, elev=22, azim=232,
                 fps=30, duration_s=16.0, frame_stride=1):
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "flower_protocol_edh"))
    from _anim_writer import save_via_png_dup
    ctx=_build_ctx(h5path, m_list, iso_frac, phase_mode, lang, title, elev, azim)
    nf=ctx["n_tot"].shape[0]
    frames=list(range(0, nf, frame_stride))
    # TIME-FIXED absolute level: iso_frac * max over ALL frames of the global peak
    gpk_fixed=float(max(ctx["n_tot"][k].max() for k in range(nf)))
    ctx["iso_abs"]=iso_frac*gpk_fixed; ctx["gpk_norm"]=gpk_fixed
    print(f"[isoviz] movie {out}: {len(frames)} frames, FIXED iso={ctx['iso_abs']:.3e} "
          f"(= {iso_frac:.0%} x max global peak {gpk_fixed:.3e})", flush=True)
    fig=plt.figure(figsize=(6.0*len(m_list)+1.2, 6.6), facecolor="white")
    def draw_fn(j):
        _draw_frame(fig, ctx, frames[j])
        if (j+1) % 10 == 0 or j == len(frames)-1:
            print(f"  frame {j+1}/{len(frames)} (k={frames[j]})", flush=True)
    save_via_png_dup(fig, draw_fn, len(frames), out, fps=fps, duration_s=duration_s, dpi=120)
    plt.close(fig)
    print(f"[isoviz] wrote {out}", flush=True)
    return out

if __name__ == "__main__":
    out=os.environ.get("OUT", "iso.png")
    common=dict(
        m_list=tuple(int(x) for x in os.environ.get("M_LIST","-6,-5,-4").split(",")),
        iso_frac=float(os.environ.get("ISO_FRAC","0.12")),
        lang=os.environ.get("V8_LANG","ja"),
        title=os.environ.get("TITLE") or None,
    )
    if out.lower().endswith((".mp4",".gif")):
        render_movie(os.environ.get("GOTO_H5","goto.h5"), out=out,
                     fps=int(os.environ.get("FPE_FPS","30")),
                     duration_s=float(os.environ.get("FPE_DURATION_S","16")),
                     frame_stride=int(os.environ.get("FRAME_STRIDE","1")), **common)
    else:
        frame=os.environ.get("FRAME","last")
        render_isosurfaces(os.environ.get("GOTO_H5","goto.h5"), out=out,
                           frame=frame if frame=="last" else int(frame), **common)
