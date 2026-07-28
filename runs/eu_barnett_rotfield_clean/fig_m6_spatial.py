import numpy as np, matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt
H="runs/eu_barnett_rotfield_clean/rebuild"
rows=[("ellp1","$\\ell=+1$"),("ellp0","$\\ell=0$"),("ellm1","$\\ell=-1$")]
ms=[-6,-5,-4,-3,-2,-1,0]
cols=[("tot","total")]+[ (f"m{m}", f"$m={m}$") for m in ms]
fig,ax=plt.subplots(3,len(cols),figsize=(2.0*len(cols),6.4))
ext=[-10,10,-10,10]
for i,(tag,rl) in enumerate(rows):
    tot=np.loadtxt(f"{H}/m6col_{tag}_tot.csv",delimiter=",")
    tsum=tot.sum()
    for j,(comp,cl) in enumerate(cols):
        d=np.loadtxt(f"{H}/m6col_{tag}_{comp}.csv",delimiter=",")
        vmax=d.max() if d.max()>0 else 1.0        # per-panel norm -> structure visible
        ax[i,j].imshow(d.T,origin="lower",extent=ext,cmap="magma",vmin=0,vmax=vmax)
        frac=d.sum()/tsum
        ttl = f"{rl} {cl}" if comp=="tot" else f"{cl} ({frac*100:.0f}%)"
        ax[i,j].set_title(ttl,fontsize=8.5)
        ax[i,j].set_xticks([]); ax[i,j].set_yticks([])
    ax[i,0].set_ylabel(rl,fontsize=11)
fig.suptitle("Spatial distribution at end of quench (t=50), per-$m$ column density (each panel self-normalised) — m=$-$6 axial + $\\pm$vortex",fontsize=11)
fig.tight_layout(rect=(0,0,1,0.95))
fig.savefig("runs/eu_barnett_rotfield_clean/figures/fig_m6_spatial.png",dpi=135)
print("wrote fig_m6_spatial.png")

# population ladder bar
fig2,axb=plt.subplots(figsize=(8,4))
allm=list(range(6,-7,-1))
import csv
# recompute N_m from printed fractions is unavailable; read from the col csvs we have (m=-6..0) + note others small
w=0.26
colors={"ellp1":"#1f77b4","ellp0":"#555555","ellm1":"#d62728"}
labels={"ellp1":"$\\ell=+1$","ellp0":"$\\ell=0$","ellm1":"$\\ell=-1$"}
# fractions hard-coded from compute output (m=-6..+6)
frac={"ellp1":{-6:5.3,-5:10.9,-4:16.1,-3:18.0,-2:16.0,-1:13.1,0:9.0,1:4.1,2:2.1,3:2.0,4:1.5,5:1.0,6:0.9},
      "ellp0":{-6:13.4,-5:11.4,-4:20.2,-3:12.4,-2:16.9,-1:10.7,0:9.7,1:1.7,2:0.7,3:0.4,4:0.7,5:0.6,6:1.1},
      "ellm1":{-6:30.2,-5:6.3,-4:7.8,-3:7.8,-2:13.8,-1:12.3,0:12.2,1:2.9,2:2.9,3:0.8,4:1.4,5:0.8,6:0.7}}
x=np.arange(len(allm))
for k,tag in enumerate(["ellp1","ellp0","ellm1"]):
    vals=[frac[tag].get(m,0) for m in allm]
    axb.bar(x+(k-1)*w,vals,w,color=colors[tag],label=labels[tag])
axb.set_xticks(x); axb.set_xticklabels([str(m) for m in allm])
axb.set_xlabel("$m$"); axb.set_ylabel("$N_m/N$ [%]")
axb.set_title("Full $m$-ladder population at t=50 (Stern–Gerlach) — cascade reaches $m\\sim0$")
axb.legend(); axb.axvline(x[allm.index(-6)]-0.5,color="k",lw=0.5,ls=":")
fig2.tight_layout(); fig2.savefig("runs/eu_barnett_rotfield_clean/figures/fig_m6_ladder.png",dpi=135)
print("wrote fig_m6_ladder.png")
