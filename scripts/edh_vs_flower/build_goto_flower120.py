"""Build a consistent goto.h5 (Fx/Fy/Fz/n + n_m/arg, analytic t & parabolic B)
from a psi13 file for the flower120 parabolic run (10mG->120uG over 90 internal,
then hold at 120uG). Save cadence every 1125 steps * dt 0.002 = 2.25 internal/frame
(uniform across both legs). env: PSI13, OUT"""
import os, sys, numpy as np, h5py
sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),"v7_fable"))
from v7_common import ms,FX,FY,FZ,load_frames_bulk,open_psi13,psi13_nframes
PSI13=os.environ.get("PSI13","flower120_psi13.jld2"); OUT=os.environ.get("OUT","flower120_goto.h5")
OM=691.15; DTFRAME=1125*0.002               # 2.25 internal time units per saved frame
B0=0.01; BEND=1.2e-4; TDESC=90.0            # parabolic descent 10mG->120uG over 90 internal
P=open_psi13(PSI13); nf=psi13_nframes(P); Ng=load_frames_bulk(P,[0])[0].shape[0]
t=np.arange(1,nf+1)*DTFRAME
Bg=np.where(t<=TDESC, BEND+(B0-BEND)*(1-t/TDESC)**2, BEND).astype(float)
i6,i5,i4=[int(np.where(ms==m)[0][0]) for m in (-6,-5,-4)]
F={k:np.zeros((Ng,Ng,Ng,nf),np.float32) for k in
   ("Fx_3d","Fy_3d","Fz_3d","n_total_3d","n_m6_3d","n_m5_3d","n_m4_3d","arg_psi_m6_3d","arg_psi_m5_3d","arg_psi_m4_3d")}
CH=30
for a in range(0,nf,CH):
    fr=list(range(a,min(a+CH,nf))); ps=load_frames_bulk(P,fr)
    for j,k in enumerate(fr):
        p=ps[j]
        F["Fx_3d"][...,k]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FX,p))
        F["Fy_3d"][...,k]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FY,p))
        F["Fz_3d"][...,k]=np.real(np.einsum("xyzm,mn,xyzn->xyz",np.conj(p),FZ,p))
        F["n_total_3d"][...,k]=np.sum(np.abs(p)**2,-1)
        F["n_m6_3d"][...,k]=np.abs(p[...,i6])**2; F["n_m5_3d"][...,k]=np.abs(p[...,i5])**2; F["n_m4_3d"][...,k]=np.abs(p[...,i4])**2
        F["arg_psi_m6_3d"][...,k]=np.angle(p[...,i6]); F["arg_psi_m5_3d"][...,k]=np.angle(p[...,i5]); F["arg_psi_m4_3d"][...,k]=np.angle(p[...,i4])
    print(f"[goto] {min(a+CH,nf)}/{nf}")
O=h5py.File(OUT,"w")
for k,arr in F.items(): O[k]=arr
O["t"]=t; O["B_gauss"]=Bg
g=O.create_group("meta")
for k,v in (("F",6),("NX",64),("L_box",18.0),("vol_stride",2),("omega_ref",OM)): g[k]=v
O.close()
print(f"wrote {OUT}: {nf} frames  tms {t[0]/OM*1000:.1f}->{t[-1]/OM*1000:.1f}  B {Bg[0]*1e6:.0f}->{Bg[-1]*1e6:.0f} uG")
