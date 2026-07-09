"""CAN Goto's difference imaging see precession? Extract the transverse-spin
orientation phi0(t) using ONLY Goto's m=-6 difference maps (2 tilts x,y + untilted):
  D_y = |[R_y(b)psi]_-6|^2_INTdy - Cp*|psi_-6|^2_INTdy   ~ +INTdy f_x
  D_x = |[R_x(b)psi]_-6|^2_INTdy - Cp*|psi_-6|^2_INTdy   ~ -INTdy f_y
  phi0_Goto = atan2( sum sign(x)(-D_x), sum sign(x)(D_y) )   [= transverse direction]
Compare to the TRUE transverse phase (column) as validation. Report dphi0/dt.
env: PSI13, GOTO, BETA_DEG, OUT, LABEL"""
import os, sys, numpy as np, h5py
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,os.path.join(HERE,"v7_fable")); sys.path.insert(0,HERE)
from v7_common import ms, rot, FX, FY, load_frames_bulk, open_psi13, psi13_nframes
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI13=os.environ["PSI13"]; GOTO=os.environ["GOTO"]; B=float(os.environ.get("BETA_DEG","16"))
OUT=os.environ.get("OUT","goto_precession.png"); LABEL=os.environ.get("LABEL","EdH")
i6=int(np.where(ms==-6)[0][0]); Cp=np.abs(rot("y",B)[i6,i6])**2
with h5py.File(GOTO,"r") as G:
    t=np.asarray(G["t"]); om=float(G["meta/omega_ref"][()]); L=float(G["meta/L_box"][()]); Bg=np.asarray(G["B_gauss"])
tms=t/om*1000.0; P=open_psi13(PSI13); nf=min(psi13_nframes(P),len(tms))
Ng=load_frames_bulk(P,[0])[0].shape[0]; ax=np.linspace(-L/2,L/2,Ng); sgnx=np.sign(ax)[:,None]*np.ones((1,Ng))
def m6(psi,R): return (np.abs(np.einsum("mn,xyzn->xyzm",R,psi)[...,i6])**2).sum(1)
phiG=np.full(nf,np.nan); phiG2=np.full(nf,np.nan); phiT=np.full(nf,np.nan); ampG=np.zeros(nf); ampT=np.zeros(nf)
CH=40
for a in range(0,nf,CH):
    fr=list(range(a,min(a+CH,nf))); ps=load_frames_bulk(P,fr)
    for j,k in enumerate(fr):
        psi=ps[j]; u=m6(psi,rot("id",0)); Dy=m6(psi,rot("y",B))-Cp*u; Dx=m6(psi,rot("x",B))-Cp*u
        ZG=np.sum(sgnx*(Dy-1j*Dx)); phiG[k]=np.angle(ZG); ampG[k]=np.abs(ZG)
        # improved Goto: +-tilt on m=-6 (cancels the symmetric m=-5 population term)
        Dy2=m6(psi,rot("y",B))-m6(psi,rot("y",-B)); Dx2=m6(psi,rot("x",B))-m6(psi,rot("x",-B))
        ZG2=np.sum(sgnx*(Dy2-1j*Dx2)); phiG2[k]=np.angle(ZG2)
        # true column transverse phase for validation
        sd=lambda Op:np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(psi),Op,psi)); nc=np.sum(np.abs(psi)**2,-1).sum(1)
        cfx=sd(FX).sum(1)/np.clip(nc,1e-30,None); cfy=sd(FY).sum(1)/np.clip(nc,1e-30,None)
        ZT=np.sum(nc*sgnx*(cfx+1j*cfy)); phiT[k]=np.angle(ZT); ampT[k]=np.abs(ZT)
    print(f"[goto-prec] {min(a+CH,nf)}/{nf}")
good=ampT>0.1*ampT.max()
to_branch=lambda p,ref: p+2*np.pi*np.round((ref-p)/(2*np.pi))
phiGb=to_branch(phiG,phiT); phiG2b=to_branch(phiG2,phiT)
fig,axs=plt.subplots(1,2,figsize=(12,4.3),constrained_layout=True)
pg=np.where(good,np.degrees(phiGb),np.nan); pg2=np.where(good,np.degrees(phiG2b),np.nan); pt=np.where(good,np.degrees(phiT),np.nan)
axs[0].plot(tms,pt,"k-",lw=2.4,label="true transverse phase (validation)")
axs[0].plot(tms,pg,"s-",ms=4,color="#d1495b",label="φ0: Goto single-tilt m=-6 (actual method)")
axs[0].plot(tms,pg2,"o-",ms=4,color="#2ca6a4",label="φ0: Goto ±tilt m=-6 (improved)")
gg=np.where(good)[0]
if len(gg)>1: axs[0].axvspan(tms[gg[0]],tms[gg[-1]],color="0.92",zorder=0)
axs[0].set_xlabel("t [ms]"); axs[0].set_ylabel("transverse spin orientation φ0 [deg]"); axs[0].legend(fontsize=9); axs[0].grid(alpha=0.25)
axs[0].set_title(f"{LABEL}: precession phase from Goto difference imaging")
axs[1].plot(tms,ampT/max(ampT.max(),1e-30),"k-",label="transverse signal (norm)")
axs[1].plot(tms,Bg*1e6,"--",color="#c8a415",label="ext. B [µG]")
axs[1].set_xlabel("t [ms]"); axs[1].set_ylabel("transverse signal / B[µG]"); axs[1].legend(fontsize=9); axs[1].grid(alpha=0.25)
axs[1].set_title(f"{LABEL}: when is transverse spin present?")
fig.savefig(OUT,dpi=150,bbox_inches="tight"); plt.close(fig)
if len(gg)>2:
    rG=(np.degrees(phiGb)[gg[-1]]-np.degrees(phiGb)[gg[0]])/(tms[gg[-1]]-tms[gg[0]])
    rT=(np.degrees(phiT)[gg[-1]]-np.degrees(phiT)[gg[0]])/(tms[gg[-1]]-tms[gg[0]])
    dev=np.nanstd((phiGb-phiT)[good])*180/np.pi
    print(f"=== {LABEL} 歳差ダイナミクス (窓 {tms[gg[0]]:.0f}-{tms[gg[-1]]:.0f}ms) ===")
    rG2=(np.degrees(phiG2b)[gg[-1]]-np.degrees(phiG2b)[gg[0]])/(tms[gg[-1]]-tms[gg[0]]); dev2=np.nanstd((phiG2b-phiT)[good])*180/np.pi
    print(f"  Goto単一傾け φ0: {np.degrees(phiGb)[gg[0]]:+.0f}->{np.degrees(phiGb)[gg[-1]]:+.0f}°, {rG/360*1000:+.1f}Hz, 真値との食い違いRMS={dev:.0f}°")
    print(f"  Goto±傾け   φ0: {np.degrees(phiG2b)[gg[0]]:+.0f}->{np.degrees(phiG2b)[gg[-1]]:+.0f}°, {rG2/360*1000:+.1f}Hz, 食い違いRMS={dev2:.0f}°")
    print(f"  真値       φ0: {np.degrees(phiT)[gg[0]]:+.0f}->{np.degrees(phiT)[gg[-1]]:+.0f}°, {rT/360*1000:+.1f}Hz")
print("wrote",OUT)
