using HomotopyContinuation
using LinearAlgebra
using Printf

include("M23Belyi8A.jl")
using .M23Belyi8A

function main(args)
    isempty(args) && error("usage: run_continuation.jl SEED.tsv [PATHS] [E0,E1,EINF] [PERTURB]")
    seed_path=args[1]
    paths=length(args)>=2 ? parse(Int,args[2]) : 8
    normalization=length(args)>=3 ? Tuple(parse.(Int,split(args[3],','))) : (4,2,1)
    perturb=length(args)>=4 ? parse(Float64,args[4]) : 0.0
    perturb>=0 || error("PERTURB must be nonnegative")
    paths>=0 || error("PATHS must be nonnegative")
    point=read_seed(seed_path)
    coordinate_scales=max.(abs.(point),1e-12)
    # Alternate row and column equilibration at the seed.  Updating a
    # coordinate scale multiplies the corresponding Jacobian column while the
    # represented geometric point remains unchanged.
    for _ in 1:4
        scaled_point=point./coordinate_scales
        trial_expressions=reduced_expressions(coordinate_scales;
                                              normalization=normalization)
        trial_system=System(trial_expressions;
                            variables=M23Belyi8A.REDUCED_VARIABLES)
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
        scaled_point += perturb.*[cis(2*pi*i*i/17) for i in 1:16]
    end
    raw_expressions=reduced_expressions(coordinate_scales;
                                        normalization=normalization)
    raw_target=System(raw_expressions;variables=M23Belyi8A.REDUCED_VARIABLES)
    raw_values=raw_target(scaled_point)
    raw_jacobian=jacobian(raw_target,scaled_point)
    equation_scales=[max(norm(raw_jacobian[row,:]),1.0)
                     for row in 1:size(raw_jacobian,1)]
    expressions=[raw_expressions[i]/equation_scales[i]
                 for i in eachindex(raw_expressions)]
    target=System(expressions;variables=M23Belyi8A.REDUCED_VARIABLES)
    setprecision(BigFloat,256)
    tracking_point=Complex{BigFloat}.(scaled_point)
    start=System([M23Belyi8A.REDUCED_VARIABLES[i]-tracking_point[i]
                  for i in eachindex(expressions)];
                 variables=M23Belyi8A.REDUCED_VARIABLES)
    singular_values=svdvals(jacobian(target,scaled_point))
    @printf("seed=%s equations=%d variables=%d perturb=%.17e start_residual=%.17e target_residual=%.17e\n",
            seed_path,length(expressions),length(point),perturb,
            residual_norm(start,tracking_point),residual_norm(target,tracking_point))
    @printf("jacobian_max=%.17e jacobian_min=%.17e jacobian_condition=%.17e\n",
            first(singular_values),last(singular_values),
            first(singular_values)/last(singular_values))
    for path_number in 1:paths
        angle=2*pi*(path_number-0.5)/paths
        gamma=cis(angle)
        result=solve(start,target,[tracking_point];gamma=gamma,
                     seed=UInt32(0x8a000000+path_number),show_progress=false,
                     compile=:none,
                     tracker_options=TrackerOptions(max_steps=500,
                                                    min_step_size=1e-30,
                                                    terminate_cond=1e18),
                     endgame_options=EndgameOptions(max_endgame_steps=1000,
                                                    max_endgame_extended_steps=200))
        path=only(path_results(result))
        endpoint=coordinate_scales.*solution(path)
        metrics=endpoint_metrics(endpoint;normalization=normalization)
        @printf("path=%d gamma_angle=%.17g code=%s t=%.17g residual=%.17e condition=%.17e singular=%s accepted=%d rejected=%d endgame=%d extended=%s endpoint_norm=%.17e\n",
                path_number,angle,string(path.return_code),path.t,path.residual,
                path.condition_jacobian,string(path.singular),path.accepted_steps,
                path.rejected_steps,path.steps_eg,string(path.extended_precision_used),
                maximum(abs,endpoint))
        @printf("path=%d winding=%s valuation_min=%.17e valuation_max=%.17e division_residual=%.17e p_separation=%.17e f_separation=%.17e q_separation=%.17e pf_separation=%.17e\n",
                path_number,string(path.winding_number),minimum(path.valuation),
                maximum(path.valuation),metrics.division_residual,
                metrics.p_separation,metrics.f_separation,
                metrics.q_separation,metrics.pf_separation)
        if path.return_code == :success
            certification=certify(target,[solution(path)];compile=false,
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
