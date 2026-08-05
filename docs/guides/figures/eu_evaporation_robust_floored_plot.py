import sys, csv, os, re
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec
OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"; C_LAB="#2a78d6"; C_ROB="#eb6834"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":11,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,"axes.spines.top":False,"axes.spines.right":False})
rows=list(csv.DictReader(open(os.path.join(OUT,"robustness_grid.csv"))))
def series(ramp,col):
    d={}
    for r in rows:
        if r["ramp"]!=ramp: continue
        K=float(r["K3"]); d.setdefault(K,[]).append(float(r[col]))
    Ks=sorted(d); return np.array(Ks),np.array([np.median(d[K]) for K in Ks]),np.array([min(d[K]) for K in Ks]),np.array([max(d[K]) for K in Ks])
def cols(p):
    with open(p) as f:
        r=csv.reader(f);h=next(r);c={k:[] for k in h}
        for row in r:
            for k,v in zip(h,row):c[k].append(float(v))
    return {k:np.array(v) for k,v in c.items()}
rlab=cols(os.path.join(OUT,"ramp_lab.csv")); rrob=cols(os.path.join(OUT,"ramp_opt.csv"))
S=open(os.path.join(OUT,"summary.txt")).read(); g=lambda p:re.search(p,S).group(1)
factor=g(r"factor=([\d.]+)x"); Trob=g(r"robust N0=[\d.eE+-]+ T=([\d.]+)nK"); ncr=g(r"robust=(\d+)")

fig=plt.figure(figsize=(14.5,7.6))
gs=gridspec.GridSpec(2,3,height_ratios=[0.30,1],hspace=0.32,wspace=0.34,left=0.07,right=0.975,top=0.99,bottom=0.10)
hero=fig.add_subplot(gs[0,:]); hero.axis("off")
hero.text(0.0,0.7,"Robust optimization WITH physical floors",fontsize=19,fontweight="bold",color=INK,va="center")
hero.text(0.0,0.1,"heating floor (T no longer → 0)  +  rethermalization floor (∫γ_el dt ≥ 150 coll/atom)",fontsize=11,color=INK2,va="center")
def stat(x,b,s,c):
    hero.text(x,0.72,b,fontsize=22,fontweight="bold",color=c,va="center",ha="left"); hero.text(x,0.05,s,fontsize=10,color=INK2,va="center",ha="left")
stat(0.58,f"{float(factor):.0f}×","more condensate\n(robust vs lab)",C_ROB)
stat(0.74,f"{float(Trob):.0f} nK","pure-BEC T\n(heating floor on)",C_ROB)
stat(0.90,f"{int(ncr)}","collisions/atom\n(floor 150 — ample)",INK)

# N0 vs K3
ax=fig.add_subplot(gs[1,0])
for ramp,c,l in (("lab",C_LAB,"lab (thesis)"),("robust",C_ROB,"robust-opt (+floors)")):
    K,med,lo,hi=series(ramp,"N0"); ax.fill_between(K,lo,hi,color=c,alpha=0.15,lw=0)
    ax.plot(K,med,color=c,lw=2.4,marker="o",ms=5,mec=SURFACE,mew=1,label=l)
ax.set_xscale("log");ax.set_yscale("log");ax.set_xlabel("K₃ [m⁶/s] (unknown)");ax.set_ylabel("pure-BEC N₀")
ax.set_title("N₀ across K₃ (band = heating spread)",fontsize=12,loc="left",pad=6);ax.legend(fontsize=9,frameon=False,loc="lower left")
# T vs K3
ax2=fig.add_subplot(gs[1,1])
for ramp,c in (("lab",C_LAB),("robust",C_ROB)):
    K,med,lo,hi=series(ramp,"T"); ax2.fill_between(K,lo,hi,color=c,alpha=0.15,lw=0); ax2.plot(K,med,color=c,lw=2.4,marker="o",ms=5,mec=SURFACE,mew=1)
ax2.set_xscale("log");ax2.set_yscale("log");ax2.set_xlabel("K₃ [m⁶/s]");ax2.set_ylabel("final T [nK]")
ax2.set_title("final T — physical (no longer 0 nK)",fontsize=11.5,loc="left",pad=6)
# ramps
ax3=fig.add_subplot(gs[1,2])
ax3.plot(rlab["t"],rlab["HFORT"],color=C_LAB,lw=2.0);ax3.plot(rlab["t"],rlab["VFORT"],color=C_LAB,lw=1.4,ls=(0,(3,2)))
ax3.plot(rrob["t"],rrob["HFORT"],color=C_ROB,lw=2.0);ax3.plot(rrob["t"],rrob["VFORT"],color=C_ROB,lw=1.4,ls=(0,(3,2)))
ax3.set_yscale("log");ax3.set_xlabel("time t [s]");ax3.set_ylabel("ODT power [W]")
ax3.set_title("robust ramp (orange) vs lab (blue)",fontsize=11.5,loc="left",pad=6)
ax3.text(rlab["t"][-1],rlab["HFORT"][-1]," lab",color=C_LAB,fontsize=9,va="center",fontweight="bold")
ax3.text(rrob["t"][-1],rrob["HFORT"][-1]," robust",color=C_ROB,fontsize=9,va="center",fontweight="bold")
png=os.path.join(OUT,"evap_robust_floored.png");fig.savefig(png,dpi=140);print("wrote",png)
