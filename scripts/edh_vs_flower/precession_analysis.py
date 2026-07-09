"""Precession dynamics of the transverse spin (l=1 phase phi0(t)) computed 3 ways:
 A = from Goto m=-6 difference maps (D_y ~ INTdy f_x, D_x ~ -INTdy f_y) [observable]
 B = from our tilted-SG +-16 visible-block column <Fx>,<Fy>            [observable]
 C = ground truth l=1 phase phi0 = arg( sum_r n (f_x+i f_y) e^{-i phi} ) [reference]
plus the Larmor prediction Phi_L(t)=int gamma|B_ext|dt.  Also |transverse| amplitude.
env: PSI13, GOTO, BETA_DEG, OUT, LABEL"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, VISIBLE_IDX, FX, FY, FZ, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; B=float(os.environ.get("BETA_DEG","16")); s16=np.sin(np.radians(B))
OUT=os.environ.get("OUT","precession.png"); LABEL=os.environ.get("LABEL","EdH")
ms_v=ms[VISIBLE_IDX].astype(float); i6=int(np.where(ms==-6)[0][0]); Cp=np.abs(rot("y",B)[i6,i6])**2
GAMMA=1.163*1.399e6*2*np.pi     # g_F mu_B/hbar [rad/s per Gauss]  (approx, for phase-rate reference)
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000.0; P=open_psi13(PSI13); nf=min(psi13_nframes(P),len(tms))
Ng=load_frames_bulk(P,[0])[0].shape[0]; ax=np.linspace(-L/2,L/2,Ng)
X=ax[:,None,None]; Y=ax[None,:,None]; PHI3=np.arctan2(Y+0*np.ones((Ng,Ng,Ng)),X+0*np.ones((Ng,Ng,Ng)))
sgnx=np.sign(ax)[:,None]*np.ones((1,Ng))   # sign(x) on (x,z) plane
def col_cen(psi,R,idx,mv):
    o=np.abs(np.einsum("mn,xyzn->xyzm",R,psi))**2; ov=o[...,idx].sum(1); return np.einsum("xzm,m->xz",ov,mv)/np.clip(ov.sum(-1),1e-30,None)
def m6img(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
phiA=np.full(nf,np.nan); phiB=np.full(nf,np.nan); phiC=np.full(nf,np.nan); amp=np.zeros(nf)
CH=40
for a in range(0,nf,CH):
    fr=list(range(a,min(a+CH,nf))); ps=load_frames_bulk(P,fr)
    for j,k in enumerate(fr):
        psi=ps[j]; n=np.sum(np.abs(psi)**2,-1); nc=n.sum(1)
        sd=lambda Op:np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi))
        fx3,fy3=sd(FX),sd(FY)
        # C: true l=1 phase (3D density-weighted azimuthal projection)
        ZC=np.sum(n*(fx3+1j*fy3)*np.exp(-1j*PHI3)); phiC[k]=np.angle(ZC); amp[k]=np.abs(ZC)/max(n.sum(),1e-30)
        # B: our +-16 visible-block column <Fx>,<Fy>
        cfz=col_cen(psi,rot("id",0),VISIBLE_IDX,ms_v)
        cfx=-(col_cen(psi,rot("y",B),VISIBLE_IDX,ms_v)-col_cen(psi,rot("y",-B),VISIBLE_IDX,ms_v))/(2*s16)
        cfy=+(col_cen(psi,rot("x",B),VISIBLE_IDX,ms_v)-col_cen(psi,rot("x",-B),VISIBLE_IDX,ms_v))/(2*s16)
        ZB=np.sum(nc*sgnx*(cfx+1j*cfy)); phiB[k]=np.angle(ZB)
        # A: Goto m=-6 difference maps (single +B tilt), D_y~+INTf_x, D_x~-INTf_y
        u=m6img(psi,rot("id",0)); Dy=m6img(psi,rot("y",B))-Cp*u; Dx=m6img(psi,rot("x",B))-Cp*u
        ZA=np.sum(sgnx*(Dy-1j*Dx)); phiA[k]=np.angle(ZA)
    print(f"[prec] {min(a+CH,nf)}/{nf}")
good=amp>0.1*amp.max()
# bring all phases to a common branch (they barely wind -> no unwrap, just align mod 2pi to C)
to_branch=lambda p,ref: p+2*np.pi*np.round((ref-p)/(2*np.pi))
phiCu=phiC.copy(); phiBu=to_branch(phiB,phiC); phiAu=to_branch(phiA,phiC)
# Larmor predicted phase from external field
PhiL=np.concatenate([[0],np.cumsum(GAMMA*Bg[1:]*np.diff(t/om))]); PhiL=PhiL-PhiL[good.argmax()]+phiCu[good.argmax()]
fig,axs=plt.subplots(1,2,figsize=(12,4.3),constrained_layout=True)
gg=np.where(good)[0]; tw=(tms[gg[0]],tms[gg[-1]]) if len(gg)>1 else (tms[0],tms[-1])
# show phi0 only where transverse amplitude is significant (else it's noise)
pc=np.where(good,np.degrees(phiCu),np.nan); pb=np.where(good,np.degrees(phiBu),np.nan); pa=np.where(good,np.degrees(phiAu),np.nan)
axs[0].plot(tms,pc,"k-",lw=2.4,label="C: truth (l=1 phase)")
axs[0].plot(tms,pb,"o-",ms=4,color="#2ca6a4",label="B: our recon (±16 column)")
axs[0].plot(tms,pa,"s-",ms=4,color="#d1495b",label="A: Goto m=-6 diff")
axs[0].axvspan(tw[0],tw[1],color="0.9",zorder=0)
axs[0].set_xlabel("t [ms]"); axs[0].set_ylabel("precession phase φ0 [deg]"); axs[0].legend(fontsize=9,loc="best"); axs[0].grid(alpha=0.25); axs[0].set_title(f"{LABEL}: precession phase φ0(t)  (shaded = transverse present)")
axs[0].text(0.02,0.03,f"naive Larmor(ext B) would give {np.degrees(PhiL[gg[-1]]-PhiL[gg[0]]):.0f}°\nover the shaded window — NOT realized",transform=axs[0].transAxes,fontsize=8,color="0.4",va="bottom")
ax2=axs[1]; ax2.plot(tms,amp/max(amp.max(),1e-30),"k-",label="|transverse l=1| (norm)")
ax2.plot(tms,Bg*1e6,color="#c8a415",ls="--",label="ext. B [µG]")
ax2.axvspan(tw[0],tw[1],color="0.9",zorder=0)
ax2.set_xlabel("t [ms]"); ax2.set_ylabel("transverse amp (norm)  /  B [µG]"); ax2.legend(fontsize=9,loc="upper left"); ax2.grid(alpha=0.25); ax2.set_title(f"{LABEL}: transverse amplitude vs field")
fig.savefig(OUT,dpi=150,bbox_inches="tight"); plt.close(fig)
# console summary: mean precession rate over good window
gw=np.where(good)[0]
if len(gw)>2:
    for lab,p in [("C truth",phiCu),("B recon",phiBu),("A Goto",phiAu)]:
        rate=(np.degrees(p)[gw[-1]]-np.degrees(p)[gw[0]])/((tms[gw[-1]]-tms[gw[0]]))   # deg/ms
        print(f"  {lab}: mean dphi0/dt = {rate:+.1f} deg/ms = {rate/360*1000:+.1f} Hz over t=[{tms[gw[0]]:.0f},{tms[gw[-1]]:.0f}]ms")
print("wrote",OUT)
