import numpy as np, matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt
H="runs/eu_barnett_rotfield_clean/rebuild"
rows=[("ellp1","$\\ell=+1$"),("ellp0","$\\ell=0$"),("ellm1","$\\ell=-1$")]
ms=[-6,-5,-4,-3,-2,-1,0]; cols=[("tot","total")]+[(f"m{m}",f"$m={m}$") for m in ms]
fig,ax=plt.subplots(3,len(cols),figsize=(2.0*len(cols),6.4))
ext=[-10,10,-10,10]
for i,(tag,rl) in enumerate(rows):
    tot=np.loadtxt(f"{H}/m6col_lossy_{tag}_tot.csv",delimiter=","); tsum=tot.sum()
    for j,(comp,cl) in enumerate(cols):
        d=np.loadtxt(f"{H}/m6col_lossy_{tag}_{comp}.csv",delimiter=",")
        vmax=d.max() if d.max()>0 else 1.0
        ax[i,j].imshow(d.T,origin="lower",extent=ext,cmap="magma",vmin=0,vmax=vmax)
        frac=d.sum()/tsum
        ax[i,j].set_title((f"{rl} {cl}" if comp=="tot" else f"{cl} ({frac*100:.0f}%)"),fontsize=8.5)
        ax[i,j].set_xticks([]); ax[i,j].set_yticks([])
fig.suptitle("Spatial distribution at end of quench (t=50, ~80 ms) WITH LOSS (K3+$\\gamma_{dr}$, ~37% atoms lost) — per-$m$ column density, self-normalised",fontsize=10.5)
fig.tight_layout(rect=(0,0,1,0.95))
fig.savefig("runs/eu_barnett_rotfield_clean/figures/fig_m6_spatial_lossy.png",dpi=135)
print("wrote fig_m6_spatial_lossy.png")
