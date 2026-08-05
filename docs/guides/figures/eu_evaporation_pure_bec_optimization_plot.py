import sys, csv, os, re
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec

OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"
C_LAB="#2a78d6"; C_OPT="#eb6834"; C_MEAS="#718096"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":11,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,
    "axes.spines.top":False,"axes.spines.right":False})
def load(n):
    with open(os.path.join(OUT,n)) as f:
        r=csv.reader(f); h=next(r); c={k:[] for k in h}
        for row in r:
            for k,v in zip(h,row): c[k].append(float(v))
    return {k:np.array(v) for k,v in c.items()}
bl,bo=load("bec_lab.csv"),load("bec_opt.csv")
rl,ro=load("ramp_lab.csv"),load("ramp_opt.csv")
S=open(os.path.join(OUT,"summary_pure.txt")).read()
g=lambda p:re.search(p,S).group(1)
labN=float(g(r"LAB thesis ramp: N0=([\d.eE+-]+)")); optN=float(g(r"OPT ramp\s*: N0=([\d.eE+-]+)"))
labT=float(g(r"LAB thesis ramp:.*T=([\d.]+)nK"));   optT=float(g(r"OPT ramp\s*:.*T=([\d.]+)nK"))
labCF=float(g(r"LAB thesis ramp:.*cond_frac=([\d.]+)")); optCF=float(g(r"OPT ramp\s*:.*cond_frac=([\d.]+)"))
factor=g(r"factor\(opt/lab N0\)=([\d.]+)x")
measN=1.5e4
tfl,tfo=bl["t"][-1],bo["t"][-1]

fig=plt.figure(figsize=(14.5,8.4))
gs=gridspec.GridSpec(3,3,height_ratios=[0.42,1,1],width_ratios=[1.35,1,1],
    hspace=0.42,wspace=0.32,left=0.065,right=0.975,top=0.99,bottom=0.075)
hero=fig.add_subplot(gs[0,:]); hero.axis("off")
hero.text(0.0,0.72,"¹⁵¹Eu evaporation — optimized for a pure BEC",fontsize=19,fontweight="bold",color=INK,va="center")
hero.text(0.0,0.18,"Thesis-calibrated two-component model  ·  max N₀ s.t. condensate fraction ≥ 0.95  ·  K₃=10⁻⁴²",fontsize=11,color=INK2,va="center")
def stat(x,big,small,col):
    hero.text(x,0.72,big,fontsize=25,fontweight="bold",color=col,va="center",ha="left")
    hero.text(x,0.15,small,fontsize=10.5,color=INK2,va="center",ha="left")
stat(0.60,f"{factor}×",f"more condensate\n(N₀ {optN/1e4:.1f}×10⁴)",C_OPT)
stat(0.76,f"{optT:.0f} nK",f"pure-BEC T\n(lab {labT:.0f} nK)",C_OPT)
stat(0.90,f"{optCF*100:.0f}%",f"condensate\nfraction (pure)",INK)

ax=fig.add_subplot(gs[1:,0])
for d,c in ((bl,C_LAB),(bo,C_OPT)):
    ax.plot(d["t"],np.maximum(d["N0"],1),color=c,lw=2.4,solid_capstyle="round")
    ax.plot(d["t"],np.maximum(d["Nth"],1),color=c,lw=1.5,ls=(0,(3,2)))
ax.plot(tfl,labN,"o",ms=10,color=C_LAB,mec=SURFACE,mew=1.8,zorder=5)
ax.plot(tfo,optN,"o",ms=10,color=C_OPT,mec=SURFACE,mew=1.8,zorder=5)
ax.axhline(measN,color=C_MEAS,ls=(0,(1,2)),lw=1.3)
ax.text(ax.get_xlim()[1],measN," thesis 1.5×10⁴",color=C_MEAS,fontsize=9,va="center",ha="right")
ax.set_yscale("log"); ax.set_xlabel("time  t  [s]"); ax.set_ylabel("atom number")
ax.set_title("Condensate N₀ (solid) vs thermal N_th (dashed)\nboth ramps reach a (nearly) pure BEC",fontsize=12.5,loc="left",pad=8)
ax.text(tfo,optN*1.4,f"opt N₀\n{optN/1e4:.1f}×10⁴",color=C_OPT,fontsize=10,ha="center",va="bottom",fontweight="bold")
ax.text(tfl,labN*0.6,f"lab N₀\n{labN/1e4:.2f}×10⁴",color=C_LAB,fontsize=10,ha="center",va="top")

ax2=fig.add_subplot(gs[1,1:])
ax2.plot(rl["t"],rl["HFORT"],color=C_LAB,lw=2.2,solid_capstyle="round")
ax2.plot(rl["t"],rl["VFORT"],color=C_LAB,lw=1.6,ls=(0,(3,2)))
ax2.plot(ro["t"],ro["HFORT"],color=C_OPT,lw=2.2,solid_capstyle="round")
ax2.plot(ro["t"],ro["VFORT"],color=C_OPT,lw=1.6,ls=(0,(3,2)))
ax2.set_yscale("log"); ax2.set_xlabel("time  t  [s]"); ax2.set_ylabel("ODT power  [W]")
ax2.set_title("ODT power schedule (hODT solid, vODT dashed)",fontsize=12,loc="left",pad=6)
ax2.text(rl["t"][-1],rl["HFORT"][-1]," lab",color=C_LAB,fontsize=10,va="center",fontweight="bold")
ax2.text(ro["t"][-1],ro["HFORT"][-1]," opt",color=C_OPT,fontsize=10,va="center",fontweight="bold")

ax3=fig.add_subplot(gs[2,1])
ax3.plot(bl["t"],bl["T"]*1e9,color=C_LAB,lw=2.2,solid_capstyle="round")
ax3.plot(bo["t"],bo["T"]*1e9,color=C_OPT,lw=2.2,solid_capstyle="round")
ax3.plot(tfl,labT,"o",ms=9,color=C_LAB,mec=SURFACE,mew=1.6,zorder=5)
ax3.plot(tfo,optT,"o",ms=9,color=C_OPT,mec=SURFACE,mew=1.6,zorder=5)
ax3.set_yscale("log"); ax3.set_xlabel("time  t  [s]"); ax3.set_ylabel("temperature  T  [nK]")
ax3.set_title("temperature → pure-BEC point",fontsize=11.5,loc="left",pad=6)
ax3.text(tfo,optT*1.6,f"opt {optT:.0f} nK",color=C_OPT,fontsize=9.5,ha="right",va="bottom",fontweight="bold")
ax3.text(tfl,labT*0.6,f"lab {labT:.0f} nK",color=C_LAB,fontsize=9.5,ha="right",va="top")

ax4=fig.add_subplot(gs[2,2])
bars=ax4.bar(["lab\nramp","opt\nramp","thesis\nmeasured"],[labN,optN,measN],color=[C_LAB,C_OPT,C_MEAS])
ax4.set_yscale("log"); ax4.set_ylabel("pure-BEC  N₀"); ax4.set_title("pure BEC atom number",fontsize=11.5,loc="left",pad=6)
for b,v in zip(bars,[labN,optN,measN]): ax4.text(b.get_x()+b.get_width()/2,v*1.15,f"{v:.2e}",ha="center",fontsize=9)
ax4.grid(alpha=0.3,axis="y")
png=os.path.join(OUT,"evap_pure_bec_optimization.png"); fig.savefig(png,dpi=140); print("wrote",png)
