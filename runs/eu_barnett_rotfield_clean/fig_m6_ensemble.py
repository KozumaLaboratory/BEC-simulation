import glob,csv,numpy as np,matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt
H="runs/eu_barnett_rotfield_clean/rebuild/ens"
def seeds(ell): return sorted(int(f.split("_s")[1].split("_")[0]) for f in glob.glob(f"{H}/col_ell{ell}_s*_tot.csv"))
def col(ell,s,comp="tot"): return np.loadtxt(f"{H}/col_ell{ell}_s{s}_{comp}.csv",delimiter=",")
ext=[-10,10,-10,10]
# --- spatial: individual shots vs ensemble mean (total column density) ---
ells=[0,-1]
fig,ax=plt.subplots(len(ells),5,figsize=(15,6))
for i,ell in enumerate(ells):
    ss=seeds(ell)
    if not ss: continue
    stack=np.array([col(ell,s) for s in ss])
    mean=stack.mean(0)
    for j,s in enumerate(ss[:4]):
        d=col(ell,s); ax[i,j].imshow(d.T,origin="lower",extent=ext,cmap="magma",vmin=0,vmax=d.max())
        ax[i,j].set_title(f"$\\ell={ell}$ seed {s}",fontsize=9); ax[i,j].set_xticks([]);ax[i,j].set_yticks([])
    ax[i,4].imshow(mean.T,origin="lower",extent=ext,cmap="magma",vmin=0,vmax=mean.max())
    ax[i,4].set_title(f"$\\ell={ell}$ ENSEMBLE MEAN ({len(ss)})",fontsize=9,color="darkred"); ax[i,4].set_xticks([]);ax[i,4].set_yticks([])
fig.suptitle("Individual shots (seed-dependent, asymmetric) vs ensemble mean (symmetry recovered?) — total column density",fontsize=12)
fig.tight_layout(rect=(0,0,1,0.95)); fig.savefig("runs/eu_barnett_rotfield_clean/figures/fig_m6_ensemble.png",dpi=140)
print("wrote fig_m6_ensemble.png")
# --- N_m6(t) mean +/- std across seeds ---
def traj(ell,s):
    d={}; r=list(csv.DictReader(open(f"{H}/traj_ell{ell}_s{s}.csv")))
    for k in r[0]: d[k]=np.array([float(x[k]) for x in r])
    return d
fig2,axr=plt.subplots(1,2,figsize=(12,4.5))
for a,ell,cl in [(axr[0],0,"$\\ell=0$"),(axr[1],-1,"$\\ell=-1$")]:
    ss=seeds(ell)
    if not ss: continue
    T=[traj(ell,s) for s in ss]; t=T[0]["t"]
    nm6=np.array([x["N_m6"] for x in T]); m=nm6.mean(0); sd=nm6.std(0)
    for x in T: a.plot(t,x["N_m6"],color="grey",lw=0.5,alpha=0.5)
    a.plot(t,m,color="darkred",lw=2.2,label="mean"); a.fill_between(t,m-sd,m+sd,color="red",alpha=0.2,label="$\\pm$std")
    a.set_title(f"{cl}: $N_{{-6}}(t)$ over {len(ss)} seeds"); a.set_xlabel("t"); a.set_ylabel("$N_{-6}/N$"); a.legend()
fig2.suptitle("Chirality signal $N_{-6}$ robustness across noise seeds (thin=shots, band=$\\pm$std)",fontsize=12)
fig2.tight_layout(rect=(0,0,1,0.94)); fig2.savefig("runs/eu_barnett_rotfield_clean/figures/fig_m6_ens_Nm.png",dpi=140)
print("wrote fig_m6_ens_Nm.png")
for ell in ells:
    ss=seeds(ell)
    if ss:
        vals=[traj(ell,s)["N_m6"][-3:].mean() for s in ss]
        print(f"  ell={ell}: N_m6_end mean={np.mean(vals):.3f} std={np.std(vals):.3f} ({len(ss)} seeds)")
