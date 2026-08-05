import sys, csv, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec
OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"; C="#eb6834"; C2="#2a78d6"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":12,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,"axes.spines.top":False,"axes.spines.right":False})
rows=list(csv.DictReader(open(os.path.join(OUT,"mc.csv"))))
N=np.array([float(r["N0"]) for r in rows]); T=np.array([float(r["T"]) for r in rows])
def band(x): return np.median(x),np.percentile(x,16),np.percentile(x,84),np.percentile(x,2.5),np.percentile(x,97.5)
nm,n16,n84,n025,n975=band(N); tm,t16,t84,t025,t975=band(T)

fig=plt.figure(figsize=(13.5,5.6))
gs=gridspec.GridSpec(1,2,wspace=0.25,left=0.07,right=0.975,top=0.86,bottom=0.14)
fig.suptitle(f"Uncertainty propagation ({len(rows)} Monte-Carlo samples over K₃, heating, τ_bg, a_s, waists, α, N₀, T₀)",
             fontsize=13,fontweight="bold",x=0.07,ha="left")
# N0 (atom number → log bins)
ax=fig.add_subplot(gs[0,0])
bins=np.logspace(np.log10(max(N.min(),1e3)),np.log10(N.max()),50)
ax.hist(N,bins=bins,color=C,alpha=0.75,edgecolor=SURFACE,lw=0.4)
for v,ls,lab in [(nm,"-","median"),(n16,"--",None),(n84,"--",None),(n025,":",None),(n975,":",None)]:
    ax.axvline(v,color=INK,lw=1.6 if ls=="-" else 1.0,ls=ls)
ax.set_xscale("log"); ax.set_xlabel("pure-BEC condensate number  N₀"); ax.set_ylabel("samples")
ax.set_title(f"N₀ = {nm:.1e}  (68%: {n16:.1e}–{n84:.1e};  95%: {n025:.1e}–{n975:.1e})",fontsize=11,loc="left",pad=6)
# T (linear)
ax2=fig.add_subplot(gs[0,1])
ax2.hist(T,bins=40,color=C2,alpha=0.75,edgecolor=SURFACE,lw=0.4)
for v,ls in [(tm,"-"),(t16,"--"),(t84,"--"),(t025,":"),(t975,":")]:
    ax2.axvline(v,color=INK,lw=1.6 if ls=="-" else 1.0,ls=ls)
ax2.set_xlabel("final temperature  T  [nK]"); ax2.set_ylabel("samples")
ax2.set_title(f"T = {tm:.0f} nK  (68%: {t16:.0f}–{t84:.0f};  95%: {t025:.0f}–{t975:.0f})",fontsize=11,loc="left",pad=6)
png=os.path.join(OUT,"evap_uncertainty.png"); fig.savefig(png,dpi=140); print("wrote",png)
