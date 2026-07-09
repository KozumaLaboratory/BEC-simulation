#!/usr/bin/env python3
"""par_T90 (最も綺麗なEdH) の再構成 vs 真値 の誤差評価.

観測モデル: 視線=y (∫dy), SG分離=z.  傾斜SG ±16° プロトコル (5設定: id, R_y±16, R_x±16),
可視ブロック m=-6,-5,-4,-3 のみ centroid で列平均スピン <F>(x,z) を復元.
  s^(k)(x,z)=Σ_V m [∫dy n_m^(k)] / Σ_V [∫dy n_m^(k)]
  <Fz>=s^(0),  <Fx>=-(s^{y+}-s^{y-})/(2 sin16),  <Fy>=+(s^{x+}-s^{x-})/(2 sin16)
真値: 完全スピノルから直接 sd(Op)=Re<ψ|Op|ψ> を ∫dy 列平均.
参照上限: 全13ch・厳密90°法 (列平均としては機械精度).
時刻ごとに corr / rel-L2 / RMS / 方向誤差 を出し, 代表時刻の texture と誤差マップ, 時系列サマリを描画.
env: PSI13, GOTO, OUT, OUT_TS
"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, VISIBLE_IDX, FX, FY, FZ, load_frames_bulk, open_psi13
from isoviz import setup_font
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
setup_font("ja")

PSI13=os.environ.get("PSI13","par_T90_psi13.jld2"); GOTO=os.environ.get("GOTO","par_T90_goto.h5")
LABEL=os.environ.get("LABEL","par_T90 (最も綺麗なEdH)")
OUT=os.environ.get("OUT","recon_vs_truth_par.png"); OUT_TS=os.environ.get("OUT_TS","recon_vs_truth_par_timeseries.png")
TH=16.0; s16=np.sin(np.radians(TH)); ms_v=ms[VISIBLE_IDX].astype(float)

with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); Bg=np.asarray(G["B_gauss"])
    meta={k:np.asarray(G["meta"][k]).item() for k in G["meta"]}
tms=t/om*1000.0; L=float(meta["L_box"]); nf=len(tms)

def col_cen_vis(psi,R):            # visible-block centroid on ∫dy image -> (x,z)
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2
    ov=o[...,VISIBLE_IDX].sum(axis=1)                       # ∫dy -> (x,z,|V|)
    return np.einsum("xzm,m->xz",ov,ms_v)/np.clip(ov.sum(-1),1e-30,None)
def col_cen_all(psi,R):            # all-13 centroid -> exact column <R^dag Fz R>
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2
    return np.einsum("xzm,m->xz",o.sum(axis=1),ms.astype(float))/np.clip(o.sum(axis=1).sum(-1),1e-30,None)
def recon_vis(psi):
    fz=col_cen_vis(psi,rot("id",0)); fx=-(col_cen_vis(psi,rot("y",TH))-col_cen_vis(psi,rot("y",-TH)))/(2*s16)
    fy=+(col_cen_vis(psi,rot("x",TH))-col_cen_vis(psi,rot("x",-TH)))/(2*s16); return fx,fy,fz
def recon_exact(psi):              # all-13, 90 deg (column-exact)
    fz=col_cen_all(psi,rot("id",0)); fx=-col_cen_all(psi,rot("y",90.0)); fy=+col_cen_all(psi,rot("x",90.0)); return fx,fy,fz
def truth_col(psi):
    sd=lambda Op: np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
    ncol=np.sum(np.abs(psi)**2,axis=-1).sum(axis=1)
    return (sd(FX).sum(1)/np.clip(ncol,1e-30,None), sd(FY).sum(1)/np.clip(ncol,1e-30,None),
            sd(FZ).sum(1)/np.clip(ncol,1e-30,None), ncol)

def metrics(R,T,w):                                    # 密度重み(全グリッド・選択なし)
    w=w/max(w.sum(),1e-30); ma=(w*R).sum(); mb=(w*T).sum()
    cov=(w*(R-ma)*(T-mb)).sum(); va=(w*(R-ma)**2).sum(); vb=(w*(T-mb)**2).sum()
    corr=cov/np.sqrt(va*vb) if va>1e-12 and vb>1e-12 else 1.0
    rel=np.sqrt((w*(R-T)**2).sum()/max((w*T**2).sum(),1e-30)); return corr,rel,rel
clip6=lambda A: np.clip(A,-6,6)

# ---- full time series (visible-block method) ----
P=open_psi13(PSI13)
ts_corr=np.zeros((nf,3)); ts_rel=np.zeros((nf,3)); ts_dir=np.zeros(nf); ts_amp=np.zeros(nf)
CH=32                                                  # chunk to bound memory
for a in range(0,nf,CH):
    fr=list(range(a,min(a+CH,nf))); psis=load_frames_bulk(P,fr)
    for j,k in enumerate(fr):
        psi=psis[j]; fxR,fyR,fzR=map(clip6,recon_vis(psi)); fxT,fyT,fzT,ncol=truth_col(psi)
        for c,(Rc,Tc) in enumerate([(fxR,fxT),(fyR,fyT),(fzR,fzT)]):
            ts_corr[k,c],ts_rel[k,c],_=metrics(Rc,Tc,ncol)
        # direction error of column vector (deg), density-weighted over FULL grid
        vR=np.stack([fxR,fyR,fzR],-1); vT=np.stack([fxT,fyT,fzT],-1)
        nR=np.linalg.norm(vR,axis=-1); nT=np.linalg.norm(vT,axis=-1)
        cos=np.clip(np.sum(vR*vT,-1)/np.clip(nR*nT,1e-30,None),-1,1)
        w=ncol; ts_dir[k]=np.degrees(np.sum(np.arccos(cos)*w)/max(w.sum(),1e-30))
        ts_amp[k]=np.sum(nT*ncol)/max(ncol.sum(),1e-30)
    print(f"[ts] {min(a+CH,nf)}/{nf} frames")

# ---- representative-time texture panels ----
REP_MS=[float(x) for x in os.environ.get("REP_MS","131,146,161,188").split(",")]
REP=[int(np.argmin(np.abs(tms-x))) for x in REP_MS]
psis=load_frames_bulk(P,REP)
fig,ax=plt.subplots(len(REP),4,figsize=(15,3.4*len(REP)),constrained_layout=True)
ax1d=np.linspace(-L/2,L/2,psis[0].shape[0]); xx,zz=np.meshgrid(ax1d,ax1d,indexing="ij")
Ng=psis[0].shape[0]; ext=[-L/2,L/2,-L/2,L/2]
def tex(a,fx,fy,fz,dens,title):                        # 全グリッド・密度α・間引きなし
    al=np.clip(dens/max(dens.max(),1e-30),0,1)**0.5
    im=a.imshow(fz.T,origin="lower",extent=ext,cmap="PuOr_r",vmin=-3,vmax=3,aspect="equal",alpha=al.T)
    rgba=np.zeros((Ng,Ng,4)); rgba[...,3]=al
    a.quiver(xx,zz,fx,fz,color=rgba.reshape(-1,4),scale=42,width=0.004,pivot="mid")
    a.set_title(title,fontsize=9); a.set_xlabel("x [ℓ₀]",fontsize=7); a.set_ylabel("z [ℓ₀]",fontsize=7); a.tick_params(labelsize=6); return im
for r,k in enumerate(REP):
    psi=psis[r]; fxR,fyR,fzR=map(clip6,recon_vis(psi)); fxE,fyE,fzE=map(clip6,recon_exact(psi)); fxT,fyT,fzT,ncol=truth_col(psi)
    cs=[metrics(a,b,ncol) for a,b in [(fxR,fxT),(fyR,fyT),(fzR,fzT)]]
    tex(ax[r,0],fxT,fyT,fzT,ncol,f"真値 列平均<F>(x,z)\nt={tms[k]:.0f}ms  B={Bg[k]*1e3:.1f}µG")
    tex(ax[r,1],fxE,fyE,fzE,ncol,"参照: 全13ch 厳密90°")
    im=tex(ax[r,2],fxR,fyR,fzR,ncol,f"再構成 [±16°可視ブロック]\ncorr(Fx,Fy,Fz)=({cs[0][0]:.2f},{cs[1][0]:.2f},{cs[2][0]:.2f})")
    al=np.clip(ncol/max(ncol.max(),1e-30),0,1)**0.5
    em=np.sqrt((fxR-fxT)**2+(fyR-fyT)**2+(fzR-fzT)**2)
    ie=ax[r,3].imshow(em.T,origin="lower",extent=ext,cmap="magma",aspect="equal",vmin=0,alpha=al.T)
    ax[r,3].set_title(f"|誤差ベクトル|(α=密度)  相対誤差=({cs[0][1]:.2f},{cs[1][1]:.2f},{cs[2][1]:.2f})",fontsize=9)
    ax[r,3].set_xticks([]); ax[r,3].set_yticks([]); fig.colorbar(ie,ax=ax[r,3],shrink=0.7)
    if r==0: fig.colorbar(im,ax=ax[r,1],shrink=0.7,label="<Fy>(面外)")
fig.suptitle(f"{LABEL} — 傾斜SG±16°再構成 vs 真値  列平均<F>(x,z) [矢印=(<Fx>,<Fz>) 色=<Fy>]  視線=y(∫dy)",fontsize=12)
fig.savefig(OUT,dpi=125,bbox_inches="tight"); plt.close(fig); print("wrote",OUT)

# ---- time-series metrics ----
fig,ax=plt.subplots(1,3,figsize=(15,4.2),constrained_layout=True)
cols=["#d1495b","#2ca6a4","#3a6ea5"]; labs=["<Fx>","<Fy>","<Fz>"]
for c in range(3): ax[0].plot(tms,ts_corr[:,c],color=cols[c],label=labs[c])
ax[0].set_ylabel("相関係数"); ax[0].set_ylim(-0.05,1.03); ax[0].legend(fontsize=9); ax[0].set_title("再構成 vs 真値 相関 (列平均)")
for c in range(3): ax[1].plot(tms,ts_rel[:,c],color=cols[c],label=labs[c])
ax[1].set_ylabel("相対L2誤差"); ax[1].set_ylim(0,1.2); ax[1].legend(fontsize=9); ax[1].set_title("相対L2誤差")
ax[2].plot(tms,ts_dir,color="k",label="方向誤差(密度重み)"); ax[2].set_ylabel("平均方向誤差 [deg]")
ax[2].legend(loc="upper left",fontsize=9); ax2=ax[2].twinx(); ax2.plot(tms,ts_amp,color="0.6",ls="--",label="真の|<F>|平均")
ax2.set_ylabel("|<F>| 列平均",color="0.5"); ax[2].set_title("方向誤差とスピン振幅")
for a in ax: a.set_xlabel("t [ms]"); a.grid(alpha=0.25)
fig.suptitle(f"{LABEL} 傾斜SG±16°可視ブロック法: 列平均<F>(x,z) 誤差の時間発展 (真値=完全スピノル)",fontsize=12)
fig.savefig(OUT_TS,dpi=130,bbox_inches="tight"); plt.close(fig); print("wrote",OUT_TS)

# ---- console summary at reps ----
print("\n=== 代表時刻サマリ (列平均, mask=col-density>5%) ===")
for k in REP:
    psi=load_frames_bulk(P,[k])[0]; fxR,fyR,fzR=map(clip6,recon_vis(psi)); fxE,fyE,fzE=map(clip6,recon_exact(psi)); fxT,fyT,fzT,ncol=truth_col(psi)
    cv=[metrics(a,b,ncol) for a,b in [(fxR,fxT),(fyR,fyT),(fzR,fzT)]]
    ce=[metrics(a,b,ncol) for a,b in [(fxE,fxT),(fyE,fyT),(fzE,fzT)]]
    print(f"t={tms[k]:6.1f}ms  ±16可視: corr={tuple(round(c[0],3) for c in cv)} relL2={tuple(round(c[1],3) for c in cv)}")
    print(f"            厳密90全13: corr={tuple(round(c[0],3) for c in ce)} relL2={tuple(round(c[1],3) for c in ce)}")
