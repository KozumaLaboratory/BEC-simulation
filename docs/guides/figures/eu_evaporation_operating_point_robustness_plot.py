import sys, csv, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec
OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"; C="#eb6834"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":11,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,"axes.spines.top":False,"axes.spines.right":False})
rows=list(csv.DictReader(open(os.path.join(OUT,"sweep.csv"))))
def ax_data(a):
    s=sorted([r for r in rows if r["axis"]==a],key=lambda r:float(r["x"]))
    return (np.array([float(r["x"]) for r in s]),np.array([float(r["N0"]) for r in s]),
            np.array([float(r["T"]) for r in s]),np.array([float(r["cf"]) for r in s]))

fig=plt.figure(figsize=(14.5,5.4))
gs=gridspec.GridSpec(1,3,wspace=0.30,left=0.06,right=0.975,top=0.82,bottom=0.14)
fig.suptitle("How robust is the operating point? — N₀ vs each unknown (others nominal; T pinned at 50 nK)",
             fontsize=13.5,fontweight="bold",x=0.06,ha="left")
panels=[("heat","heating rate  [1/s]  (MEASURE)","log"),
        ("K3","three-body  K₃  [m⁶/s]","log"),
        ("tau","background  τ_bg  [s]","linear")]
for i,(a,xl,xs) in enumerate(panels):
    ax=fig.add_subplot(gs[0,i]); x,N,T,cfv=ax_data(a)
    Np=N/1e5
    ax.plot(x,Np,color=C,lw=2.8,solid_capstyle="round")
    ax.fill_between(x,Np,0,color=C,alpha=0.08,lw=0)
    ax.set_xscale(xs); ax.set_ylim(0,3.2)      # linear y
    ax.set_xlabel(xl); ax.set_ylabel("condensate  N₀  [×10⁵]" if i==0 else "")
    ax.set_title(f"N₀ varies {N.max()/N.min():.1f}×",fontsize=12,loc="left",pad=6)
    # mark nominal
    nomx={"heat":0.05,"K3":1e-42,"tau":15.0}[a]
    j=int(np.argmin(np.abs(x-nomx)))
    ax.plot(x[j],Np[j],"o",ms=9,color=INK,mec=SURFACE,mew=1.5,zorder=5)
    ax.annotate("nominal",(x[j],Np[j]),textcoords="offset points",xytext=(6,8),fontsize=9,color=INK)
png=os.path.join(OUT,"evap_operating_robustness.png"); fig.savefig(png,dpi=140); print("wrote",png)
