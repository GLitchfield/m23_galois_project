using Test
using HomotopyContinuation

include("M23Belyi8A.jl")
using .M23Belyi8A
include("M23Belyi8ARoots.jl")
import .M23Belyi8ARoots

@testset "continuation fixture" begin
    @var x
    target=System([x^2-2];variables=[x])
    start=System([x^2-1];variables=[x])
    result=solve(start,target,[[1.0+0im]];
                 gamma=cis(0.7),seed=UInt32(0x8a),show_progress=false)
    path=only(path_results(result))
    @test path.return_code == :success
    @test path.residual < 1e-12
    @test abs(only(solution(path))-sqrt(2)) < 1e-12
end

@testset "parameter homotopy waypoint capability" begin
    @var waypoint_x waypoint_parameter
    family=System([waypoint_x^2-waypoint_parameter];
                  variables=[waypoint_x],parameters=[waypoint_parameter])
    point=ComplexF64[1]
    current=ComplexF64[1]
    for target in (ComplexF64[1+im],ComplexF64[2])
        result=solve(family,[point];start_parameters=current,
                     target_parameters=target,seed=UInt32(0x8a74),
                     threading=false,show_progress=false)
        path=only(path_results(result))
        @test path.return_code == :success
        @test path.residual < 1e-12
        point=solution(path)
        current=target
    end
    @test abs(only(point)^2-2) < 1e-12
end

@testset "parameter monodromy and transport capability" begin
    @var monodromy_x monodromy_parameter
    family=System([monodromy_x^2-monodromy_parameter];
                  variables=[monodromy_x],parameters=[monodromy_parameter])
    monodromy=monodromy_solve(
        family,[[1+0im]],ComplexF64[1];seed=UInt32(0x8a74),
        target_solutions_count=2,max_loops_no_progress=20,
        duplicate_check=:certified,permutations=true,threading=false,
        show_progress=false)
    @test monodromy.returncode == :success
    @test nsolutions(monodromy) == 2
    @test ncertified_distinct(monodromy) == 2
    @test all(abs(only(point)^2-1)<1e-12 for point in solutions(monodromy))

    transported=solve(family,monodromy;target_parameters=ComplexF64[2],
                      seed=UInt32(0x8a75),threading=false,
                      show_progress=false)
    @test nsolutions(transported) == 2
    @test all(abs(only(point)^2-2)<1e-12 for point in solutions(transported))
end

@testset "root and coefficient formulations agree" begin
    roots=ComplexF64[0.7,2,3,4,5,6,7,8,
                     9,10,11,12,13,14,15,16,
                     17,18,19,20,21,22,23]
    A=M23Belyi8A.poly_mul([-roots[2],1],[-roots[3],1])
    B=M23Belyi8A.poly_mul([-roots[4],1],[-roots[5],1])
    U=foldl(M23Belyi8A.poly_mul,([-root,1] for root in roots[9:16]))
    V=foldl(M23Belyi8A.poly_mul,([-root,1] for root in roots[17:23]))
    coefficients=ComplexF64[roots[1],A[1],A[2],B[1],B[2],roots[6:8]...,
                            U[1:8]...,V[1:7]...]
    for chart in ((4,2,1),(4,1,2),(2,4,1),(2,1,4),(1,4,2),(1,2,4))
        root_values=System(M23Belyi8ARoots.coefficient_expressions(
                               ;normalization=chart);
                           variables=M23Belyi8ARoots.ROOT_VARIABLES)(roots)
        @test root_values≈full_system(;normalization=chart)(coefficients) rtol=1e-12
    end
end

@testset "five-factor root saturation" begin
    roots=ComplexF64[0.7,2,3,4,5,6,7,8,
                     9,10,11,12,13,14,15,16,
                     17,18,19,20,21,22,23]
    scales=M23Belyi8ARoots.saturation_values(roots)
    system=M23Belyi8ARoots.saturated_system(ones(28),scales)
    values=system(vcat(roots,ones(ComplexF64,5)))
    @test length(system)==28
    @test length(M23Belyi8ARoots.ROOT_VARIABLES)==23
    @test values[24:28]≈zeros(ComplexF64,5) atol=1e-12
end

@testset "seven-factor strong root saturation" begin
    roots=ComplexF64[0.7,2,3,4,5,6,7,8,
                     9,10,11,12,13,14,15,16,
                     17,18,19,20,21,22,23]
    scales=M23Belyi8ARoots.strong_saturation_values(roots)
    system=M23Belyi8ARoots.strong_saturated_system(ones(30),scales)
    values=system(vcat(roots,ones(ComplexF64,7)))
    @test length(system)==30
    @test length(M23Belyi8ARoots.STRONG_SATURATION_VARIABLES)==7
    @test values[24:30]≈zeros(ComplexF64,7) atol=1e-12
    metrics=M23Belyi8ARoots.endpoint_metrics(roots)
    @test metrics.pq_separation>0
    @test metrics.fq_separation>0
end

@testset "reduced 8A system shape" begin
    expressions=reduced_expressions()
    system=reduced_system()
    @test length(expressions)==16
    @test length(M23Belyi8A.REDUCED_VARIABLES)==16
    @test length(system)==16
end

@testset "full coefficient 8A system shape" begin
    expressions=full_expressions()
    system=full_system()
    @test length(expressions)==23
    @test length(M23Belyi8A.FULL_VARIABLES)==23
    @test length(system)==23
end

@testset "full coefficient identity fixture" begin
    B=[2,3,1]
    U=M23Belyi8A.poly_pow(B,4)
    V=M23Belyi8A.poly_mul(
        M23Belyi8A.poly_pow([-4,1],4),
        M23Belyi8A.poly_mul(M23Belyi8A.poly_pow([-5,1],2),[-6,1]))
    point=ComplexF64[0,7,8,2,3,4,5,6,U[1:8]...,V[1:7]...]
    @test residual_norm(full_system(),point)==0
    @test endpoint_metrics(point).division_residual==0
end
