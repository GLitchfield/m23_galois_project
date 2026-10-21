module M23Belyi8ARoots

using HomotopyContinuation
using LinearAlgebra

export ROOT_NAMES, ROOT_VARIABLES, SATURATION_NAMES, SATURATION_VARIABLES,
       coefficient_expressions, saturation_values, saturated_expressions,
       saturated_system, STRONG_SATURATION_NAMES,
       STRONG_SATURATION_VARIABLES, strong_saturation_values,
       strong_saturated_expressions, strong_saturated_system,
       endpoint_metrics

@var alpha ar1 ar2 br1 br2 cr4 cr2 cr1
@var ur1 ur2 ur3 ur4 ur5 ur6 ur7 ur8
@var vr1 vr2 vr3 vr4 vr5 vr6 vr7
@var inverse_alpha inverse_p inverse_f inverse_q inverse_pf
@var inverse_pq inverse_fq

const ROOT_VARIABLES=[alpha,ar1,ar2,br1,br2,cr4,cr2,cr1,
                      ur1,ur2,ur3,ur4,ur5,ur6,ur7,ur8,
                      vr1,vr2,vr3,vr4,vr5,vr6,vr7]
const ROOT_NAMES=["alpha","ar1","ar2","br1","br2","cr4","cr2","cr1",
                  "ur1","ur2","ur3","ur4","ur5","ur6","ur7","ur8",
                  "vr1","vr2","vr3","vr4","vr5","vr6","vr7"]
const SATURATION_VARIABLES=[inverse_alpha,inverse_p,inverse_f,inverse_q,inverse_pf]
const SATURATION_NAMES=["inverse_alpha","inverse_p","inverse_f","inverse_q",
                        "inverse_pf"]
const STRONG_SATURATION_VARIABLES=vcat(
    SATURATION_VARIABLES,[inverse_pq,inverse_fq])
const STRONG_SATURATION_NAMES=vcat(
    SATURATION_NAMES,["inverse_pq","inverse_fq"])

function poly_mul(left,right)
    result=[0*left[1]*right[1] for _ in 1:(length(left)+length(right)-1)]
    for i in eachindex(left),j in eachindex(right)
        result[i+j-1]+=left[i]*right[j]
    end
    result
end

function poly_pow(poly,exponent)
    result=[1+0*poly[1]]
    for _ in 1:exponent
        result=poly_mul(result,poly)
    end
    result
end

function factor_product(roots,exponents)
    result=[1+0*roots[1]]
    for (root,exponent) in zip(roots,exponents)
        result=poly_mul(result,poly_pow([-root,1],exponent))
    end
    result
end

function coefficient_expressions(scales=ones(23);normalization=(4,2,1))
    length(scales)==23 || error("expected 23 root-coordinate scales")
    sort(collect(normalization))==[1,2,4] ||
        error("normalization must permute (4,2,1)")
    values=[scales[i]*ROOT_VARIABLES[i] for i in 1:23]
    av=values[1]
    p_roots=vcat(values[2:3],[0,1])
    p_exponents=[8,8,normalization[1],normalization[2]]
    f_roots=values[4:8]
    q_roots=values[9:23]
    P=av.*factor_product(p_roots,p_exponents)
    F=factor_product(f_roots,[8,8,4,2,1])
    Q=factor_product(q_roots,vcat(fill(2,8),fill(1,7)))
    # When the point at infinity has multiplicity 2 or 4, P has degree 21 or
    # 19 rather than 22. Pad its missing high coefficients with symbolic zero.
    padded_P=vcat(P,[0*P[1] for _ in 1:(23-length(P))])
    [padded_P[i]+F[i]-Q[i] for i in 1:23]
end

function vandermonde(roots)
    value=1+0*roots[1]
    for i in eachindex(roots),j in (i+1):length(roots)
        value*=roots[i]-roots[j]
    end
    value
end

function saturation_values(root_values)
    length(root_values)==23 || error("expected 23 root coordinates")
    p=vcat(root_values[2:3],[0,1])
    f=root_values[4:8]
    q=root_values[9:23]
    pf=prod(a-b for a in p for b in f)
    [root_values[1],vandermonde(p),vandermonde(f),vandermonde(q),pf]
end

function strong_saturation_values(root_values)
    length(root_values)==23 || error("expected 23 root coordinates")
    p=vcat(root_values[2:3],[0,1])
    f=root_values[4:8]
    q=root_values[9:23]
    pq=prod(a-b for a in p for b in q)
    fq=prod(a-b for a in f for b in q)
    vcat(saturation_values(root_values),[pq,fq])
end

function saturated_expressions(scales=ones(28),saturation_scales=ones(5);
                               normalization=(4,2,1))
    length(scales)==28 || error("expected 28 coordinate scales")
    length(saturation_scales)==5 || error("expected five saturation scales")
    roots=[scales[i]*ROOT_VARIABLES[i] for i in 1:23]
    inverses=[scales[23+i]*SATURATION_VARIABLES[i] for i in 1:5]
    coefficients=coefficient_expressions(scales[1:23];normalization=normalization)
    saturations=saturation_values(roots)
    vcat(coefficients,
         [inverses[i]*saturations[i]/saturation_scales[i]-1 for i in 1:5])
end

saturated_system(scales=ones(28),saturation_scales=ones(5);
                 normalization=(4,2,1))=
    System(saturated_expressions(scales,saturation_scales;
                                 normalization=normalization);
           variables=vcat(ROOT_VARIABLES,SATURATION_VARIABLES))

function strong_saturated_expressions(
    scales=ones(30),
    saturation_scales=ones(7);
    normalization=(4,2,1),
)
    length(scales)==30 || error("expected 30 coordinate scales")
    length(saturation_scales)==7 ||
        error("expected seven saturation scales")
    roots=[scales[i]*ROOT_VARIABLES[i] for i in 1:23]
    inverses=[
        scales[23+i]*STRONG_SATURATION_VARIABLES[i] for i in 1:7
    ]
    coefficients=coefficient_expressions(
        scales[1:23];normalization=normalization)
    saturations=strong_saturation_values(roots)
    vcat(
        coefficients,
        [
            inverses[i]*saturations[i]/saturation_scales[i]-1
            for i in 1:7
        ],
    )
end

strong_saturated_system(
    scales=ones(30),
    saturation_scales=ones(7);
    normalization=(4,2,1),
)=System(
    strong_saturated_expressions(
        scales,saturation_scales;normalization=normalization);
    variables=vcat(ROOT_VARIABLES,STRONG_SATURATION_VARIABLES),
)

chordal(left,right)=abs(left-right)/sqrt((1+abs2(left))*(1+abs2(right)))
chordal_infinity(value)=inv(sqrt(1+abs2(value)))

function separation(roots;include_infinity=false)
    distances=[chordal(roots[i],roots[j])
               for i in eachindex(roots) for j in (i+1):length(roots)]
    include_infinity && append!(distances,chordal_infinity.(roots))
    minimum(distances)
end

function endpoint_metrics(point;normalization=(4,2,1))
    roots=ComplexF64.(point[1:23])
    coefficients=coefficient_expressions(;normalization=normalization)
    residual=maximum(abs,System(coefficients;variables=ROOT_VARIABLES)(roots))
    av=roots[1]
    p=vcat(roots[2:3],ComplexF64[0,1])
    f=roots[4:8]
    q=roots[9:23]
    cross_pf=minimum(chordal(a,b) for a in p for b in f)
    cross_pq=minimum(chordal(a,b) for a in p for b in q)
    cross_fq=minimum(chordal(a,b) for a in f for b in q)
    (coefficient_residual=residual,
     alpha_abs=abs(av),
     p_separation=separation(p;include_infinity=true),
     f_separation=separation(f),
     q_separation=separation(q),
     pf_separation=cross_pf,
     pq_separation=cross_pq,
     fq_separation=cross_fq,
     saturation_abs=abs.(saturation_values(roots)))
end

end
