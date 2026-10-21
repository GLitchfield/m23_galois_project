using HomotopyContinuation
using LinearAlgebra
using Printf

include("M23Belyi8A.jl")
using .M23Belyi8A

@var homogenizer inverse_alpha

function homogenize_to_degree(expression,variables,degree)
    expand(homogenizer^degree*
           subs(expression,variables=>variables./homogenizer))
end

function main(args)
    isempty(args) && error("usage: run_full_continuation.jl SEED.tsv [PATHS] [E0,E1,EINF] [PERTURB] [ANGLE] [REGULARIZATION] [MODE] [ENDPOINT_PREFIX]")
    seed_path=args[1]
    paths=length(args)>=2 ? parse(Int,args[2]) : 8
    normalization=length(args)>=3 ? Tuple(parse.(Int,split(args[3],','))) : (4,2,1)
    perturb=length(args)>=4 ? parse(Float64,args[4]) : 0.0
    angle_override=length(args)>=5 ? parse(Float64,args[5]) : nothing
    regularization=length(args)>=6 ? parse(Float64,args[6]) : 0.0
    mode=length(args)>=7 ? Symbol(args[7]) : :affine
    endpoint_prefix=length(args)>=8 ? args[8] : nothing
    mode in (:affine,:projective,:affine_alpha,:projective_alpha) ||
        error("MODE must be affine, projective, affine_alpha, or projective_alpha")
    is_projective=mode in (:projective,:projective_alpha)
    saturate_alpha=mode in (:affine_alpha,:projective_alpha)
    regularization>=0 || error("REGULARIZATION must be nonnegative")
    perturb>=0 || error("PERTURB must be nonnegative")
    paths>=0 || error("PATHS must be nonnegative")
    point=read_seed(seed_path;names=M23Belyi8A.FULL_NAMES)
    coordinate_scales=max.(abs.(point),1e-12)
    # Alternate row and column equilibration at the seed.  Updating a
    # coordinate scale multiplies the corresponding Jacobian column while the
    # represented geometric point remains unchanged.
    for _ in 1:4
        scaled_point=point./coordinate_scales
        trial_expressions=full_expressions(coordinate_scales;
                                           normalization=normalization)
        trial_system=System(trial_expressions;
                            variables=M23Belyi8A.FULL_VARIABLES)
        trial_jacobian=jacobian(trial_system,scaled_point)
        row_norms=[max(norm(trial_jacobian[row,:]),1e-300)
                   for row in 1:size(trial_jacobian,1)]
        row_scaled=trial_jacobian./reshape(row_norms,:,1)
        column_norms=[max(norm(row_scaled[:,column]),1e-300)
                      for column in 1:size(row_scaled,2)]
        coordinate_scales ./= column_norms
    end
    scaled_point=point./coordinate_scales
    if perturb>0
        scaled_point += perturb.*[cis(2*pi*i*i/24) for i in 1:length(point)]
    end
    raw_expressions=full_expressions(coordinate_scales;
                                     normalization=normalization)
    raw_target=System(raw_expressions;variables=M23Belyi8A.FULL_VARIABLES)
    raw_values=raw_target(scaled_point)
    raw_jacobian=jacobian(raw_target,scaled_point)
    equation_scales=[max(norm(raw_jacobian[row,:]),1.0)
                     for row in 1:size(raw_jacobian,1)]
    expressions=[raw_expressions[i]/equation_scales[i]
                 for i in eachindex(raw_expressions)]
    system_expressions=copy(expressions)
    system_variables=copy(M23Belyi8A.FULL_VARIABLES)
    system_point=ComplexF64.(scaled_point)
    if saturate_alpha
        push!(system_expressions,
              coordinate_scales[1]*M23Belyi8A.FULL_VARIABLES[1]*inverse_alpha-1)
        push!(system_variables,inverse_alpha)
        push!(system_point,inv(point[1]))
    end
    affine_target=System(system_expressions;variables=system_variables)
    setprecision(BigFloat,256)
    affine_tracking_point=Complex{BigFloat}.(system_point)
    target_values=affine_target(affine_tracking_point)
    start_expressions=[system_expressions[i]-target_values[i] +
                       regularization*(system_variables[i]-affine_tracking_point[i])
                       for i in eachindex(system_expressions)]
    if is_projective
        degrees=[HomotopyContinuation.ModelKit.degree(
                     expression,system_variables)
                 for expression in system_expressions]
        projective_variables=vcat(system_variables,[homogenizer])
        target=System([homogenize_to_degree(system_expressions[i],
                                            system_variables,degrees[i])
                       for i in eachindex(system_expressions)];
                      variables=projective_variables)
        start=System([homogenize_to_degree(start_expressions[i],
                                           system_variables,degrees[i])
                      for i in eachindex(system_expressions)];
                     variables=projective_variables)
        tracking_point=vcat(affine_tracking_point,[one(Complex{BigFloat})])
    else
        target=affine_target
        start=System(start_expressions;variables=system_variables)
        tracking_point=affine_tracking_point
    end
    singular_values=svdvals(jacobian(affine_target,system_point))
    @printf("seed=%s mode=%s equations=%d variables=%d perturb=%.17e regularization=%.17e start_residual=%.17e target_residual=%.17e\n",
            seed_path,string(mode),length(system_expressions),length(tracking_point),perturb,regularization,
            residual_norm(start,tracking_point),residual_norm(target,tracking_point))
    @printf("jacobian_max=%.17e jacobian_min=%.17e jacobian_condition=%.17e\n",
            first(singular_values),last(singular_values),
            first(singular_values)/last(singular_values))
    for path_number in 1:paths
        angle=isnothing(angle_override) ? 2*pi*(path_number-0.5)/paths : angle_override
        gamma=cis(angle)
        result=solve(start,target,[tracking_point];gamma=gamma,
                     seed=UInt32(0x8a000000+path_number),show_progress=false,
                     compile=:none,
                     tracker_options=TrackerOptions(max_steps=500,
                                                    min_step_size=1e-100,
                                                    terminate_cond=1e18),
                     endgame_options=EndgameOptions(endgame_start=0.2,
                                                    min_cond=1e4,
                                                    min_cond_growth=10.0,
                                                    singular_min_accuracy=1e-5,
                                                    max_winding_number=16,
                                                    max_endgame_steps=3000,
                                                    max_endgame_extended_steps=1000))
        path=only(path_results(result))
        tracked_solution=solution(path)
        homogenizer_abs=is_projective ? abs(last(tracked_solution)) : 1.0
        affine_solution=is_projective ?
            tracked_solution[1:length(system_variables)]./tracked_solution[end] :
            tracked_solution
        endpoint=coordinate_scales.*affine_solution[1:23]
        metrics=endpoint_metrics(endpoint;normalization=normalization)
        endpoint_singular_values=svdvals(jacobian(
            affine_target,ComplexF64.(affine_solution)))
        endpoint_condition=first(endpoint_singular_values)/last(endpoint_singular_values)
        relative_singular_values=endpoint_singular_values./first(endpoint_singular_values)
        ranks=[count(>=(threshold),relative_singular_values)
               for threshold in (1e-8,1e-12,1e-16)]
        @printf("path=%d gamma_angle=%.17g code=%s t=%.17g residual=%.17e condition=%.17e singular=%s accepted=%d rejected=%d endgame=%d extended=%s endpoint_norm=%.17e homogenizer_abs=%.17e\n",
                path_number,angle,string(path.return_code),path.t,path.residual,
                path.condition_jacobian,string(path.singular),path.accepted_steps,
                path.rejected_steps,path.steps_eg,string(path.extended_precision_used),
                maximum(abs,endpoint),homogenizer_abs)
        valuation_min=isnothing(path.valuation) ? NaN : minimum(path.valuation)
        valuation_max=isnothing(path.valuation) ? NaN : maximum(path.valuation)
        @printf("path=%d winding=%s valuation_min=%.17e valuation_max=%.17e division_residual=%.17e p_separation=%.17e f_separation=%.17e q_separation=%.17e pf_separation=%.17e\n",
                path_number,string(path.winding_number),valuation_min,
                valuation_max,metrics.division_residual,
                metrics.p_separation,metrics.f_separation,
                metrics.q_separation,metrics.pf_separation)
        @printf("path=%d endpoint_jacobian_min=%.17e endpoint_jacobian_condition=%.17e rank_1e8=%d rank_1e12=%d rank_1e16=%d\n",
                path_number,last(endpoint_singular_values),endpoint_condition,
                ranks...)
        if !isnothing(endpoint_prefix)
            output_path="$(endpoint_prefix)-path$(path_number).tsv"
            open(output_path,"w") do io
                println(io,"# format=m23_8a_continuation_endpoint_v1")
                println(io,"# seed=",seed_path)
                println(io,"# normalization=",join(normalization,','))
                println(io,"# gamma_angle=",repr(angle))
                println(io,"# regularization=",repr(regularization))
                println(io,"# mode=",string(mode))
                println(io,"# homogenizer_abs=",repr(homogenizer_abs))
                println(io,"name\treal\timag")
                for (name,value) in zip(M23Belyi8A.FULL_NAMES,endpoint)
                    println(io,name,'\t',repr(real(value)),'\t',repr(imag(value)))
                end
                saturate_alpha && println(io,"inverse_alpha",'\t',
                                          repr(real(affine_solution[end])),'\t',
                                          repr(imag(affine_solution[end])))
            end
            println("path=",path_number," endpoint_file=",output_path)
        end
        minimum_separation=min(metrics.p_separation,metrics.f_separation,
                               metrics.q_separation,metrics.pf_separation)
        if path.return_code == :success ||
                (metrics.division_residual<1e-10 && minimum_separation>1e-8)
            certification=certify(affine_target,[affine_solution];compile=false,
                                  max_precision=1024,show_progress=false)
            certificate=only(certificates(certification))
            @printf("path=%d certified=%s\n",path_number,
                    string(is_certified(certificate)))
        else
            @printf("path=%d certified=skipped_non_success\n",path_number)
        end
    end
end

main(ARGS)
