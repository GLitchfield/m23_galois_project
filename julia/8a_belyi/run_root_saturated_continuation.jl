using HomotopyContinuation
using LinearAlgebra
using Printf
using SHA

include("M23Belyi8A.jl")
using .M23Belyi8A: read_seed, residual_norm
include("M23Belyi8ARoots.jl")
import .M23Belyi8ARoots

function main(args)
    isempty(args) && error("usage: run_root_saturated_continuation.jl ROOT_SEED.tsv [PATHS] [E0,E1,EINF] [ANGLE] [REGULARIZATION] [ENDPOINT_PREFIX] [five|strong]")
    seed_path=args[1]
    paths=length(args)>=2 ? parse(Int,args[2]) : 4
    normalization=length(args)>=3 ? Tuple(parse.(Int,split(args[3],','))) : (4,2,1)
    angle_override=length(args)>=4 ? parse(Float64,args[4]) : nothing
    regularization=length(args)>=5 ? parse(Float64,args[5]) : 0.0
    endpoint_prefix=length(args)>=6 ? args[6] : nothing
    saturation_mode=length(args)>=7 ? Symbol(args[7]) : :five
    paths>=0 || error("PATHS must be nonnegative")
    regularization>=0 || error("REGULARIZATION must be nonnegative")
    saturation_mode in (:five,:strong) ||
        error("saturation mode must be five or strong")

    root_point=read_seed(seed_path;names=M23Belyi8ARoots.ROOT_NAMES)
    strong=saturation_mode==:strong
    saturation_value_function=strong ?
        M23Belyi8ARoots.strong_saturation_values :
        M23Belyi8ARoots.saturation_values
    expression_function=strong ?
        M23Belyi8ARoots.strong_saturated_expressions :
        M23Belyi8ARoots.saturated_expressions
    saturation_variables=strong ?
        M23Belyi8ARoots.STRONG_SATURATION_VARIABLES :
        M23Belyi8ARoots.SATURATION_VARIABLES
    saturation_names=strong ?
        M23Belyi8ARoots.STRONG_SATURATION_NAMES :
        M23Belyi8ARoots.SATURATION_NAMES
    saturation_scales=saturation_value_function(root_point)
    minimum(abs,saturation_scales)>0 || error("seed is degenerate")
    point=vcat(root_point,ones(ComplexF64,length(saturation_variables)))
    variables=vcat(M23Belyi8ARoots.ROOT_VARIABLES,
                   saturation_variables)
    coordinate_scales=max.(abs.(point),1e-12)
    for _ in 1:4
        scaled_point=point./coordinate_scales
        trial_expressions=expression_function(
            coordinate_scales,saturation_scales;normalization=normalization)
        trial_system=System(trial_expressions;variables=variables)
        trial_jacobian=jacobian(trial_system,scaled_point)
        row_norms=[max(norm(trial_jacobian[row,:]),1e-300)
                   for row in 1:size(trial_jacobian,1)]
        row_scaled=trial_jacobian./reshape(row_norms,:,1)
        column_norms=[max(norm(row_scaled[:,column]),1e-300)
                      for column in 1:size(row_scaled,2)]
        coordinate_scales./=column_norms
    end
    scaled_point=point./coordinate_scales
    raw_expressions=expression_function(
        coordinate_scales,saturation_scales;normalization=normalization)
    raw_target=System(raw_expressions;variables=variables)
    raw_jacobian=jacobian(raw_target,scaled_point)
    equation_scales=[max(norm(raw_jacobian[row,:]),1.0)
                     for row in 1:size(raw_jacobian,1)]
    expressions=[raw_expressions[i]/equation_scales[i]
                 for i in eachindex(raw_expressions)]
    target=System(expressions;variables=variables)

    setprecision(BigFloat,256)
    tracking_point=Complex{BigFloat}.(scaled_point)
    target_values=target(tracking_point)
    start=System([expressions[i]-target_values[i] +
                  regularization*(variables[i]-tracking_point[i])
                  for i in eachindex(expressions)];variables=variables)
    singular_values=svdvals(jacobian(target,scaled_point))
    @printf("seed=%s saturation_mode=%s equations=%d variables=%d regularization=%.17e start_residual=%.17e target_residual=%.17e\n",
            seed_path,string(saturation_mode),length(expressions),
            length(variables),regularization,
            residual_norm(start,tracking_point),residual_norm(target,tracking_point))
    @printf("jacobian_max=%.17e jacobian_min=%.17e jacobian_condition=%.17e saturation_scale_min=%.17e saturation_scale_max=%.17e\n",
            first(singular_values),last(singular_values),
            first(singular_values)/last(singular_values),
            minimum(abs,saturation_scales),maximum(abs,saturation_scales))

    for path_number in 1:paths
        angle=isnothing(angle_override) ? 2*pi*(path_number-0.5)/paths : angle_override
        gamma=cis(angle)
        result=solve(start,target,[tracking_point];gamma=gamma,
                     seed=UInt32(0x8af00000+path_number),show_progress=false,
                     compile=:none,
                     tracker_options=TrackerOptions(max_steps=800,
                                                    min_step_size=1e-100,
                                                    terminate_cond=1e18),
                     endgame_options=EndgameOptions(endgame_start=0.2,
                                                    min_cond=1e4,
                                                    min_cond_growth=10.0,
                                                    singular_min_accuracy=1e-5,
                                                    max_winding_number=16,
                                                    max_endgame_steps=4000,
                                                    max_endgame_extended_steps=1200))
        path=only(path_results(result))
        affine_solution=solution(path)
        endpoint=coordinate_scales.*affine_solution
        metrics=M23Belyi8ARoots.endpoint_metrics(endpoint;
                                                 normalization=normalization)
        endpoint_singular_values=svdvals(jacobian(target,
                                                   ComplexF64.(affine_solution)))
        endpoint_condition=first(endpoint_singular_values)/last(endpoint_singular_values)
        relative_singular_values=endpoint_singular_values./first(endpoint_singular_values)
        ranks=[count(>=(threshold),relative_singular_values)
               for threshold in (1e-8,1e-12,1e-16)]
        minimum_separation=min(metrics.p_separation,metrics.f_separation,
                               metrics.q_separation,metrics.pf_separation,
                               metrics.pq_separation,metrics.fq_separation)
        inverse_norm=maximum(abs,endpoint[24:end])
        @printf("path=%d gamma_angle=%.17g code=%s t=%.17g residual=%.17e accepted=%d rejected=%d endgame=%d extended=%s endpoint_norm=%.17e inverse_norm=%.17e\n",
                path_number,angle,string(path.return_code),path.t,path.residual,
                path.accepted_steps,path.rejected_steps,path.steps_eg,
                string(path.extended_precision_used),maximum(abs,endpoint[1:23]),
                inverse_norm)
        @printf("path=%d coefficient_residual=%.17e alpha_abs=%.17e p_separation=%.17e f_separation=%.17e q_separation=%.17e pf_separation=%.17e pq_separation=%.17e fq_separation=%.17e saturation_min=%.17e saturation_max=%.17e\n",
                path_number,metrics.coefficient_residual,metrics.alpha_abs,
                metrics.p_separation,metrics.f_separation,metrics.q_separation,
                metrics.pf_separation,metrics.pq_separation,
                metrics.fq_separation,minimum(metrics.saturation_abs),
                maximum(metrics.saturation_abs))
        @printf("path=%d endpoint_jacobian_min=%.17e endpoint_jacobian_condition=%.17e rank_1e8=%d rank_1e12=%d rank_1e16=%d\n",
                path_number,last(endpoint_singular_values),endpoint_condition,
                ranks...)
        certification_status="skipped_failed_gate"
        if path.return_code==:success && metrics.coefficient_residual<1e-10 &&
                minimum_separation>1e-8 && metrics.alpha_abs>1e-8
            certification=certify(target,[affine_solution];compile=false,
                                  max_precision=1024,show_progress=false)
            certificate=only(certificates(certification))
            certification_status=string(is_certified(certificate))
        end
        @printf("path=%d certified=%s\n",path_number,certification_status)
        if !isnothing(endpoint_prefix)
            output_path="$(endpoint_prefix)-path$(path_number).tsv"
            open(output_path,"w") do io
                println(io,"# format=m23_8a_root_saturated_endpoint_v2")
                println(io,"# code_revision=",readchomp(`git rev-parse HEAD`))
                println(io,"# seed=",seed_path)
                println(io,"# seed_sha256=",bytes2hex(sha256(read(seed_path))))
                println(io,"# normalization=",join(normalization,','))
                println(io,"# gamma_angle=",repr(angle))
                println(io,"# regularization=",repr(regularization))
                println(io,"# saturation_mode=",string(saturation_mode))
                println(io,"# julia_version=",string(VERSION))
                println(io,"# HomotopyContinuation_version=",
                        string(pkgversion(HomotopyContinuation)))
                println(io,"# return_code=",string(path.return_code))
                println(io,"# homotopy_parameter=",repr(path.t))
                println(io,"# path_residual=",repr(path.residual))
                println(io,"# accepted_steps=",path.accepted_steps)
                println(io,"# rejected_steps=",path.rejected_steps)
                println(io,"# endgame_steps=",path.steps_eg)
                println(io,"# extended_precision=",
                        string(path.extended_precision_used))
                println(io,"# coefficient_residual=",
                        repr(metrics.coefficient_residual))
                println(io,"# minimum_chordal_separation=",
                        repr(minimum_separation))
                println(io,"# endpoint_jacobian_condition=",
                        repr(endpoint_condition))
                println(io,"# certified=",certification_status)
                println(io,"name\treal\timag")
                names=vcat(M23Belyi8ARoots.ROOT_NAMES,
                           saturation_names)
                for (name,value) in zip(names,endpoint)
                    println(io,name,'\t',repr(real(value)),'\t',repr(imag(value)))
                end
            end
            println("path=",path_number," endpoint_file=",output_path)
        end
    end
end

main(ARGS)
