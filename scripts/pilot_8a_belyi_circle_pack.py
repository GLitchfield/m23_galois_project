#!/usr/bin/env python3
"""Refined circle-packing feasibility pilot for a certified 8A Belyi class.

The calculation develops the exact permutation dessin, refines its flag
triangulation, and feeds the resulting branch-point positions to the canonical
coefficient system.  It reports both raw residuals and saturation factors so
that a degenerate Newton limit cannot be mistaken for a Belyi map.
"""
import argparse
import itertools
import math
import numpy as np
from pathlib import Path
from scipy.sparse import coo_matrix
from scipy.sparse.linalg import spsolve

import pilot_8a_belyi_numeric as pilot

REDUCED_NAMES=('alpha','a0','a1','b0','b1','c4','c2','c1',
               *(f'u{i}' for i in range(8)))
FULL_NAMES=(*REDUCED_NAMES,*(f'v{i}' for i in range(7)))
ROOT_NAMES=('alpha','ar1','ar2','br1','br2','cr4','cr2','cr1',
            *(f'ur{i}' for i in range(1,9)),*(f'vr{i}' for i in range(1,8)))

def reduced_seed(full_seed):
    alpha=full_seed[0]
    a=np.polynomial.polynomial.polyfromroots(full_seed[1:3])
    b=np.polynomial.polynomial.polyfromroots(full_seed[3:5])
    u=np.polynomial.polynomial.polyfromroots(full_seed[8:16])
    return np.array([alpha,a[0],a[1],b[0],b[1],*full_seed[5:8],*u[:8]],complex)

def coefficient_seed(root_seed):
    reduced=reduced_seed(root_seed)
    v=np.polynomial.polynomial.polyfromroots(root_seed[16:23])
    return np.array([*reduced,*v[:7]],complex)

def write_seed(path,seed,refinements,vertices,triangles,normalization=(4,2,1),
               names=FULL_NAMES,class_id=1,rotation=0):
    lines=[
        '# format=m23_8a_coefficient_seed_v1',
        f'# refinements={refinements}',
        f'# vertices={vertices}',
        f'# triangles={triangles}',
        f'# class_id={class_id}',
        f'# cyclic_rotation={rotation}',
        '# normalization=' + ','.join(map(str,normalization)),
        'name\treal\timag',
    ]
    lines.extend(f'{name}\t{value.real:.17g}\t{value.imag:.17g}'
                 for name,value in zip(names,seed))
    Path(path).write_text('\n'.join(lines)+'\n')

def subdivide(n,triangles,old_outer):
    edges=sorted({tuple(sorted((a,b))) for a,b,c in triangles for a,b in ((a,b),(b,c),(c,a))})
    midpoint={edge:n+i for i,edge in enumerate(edges)}
    center={triangle:n+len(edges)+i for i,triangle in enumerate(triangles)}
    refined=[]; outer_candidates=[]
    for triangle in triangles:
        a,b,c=triangle; mab=midpoint[tuple(sorted((a,b)))]; mbc=midpoint[tuple(sorted((b,c)))]; mac=midpoint[tuple(sorted((a,c)))]; f=center[triangle]
        small=[tuple(sorted(x)) for x in ((a,mab,f),(a,mac,f),(b,mab,f),(b,mbc,f),(c,mac,f),(c,mbc,f))]
        refined.extend(small)
        if triangle==tuple(sorted(old_outer)): outer_candidates=small
    return n+len(edges)+len(triangles),sorted(set(refined)),outer_candidates[0]

def triangle_angles(r,triangle):
    a,b,c=triangle; out=[]
    for v,j,k in ((a,b,c),(b,a,c),(c,a,b)):
        x=r[v]+r[j]; y=r[v]+r[k]; z=r[j]+r[k]
        out.append(math.acos(np.clip((x*x+y*y-z*z)/(2*x*y),-1,1)))
    return np.array(out)

def pack(n,triangles,outer,maxiter=30):
    outer=tuple(sorted(outer)); inside=[v for v in range(n) if v not in outer]; index={v:i for i,v in enumerate(inside)}
    incident=[[] for _ in range(n)]
    for ti,t in enumerate(triangles):
        for v in t: incident[v].append(ti)
    def evaluate(logr,need_jac=False):
        r=np.ones(n); r[inside]=np.exp(logr)
        angles=[triangle_angles(r,t) for t in triangles]
        sums=np.zeros(n)
        for t,values in zip(triangles,angles):
            for v,value in zip(t,values): sums[v]+=value
        f=sums[inside]-2*math.pi
        if not need_jac: return f,r
        rows=[]; cols=[]; values=[]; eps=1e-6
        for w in inside:
            changed=r.copy(); changed[w]*=math.exp(eps); col=index[w]
            accum={}
            for ti in incident[w]:
                t=triangles[ti]; difference=(triangle_angles(changed,t)-angles[ti])/eps
                for v,value in zip(t,difference):
                    if v in index: accum[v]=accum.get(v,0.0)+value
            for v,value in accum.items(): rows.append(index[v]); cols.append(col); values.append(value)
        return f,r,coo_matrix((values,(rows,cols)),shape=(len(inside),len(inside))).tocsr()
    logr=np.full(len(inside),-4.0)
    for iteration in range(maxiter):
        f,r,j=evaluate(logr,True); norm=np.linalg.norm(f,np.inf)
        print('refined radii',iteration,'error',norm,'range',r.min(),r.max(),flush=True)
        if norm<1e-9: break
        step=spsolve(j,-f); accepted=False
        for k in range(18):
            candidate=logr+step/(2**k); fn,_=evaluate(candidate)
            if np.linalg.norm(fn,np.inf)<norm:
                logr=candidate; accepted=True; break
        if not accepted: raise RuntimeError('sparse radius Newton stalled')
    f,r=evaluate(logr)
    if np.linalg.norm(f,np.inf)>1e-7: raise RuntimeError('sparse radius solve incomplete')
    edges=sorted({tuple(sorted((a,b))) for a,b,c in triangles for a,b in ((a,b),(b,c),(c,a))})
    edge_triangles={e:[] for e in edges}
    for t in triangles:
        for e in ((t[0],t[1]),(t[1],t[2]),(t[2],t[0])): edge_triangles[tuple(sorted(e))].append(t)
    pos=np.full(n,np.nan+1j*np.nan,complex); a,b,c=outer
    pos[a]=0; pos[b]=r[a]+r[b]; d=abs(pos[b]); da=r[a]+r[c]; db=r[b]+r[c]
    along=(da*da-db*db+d*d)/(2*d); pos[c]=along+1j*math.sqrt(max(0,da*da-along*along))
    queue=[outer]; visited={outer}
    while queue:
        triangle=queue.pop(0)
        for u,v in ((triangle[0],triangle[1]),(triangle[1],triangle[2]),(triangle[2],triangle[0])):
            for neighbor in edge_triangles[tuple(sorted((u,v)))]:
                if neighbor==triangle or neighbor in visited: continue
                old=next(x for x in triangle if x not in (u,v)); new=next(x for x in neighbor if x not in (u,v))
                delta=pos[v]-pos[u]; distance=abs(delta); du=r[u]+r[new]; dv=r[v]+r[new]
                along=(du*du-dv*dv+distance*distance)/(2*distance); height=math.sqrt(max(0,du*du-along*along))
                base=pos[u]+along*delta/distance; offset=1j*height*delta/distance
                candidates=(base+offset,base-offset); side=np.imag(np.conj(delta)*(pos[old]-pos[u]))
                chooser=max if triangle==outer else min
                chosen=chooser(candidates,key=lambda z: np.imag(np.conj(delta)*(z-pos[u]))*side)
                if np.isnan(pos[new].real): pos[new]=chosen
                elif abs(pos[new]-chosen)>1e-4: raise RuntimeError(('development inconsistent',new,abs(pos[new]-chosen)))
                visited.add(neighbor); queue.append(neighbor)
    errors=[abs(pos[i]-pos[j])-(r[i]+r[j]) for i,j in edges]
    print('refined centers error',np.linalg.norm(errors,np.inf),flush=True)
    return pos,r

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--class-id',type=int,default=1,
                        help='certified inner class ID (1 through 28)')
    parser.add_argument('--rotation',type=int,choices=(0,1,2),default=0,
                        help='cyclic branch rotation (default: 0)')
    parser.add_argument('--normalization',default='4,2,1',
                        choices=('4,2,1','4,1,2','2,4,1','2,1,4','1,4,2','1,2,4'),
                        help='distinguished multiplicities sent to 0, 1, infinity')
    parser.add_argument('--refinements',type=int,default=2,
                        help='barycentric refinements after the 140-node flag mesh')
    parser.add_argument('--newton-iterations',type=int,default=1500)
    parser.add_argument('--seed-tsv',help='write the full 23-variable coefficient seed')
    parser.add_argument('--seed-dir',help='write all six distinguished-point charts')
    parser.add_argument('--root-seed-dir',
                        help='write all six 23-variable labeled-root charts')
    parser.add_argument('--seed-only',action='store_true',
                        help='stop after writing the requested seed')
    args=parser.parse_args()
    if args.refinements < 0: parser.error('--refinements must be nonnegative')
    try:
        sigmas=pilot.parse(args.class_id)
    except ValueError as error:
        parser.error(str(error))
    rotations=(((0,1),('B','W','F')),((1,2),('F','B','W')),
               ((2,0),('W','F','B')))
    (first,second),roles=rotations[args.rotation]
    normalization=tuple(map(int,args.normalization.split(',')))
    data=pilot.dessin_graph(sigmas[first],sigmas[second]); n=len(data[-2]); old_outer=data[-1][0]
    print('class',args.class_id,'rotation',args.rotation,
          'normalization',normalization,flush=True)
    refined_n,refined_triangles,outer=n,data[-1],old_outer
    for _ in range(args.refinements):
        refined_n,refined_triangles,outer=subdivide(refined_n,refined_triangles,outer)
    print('refined mesh',refined_n,len(refined_triangles),3*refined_n-6,'outer',outer,flush=True)
    positions,radii=pack(refined_n,refined_triangles,outer)
    z=pilot.initial_from_positions(data,positions[:n],roles,normalization)
    rr,_,parts=pilot.residual_jac(z,normalization)
    print('INITIAL',np.linalg.norm(rr)/max(np.linalg.norm(x) for x in parts),flush=True)
    if args.seed_tsv:
        write_seed(args.seed_tsv,coefficient_seed(z),args.refinements,
                   refined_n,len(refined_triangles),normalization,
                   class_id=args.class_id,rotation=args.rotation)
        print('SEED',args.seed_tsv,flush=True)
    if args.seed_dir:
        seed_dir=Path(args.seed_dir); seed_dir.mkdir(parents=True,exist_ok=True)
        for normalization in itertools.permutations((4,2,1)):
            chart=pilot.initial_from_positions(data,positions[:n],roles,
                                               normalization=normalization)
            path=seed_dir / ('seed_'+'_'.join(map(str,normalization))+'.tsv')
            write_seed(path,coefficient_seed(chart),args.refinements,
                       refined_n,len(refined_triangles),normalization,
                       class_id=args.class_id,rotation=args.rotation)
            print('SEED',path,flush=True)
    if args.root_seed_dir:
        seed_dir=Path(args.root_seed_dir); seed_dir.mkdir(parents=True,exist_ok=True)
        for normalization in itertools.permutations((4,2,1)):
            chart=pilot.initial_from_positions(data,positions[:n],roles,
                                               normalization=normalization)
            path=seed_dir / ('root_seed_'+'_'.join(map(str,normalization))+'.tsv')
            write_seed(path,chart,args.refinements,refined_n,
                       len(refined_triangles),normalization,names=ROOT_NAMES,
                       class_id=args.class_id,rotation=args.rotation)
            print('ROOT_SEED',path,flush=True)
    if args.seed_only:
        if not (args.seed_tsv or args.seed_dir or args.root_seed_dir):
            parser.error('--seed-only requires a seed output option')
        return
    root,history=pilot.newton(
        z,args.newton_iterations,normalization=normalization)
    g,_=pilot.saturation_values_derivatives(root)
    print('DIRECT',history[-1],'steps',len(history)-1,'alpha',root[0],'saturation',np.abs(g),flush=True)
    tracked,steps,status=pilot.track(z,normalization=normalization)
    print('TRACK',status,len(steps),steps[-1] if steps else None,flush=True)
    relative=history[-1][2]
    accepted=(relative < 1e-10 and np.min(np.abs(g)) > 1e-10
              and status == 'complete')
    print('VERDICT',('candidate' if accepted else 'rejected'),
          'gate_relative_lt=1e-10 gate_saturation_gt=1e-10 track_complete',flush=True)
    print('VARIABLES')
    for x in root: print(repr(x))

if __name__=='__main__': main()
