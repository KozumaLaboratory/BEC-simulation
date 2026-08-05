import sys, csv, os, re
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec

OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"
C_LAB="#2a78d6"; C_ROB="#eb6834"; C_NOM="#718096"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":11,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,
    "axes.spines.top":False,"axes.spines.right":False})

# --- load robustness grid ---
rows=list(csv.DictReader(open(os.path.join(OUT,"robustness_grid.csv"))))
def series(ramp):
    d={}
    for r in rows:
        if r["ramp"]!=ramp: continue
        K=float(r["K3"]); d.setdefault(K,{"N0":[],"T":[]})
        d[K]["N0"].append(float(r["N0"])); d[K]["T"].append(float(r["T"]))
    Ks=sorted(d)
    N0med=[np.median(d[K]["N0"]) for K in Ks]
    N0lo=[min(d[K]["N0"]) for K in Ks]; N0hi=[max(d[K]["N0"]) for K in Ks]
    Tmed=[np.median(d[K]["T"]) for K in Ks]
    return np.array(Ks),np.array(N0med),np.array(N0lo),np.array(N0hi),np.array(Tmed)

S=open(os.path.join(OUT,"robust_summary.txt")).read()
g=lambda p:re.search(p,S).group(1)
wc_lab=float(g(r"lab thesis ramp\s*: ([\d.eE+-]+)"))
wc_nom=float(g(r"NOMINAL-opt ramp\s*: ([\d.eE+-]+)"))
wc_rob=float(g(r"ROBUST-opt ramp\s*: ([\d.eE+-]+)"))
rl=load=lambda n:{h:np.array(v) for h,v in _cols(os.path.join(OUT,n)).items()}
def _cols(p):
    with open(p) as f:
        r=csv.reader(f); h=next(r); c={k:[] for k in h}
        for row in r:
            for k,v in zip(h,row): c[k].append(float(v))
    return c
rlab=rl("ramp_lab.csv"); rrob=rl("ramp_opt.csv")

fig=plt.figure(figsize=(14.5,8.0))
gs=gridspec.GridSpec(2,3,height_ratios=[0.32,1],width_ratios=[1.4,1,1],
    hspace=0.33,wspace=0.34,left=0.07,right=0.975,top=0.99,bottom=0.09)
hero=fig.add_subplot(gs[0,:]); hero.axis("off")
hero.text(0.0,0.7,"How robust is the optimized ramp?",fontsize=19,fontweight="bold",color=INK,va="center")
hero.text(0.0,0.12,"Worst-case pure-BEC N₀ over the unknown-parameter set  K₃∈[10⁻⁴²,10⁻⁴⁰] × τ_bg∈[10,30]s",fontsize=11,color=INK2,va="center")
def stat(x,big,small,col):
    hero.text(x,0.72,big,fontsize=23,fontweight="bold",color=col,va="center",ha="left")
    hero.text(x,0.06,small,fontsize=10,color=INK2,va="center",ha="left")
stat(0.60,f"{wc_rob/wc_lab:.1f}×",f"robust worst-case\nvs lab",C_ROB)
stat(0.78,f"{wc_rob/wc_nom:.1f}×",f"robust vs nominal\n(worst-case)",C_ROB)

# ---- MAIN: N0 vs K3, band over tau, 3 ramps ----
ax=fig.add_subplot(gs[1,0])
for ramp,c,lab in (("lab",C_LAB,"lab (thesis)"),("nominal",C_NOM,"nominal-opt (K₃=10⁻⁴² only)"),("robust",C_ROB,"robust-opt")):
    Ks,med,lo,hi,_=series(ramp)
    ax.fill_between(Ks,lo,hi,color=c,alpha=0.15,lw=0)
    ax.plot(Ks,med,color=c,lw=2.4,solid_capstyle="round",label=lab,marker="o",ms=5,mec=SURFACE,mew=1)
ax.set_xscale("log"); ax.set_yscale("log")
ax.set_xlabel("three-body coefficient  K₃  [m⁶/s]  (unknown)")
ax.set_ylabel("pure-BEC condensate number  N₀")
ax.set_title("N₀ across the K₃ uncertainty (band = τ_bg spread)\nrobust ramp stays highest everywhere",fontsize=12,loc="left",pad=8)
ax.legend(fontsize=9,frameon=False,loc="lower left")

# ---- worst-case bars ----
ax2=fig.add_subplot(gs[1,1])
bars=ax2.bar(["lab","nominal\nopt","robust\nopt"],[wc_lab,wc_nom,wc_rob],color=[C_LAB,C_NOM,C_ROB])
ax2.set_yscale("log"); ax2.set_ylabel("worst-case pure-BEC N₀")
ax2.set_title("worst-case over the whole set",fontsize=11.5,loc="left",pad=6)
for b,v in zip(bars,[wc_lab,wc_nom,wc_rob]): ax2.text(b.get_x()+b.get_width()/2,v*1.2,f"{v:.1e}",ha="center",fontsize=9)
ax2.grid(alpha=0.3,axis="y")

# ---- the ramps ----
ax3=fig.add_subplot(gs[1,2])
ax3.plot(rlab["t"],rlab["HFORT"],color=C_LAB,lw=2.0,solid_capstyle="round")
ax3.plot(rlab["t"],rlab["VFORT"],color=C_LAB,lw=1.4,ls=(0,(3,2)))
ax3.plot(rrob["t"],rrob["HFORT"],color=C_ROB,lw=2.0,solid_capstyle="round")
ax3.plot(rrob["t"],rrob["VFORT"],color=C_ROB,lw=1.4,ls=(0,(3,2)))
ax3.set_yscale("log"); ax3.set_xlabel("time  t  [s]"); ax3.set_ylabel("ODT power  [W]")
ax3.set_title("robust ramp (orange) vs lab (blue)\nhODT solid, vODT dashed",fontsize=11.5,loc="left",pad=6)
ax3.text(rlab["t"][-1],rlab["HFORT"][-1]," lab",color=C_LAB,fontsize=9,va="center",fontweight="bold")
ax3.text(rrob["t"][-1],rrob["HFORT"][-1]," robust",color=C_ROB,fontsize=9,va="center",fontweight="bold")

png=os.path.join(OUT,"evap_robustness.png"); fig.savefig(png,dpi=140); print("wrote",png)
