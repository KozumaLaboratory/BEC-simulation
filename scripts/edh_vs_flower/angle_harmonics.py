#!/usr/bin/env python3
"""WHY 13 angles: P_m(beta) for a tilt about one axis is a trig polynomial of
degree 2F=12, i.e. it carries angular harmonics k=0..2F = 13 of them (= multipole
ranks). Nyquist => >=13 equispaced angles over [0,180) to resolve them.
Left: harmonic spectrum |c_k| of P_{-6}(beta) for the real EdH local state vs a
random full-rank state (EdH decays fast -> few angles suffice; random fills all
13 -> need 13). Right: rank of the LINEAR tomography map vs #angles -> jumps to
full at 13. env: PSI13, OUT, FRAME"""
import os, numpy as np, h5py
from scipy.linalg import expm
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); OUT=os.environ.get("OUT","angle_harmonics.png"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fy=(Fp-Fp.T)/(2j)
P=h5py.File(PSI,"r")
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1)
score=np.abs(psi[...,11])*np.abs(psi[...,12]); ix=np.unravel_index(np.argmax(score),score.shape)
z_edh=psi[ix].copy(); z_edh/=np.linalg.norm(z_edh); rho_edh=np.outer(z_edh,z_edh.conj())
rng=np.random.default_rng(3); A=rng.standard_normal((D,D))+1j*rng.standard_normal((D,D)); rho_rnd=A@A.conj().T; rho_rnd/=np.trace(rho_rnd).real
# --- harmonic spectrum of P_{-6}(beta) over full circle ---
bb=np.linspace(0,2*np.pi,720,endpoint=False)
def Pm_beta(rho,mi):
    out=np.zeros(len(bb))
    for j,b in enumerate(bb):
        R=expm(-1j*b*Fy); out[j]=np.real((R@rho@R.conj().T)[mi,mi])
    return out
i6=list(ms).index(-6)
ck_edh=np.abs(np.fft.rfft(Pm_beta(rho_edh,i6)))/len(bb)
ck_rnd=np.abs(np.fft.rfft(Pm_beta(rho_rnd,i6)))/len(bb)
# --- linear tomography map rank vs #angles (both axes) ---
Fx=0.5*(Fp+Fp.T)
def herm_basis():
    ps=[("d",a,a) for a in range(D)]+[(t,a,c) for a in range(D) for c in range(a+1,D) for t in ("re","im")]
    return ps
ps=herm_basis()
def rho_of(r):
    M=np.zeros((D,D),complex)
    for v,(t,a,c) in zip(r,ps):
        if t=="d": M[a,a]=v
        elif t=="re": M[a,c]+=v; M[c,a]+=v
        else: M[a,c]+=1j*v; M[c,a]-=1j*v
    return M
def rank_for(N,axes):
    angs=np.linspace(0,180,N,endpoint=False); sett=[(ax,b) for ax in axes for b in angs]
    Rs=[expm(-1j*np.radians(b)*(Fy if ax=="y" else Fx)) for ax,b in sett]
    Mm=np.zeros((len(Rs)*D,len(ps)))
    for j in range(len(ps)):
        e=np.zeros(len(ps)); e[j]=1
        Mm[:,j]=np.array([np.real(np.diag(R@rho_of(e)@R.conj().T)) for R in Rs]).reshape(-1)
    return np.linalg.matrix_rank(Mm,tol=1e-9)
Ns=list(range(1,16))
rank_y=[rank_for(N,["y"]) for N in Ns]
rank_yx=[rank_for(N,["y","x"]) for N in Ns]
print("N, rank(y only), rank(y+x):  full=169")
for N,a,b in zip(Ns,rank_y,rank_yx): print(f"  N={N:2d}  y:{a:3d}  y+x:{b:3d}")
fig,ax=plt.subplots(1,2,figsize=(13,5),constrained_layout=True)
k=np.arange(len(ck_edh))
ax[0].semilogy(k[:16],np.maximum(ck_edh[:16],1e-12),"o-",c="C0",label="EdH local state (real data)")
ax[0].semilogy(k[:16],np.maximum(ck_rnd[:16],1e-12),"s-",c="C3",label="random full-rank state")
ax[0].axvline(2*F,ls="--",c="gray"); ax[0].text(2*F-0.2,ck_rnd.max(),f"k=2F={2*F}",ha="right",fontsize=9,color="gray")
ax[0].set_xlabel("angular harmonic k of $P_{-6}(\\beta)$"); ax[0].set_ylabel("|harmonic amplitude|")
ax[0].set_title("Harmonics in $P_m(\\beta)$: degree 2F=12 → 13 ranks k=0..12.\nEdH amplitudes small but nonzero to k=12; both vanish beyond 2F=12.")
ax[0].legend(); ax[0].grid(alpha=.3)
ax[1].plot(Ns,rank_y,"o-",c="C1",label="1 axis (y only)")
ax[1].plot(Ns,rank_yx,"s-",c="C2",label="2 axes (y + x)")
ax[1].axhline(169,ls=":",c="k",label="full ρ (169 real params)")
ax[1].axvline(13,ls="--",c="gray"); ax[1].text(13.1,40,"13 = 2F+1",color="gray",fontsize=9)
ax[1].set_xlabel("# tilt angles per axis"); ax[1].set_ylabel("rank of linear tomography map")
ax[1].set_title("Linear-inversion rank: saturates at 13 angles/axis.\ny+x reach only 133/169; full ρ needs a 3rd tilt axis (caveat 5a).")
ax[1].legend(fontsize=9); ax[1].grid(alpha=.3)
fig.suptitle("How many tilt angles, and why 13?  (F=6 ¹⁵¹Eu)  — your intuition is correct: 13 angles ≈ 14° spacing",fontsize=12.5)
fig.savefig(OUT,dpi=130); print("wrote",OUT)
