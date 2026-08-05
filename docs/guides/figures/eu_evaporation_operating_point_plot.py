import sys, csv, os, re
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec
OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"; C_H="#eb6834"; C_V="#2a78d6"; C_N="#1baf7a"
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
be=cols(os.path.join(OUT,"bec_opt.csv")); rm=cols(os.path.join(OUT,"ramp_opt.csv"))
S=open(os.path.join(OUT,"operating_point.txt")).read(); g=lambda p:re.search(p,S).group(1)
N0=float(g(r"N0=([\d.eE+-]+)")); T=float(g(r"T_final=([\d.]+)")); cfv=float(g(r"cond_frac=([\d.]+)")); dur=float(g(r"duration=([\d.]+)"))
# breakpoint schedule from operating_point.txt
bk=[l.split() for l in S.splitlines() if re.match(r"\s+\d\.\d{3}\s",l)]
bt=[float(x[0]) for x in bk]; bh=[float(x[1]) for x in bk]; bv=[float(x[2]) for x in bk]

fig=plt.figure(figsize=(14,5.6))
gs=gridspec.GridSpec(1,2,width_ratios=[1.05,1],wspace=0.26,left=0.06,right=0.975,top=0.88,bottom=0.13)
fig.suptitle(f"Confirmed balanced operating point:  N₀ = {N0:.2e}   T = {T:.0f} nK   "
             f"(cond. frac {cfv:.2f}, {dur:.1f} s)   —  keeps atoms while cold",
             fontsize=14,fontweight="bold",x=0.06,ha="left")

ax=fig.add_subplot(gs[0,0])
ax.plot(rm["t"],rm["HFORT"],color=C_H,lw=2.4,solid_capstyle="round",label="HFORT")
ax.plot(rm["t"],rm["VFORT"],color=C_V,lw=2.4,solid_capstyle="round",label="VFORT")
ax.plot(bt,bh,"o",ms=8,color=C_H,mec=SURFACE,mew=1.5,zorder=5)
ax.plot(bt,bv,"o",ms=8,color=C_V,mec=SURFACE,mew=1.5,zorder=5)
ax.set_yscale("log"); ax.set_xlabel("time  t  [s]"); ax.set_ylabel("ODT power  [W]")
ax.set_title("ramp schedule (markers = breakpoints the lab sets)",fontsize=12,loc="left",pad=6)
ax.legend(fontsize=10,frameon=False)

ax2=fig.add_subplot(gs[0,1])
ax2.plot(be["t"],np.maximum(be["N0"],1),color=C_N,lw=2.4,solid_capstyle="round",label="condensate N₀")
ax2.plot(be["t"],np.maximum(be["Nth"],1),color=C_N,lw=1.5,ls=(0,(3,2)),label="thermal N_th")
ax2.plot(be["t"],be["N"],color=INK2,lw=1.2,alpha=0.6,label="total N")
ax2.set_yscale("log"); ax2.set_xlabel("time  t  [s]"); ax2.set_ylabel("atom number")
ax2b=ax2.twinx(); ax2b.plot(be["t"],be["T"]*1e9,color="#c0392b",lw=2.0)
ax2b.set_yscale("log"); ax2b.set_ylabel("T [nK]",color="#c0392b"); ax2b.tick_params(axis="y",colors="#c0392b"); ax2b.grid(False); ax2b.spines["top"].set_visible(False)
ax2.set_title("trajectory to the operating point (T on right axis)",fontsize=12,loc="left",pad=6)
ax2.legend(fontsize=9,frameon=False,loc="lower left")
png=os.path.join(OUT,"evap_operating_point.png"); fig.savefig(png,dpi=140); print("wrote",png)
