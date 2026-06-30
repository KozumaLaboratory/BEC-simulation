#!/usr/bin/env python3
"""VERIFICATION -> IMPLEMENTATION bridge: 4-level block {-6,-5,-4,-3}, posture B.
Tasks (per the reviewer's exact instruction):
 (1) posture B: measure ALL 13 SG channels, ESTIMATE only the 4-level block;
     build M_(4), report rank & condition number.
 (2) decide the tilt-axis set that makes the 4-level block fully solvable,
     INDEPENDENTLY of the 13-level/169 result.
 (3) priority subspace (4 pops + 3 ADJACENT coherences = 10 real params):
     minimal #settings + condition number.
 (4) §5b conservation path: <Fz>=sum_{m=-6}^{+6} m N_m/N over ALL channels,
     computed separately from the block tomography.
Also validates the posture-B reconstruction on the REAL EdH local state.
env: PSI13, GOTO, FRAME"""
import os, numpy as np, h5py
from scipy.linalg import expm
PSI=os.environ.get("PSI13","edh_v4_psi13.jld2"); GOTO=os.environ.get("GOTO","edh_v4_goto.h5"); FR=int(os.environ.get("FRAME","100"))
F=6; D=13; ms=np.arange(F,-F-1,-1)            # c-index 0..12 -> m=+6..-6
Fp=np.zeros((D,D))
for i in range(D):
    m=ms[i]
    if m<F: Fp[i-1,i]=np.sqrt(F*(F+1)-m*(m+1))
Fz=np.diag(ms.astype(float)); Fx=0.5*(Fp+Fp.T); Fy=(Fp-Fp.T)/(2j)
AX={"y":Fy,"x":Fx,"z":Fz,"xz":(Fx+Fz)/np.sqrt(2),"xy":(Fx+Fy)/np.sqrt(2)}
def Rs_for(axes,N):
    angs=np.linspace(0,180,N,endpoint=False); return [expm(-1j*np.radians(b)*AX[ax]) for ax in axes for b in angs]
# ---- block + param-basis machinery ----
BLK=[list(ms).index(m) for m in (-6,-5,-4,-3)]          # = [12,11,10,9]
def param_basis(idx, pairs):
    ps=[("d",a,a) for a in idx]+[(t,a,c) for (a,c) in pairs for t in ("re","im")]
    return ps
def mat_of(r, ps):
    M=np.zeros((D,D),complex)
    for v,(t,a,c) in zip(r,ps):
        if t=="d": M[a,a]=v
        elif t=="re": M[a,c]+=v; M[c,a]+=v
        else: M[a,c]+=1j*v; M[c,a]-=1j*v
    return M
def build_M(ps, Rs):
    """posture B: rows = ALL 13 channels x settings; cols = block params."""
    rows=len(Rs)*D
    Mm=np.zeros((rows,len(ps)))
    for j in range(len(ps)):
        e=np.zeros(len(ps)); e[j]=1.0; rho=mat_of(e,ps)
        Mm[:,j]=np.array([np.real(np.diag(R@rho@R.conj().T)) for R in Rs]).reshape(-1)
    return Mm
def rank_cond(Mm):
    sv=np.linalg.svd(Mm,compute_uv=False); tol=1e-9*sv[0]
    r=int((sv>tol).sum()); cond=sv[0]/sv[r-1] if r>0 else np.inf
    return r, cond, sv
ALLP=param_basis(BLK,[(BLK[i],BLK[j]) for i in range(4) for j in range(i+1,4)])  # 16 params (full 4x4 Herm)
PRI =param_basis(BLK,[(BLK[0],BLK[1]),(BLK[1],BLK[2]),(BLK[2],BLK[3])])           # 10 params (4 pop + 3 adjacent)
print(f"4-level block = m=-6,-5,-4,-3 (indices {BLK})")
print(f"full block Hermitian params = {len(ALLP)} (16); minus block-trace normalization -> 15 free")
print(f"priority params (4 pop + 3 adjacent coherence) = {len(PRI)} real\n")

# ===== (2) axis set needed for FULL 4-level block (16 params), independent of 169 =====
print("="*86); print("(2) FULL 4-level block solvability (rank out of 16) vs tilt-axis set, N=13/axis:")
for axes in [("y",),("y","x"),("y","x","z"),("y","x","xy"),("y","x","xz")]:
    r,cond,_=rank_cond(build_M(ALLP,Rs_for(axes,13)))
    print(f"   axes={str(axes):20s} rank={r:2d}/16   cond(restricted)={cond:8.2f}")

# ===== (1) posture-B M_(4) condition number for the chosen working set =====
print("="*86); print("(1) posture B  M_(4)  rank & condition number (full 16-param block):")
for axes,N in [(("y","x"),13),(("y","x","xz"),13),(("y","x","xz"),7)]:
    Mm=build_M(ALLP,Rs_for(axes,N)); r,cond,sv=rank_cond(Mm)
    print(f"   axes={str(axes):18s} N={N:2d} settings={len(axes)*N:2d} meas={Mm.shape[0]:3d}  rank={r:2d}/16  cond={cond:8.2f}")

# ===== (3) priority subspace: minimal #settings + condition number =====
print("="*86); print("(3) PRIORITY subspace (4 pop + 3 adjacent coherence = 10 real params):")
print("    minimal small-angle y,x settings (posture-A spirit):")
for axes,N in [(("y","x"),2),(("y","x"),3),(("y","x"),4),(("y","x"),5),(("y","x"),13)]:
    Mm=build_M(PRI,Rs_for(axes,N)); r,cond,_=rank_cond(Mm)
    tag="FULL" if r==len(PRI) else ""
    print(f"   axes={str(axes):10s} N={N:2d} settings={len(axes)*N:2d}  rank={r:2d}/10  cond={cond:8.2f} {tag}")
# explicit minimal small-angle set (does small-angle y,x suffice for adjacent coherences?)
def small_set(angs_y,angs_x):
    return [expm(-1j*np.radians(b)*Fy) for b in angs_y]+[expm(-1j*np.radians(b)*Fx) for b in angs_x]
for name,sy,sx in [("identity+small ±16° y,x",[0,16,-16],[16,-16]),("0,±30 y,x",[0,30,-30],[30,-30])]:
    Mm=build_M(PRI,small_set(sy,sx)); r,cond,_=rank_cond(Mm)
    print(f"   {name:28s} settings={len(sy)+len(sx)}  rank={r:2d}/10  cond={cond:8.2f} {'FULL' if r==10 else ''}")

# ===== load real EdH local state for validation + (4) conservation =====
P=h5py.File(PSI,"r"); G=h5py.File(GOTO,"r")
def comp(c):
    re=np.transpose(np.asarray(P[f"psi_re_c{c:02d}"]),(2,1,0,3))[...,FR]
    im=np.transpose(np.asarray(P[f"psi_im_c{c:02d}"]),(2,1,0,3))[...,FR]
    return re+1j*im
psi=np.stack([comp(c) for c in range(1,14)],axis=-1); n3=np.sum(np.abs(psi)**2,axis=-1)
score=np.abs(psi[...,11])*np.abs(psi[...,12]); ix=np.unravel_index(np.argmax(score),score.shape)
zeta=psi[ix].copy(); zeta/=np.linalg.norm(zeta); rho_full=np.outer(zeta,zeta.conj())
pop_blk=np.sum(np.abs(zeta[BLK])**2); pop_out=1-pop_blk
print("="*86); print(f"REAL EdH local voxel {ix}: block pop={pop_blk*100:.2f}%  out-of-block(m<=-2 & +)= {pop_out*100:.2f}%")

# ===== posture-B reconstruction on real data (constrained ML, restricted to block) =====
def ml_block(axes,N,ps):
    Rs=Rs_for(axes,N); Pi=[]; fd=[]
    for R in Rs:
        occ=np.abs(R@zeta)**2                  # posture B: ALL 13 channels measured (incl. leakage)
        for m in range(D):
            em=np.zeros(D); em[m]=1; Pi.append(R.conj().T@np.outer(em,em)@R); fd.append(occ[m])
    Pi=np.array(Pi); fd=np.array(fd)
    # ML on the FULL ρ but we will read out only the block (posture B estimates block, leakage absorbs rest)
    rho=np.eye(D,dtype=complex)/D
    for _ in range(500):
        p=np.maximum(np.array([np.real(np.trace(rho@Pim)) for Pim in Pi]),1e-12)
        Rop=np.tensordot(fd/p,Pi,axes=(0,0)); rho=Rop@rho@Rop; rho=(rho+rho.conj().T)/2; rho/=np.real(np.trace(rho))
    return rho
def blk(M): return M[np.ix_(BLK,BLK)]
for axes,N in [(("y","x"),13),(("y","x","xz"),13)]:
    rho=ml_block(axes,N,ALLP)
    err=np.max(np.abs(blk(rho_full)-blk(rho)))
    # adjacent-coherence specific error
    adj_t=[rho_full[BLK[i],BLK[i+1]] for i in range(3)]; adj_r=[rho[BLK[i],BLK[i+1]] for i in range(3)]
    adj_err=max(abs(a-b) for a,b in zip(adj_t,adj_r))
    print(f"   posture-B ML  axes={str(axes):16s} N={N}: block max-err={err:.2e}  adjacent-coh err={adj_err:.2e}")

# ===== (4) §5b conservation path: <Fz> over ALL channels, SEPARATE from tomography =====
print("="*86); print("(4) §5b conservation check — computed over ALL 13 SG channels, separate from block estimate:")
N_m=np.array([np.sum(np.abs(psi[...,c])**2) for c in range(D)])     # no-tilt SG, full-cloud channel populations
Fz_cons=np.sum(ms*N_m)/np.sum(N_m)
# truth global <Fz>
Fz_true=np.einsum("xyzm,m->",np.abs(psi)**2,ms.astype(float))/n3.sum()
# block-only estimate of <Fz> (what the 4-level tomography would wrongly give if used for conservation)
Fz_blkonly=np.sum(ms[BLK]*N_m[BLK])/np.sum(N_m[BLK])
print(f"   <Fz> (ALL channels, conservation path)     = {Fz_cons:+.4f}")
print(f"   <Fz> (true, from full psi)                 = {Fz_true:+.4f}   -> match {abs(Fz_cons-Fz_true):.1e}")
print(f"   <Fz> (block-only, WRONG for conservation)  = {Fz_blkonly:+.4f}   (differs by {Fz_blkonly-Fz_true:+.3f} = why §5b insists on all channels)")
print("="*86)
