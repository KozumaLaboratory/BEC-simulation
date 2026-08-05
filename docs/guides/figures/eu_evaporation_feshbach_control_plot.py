import sys, csv, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import gridspec
OUT=sys.argv[1]
SURFACE="#fcfcfb"; INK="#0b0b0b"; INK2="#52514e"; GRID="#dedcd6"; C="#eb6834"
plt.rcParams.update({"figure.facecolor":SURFACE,"axes.facecolor":SURFACE,"savefig.facecolor":SURFACE,
    "font.family":"DejaVu Sans","font.size":12,"axes.edgecolor":GRID,"axes.linewidth":1.0,
    "axes.labelcolor":INK2,"text.color":INK,"xtick.color":INK2,"ytick.color":INK2,"axes.titlecolor":INK,
    "axes.grid":True,"grid.color":GRID,"grid.linewidth":0.8,"grid.alpha":0.7,"axes.spines.top":False,"axes.spines.right":False})
rows=list(csv.DictReader(open(os.path.join(OUT,"feshbach.csv"))))
A=sorted(set(float(r["alow"]) for r in rows)); Tsw=sorted(set(float(r["tsw"]) for r in rows))
Z=np.full((len(A),len(Tsw)),np.nan)
for r in rows:
    i=A.index(float(r["alow"])); j=Tsw.index(float(r["tsw"])); Z[i,j]=float(r["N0"])/1e5
base=[float(r["N0"]) for r in rows if abs(float(r["alow"])-135)<0.6][0]/1e5

fig=plt.figure(figsize=(13.5,5.8))
gs=gridspec.GridSpec(1,2,width_ratios=[1.25,1],wspace=0.28,left=0.07,right=0.97,top=0.86,bottom=0.13)
fig.suptitle("EXPLORATORY: Feshbach control of a_s during evaporation (K₃ ∝ a_s⁴) — reducing a_s near BEC cuts three-body loss",
             fontsize=12.5,fontweight="bold",x=0.07,ha="left")
# heatmap N0 over (t_switch, a_low)
ax=fig.add_subplot(gs[0,0])
im=ax.pcolormesh(np.array(Tsw),np.array(A),Z,shading="auto",cmap="magma")
ax.set_xlabel("switch time  t_switch  [s]"); ax.set_ylabel("final-stage scattering length  a_low  [a_B]")
cb=fig.colorbar(im,ax=ax); cb.set_label("condensate N₀  [×10⁵]")
imax=np.unravel_index(np.nanargmax(Z),Z.shape)
ax.plot(Tsw[imax[1]],A[imax[0]],"*",ms=20,color="#7CFC00",mec=INK,mew=0.8)
ax.set_title(f"best N₀ = {np.nanmax(Z):.1f}×10⁵ at a_low={A[imax[0]]:.0f} a_B",fontsize=11.5,loc="left",pad=6)
# N0 vs a_low at best t_switch
ax2=fig.add_subplot(gs[0,1])
jbest=imax[1]; col=Z[:,jbest]
ax2.plot(A,col,color=C,lw=2.8,marker="o",ms=5,mec=SURFACE,mew=1)
ax2.axhline(base,color=INK2,ls="--",lw=1.4)
ax2.annotate(f"baseline (a_s=135): {base:.1f}×10⁵",(A[len(A)//2],base),textcoords="offset points",xytext=(0,8),fontsize=10,color=INK2,ha="center")
ax2.set_xlabel("final-stage a_low  [a_B]  (← lower via Feshbach)"); ax2.set_ylabel("condensate N₀  [×10⁵]")
ax2.set_title("lower a_s late → up to ~2.8× more atoms (3-body ∝ a⁴)",fontsize=11.5,loc="left",pad=6)
ax2.invert_xaxis()
fig.text(0.07,0.005,"Caveat: a_s(B) for Eu is unmeasured — this is a parametric prediction assuming the 1.3 G Feshbach resonance can reach a_low without excess resonant loss.",fontsize=9,color=INK2)
png=os.path.join(OUT,"evap_feshbach_control.png"); fig.savefig(png,dpi=140); print("wrote",png)
