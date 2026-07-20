"""Old (buggy q, q=0 GS) vs New (fixed q, auto-q GS) quantitative comparison for
the 3 main runs. Gauge-invariant observables only (populations, <Fz>, transverse
spin, and the Goto x-tilt difference image D). Confirms whether the 11x-smaller
quadratic Zeeman changes the EdH/Flower dynamics at these fields.
Old psi13 in ., new in resim/.  Writes compare_resim.png + prints a summary."""
import os, sys, numpy as np
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import japanize_matplotlib  # noqa
DIR=os.environ.get("DIR",".")   # run from isoviz_dev
RUNS=[("par_T90","par_T90 EdH (放物線)"),("flower120","flower120"),("quench","quench")]
i6=int(np.where(ms==-6)[0][0]); B=16.0; Cp=np.abs(rot("x",B)[i6,i6])**2
mvals=ms.astype(float)
def pops_fz(psi):  # per-frame: populations(13), <Fz>, transverse |Fperp|/N
    n=np.abs(psi)**2; N=n.sum(); pm=n.sum((0,1,2))/N
    fz=(mvals*pm).sum()
    fx=np.real(np.einsum("xyzm,mn,xyzn->",np.conj(psi),FX,psi))/N
    fy=np.real(np.einsum("xyzm,mn,xyzn->",np.conj(psi),FY,psi))/N
    return pm, fz, np.hypot(fx,fy)
def m6col(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
def D_xtilt(psi): return m6col(psi,rot("x",B))-Cp*m6col(psi,rot("id",0))
fig,axs=plt.subplots(3,3,figsize=(15,11));
summary=[]
for r,(key,lab) in enumerate(RUNS):
    Po=open_psi13(os.path.join(DIR,f"{key}_psi13.jld2")); Pn=open_psi13(os.path.join(DIR,"resim",f"{key}_psi13.jld2"))
    nf=min(psi13_nframes(Po),psi13_nframes(Pn)); fr=list(range(nf))
    po=load_frames_bulk(Po,fr); pn=load_frames_bulk(Pn,fr)
    PMo=np.zeros((nf,13)); PMn=np.zeros((nf,13)); FZo=np.zeros(nf); FZn=np.zeros(nf); FPo=np.zeros(nf); FPn=np.zeros(nf)
    for k in range(nf):
        PMo[k],FZo[k],FPo[k]=pops_fz(po[k]); PMn[k],FZn[k],FPn[k]=pops_fz(pn[k])
    # final-frame Goto D correlation (physical EdH/flower signature)
    Do=D_xtilt(po[-1]); Dn=D_xtilt(pn[-1])
    Dcorr=np.corrcoef(Do.ravel(),Dn.ravel())[0,1]
    dFz=np.abs(FZo-FZn).max(); dPop=np.abs(PMo-PMn).max()
    summary.append((lab,dFz,dPop,Dcorr))
    # col0: <Fz>(t) old vs new
    a=axs[r,0]; a.plot(FZo,label="旧 (buggy q)",lw=2); a.plot(FZn,"--",label="新 (fixed q)",lw=2)
    a.set_title(f"{lab}: ⟨Fz⟩(t)\nmax|Δ⟨Fz⟩|={dFz:.2e}"); a.set_xlabel("frame"); a.set_ylabel("⟨Fz⟩"); a.legend(fontsize=9); a.grid(alpha=.3)
    # col1: dominant populations n_m(t) old vs new (m=-6..-3)
    a=axs[r,1]
    for m in (-6,-5,-4,-3):
        im=int(np.where(ms==m)[0][0]); a.plot(PMo[:,im],lw=1.6); a.plot(PMn[:,im],"--",lw=1.6)
    a.set_title(f"{lab}: n_m(t) (m=-6..-3)\n実線=旧 破線=新, max|Δn|={dPop:.2e}"); a.set_xlabel("frame"); a.set_ylabel("population"); a.grid(alpha=.3)
    # col2: final-frame D old vs new diff
    a=axs[r,2]; g=np.abs(Do).max()+1e-30
    im2=a.imshow((Dn-Do).T,origin="lower",cmap="RdBu_r",vmin=-0.05*g,vmax=0.05*g,aspect="equal")
    a.set_title(f"{lab}: 差分撮像 D の新−旧 (最終)\nD相関={Dcorr:.5f}, スケール=±5%"); a.set_xlabel("x"); a.set_ylabel("z")
    fig.colorbar(im2,ax=a,fraction=0.046,pad=0.04)
fig.suptitle("修正ハミルトニアン検証: 旧(q 11倍過大, q=0 GS) vs 新(fixed q, 自動q GS) — 主要3run",fontsize=15,y=0.997)
fig.tight_layout(rect=[0,0,1,0.985]); fig.savefig(os.path.join(DIR,"compare_resim.png"),dpi=120);
print("\n===== OLD vs NEW summary (fixed Hamiltonian) =====")
print(f"{'run':<22}{'max|Δ<Fz>|':>14}{'max|Δn_m|':>14}{'D correlation':>16}")
for lab,dFz,dPop,Dc in summary: print(f"{lab:<22}{dFz:>14.3e}{dPop:>14.3e}{Dc:>16.6f}")
print("\nwrote", os.path.join(DIR,"compare_resim.png"))
