#!/usr/bin/env python3
"""Time-resolved xz column-integrated (INT dy, side-view absorption) per m, as MP4.
Panels m=-6..-1; each self-normalized per frame. m=-4 shows the three-line feature.
env: PSI13, GOTO, OUT(.mp4), DUR, FPS, TAG"""
import os, sys, numpy as np, h5py
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
sys.path.insert(0,"/Users/mitsuki/Desktop/Projects/Research/KozumaLab/projects/BEC-simulation/scripts/flower_protocol_edh")
from _anim_writer import save_matplotlib_anim, expanded_frame_indices
PSI=os.environ.get("PSI13","edh_v5_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v5_goto.h5")
OUT=os.environ.get("OUT","per_m_xz_anim.mp4"); DUR=float(os.environ.get("DUR","20")); FPS=int(os.environ.get("FPS","20")); TAG=os.environ.get("TAG","v5")
F=6; ms=np.arange(F,-F-1,-1)
P=h5py.File(PSI,"r"); L=float(P["meta/L_box"][()]); G=h5py.File(GOTO,"r")
tarr=np.asarray(G["t"])/float(G["meta/omega_ref"][()])*1000; Barr=np.asarray(G["B_gauss"])
mshow=[(-6,13),(-5,12),(-4,11),(-3,10),(-2,9),(-1,8)]
# preload |psi_m|^2 (x,y,z,nf) for the 6 shown components
DENS={}
for m,c in mshow:
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3)); im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))
    DENS[m]=(re**2+im**2)
NF=DENS[-6].shape[-1]; ext=[-L/2,L/2,-L/2,L/2]
fig,ax=plt.subplots(1,len(mshow),figsize=(2.5*len(mshow),3.4),constrained_layout=True)
ims=[]
for j,(m,c) in enumerate(mshow):
    a=ax[j]; im=a.imshow(np.zeros((DENS[m].shape[0],)*2).T,origin="lower",extent=ext,cmap="inferno",vmin=0,vmax=1,aspect="equal")
    a.set_title(f"m={m}",fontsize=11,fontweight=("bold" if m==-4 else "normal")); a.set_xlabel("x [μm]",fontsize=8); a.tick_params(labelsize=7)
    if j==0: a.set_ylabel("z [μm]",fontsize=9)
    ims.append(im)
def draw(fr):
    for j,(m,c) in enumerate(mshow):
        col_y=DENS[m][...,fr].sum(axis=1); vm=col_y.max() if col_y.max()>0 else 1
        ims[j].set_data((col_y/vm).T)
    fig.suptitle(f"xz column-integrated (∫dy) per m — EdH {TAG}   t={tarr[fr]:.1f} ms  B={Barr[fr]*1e3:.3f} mG   (m=−4: three lines)",fontsize=12)
idx=expanded_frame_indices(NF,DUR,FPS)
anim=FuncAnimation(fig,draw,frames=idx,interval=1000/FPS)
save_matplotlib_anim(anim,OUT,fps=FPS)
print(f"wrote {OUT}  ({NF} data frames)")
