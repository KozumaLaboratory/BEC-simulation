#!/usr/bin/env python3
"""CSS-ness quantitative analysis (stills) for EdH vs Flower.
Produces a 4-panel figure from the two goto.h5:
 (a) density-weighted spin length s̄(t) (band to min) + B(t) on twin axis
 (b) non-CSS mass fraction  W(s<0.9)(t)  (mass-weighted, the honest 'how much left CSS')
 (c) histogram of s over the cloud at the final frame (mass-weighted)
 (d) global Pythagoras check  (|<F_perp>|^2+<F_z>^2)/F^2 vs 1  (=1 iff pure coherent rotation)
env: GOTO_EDH, GOTO_FL, OUT(.png), LABEL_EDH, LABEL_FL
"""
import os, numpy as np, h5py
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

def load(fn):
    f=h5py.File(fn,"r"); T=lambda k: np.transpose(np.asarray(f[k]),(3,2,1,0))
    d=dict(F=float(f["meta/F"][()]), t=f["t"][:], om=float(f["meta/omega_ref"][()]),
           B=f["B_gauss"][:]*1e6, fx=T("Fx_3d"), fy=T("Fy_3d"), fz=T("Fz_3d"), n=T("n_total_3d"))
    f.close(); return d

E=load(os.environ["GOTO_EDH"]); Fl=load(os.environ["GOTO_FL"]) if os.environ.get("GOTO_FL") else None
LAB_E=os.environ.get("LABEL_EDH","EdH"); LAB_F=os.environ.get("LABEL_FL","Flower")
OUT=os.environ.get("OUT","css_analysis.png")
runs=[(E,LAB_E,"#B03A2E","-")]+([ (Fl,LAB_F,"#2F4858","--") ] if Fl else [])

def series(d):
    nt=len(d["t"]); tph=d["t"]/d["om"]*1e3; sw=np.zeros(nt); smin=np.zeros(nt); wfrac=np.zeros(nt); pyth=np.zeros(nt)
    for it in range(nt):
        n=d["n"][it]; nmax=n.max(); m=n>0.03*nmax
        fx,fy,fz=d["fx"][it],d["fy"][it],d["fz"][it]
        mag=np.sqrt(fx**2+fy**2+fz**2); s=mag[m]/(n[m]*d["F"]); w=n[m]
        sw[it]=np.average(s,weights=w); smin[it]=s.min()
        wfrac[it]=np.average((s<0.9).astype(float),weights=w)
        # global per-atom spin components
        N=n.sum(); Fz=fz.sum()/N; Fp2=(fx.sum()**2+fy.sum()**2)/N**2
        pyth[it]=(Fp2+ (Fz)**2)/d["F"]**2
    return tph,sw,smin,wfrac,pyth

fig,ax=plt.subplots(2,2,figsize=(12,8))
# (a) s̄(t) + B(t)
axb=ax[0,0].twinx()
for d,lab,c,ls in runs:
    tph,sw,smin,wf,py=series(d)
    ax[0,0].plot(tph,sw,ls,color=c,lw=2,label=lab); ax[0,0].fill_between(tph,smin,sw,color=c,alpha=0.12)
    axb.plot(tph,d["B"],":",color=c,lw=1,alpha=0.6)
ax[0,0].axhline(1,color="gray",lw=0.7); ax[0,0].set_ylim(0,1.05)
ax[0,0].set_xlabel("t [ms]"); ax[0,0].set_ylabel("spin length s=|⟨F⟩|/(nF)  (band→min)")
axb.set_ylabel("B [µG] (dotted)"); ax[0,0].legend(loc="lower left",fontsize=9)
ax[0,0].set_title("(a) local spin length (CSS-ness) vs time")
# (b) non-CSS mass fraction
for d,lab,c,ls in runs:
    tph,sw,smin,wf,py=series(d); ax[0,1].plot(tph,wf,ls,color=c,lw=2,label=lab)
ax[0,1].set_xlabel("t [ms]"); ax[0,1].set_ylabel("non-CSS mass fraction  W(s<0.9)")
ax[0,1].set_title("(b) how much mass left the CSS manifold"); ax[0,1].legend(fontsize=9)
# (c) final-frame histogram of s (mass-weighted)
for d,lab,c,ls in runs:
    n=d["n"][-1]; nmax=n.max(); m=n>0.03*nmax
    mag=np.sqrt(d["fx"][-1]**2+d["fy"][-1]**2+d["fz"][-1]**2); s=mag[m]/(n[m]*d["F"])
    ax[1,0].hist(s,bins=60,range=(0,1.02),weights=n[m],density=True,histtype="step",color=c,lw=2,label=lab)
ax[1,0].axvline(1,color="gray",lw=0.7); ax[1,0].set_xlabel("s (final frame)")
ax[1,0].set_ylabel("mass-weighted density"); ax[1,0].set_title("(c) distribution of local CSS-ness (final)"); ax[1,0].legend(fontsize=9)
# (d) global Pythagoras
for d,lab,c,ls in runs:
    tph,sw,smin,wf,py=series(d); ax[1,1].plot(tph,py,ls,color=c,lw=2,label=lab)
ax[1,1].axhline(1,color="gray",lw=0.7); ax[1,1].set_xlabel("t [ms]")
ax[1,1].set_ylabel("(|⟨F⊥⟩|²+⟨Fz⟩²)/F²  (global)")
ax[1,1].set_title("(d) global spin-vector length² (=1 iff rigid rotation)"); ax[1,1].legend(fontsize=9)
fig.suptitle("EdH vs Flower — CSS-ness / coherence quantitative analysis",fontsize=13)
fig.tight_layout(rect=[0,0,1,0.97]); fig.savefig(OUT,dpi=140); print("wrote",OUT)
