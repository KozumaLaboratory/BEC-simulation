#!/usr/bin/env python3
"""Per-m column-integrated (absorption-imaging) SIDE view in the xz plane: for each
m, n_m^col(x,z)=INT dy |psi_m|^2. Characteristic: m=-4 shows THREE lines (double-ring
+ third node projected). Plus population P_m (bar at frame) and P_m(t) trajectory.
env: PSI13, GOTO, FRAME, OUTDIR, TAG"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI=os.environ.get("PSI13","edh_v5_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v5_goto.h5")
FR=int(os.environ.get("FRAME","100")); OD=os.environ.get("OUTDIR","."); TAG=os.environ.get("TAG","v5")
F=6; D=13; ms=np.arange(F,-F-1,-1)
P=h5py.File(PSI,"r"); L=float(P["meta/L_box"][()])
G=h5py.File(GOTO,"r") if os.path.exists(GOTO) else None
tms=(float(np.asarray(G["t"])[FR])/float(G["meta/omega_ref"][()])*1000) if G else FR
def dens(c,fr):  # |psi_m|^2 (x,y,z) for c-index (1..13) at frame fr
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,fr]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,fr]
    return re**2+im**2
Ng=np.transpose(np.asarray(P["n_total_3d"]),(2,1,0,3)).shape[0]; ext=[-L/2,L/2,-L/2,L/2]
# ---- xz column images (INT dy) for m = -6..-1 ----
mshow=[(-6,13),(-5,12),(-4,11),(-3,10),(-2,9),(-1,8)]
fig,ax=plt.subplots(1,len(mshow),figsize=(2.5*len(mshow),3.2),constrained_layout=True)
for j,(m,c) in enumerate(mshow):
    d=dens(c,FR); col_y=d.sum(axis=1)             # INT dy -> (x,z)
    vm=col_y.max() if col_y.max()>0 else 1
    a=ax[j]; im=a.imshow((col_y/vm).T,origin="lower",extent=ext,cmap="inferno",vmin=0,vmax=1,aspect="equal")
    a.set_title(f"m={m}",fontsize=11,fontweight=("bold" if m==-4 else "normal")); a.set_xlabel("x [μm]",fontsize=8)
    if j==0: a.set_ylabel("z [μm]",fontsize=9)
    a.tick_params(labelsize=7)
fig.suptitle(f"xz column-integrated (∫dy, side-view absorption) per m — EdH {TAG}, t={tms:.1f} ms   (m=−4: three lines)",fontsize=12)
fig.savefig(f"{OD}/edh_{TAG}_per_m_xz_column.png",dpi=130,bbox_inches="tight"); plt.close(fig)
print(f"wrote edh_{TAG}_per_m_xz_column.png")
# ---- population: P_m bar at frame + P_m(t) trajectory ----
nf=np.asarray(P["psi_re_c01"]).shape[-1]
Pm_t=np.zeros((nf,D))
for c in range(1,D+1):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))
    Pm_t[:,c-1]=(re**2+im**2).sum(axis=(0,1,2))
Ntot=Pm_t.sum(axis=1); Pm_frac=Pm_t/Ntot[:,None]
tarr=(np.asarray(G["t"])/float(G["meta/omega_ref"][()])*1000) if G else np.arange(nf)
fig,ax=plt.subplots(1,2,figsize=(12,4.4),constrained_layout=True)
ax[0].bar(ms,Pm_frac[FR]*100,color=["C3" if m==-4 else "C0" for m in ms])
ax[0].set_xlabel("m"); ax[0].set_ylabel("population P_m [%]"); ax[0].set_title(f"P_m at t={tms:.1f} ms"); ax[0].grid(alpha=.3,axis="y")
for m,c in [(-6,13),(-5,12),(-4,11),(-3,10),(-2,9)]:
    ax[1].plot(tarr,Pm_frac[:,c-1]*100,label=f"m={m}",lw=1.6)
ax[1].set_xlabel("t [ms]"); ax[1].set_ylabel("P_m [%]"); ax[1].set_title("P_m(t) trajectory"); ax[1].legend(fontsize=8); ax[1].grid(alpha=.3)
fig.suptitle(f"EdH {TAG} per-m population (spin→orbital transfer ladder)",fontsize=12)
fig.savefig(f"{OD}/edh_{TAG}_population.png",dpi=130,bbox_inches="tight"); plt.close(fig)
print(f"wrote edh_{TAG}_population.png")
print("P_m at frame (%):", {int(m):round(float(Pm_frac[FR,i]*100),2) for i,m in enumerate(ms) if Pm_frac[FR,i]>1e-4})
