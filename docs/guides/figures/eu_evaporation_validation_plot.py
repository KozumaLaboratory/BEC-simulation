import sys, csv, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"; C42="#eb6834"; C41="#2a78d6"; CM="#111111"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":12,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,"axes.spines.top":False,"axes.spines.right":False})
rows=list(csv.DictReader(open(os.path.join(OUT,"validation.csv"))))
def curve(K3):
    s=[r for r in rows if abs(float(r["K3"])-K3)<0.3*K3]
    s=sorted(s,key=lambda r:float(r["T"]))
    return np.array([float(r["T"]) for r in s]),np.array([float(r["N_total"]) for r in s])

fig,ax=plt.subplots(figsize=(9.2,6.4))
T42,N42=curve(1e-42); T41,N41=curve(1e-41)
# K3 uncertainty band (between 1e-42 and 1e-41) on a common T grid
Tg=np.linspace(50,1200,200)
ax.fill_between(Tg,np.interp(Tg,T42,N42),np.interp(Tg,T41,N41),color="#f0a077",alpha=0.30,lw=0,label="model band, K₃ ∈ [10⁻⁴¹, 10⁻⁴²]")
ax.plot(T42,N42,color=C42,lw=2.4,label="K₃ = 10⁻⁴²")
ax.plot(T41,N41,color=C41,lw=2.4,label="K₃ = 10⁻⁴¹")
# measured thesis points (Fig 7.2)
mx=[470,270]; my=[2.2e4,1.1e4]
ax.plot(mx,my,"*",ms=24,color=CM,mec=SURFACE,mew=1.4,zorder=6,label="thesis measured (Fig 7.2)")
for x,y,t in [(470,2.2e4,"2.2×10⁴ @ 470 nK"),(270,1.1e4,"1.1×10⁴ @ 270 nK")]:
    ax.annotate(t,(x,y),textcoords="offset points",xytext=(14,-4),fontsize=10,color=CM,fontweight="bold")
ax.set_yscale("log"); ax.set_xlim(0,1200); ax.set_ylim(6e3,5e5)
ax.set_xlabel("temperature  T  [nK]"); ax.set_ylabel("total atom number  N")
ax.set_title("Validation (type C): the model reproduces the thesis BEC-transition data\nthesis ramp stopped at different points — the measured points fall in the K₃ band",fontsize=12.5,loc="left",pad=10)
ax.legend(fontsize=9.5,frameon=False,loc="lower right")
png=os.path.join(OUT,"evap_validation.png"); fig.savefig(png,dpi=140,bbox_inches="tight"); print("wrote",png)
