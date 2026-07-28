import csv,os,numpy as np,matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt
H="runs/eu_barnett_rotfield_clean/rebuild"
runs=[("ellp1","$\\ell=+1$","#1f77b4"),("ellp0","$\\ell=0$","#555555"),("ellm1","$\\ell=-1$","#d62728")]
def load(p):
    if not os.path.exists(p): return None
    d={}
    r=list(csv.DictReader(open(p)))
    for k in r[0]: d[k]=np.array([float(x[k]) for x in r])
    return d
fig,ax=plt.subplots(1,3,figsize=(15,4.6))
for tag,lbl,c in runs:
    L=load(f"{H}/traj_m6_lossy_{tag}.csv"); U=load(f"{H}/traj_m6_{tag}.csv")
    if L is not None:
        ax[0].plot(L["t"],L["Ntot"]/L["Ntot"][0],color=c,lw=2,label=lbl)
        ax[1].plot(L["t"],L["N_m6"],color=c,lw=2,label=f"{lbl} lossy")
        ax[2].plot(L["t"],L["Fz"],color=c,lw=2,label=f"{lbl} lossy")
    if U is not None:
        ax[1].plot(U["t"],U["N_m6"],color=c,lw=1.3,ls=":",alpha=0.7,label=f"{lbl} unitary")
        ax[2].plot(U["t"],U["Fz"],color=c,lw=1.3,ls=":",alpha=0.7)
ax[0].set_title("atom survival $N(t)/N_0$ (K3+$\\gamma_{dr}$, ~80 ms)"); ax[0].set_ylabel("$N/N_0$"); ax[0].set_ylim(0,1.02); ax[0].legend(fontsize=9)
ax[1].set_title("$N_{-6}$ retention: lossy (solid) vs unitary (dotted)"); ax[1].set_ylabel("$N_{-6}/N$"); ax[1].legend(fontsize=7.5,ncol=2)
ax[2].set_title("$F_z$: lossy (solid) vs unitary (dotted)"); ax[2].set_ylabel("$F_z$"); ax[2].axhline(-6,color="k",lw=0.5,ls=":"); ax[2].legend(fontsize=8)
for a in ax: a.set_xlabel("t $[\\omega_{ref}^{-1}]$")
fig.suptitle("m=$-$6 floor test WITH experiment-consistent loss (K3=1.5e-40 m$^6$/s + $\\gamma_{dr}$=0.02) — $^{151}$Eu",fontsize=12)
fig.tight_layout(rect=(0,0,1,0.94))
fig.savefig("runs/eu_barnett_rotfield_clean/figures/fig_m6_lossy.png",dpi=140); print("wrote fig_m6_lossy.png")
for tag,lbl,_ in runs:
    L=load(f"{H}/traj_m6_lossy_{tag}.csv")
    if L is not None: print(f"  {lbl}: N/N0_end={L['Ntot'][-1]/L['Ntot'][0]:.2f}  N_m6_end={L['N_m6'][-3:].mean():.2f}  Fz_end={L['Fz'][-3:].mean():+.2f}")
