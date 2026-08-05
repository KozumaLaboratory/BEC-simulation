import sys, csv, os, re
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec

OUT = sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"
C_LAB="#2a78d6"; C_OPT="#eb6834"; C_MEAS="#718096"

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
    "font.family": "DejaVu Sans", "font.size": 11,
    "axes.edgecolor": GRID, "axes.linewidth": 1.0, "axes.labelcolor": INK2, "text.color": INK,
    "xtick.color": INK2, "ytick.color": INK2, "axes.titlecolor": INK,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "grid.alpha": 0.7,
    "axes.spines.top": False, "axes.spines.right": False,
})

def load(name):
    with open(os.path.join(OUT, name)) as f:
        r=csv.reader(f); hdr=next(r); cols={h:[] for h in hdr}
        for row in r:
            for h,v in zip(hdr,row): cols[h].append(float(v))
    return {h:np.array(v) for h,v in cols.items()}

bl, bo = load("bec_lab.csv"), load("bec_opt.csv")
rl, ro = load("ramp_lab.csv"), load("ramp_opt.csv")
S=open(os.path.join(OUT,"summary_final.txt")).read()
g=lambda p: re.search(p,S).group(1)
labN0=float(g(r"LAB: N0_final=([\d.eE+-]+)")); optN0=float(g(r"OPT: N0_final=([\d.eE+-]+)"))
labTf=float(g(r"LAB: .*T_final=([\d.]+)nK"));  optTf=float(g(r"OPT: .*T_final=([\d.]+)nK"))
optCf=float(g(r"OPT: .*cond_frac=([\d.]+)"))
factor=float(g(r"factor \(opt/lab\) = ([\d.]+)x"))
measN=float(g(r"measured N_BEC=([\d.eE+-]+)"))
# final temperatures / times
tf_lab, tf_opt = bl["t"][-1], bo["t"][-1]

fig=plt.figure(figsize=(14.5,8.4))
gs=gridspec.GridSpec(3,3,height_ratios=[0.42,1,1],width_ratios=[1.35,1,1],
                     hspace=0.42,wspace=0.32,left=0.065,right=0.975,top=0.99,bottom=0.075)

hero=fig.add_subplot(gs[0,:]); hero.axis("off")
hero.text(0.0,0.72,"¹⁵¹Eu evaporation ramp — optimized for final condensate",
          fontsize=19,fontweight="bold",color=INK,va="center")
hero.text(0.0,0.18,"Two-component (thermal + condensate) LRW model  ·  final temperature set by the full evaporation ramp",
          fontsize=11,color=INK2,va="center")
def stat(x,big,small,color):
    hero.text(x,0.72,big,fontsize=25,fontweight="bold",color=color,va="center",ha="left")
    hero.text(x,0.15,small,fontsize=10.5,color=INK2,va="center",ha="left")
stat(0.615,f"{factor:.1f}×",f"more condensate\natoms (N₀ {optN0/1e4:.1f}×10⁴)",C_OPT)
stat(0.775,f"{optTf:.0f} nK",f"final T\n(lab {labTf:.0f} nK)",C_OPT)
stat(0.905,f"{optCf*100:.0f}%",f"condensate\nfraction",INK)

# ===== HERO: condensate + thermal populations vs t =====
ax=fig.add_subplot(gs[1:,0])
ax.plot(bl["t"],np.maximum(bl["N0"],1),color=C_LAB,lw=2.4,solid_capstyle="round")
ax.plot(bl["t"],np.maximum(bl["Nth"],1),color=C_LAB,lw=1.5,ls=(0,(3,2)))
ax.plot(bo["t"],np.maximum(bo["N0"],1),color=C_OPT,lw=2.4,solid_capstyle="round")
ax.plot(bo["t"],np.maximum(bo["Nth"],1),color=C_OPT,lw=1.5,ls=(0,(3,2)))
ax.plot(tf_lab,labN0,"o",ms=10,color=C_LAB,mec=SURFACE,mew=1.8,zorder=5)
ax.plot(tf_opt,optN0,"o",ms=10,color=C_OPT,mec=SURFACE,mew=1.8,zorder=5)
ax.axhline(measN,color=C_MEAS,ls=(0,(1,2)),lw=1.3)
ax.text(ax.get_xlim()[1],measN,f" measured 5.0×10⁴",color=C_MEAS,fontsize=9,va="center",ha="right")
ax.set_yscale("log"); ax.set_xlabel("time  t  [s]"); ax.set_ylabel("atom number")
ax.set_title("Condensate grows while the thermal cloud crashes\n(solid = condensate N₀, dashed = thermal N_th)",
             fontsize=12.5,loc="left",pad=8)
ax.text(tf_opt,optN0*1.4,f"opt N₀\n{optN0/1e4:.1f}×10⁴",color=C_OPT,fontsize=10,ha="center",va="bottom",fontweight="bold")
ax.text(tf_lab,labN0*0.6,f"lab N₀\n{labN0:.0f}",color=C_LAB,fontsize=10,ha="center",va="top")

# ===== power schedule =====
ax2=fig.add_subplot(gs[1,1:])
ax2.plot(rl["t"],rl["HFORT"],color=C_LAB,lw=2.2,solid_capstyle="round")
ax2.plot(rl["t"],rl["VFORT"],color=C_LAB,lw=1.6,ls=(0,(3,2)))
ax2.plot(ro["t"],ro["HFORT"],color=C_OPT,lw=2.2,solid_capstyle="round")
ax2.plot(ro["t"],ro["VFORT"],color=C_OPT,lw=1.6,ls=(0,(3,2)))
ax2.set_yscale("log"); ax2.set_xlabel("time  t  [s]"); ax2.set_ylabel("FORT power  [W]")
ax2.set_title("optimized FORT power schedule",fontsize=12,loc="left",pad=6)
ax2.text(rl["t"][-1],rl["HFORT"][-1]," lab",color=C_LAB,fontsize=10,va="center",fontweight="bold")
ax2.text(ro["t"][-1],ro["HFORT"][-1]*0.7," opt",color=C_OPT,fontsize=10,va="center",fontweight="bold")
ax2.plot([],[],color=INK2,lw=2.2,label="HFORT (solid)")
ax2.plot([],[],color=INK2,lw=1.6,ls=(0,(3,2)),label="VFORT (dashed)")
ax2.legend(loc="upper right",frameon=False,fontsize=9)

# ===== temperature T(t) to final =====
ax3=fig.add_subplot(gs[2,1])
ax3.plot(bl["t"],bl["T"]*1e9,color=C_LAB,lw=2.2,solid_capstyle="round")
ax3.plot(bo["t"],bo["T"]*1e9,color=C_OPT,lw=2.2,solid_capstyle="round")
ax3.plot(tf_lab,labTf,"o",ms=9,color=C_LAB,mec=SURFACE,mew=1.6,zorder=5)
ax3.plot(tf_opt,optTf,"o",ms=9,color=C_OPT,mec=SURFACE,mew=1.6,zorder=5)
ax3.set_yscale("log"); ax3.set_xlabel("time  t  [s]"); ax3.set_ylabel("temperature  T  [nK]")
ax3.set_title("final temperature set by evaporation",fontsize=11.5,loc="left",pad=6)
ax3.text(tf_opt,optTf*0.55,f"opt {optTf:.0f} nK",color=C_OPT,fontsize=9.5,ha="center",va="top",fontweight="bold")
ax3.text(tf_lab,labTf*1.7,f"lab {labTf:.0f} nK",color=C_LAB,fontsize=9.5,ha="right",va="bottom")

# ===== final condensate bars =====
ax4=fig.add_subplot(gs[2,2])
bars=ax4.bar(["lab","opt","measured\n(2022)"],[labN0,optN0,measN],color=[C_LAB,C_OPT,C_MEAS])
ax4.set_yscale("log"); ax4.set_ylabel("final condensate  N₀"); ax4.set_title("final BEC atom number",fontsize=11.5,loc="left",pad=6)
for b,v in zip(bars,[labN0,optN0,measN]):
    ax4.text(b.get_x()+b.get_width()/2,v*1.15,f"{v:.2e}" if v>=1e4 else f"{v:.0f}",ha="center",fontsize=9)
ax4.grid(alpha=0.3,axis="y")

png=os.path.join(OUT,"evap_final_optimization.png")
fig.savefig(png,dpi=140); print("wrote",png)
