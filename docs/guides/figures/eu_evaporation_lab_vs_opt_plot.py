import sys, csv, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec
OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"; C_LAB="#2a78d6"; C_OPT="#eb6834"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":11,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,"axes.spines.top":False,"axes.spines.right":False})
def cols(p):
    with open(p) as f:
        r=csv.reader(f);h=next(r);c={k:[] for k in h}
        for row in r:
            for k,v in zip(h,row):c[k].append(float(v))
    return {k:np.array(v) for k,v in c.items()}
bl=cols(os.path.join(OUT,"bec_lab.csv")); bo=cols(os.path.join(OUT,"bec_opt.csv"))
rl=cols(os.path.join(OUT,"ramp_lab.csv")); ro=cols(os.path.join(OUT,"ramp_opt.csv"))
labN,labT=bl["N0"][-1],bl["T"][-1]*1e9; optN,optT=bo["N0"][-1],bo["T"][-1]*1e9

fig=plt.figure(figsize=(14,7.4))
gs=gridspec.GridSpec(2,2,height_ratios=[0.26,1],hspace=0.30,wspace=0.24,left=0.07,right=0.975,top=0.99,bottom=0.09)
hero=fig.add_subplot(gs[0,:]); hero.axis("off")
hero.text(0.0,0.66,"Optimized operating point vs the lab (thesis) ramp",fontsize=18,fontweight="bold",color=INK,va="center")
hero.text(0.0,0.12,"K₃ = 10⁻⁴¹ (central) · same calibrated model + heating floor · same loaded gas (1.4×10⁶ @ 50 µK)",fontsize=11,color=INK2,va="center")
def stat(x,b,s,c):
    hero.text(x,0.66,b,fontsize=21,fontweight="bold",color=c,va="center",ha="left");hero.text(x,0.04,s,fontsize=10,color=INK2,va="center",ha="left")
stat(0.62,f"{optN/1.5e4:.0f}×",f"more condensate\nvs measured 1.5×10⁴",C_OPT)
stat(0.82,f"{optT:.0f} nK",f"final T\n(≤ 50 nK target)",C_OPT)

# ramp (POWER = LINEAR per convention)
ax=fig.add_subplot(gs[1,0])
ax.plot(rl["t"],rl["HFORT"],color=C_LAB,lw=2.3,label="lab hODT");ax.plot(rl["t"],rl["VFORT"],color=C_LAB,lw=1.5,ls=(0,(3,2)),label="lab vODT")
ax.plot(ro["t"],ro["HFORT"],color=C_OPT,lw=2.3,label="opt hODT");ax.plot(ro["t"],ro["VFORT"],color=C_OPT,lw=1.5,ls=(0,(3,2)),label="opt vODT")
ax.set_ylim(bottom=0); ax.set_xlabel("time  t  [s]"); ax.set_ylabel("ODT power  [W]")
ax.set_title("ramp schedules (linear power)",fontsize=11.5,loc="left",pad=6); ax.legend(fontsize=9,frameon=False,ncol=2)
# condensate number (atom number → log OK)
ax2=fig.add_subplot(gs[1,1])
ax2.plot(bl["t"],np.maximum(bl["N0"],1),color=C_LAB,lw=2.4,label="lab condensate N₀")
ax2.plot(bo["t"],np.maximum(bo["N0"],1),color=C_OPT,lw=2.4,label="opt condensate N₀")
ax2.plot(bl["t"][-1],max(labN,1),"o",ms=10,color=C_LAB,mec=SURFACE,mew=1.6,zorder=5)
ax2.plot(bo["t"][-1],optN,"o",ms=10,color=C_OPT,mec=SURFACE,mew=1.6,zorder=5)
ax2.set_yscale("log"); ax2.set_xlabel("time  t  [s]"); ax2.set_ylabel("condensate number  N₀")
ax2.set_title("condensate: opt keeps far more (lab's dense BEC lost to 3-body)",fontsize=11.5,loc="left",pad=6)
ax2.text(bo["t"][-1],optN*1.4,f"{optN:.1e}",color=C_OPT,ha="center",fontsize=10,fontweight="bold")
ax2.text(bl["t"][-1],max(labN,1)*0.55,f"{labN:.1e}",color=C_LAB,ha="center",va="top",fontsize=10)
ax2.legend(fontsize=9,frameon=False,loc="lower right")
png=os.path.join(OUT,"evap_lab_vs_opt.png");fig.savefig(png,dpi=140);print("wrote",png)
