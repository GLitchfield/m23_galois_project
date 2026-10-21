#!/usr/bin/env python3
"""Experimental dessin-seeded numerical helpers for the 8A Belyi target.

This is a feasibility pilot, not a proof-producing solver.  In particular,
``newton`` must be paired with the saturation values below: a small coefficient
residual obtained by colliding roots is not an acceptable candidate.
"""
import csv
import math
from pathlib import Path
import numpy as np

SOURCE = (Path(__file__).resolve().parents[1]
          / 'data/derived/m23_8a_8a_2a_inner_classes.tsv')

def cycles(p):
    seen=set(); out=[]
    for i in range(len(p)):
        if i in seen: continue
        c=[]; j=i
        while j not in seen:
            seen.add(j); c.append(j); j=p[j]
        out.append(c)
    return out

def parse(class_id=1):
    """Return the certified permutation triple with the requested class ID."""
    lines=[x for x in SOURCE.read_text().splitlines() if not x.startswith('#')]
    rows={int(row['class_id']):row for row in csv.DictReader(lines, delimiter='\t')}
    if class_id not in rows:
        available=f'{min(rows)}..{max(rows)}' if rows else 'none'
        raise ValueError(f'unknown 8A Belyi class ID {class_id}; available: {available}')
    row=rows[class_id]
    return [[int(x)-1 for x in row[k].split(',')] for k in ('first_images','second_images','third_images')]

def dessin_graph(s0,s1):
    cb, cw = cycles(s0), cycles(s1)
    eb={e:i for i,c in enumerate(cb) for e in c}
    ew={e:i for i,c in enumerate(cw) for e in c}
    # Rotation-followed-by-edge-flip face permutation on the 46 dessin darts.
    face_perm=[]
    for d in range(46):
        e,c=divmod(d,2)
        e=(s0 if c==0 else s1)[e]
        face_perm.append(2*e+(1-c))
    cf=cycles(face_perm)
    fd={d:i for i,c in enumerate(cf) for d in c}
    nb,nw=len(cb),len(cw)
    def B(i): return i
    def W(i): return nb+i
    def F(i): return nb+nw+i
    original_count=nb+nw+len(cf)
    # Barycentrically subdivide the combinatorial map, retaining distinct
    # parallel-edge and corner incidences.  This turns the 46 side triangles
    # into a genuine 276-triangle simplicial mesh.
    next_node=original_count
    bw_mid={e:next_node+e for e in range(23)}; next_node+=23
    radial_mid={}
    for fi,face in enumerate(cf):
        for k in range(len(face)):
            radial_mid[(fi,k)]=next_node; next_node+=1
    centroid={d:next_node+i for i,d in enumerate(range(46))}; next_node+=46
    n=next_node
    adj=np.zeros((n,n),float)
    triangles=set()
    def edge(a,b):
        if a!=b: adj[a,b]+=1; adj[b,a]+=1
    for e,mid in bw_mid.items(): edge(B(eb[e]),mid); edge(W(ew[e]),mid)
    face_position={d:(fi,k) for fi,face in enumerate(cf) for k,d in enumerate(face)}
    for fi,face in enumerate(cf):
        f=F(fi)
        for k,d in enumerate(face):
            e,c=divmod(d,2)
            shared=B(eb[e]) if c==0 else W(ew[e])
            mid=radial_mid[(fi,k)]; edge(shared,mid); edge(f,mid)
    for d in range(46):
        e,_=divmod(d,2); fi,k=face_position[d]; face=cf[fi]
        mids=(bw_mid[e],radial_mid[(fi,k)],radial_mid[(fi,(k-1)%len(face))])
        center=centroid[d]
        for mid in mids: edge(center,mid)
        b,w,f=B(eb[e]),W(ew[e]),F(fi)
        for vertex in (b,w,f): edge(center,vertex)
        # Each old triangle contributes two small triangles at each vertex.
        for vertex in (b,w,f):
            incident=[mid for mid in mids if adj[vertex,mid]]
            if len(incident)!=2: raise RuntimeError(('bad flag triangle',d,vertex,incident))
            triangles.add(tuple(sorted((vertex,incident[0],center))))
            triangles.add(tuple(sorted((vertex,incident[1],center))))
    return cb,cw,cf,eb,ew,fd,adj,sorted(triangles)

def tutte(adj, outer):
    n=len(adj); outer=list(outer); inside=[i for i in range(n) if i not in outer]
    fixed=np.array([0+0j,1+0j,0.5+math.sqrt(3)*0.5j])
    A=np.zeros((len(inside),len(inside)),float); rhs=np.zeros(len(inside),complex)
    pos={v:fixed[k] for k,v in enumerate(outer)}; index={v:k for k,v in enumerate(inside)}
    for v in inside:
        row=index[v]; A[row,row]=adj[v].sum()
        for w,weight in enumerate(adj[v]):
            if not weight: continue
            if w in index: A[row,index[w]]-=weight
            else: rhs[row]+=weight*pos[w]
    sol=np.linalg.solve(A,rhs)
    for v,z in zip(inside,sol): pos[v]=z
    return np.array([pos[i] for i in range(n)])

def mobius(z,z0,z1,zinf):
    return (z-z0)*(z1-zinf)/((z-zinf)*(z1-z0))

def polymul(a,b): return np.polynomial.polynomial.polymul(a,b)
def factor(root, exponent): return np.polynomial.polynomial.polypow(np.array([-root,1],complex),exponent)
def product_factors(items):
    out=np.array([1+0j])
    for root,exponent in items: out=polymul(out,factor(root,exponent))
    return out
def pad(a,n=24): return np.pad(a,(0,n-len(a)))

def residual_jac(z,normalization=(4,2,1)):
    if sorted(normalization) != [1,2,4]:
        raise ValueError('normalization must permute (4,2,1)')
    alpha=z[0]; ar=list(z[1:3]); br=list(z[3:5]); cr=list(z[5:8]); ur=list(z[8:16]); vr=list(z[16:23])
    pf=[(r,8) for r in ar]+[(0,normalization[0]),(1,normalization[1])]
    ff=[(r,8) for r in br]+[(cr[0],4),(cr[1],2),(cr[2],1)]
    qf=[(r,2) for r in ur]+[(r,1) for r in vr]
    pb=product_factors(pf); f=product_factors(ff); q=product_factors(qf)
    res=(pad(alpha*pb)+pad(f)-pad(q))[:23]
    cols=[pad(pb)[:23]]
    def deriv(items,k):
        out=np.array([1+0j]); root,exponent=items[k]
        for j,(r,e) in enumerate(items): out=polymul(out,factor(r,e-1 if j==k else e))
        return -exponent*out
    for k in range(2): cols.append((alpha*pad(deriv(pf,k)))[:23])
    for k in range(5): cols.append(pad(deriv(ff,k))[:23])
    for k in range(15): cols.append((-pad(deriv(qf,k)))[:23])
    return res,np.column_stack(cols),(alpha*pb,f,q)

def initial_from_positions(data,pos,roles=('B','W','F'),normalization=(4,2,1)):
    cb,cw,cf,eb,ew,fd,adj,_=data; nb=len(cb); nw=len(cw)
    b_by_len={}
    for i,c in enumerate(cb): b_by_len.setdefault(len(c),[]).append(pos[i])
    w_by_len={}
    for i,c in enumerate(cw): w_by_len.setdefault(len(c),[]).append(pos[nb+i])
    f_by_len={}
    for i,c in enumerate(cf): f_by_len.setdefault(len(c)//2,[]).append(pos[nb+nw+i])
    category={'B':b_by_len,'W':w_by_len,'F':f_by_len}
    p_by_len=category[roles[0]]; f_by_len=category[roles[1]]; q_by_len=category[roles[2]]
    z0=p_by_len[normalization[0]][0]
    z1=p_by_len[normalization[1]][0]
    zi=p_by_len[normalization[2]][0]
    transform=lambda x: mobius(x,z0,z1,zi)
    ar=[transform(x) for x in p_by_len[8]]
    br=[transform(x) for x in f_by_len[8]]
    cr=[transform(f_by_len[k][0]) for k in (4,2,1)]
    ur=[transform(x) for x in q_by_len[2]]
    vr=[transform(x) for x in q_by_len[1]]
    provisional=np.array([1,*ar,*br,*cr,*ur,*vr],complex)
    _,_,(pb,f,q)=residual_jac(provisional,normalization)
    target=(pad(q)-pad(f))[:23]; source=pad(pb)[:23]
    alpha=np.vdot(source,target)/np.vdot(source,source)
    provisional[0]=alpha
    return provisional

def initial_for_outer(data,outer,roles=('B','W','F')):
    return initial_from_positions(data,tutte(data[-2],outer),roles)

def circle_pack(data,outer,max_radius_iterations=24,max_center_iterations=50):
    adj=data[-2]; triangles=data[-1]; n=len(adj); outer=tuple(outer)
    inside=[v for v in range(n) if v not in outer]; index={v:i for i,v in enumerate(inside)}
    incident=[[] for _ in range(n)]
    for tri in triangles:
        for v in tri: incident[v].append(tri)
    def angle_sums(logr):
        radii=np.ones(n); radii[inside]=np.exp(logr); sums=np.zeros(n)
        for tri in triangles:
            a,b,c=tri
            for v,j,k in ((a,b,c),(b,a,c),(c,a,b)):
                x=radii[v]+radii[j]; y=radii[v]+radii[k]; z=radii[j]+radii[k]
                cosine=np.clip((x*x+y*y-z*z)/(2*x*y),-1,1)
                sums[v]+=math.acos(cosine)
        return sums[inside]-2*math.pi,radii
    logr=np.full(len(inside),-2.0)
    for iteration in range(max_radius_iterations):
        f,radii=angle_sums(logr); norm=np.linalg.norm(f,np.inf)
        print('circle radii',iteration,'error',norm,'range',radii.min(),radii.max())
        if norm<1e-10: break
        eps=2e-5; jac=np.empty((len(inside),len(inside)))
        for col in range(len(inside)):
            shifted=logr.copy(); shifted[col]+=eps
            jac[:,col]=(angle_sums(shifted)[0]-f)/eps
        step=np.linalg.lstsq(jac,-f,rcond=1e-11)[0]
        accepted=False
        for k in range(16):
            candidate=logr+(0.5**k)*step
            if np.linalg.norm(angle_sums(candidate)[0],np.inf)<norm:
                logr=candidate; accepted=True; break
        if not accepted: raise RuntimeError('circle-radius Newton stalled')
    f,radii=angle_sums(logr)
    if np.linalg.norm(f,np.inf)>1e-7: raise RuntimeError('circle radii did not converge')
    all_angle_errors=np.zeros(n)
    for triangle in triangles:
        aa,bb,cc=triangle
        for v,j,k in ((aa,bb,cc),(bb,aa,cc),(cc,aa,bb)):
            x=radii[v]+radii[j]; y=radii[v]+radii[k]; z=radii[j]+radii[k]
            all_angle_errors[v]+=math.acos(np.clip((x*x+y*y-z*z)/(2*x*y),-1,1))
    print('outer angle errors',[all_angle_errors[v]-2*math.pi for v in outer])
    edges=[(i,j) for i in range(n) for j in range(i+1,n) if adj[i,j]]
    # Recover centers by developing the metric triangulation from the chosen
    # outer face.  Across a shared edge the new triangle must lie on the side
    # opposite the third vertex of the already developed triangle.
    edge_triangles={e:[] for e in edges}
    for triangle in triangles:
        a,b,c=triangle
        for e in ((a,b),(b,c),(c,a)):
            edge_triangles[tuple(sorted(e))].append(triangle)
    outer=tuple(sorted(outer)); pos=np.full(n,np.nan+1j*np.nan,complex)
    a,b,c=outer
    pos[a]=0; pos[b]=radii[a]+radii[b]
    dab=abs(pos[b]-pos[a]); dac=radii[a]+radii[c]; dbc=radii[b]+radii[c]
    along=(dac*dac-dbc*dbc+dab*dab)/(2*dab)
    height=math.sqrt(max(0,dac*dac-along*along))
    pos[c]=along+1j*height
    queue=[outer]; visited={outer}
    while queue:
        triangle=queue.pop(0)
        for u,v in ((triangle[0],triangle[1]),(triangle[1],triangle[2]),(triangle[2],triangle[0])):
            shared=tuple(sorted((u,v)))
            for neighbor in edge_triangles[shared]:
                if neighbor==triangle or neighbor in visited: continue
                old=next(x for x in triangle if x not in shared)
                new=next(x for x in neighbor if x not in shared)
                delta=pos[v]-pos[u]; distance=abs(delta)
                du=radii[u]+radii[new]; dv=radii[v]+radii[new]
                along=(du*du-dv*dv+distance*distance)/(2*distance)
                height=math.sqrt(max(0,du*du-along*along))
                base=pos[u]+along*delta/distance
                offset=1j*height*delta/distance
                candidates=(base+offset,base-offset)
                old_side=np.imag(np.conj(delta)*(pos[old]-pos[u]))
                # The three boundary-circle centers geometrically enclose the
                # disk packing, so the triangle adjacent to the combinatorial
                # outer face is on the same geometric side.  Across every
                # interior edge, adjacent triangles lie on opposite sides.
                chooser=max if triangle==outer else min
                chosen=chooser(candidates,key=lambda z: np.imag(np.conj(delta)*(z-pos[u]))*old_side)
                if np.isnan(pos[new].real): pos[new]=chosen
                elif abs(pos[new]-chosen)>1e-5:
                    raise RuntimeError(('circle development inconsistent',new,abs(pos[new]-chosen)))
                visited.add(neighbor); queue.append(neighbor)
    if np.any(np.isnan(pos.real)): raise RuntimeError('circle development incomplete')
    errors=[abs(pos[i]-pos[j])-(radii[i]+radii[j]) for i,j in edges]
    print('circle centers developed error_inf',np.linalg.norm(errors,np.inf))
    return pos,radii

def newton(z,maxiter=80,normalization=(4,2,1)):
    best=z.copy()
    r,j,parts=residual_jac(z,normalization)
    bestn=np.linalg.norm(r)
    scale=max(np.linalg.norm(p) for p in parts)
    history=[(0,bestn,bestn/scale)]
    for iteration in range(1,maxiter+1):
        r,j,parts=residual_jac(z,normalization)
        try: step=np.linalg.solve(j,-r)
        except np.linalg.LinAlgError: step=np.linalg.lstsq(j,-r,rcond=1e-12)[0]
        old=np.linalg.norm(r); accepted=False
        for k in range(18):
            candidate=z+(0.5**k)*step
            rr,_,pp=residual_jac(candidate,normalization)
            nn=np.linalg.norm(rr)
            if np.isfinite(nn) and nn < old:
                z=candidate; accepted=True
                if nn<bestn: best,bestn=z.copy(),nn
                scale=max(np.linalg.norm(p) for p in pp)
                history.append((iteration,nn,nn/scale)); break
        if not accepted: break
        if history[-1][2] < 1e-12: break
    return best,history

def saturation_values_derivatives(z):
    alpha=z[0]; p=list(z[1:3])+[0+0j,1+0j]; f=list(z[3:8]); q=list(z[8:23])
    groups=[]
    derivs=[]
    d=np.zeros(23,complex); d[0]=1; groups.append(alpha); derivs.append(d)
    for roots,indices in ((p,[1,2,None,None]),(f,list(range(3,8))),(q,list(range(8,23)))):
        value=1+0j
        for i in range(len(roots)):
            for j in range(i+1,len(roots)): value*=roots[i]-roots[j]
        d=np.zeros(23,complex)
        for i,index in enumerate(indices):
            if index is not None: d[index]=value*sum(1/(roots[i]-roots[j]) for j in range(len(roots)) if j!=i)
        groups.append(value); derivs.append(d)
    value=1+0j
    for a in p:
        for b in f: value*=a-b
    d=np.zeros(23,complex)
    for i,index in enumerate([1,2,None,None]):
        if index is not None: d[index]=value*sum(1/(p[i]-b) for b in f)
    for j,index in enumerate(range(3,8)): d[index]=-value*sum(1/(a-f[j]) for a in p)
    groups.append(value); derivs.append(d)
    return np.array(groups),np.array(derivs)

def augmented(zs,scales,normalization=(4,2,1)):
    z=zs[:23]
    s=zs[23:]
    r,j,_=residual_jac(z,normalization)
    g,dg=saturation_values_derivatives(z); gs=g/scales; dgs=dg/scales[:,None]
    aux=s*gs-1
    jac=np.zeros((28,28),complex); jac[:23,:23]=j
    jac[23:,:23]=s[:,None]*dgs; jac[23:,23:]=np.diag(gs)
    return np.r_[r,aux],jac

def usable_saturation_scales(scales):
    """Accept nonzero finite gates even when their raw products are tiny.

    The augmented equations divide every gate by its value at the seed.  An
    absolute cutoff is therefore chart- and degree-dependent and incorrectly
    rejects separated roots when a large Vandermonde product is small.
    """
    scales=np.asarray(scales)
    return bool(np.all(np.isfinite(scales.real)) and
                np.all(np.isfinite(scales.imag)) and np.all(scales != 0))

def correct_homotopy(z,target,scales,normalization=(4,2,1),
                      tolerance=1e-9,maxiter=12):
    for iteration in range(maxiter):
        r,j=augmented(z,scales,normalization)
        h=r-target
        hn=np.linalg.norm(h)
        if hn < tolerance*max(1,np.linalg.norm(target)): return z,iteration,hn
        try: step=np.linalg.solve(j,-h)
        except np.linalg.LinAlgError: return None,iteration,hn
        accepted=False
        for k in range(14):
            candidate=z+(0.5**k)*step
            hh=augmented(candidate,scales,normalization)[0]-target
            if np.linalg.norm(hh) < hn:
                z=candidate; accepted=True; break
        if not accepted: return None,iteration,hn
    return None,maxiter,hn

def track(z0,normalization=(4,2,1)):
    scales,_=saturation_values_derivatives(z0)
    if not usable_saturation_scales(scales): return None,[],'singular seed'
    z=np.r_[z0,np.ones(5,complex)]
    aug0,j=augmented(z,scales,normalization)
    r0=aug0[:23].copy()
    rhs=np.r_[r0,np.zeros(5,complex)]
    t=0.; dt=.01; steps=[]
    while t < 1-1e-14 and len(steps)<2000:
        next_t=min(1.,t+dt)
        try: tangent=np.linalg.solve(j,-rhs)
        except np.linalg.LinAlgError: return None,steps,'singular predictor'
        predictor=z+(next_t-t)*tangent
        target=np.r_[(1-next_t)*r0,np.zeros(5,complex)]
        corrected,iters,error=correct_homotopy(
            predictor,target,scales,normalization)
        if corrected is None:
            dt*=.5
            if dt<1e-7: return None,steps,'step underflow'
            continue
        z=corrected
        t=next_t
        _,j=augmented(z,scales,normalization)
        steps.append((t,dt,iters,error,abs(z[0])))
        if iters<=3: dt=min(.08,dt*1.4)
        elif iters>=8: dt=max(1e-7,dt*.6)
    return z[:23],steps,'complete' if t>=1-1e-14 else 'step limit'

def main():
    sigmas=parse()
    print('cycles', [sorted(map(len,cycles(s)),reverse=True) for s in sigmas])
    ranked=[]
    rotations=[((0,1),('B','W','F')),((1,2),('F','B','W')),((2,0),('W','F','B'))]
    circle_data=dessin_graph(sigmas[0],sigmas[1]); circle_outer=circle_data[-1][0]
    try:
      circle_pos,circle_radii=circle_pack(circle_data,circle_outer)
      circle_z=initial_from_positions(circle_data,circle_pos,rotations[0][1])
      rr,_,pp=residual_jac(circle_z)
      print('CIRCLE_INITIAL',circle_outer,np.linalg.norm(rr)/max(np.linalg.norm(p) for p in pp))
      circle_root,circle_steps,circle_status=track(circle_z)
      print('CIRCLE_TRACK',circle_status,len(circle_steps),circle_steps[-1] if circle_steps else None)
      direct,direct_hist=newton(circle_z,160)
      print('CIRCLE_DIRECT',direct_hist[-1], 'alpha',abs(direct[0]))
    except (RuntimeError,np.linalg.LinAlgError) as error:
      print('CIRCLE_FAILED',error)
    for rotation,((i,j),roles) in enumerate(rotations):
      data=dessin_graph(sigmas[i],sigmas[j])
      print('rotation',rotation,'faces',sorted((len(c)//2 for c in data[2]),reverse=True),'triangles',len(data[-1]),'edges',int((data[-2]>0).sum()/2))
      for index,outer in enumerate(data[-1]):
        try: z=initial_for_outer(data,outer,roles); r,_,parts=residual_jac(z)
        except (np.linalg.LinAlgError,ZeroDivisionError,FloatingPointError): continue
        rel=np.linalg.norm(r)/max(np.linalg.norm(p) for p in parts)
        if np.isfinite(rel): ranked.append((rel,100*rotation+index,outer,z))
    ranked.sort(key=lambda x:x[0])
    print('initial candidates',len(ranked),'best_relative',ranked[0][0])
    tracked=[]
    for rel,index,outer,z in ranked[:36]:
        root,steps,status=track(z)
        if root is None:
            print('track',index,status,'progress',steps[-1][0] if steps else 0,'steps',len(steps))
            continue
        rr,_,pp=residual_jac(root); relative=np.linalg.norm(rr)/max(np.linalg.norm(p) for p in pp)
        tracked.append((relative,index,outer,root,steps))
        print('track',index,status,'steps',len(steps),'relative',relative,'alpha',abs(root[0]))
        if relative<1e-8 and abs(root[0])>1e-8: break
    if tracked:
        tracked.sort(key=lambda x:x[0])
        print('TRACK_BEST',tracked[0][0:3], 'alpha',abs(tracked[0][3][0]))
    outcomes=[]
    for rel,index,outer,z in ranked[:20]:
        root,hist=newton(z)
        outcomes.append((hist[-1][2],index,outer,len(hist)-1,hist[-1][1],root,hist))
        print('try',index,'outer',outer,'initial',rel,'steps',len(hist)-1,'relative',hist[-1][2])
    outcomes.sort(key=lambda x:x[0])
    best=outcomes[0]
    print('BEST',best[:5])
    print('history',best[-1])
    print('variables')
    for x in best[5]: print(repr(x))

if __name__=='__main__': main()
