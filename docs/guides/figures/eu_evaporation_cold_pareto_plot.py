import sys, csv, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"; C="#eb6834"; C2="#2a78d6"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":12,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,"axes.spines.top":False,"axes.spines.right":False})
rows=list(csv.DictReader(open(os.path.join(OUT,"tradeoff.csv"))))
T=np.array([float(r["T"]) for r in rows]); N=np.array([float(r["N0"]) for r in rows]); cfv=np.array([float(r["cf"]) for r in rows])
m=(N>0)&(cfv>=0.80); T,N,cfv=T[m],N[m],cfv[m]   # pure-BEC region only
o=np.argsort(T); T,N,cfv=T[o],N[o],cfv[o]

fig,ax=plt.subplots(figsize=(9.6,6.4))
ax.fill_between(T,N/1e5,0,color=C,alpha=0.08,lw=0)
ax.plot(T,N/1e5,color=C,lw=3.0,solid_capstyle="round",zorder=3)
# thesis measured
ax.plot([56],[1.5e4/1e5],marker="*",ms=22,color=C2,mec=SURFACE,mew=1.5,zorder=5)
ax.annotate("thesis measured  1.5×10⁴ @ 56 nK",(56,1.5e4/1e5),textcoords="offset points",xytext=(10,16),fontsize=10.5,color=C2,fontweight="bold")
# annotate
ax.annotate("knee ≈ 70 nK: below it, cooling costs atoms fast",(78,1.28),
            fontsize=10.5,color=INK2,ha="center")
ax.set_xlim(left=0); ax.set_ylim(bottom=0)
ax.set_xlabel("final (pure-BEC) temperature  T  [nK]      (← colder      warmer →)")
ax.set_ylabel("condensate number  N₀  [×10⁵]")
ax.set_title("Colder BEC ⇄ fewer atoms — the tradeoff\n(K₃ = 10⁻⁴¹, heating rate 0.05/s; smooth monotone ramp, final trap depth swept)",fontsize=13,loc="left",pad=10)
png=os.path.join(OUT,"evap_cold_pareto.png"); fig.savefig(png,dpi=140,bbox_inches="tight"); print("wrote",png)
