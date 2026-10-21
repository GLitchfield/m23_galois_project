module M23Belyi8A

using HomotopyContinuation
using LinearAlgebra

export REDUCED_NAMES, REDUCED_VARIABLES, FULL_NAMES, FULL_VARIABLES,
       reduced_expressions, reduced_system, full_expressions, full_system,
       read_seed, residual_norm
export endpoint_metrics

@var alpha a0 a1 b0 b1 c4 c2 c1 u0 u1 u2 u3 u4 u5 u6 u7
@var v0 v1 v2 v3 v4 v5 v6

const REDUCED_VARIABLES = [alpha,a0,a1,b0,b1,c4,c2,c1,
                           u0,u1,u2,u3,u4,u5,u6,u7]
const REDUCED_NAMES = ["alpha","a0","a1","b0","b1","c4","c2","c1",
                       "u0","u1","u2","u3","u4","u5","u6","u7"]
const FULL_VARIABLES = vcat(REDUCED_VARIABLES,[v0,v1,v2,v3,v4,v5,v6])
const FULL_NAMES = vcat(REDUCED_NAMES,["v0","v1","v2","v3","v4","v5","v6"])

function poly_mul(left,right)
    result=[0*left[1]*right[1] for _ in 1:(length(left)+length(right)-1)]
    for i in eachindex(left), j in eachindex(right)
        result[i+j-1] += left[i]*right[j]
    end
    result
end

function poly_pow(poly,exponent)
    result=[1+0*poly[1]]
    base=poly
    n=exponent
    while n>0
        isodd(n) && (result=poly_mul(result,base))
        n >>= 1
        n>0 && (base=poly_mul(base,base))
    end
    result
end

function poly_add(left,right)
    zero_value=0*left[1]*right[1]
    result=[zero_value for _ in 1:max(length(left),length(right))]
    for i in eachindex(left); result[i]+=left[i]; end
    for i in eachindex(right); result[i]+=right[i]; end
    result
end

function monic_remainder(dividend,divisor)
    degree=length(divisor)-1
    @assert divisor[end] == 1
    result=copy(dividend)
    for k in (length(result)-1):-1:degree
        lead=result[k+1]
        shift=k-degree
        for j in 0:degree
            result[shift+j+1] -= lead*divisor[j+1]
        end
    end
    result[1:degree]
end

function derivative(poly)
    [(i-1)*poly[i] for i in 2:length(poly)]
end

function reduced_expressions(scales=ones(16);normalization=(4,2,1))
    length(scales)==16 || error("expected 16 coordinate scales")
    sort(collect(normalization))==[1,2,4] ||
        error("normalization must permute (4,2,1)")
    av,a0v,a1v,b0v,b1v,c4v,c2v,c1v,
        u0v,u1v,u2v,u3v,u4v,u5v,u6v,u7v =
        [scales[i]*REDUCED_VARIABLES[i] for i in 1:16]
    A=[a0v,a1v,1]
    B=[b0v,b1v,1]
    P=poly_mul([av],poly_mul(poly_pow(A,8),
        poly_mul(poly_pow([0,1],normalization[1]),
                 poly_pow([-1,1],normalization[2]))))
    F=poly_pow(B,8)
    for (root,exponent) in ((c4v,4),(c2v,2),(c1v,1))
        F=poly_mul(F,poly_pow([-root,1],exponent))
    end
    H=poly_add(P,F)
    U=[u0v,u1v,u2v,u3v,u4v,u5v,u6v,u7v,1]
    vcat(monic_remainder(H,U),monic_remainder(derivative(H),U))
end

reduced_system(scales=ones(16);normalization=(4,2,1))=
    System(reduced_expressions(scales;normalization=normalization);
           variables=REDUCED_VARIABLES)

function full_expressions(scales=ones(23);normalization=(4,2,1))
    length(scales)==23 || error("expected 23 coordinate scales")
    sort(collect(normalization))==[1,2,4] ||
        error("normalization must permute (4,2,1)")
    values=[scales[i]*FULL_VARIABLES[i] for i in 1:23]
    av,a0v,a1v,b0v,b1v,c4v,c2v,c1v=values[1:8]
    A=[a0v,a1v,1]
    B=[b0v,b1v,1]
    P=poly_mul([av],poly_mul(poly_pow(A,8),
        poly_mul(poly_pow([0,1],normalization[1]),
                 poly_pow([-1,1],normalization[2]))))
    F=poly_pow(B,8)
    for (root,exponent) in ((c4v,4),(c2v,2),(c1v,1))
        F=poly_mul(F,poly_pow([-root,1],exponent))
    end
    H=poly_add(P,F)
    U=vcat(values[9:16],[1])
    V=vcat(values[17:23],[1])
    Q=poly_mul(poly_mul(U,U),V)
    # Both degree-23 leading coefficients are one and cancel identically.
    [H[i]-Q[i] for i in 1:23]
end

full_system(scales=ones(23);normalization=(4,2,1))=
    System(full_expressions(scales;normalization=normalization);
           variables=FULL_VARIABLES)

function read_seed(path;names=REDUCED_NAMES)
    values=Dict{String,ComplexF64}()
    for line in eachline(path)
        (isempty(line) || startswith(line,"#") || startswith(line,"name\t")) && continue
        fields=split(line,'\t')
        length(fields)==3 || error("malformed seed row: $line")
        values[fields[1]]=parse(Float64,fields[2])+im*parse(Float64,fields[3])
    end
    missing=setdiff(names,collect(keys(values)))
    isempty(missing) || error("seed is missing variables: $(join(missing,','))")
    [values[name] for name in names]
end

residual_norm(system,point)=maximum(abs,system(point))

function monic_divrem(dividend,divisor)
    degree=length(divisor)-1
    result=ComplexF64.(dividend)
    quotient=zeros(ComplexF64,max(1,length(dividend)-length(divisor)+1))
    for k in (length(result)-1):-1:degree
        lead=result[k+1]
        shift=k-degree
        quotient[shift+1]=lead
        for j in 0:degree
            result[shift+j+1]-=lead*divisor[j+1]
        end
    end
    quotient,result[1:degree]
end

function polynomial_roots(coefficients)
    degree=length(coefficients)-1
    degree==0 && return ComplexF64[]
    monic=ComplexF64.(coefficients)./coefficients[end]
    companion=zeros(ComplexF64,degree,degree)
    for i in 1:degree-1; companion[i+1,i]=1; end
    companion[:,end] = -monic[1:degree]
    eigvals(companion)
end

chordal(left,right)=abs(left-right)/sqrt((1+abs2(left))*(1+abs2(right)))
chordal_infinity(value)=inv(sqrt(1+abs2(value)))

function fibre_separation(roots;include_infinity=false)
    distances=Float64[]
    for i in eachindex(roots),j in (i+1):length(roots)
        push!(distances,chordal(roots[i],roots[j]))
    end
    include_infinity && append!(distances,chordal_infinity.(roots))
    isempty(distances) ? Inf : minimum(distances)
end

function endpoint_metrics(point;normalization=(4,2,1))
    av,a0v,a1v,b0v,b1v,c4v,c2v,c1v,
        u0v,u1v,u2v,u3v,u4v,u5v,u6v,u7v = ComplexF64.(point[1:16])
    A=[a0v,a1v,1]
    B=[b0v,b1v,1]
    P=poly_mul([av],poly_mul(poly_pow(A,8),
        poly_mul(poly_pow([0,1],normalization[1]),
                 poly_pow([-1,1],normalization[2]))))
    F=poly_pow(B,8)
    for (root,exponent) in ((c4v,4),(c2v,2),(c1v,1))
        F=poly_mul(F,poly_pow([-root,1],exponent))
    end
    H=poly_add(P,F)
    U=ComplexF64[u0v,u1v,u2v,u3v,u4v,u5v,u6v,u7v,1]
    if length(point)==23
        V=vcat(ComplexF64.(point[17:23]),ComplexF64[1])
        Q=poly_mul(poly_mul(U,U),V)
        coefficient_error=maximum(abs,H.-Q)
    elseif length(point)==16
        quotient1,remainder1=monic_divrem(H,U)
        V,remainder2=monic_divrem(quotient1,U)
        coefficient_error=max(maximum(abs,remainder1),maximum(abs,remainder2))
    else
        error("endpoint must have 16 or 23 coordinates")
    end
    roots_a=polynomial_roots(A)
    roots_b=polynomial_roots(B)
    roots_u=polynomial_roots(U)
    roots_v=polynomial_roots(V)
    roots_p=vcat(roots_a,ComplexF64[0,1])
    roots_f=vcat(roots_b,ComplexF64[c4v,c2v,c1v])
    roots_q=vcat(roots_u,roots_v)
    cross_pf=minimum(chordal(a,b) for a in roots_p for b in roots_f)
    scale=max(maximum(abs,H),1.0)
    (division_residual=coefficient_error/scale,
     p_separation=fibre_separation(roots_p;include_infinity=true),
     f_separation=fibre_separation(roots_f),
     q_separation=fibre_separation(roots_q),
     pf_separation=cross_pf)
end

end
