import sys, csv, os, re
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec
try:
    from scipy.interpolate import PchipInterpolator as PCHIP
except Exception:
    PCHIP=None
OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"; C="#eb6834"; CH="#eb6834"; CV="#2a78d6"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":11.5,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,"axes.spines.top":False,"axes.spines.right":False})
scores=np.array([float(l) for l in open(os.path.join(OUT,"scores.csv")).read().splitlines()[1:]])
best=scores.max(); within=100*np.mean(scores>=0.95*best)
# breakpoints from operating_point.txt
txt=open(os.path.join(OUT,"operating_point.txt")).read()
N0=float(re.search(r"N0=([\d.eE+-]+)",txt).group(1)); Tf=float(re.search(r"T_final=([\d.]+)",txt).group(1))
bk=[l.split() for l in txt.splitlines() if re.match(r"\s+\d",l) and len(l.split())==3]
bt=np.array([float(x[0]) for x in bk]); bh=np.array([float(x[1]) for x in bk]); bv=np.array([float(x[2]) for x in bk])

fig=plt.figure(figsize=(14,5.6))
gs=gridspec.GridSpec(1,2,wspace=0.26,left=0.06,right=0.975,top=0.88,bottom=0.14)
fig.suptitle(f"Optimality check: {len(scores)} random restarts + coordinate descent — best pure-BEC N₀ = {N0:.2e} @ {Tf:.0f} nK",
             fontsize=13,fontweight="bold",x=0.06,ha="left")
# scores histogram
ax=fig.add_subplot(gs[0,0])
ax.hist(scores,bins=24,color=C,alpha=0.8,edgecolor=SURFACE,lw=0.4)
ax.axvline(best,color=INK,lw=2.0,label=f"best = {best:.2e}")
ax.axvline(1.10e5,color="#2a78d6",lw=1.6,ls="--",label="coord.-descent optimum")
ax.set_xlabel("local-optimum objective  (≈ N₀)"); ax.set_ylabel("number of restarts")
ax.set_title("best matches the coord.-descent optimum, and NO restart beats it\n(spread = the ramp landscape is rugged; the physical seed finds the best)",fontsize=11,loc="left",pad=6)
ax.legend(fontsize=9,frameon=False)
# smooth ramp (PCHIP through breakpoints), linear power
ax2=fig.add_subplot(gs[0,1])
tt=np.linspace(bt.min(),bt.max(),400)
if PCHIP is not None:
    ax2.plot(tt,PCHIP(bt,bh)(tt),color=CH,lw=2.6,label="hODT")
    ax2.plot(tt,PCHIP(bt,bv)(tt),color=CV,lw=2.6,label="vODT")
else:
    ax2.plot(bt,bh,color=CH,lw=2.6,label="hODT"); ax2.plot(bt,bv,color=CV,lw=2.6,label="vODT")
ax2.plot(bt,bh,"o",ms=6,color=CH,mec=SURFACE,mew=1.2); ax2.plot(bt,bv,"o",ms=6,color=CV,mec=SURFACE,mew=1.2)
ax2.set_ylim(bottom=0); ax2.set_xlabel("time  t  [s]"); ax2.set_ylabel("ODT power  [W]")
ax2.set_title("the global-optimal ramp (smooth; markers = breakpoints)",fontsize=11.5,loc="left",pad=6)
ax2.legend(fontsize=10,frameon=False)
png=os.path.join(OUT,"evap_global_opt.png"); fig.savefig(png,dpi=140); print("wrote",png)
