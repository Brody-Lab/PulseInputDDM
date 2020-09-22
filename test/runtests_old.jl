using Test, pulse_input_DDM, LinearAlgebra, Flatten, Parameters

n = 53

## Choice model
θ = θchoice(θz=θz(σ2_i = 0.5, B = 15., λ = -0.5, σ2_a = 50., σ2_s = 1.5,
    ϕ = 0.8, τ_ϕ = 0.05),
    bias=1., lapse=0.05)

θ, data = synthetic_data(;θ=θ, ntrials=10, rng=1)
model_gen = choiceDDM(θ, data)

@test round(loglikelihood(model_gen, n), digits=2) ≈ -3.76
@time loglikelihood(model_gen, n)
@test round(θ(data), digits=2) ≈ -3.76
@test round(norm(gradient(model_gen, n)), digits=2) ≈ 13.7

options = choiceoptions(fit = vcat(trues(9)),
    lb = vcat([0., 8., -5., 0., 0., 0.01, 0.005], [-30, 0.]),
    ub = vcat([2., 30., 5., 100., 2.5, 1.2, 1.], [30, 1.]),
    x0 = vcat([0.1, 15., -0.1, 20., 0.5, 0.8, 0.008], [0.,0.01]))

model, = optimize(data, options, n; iterations=5, outer_iterations=1);
@test round(norm(Flatten.flatten(model.θ)), digits=2) ≈ 25.04

H = Hessian(model, n)
@test round(norm(H), digits=2) ≈ 9.1

CI, HPSD = CIs(H)
@test round(norm(CI), digits=2) ≈ 27478.64

## Neural model
f, ncells, ntrials, nparams = "Sigmoid", [1,2], [10,5], 4

θ = θneural(θz = θz(σ2_i = 0.5, B = 15., λ = -0.5, σ2_a = 10., σ2_s = 1.2,
    ϕ = 0.6, τ_ϕ =  0.02),
    θy=[[Sigmoid() for n in 1:N] for N in ncells], ncells=ncells,
    nparams=nparams, f=f);

data, = synthetic_data(θ, ntrials);
model_gen = neuralDDM(θ, data);

@test round(loglikelihood(model_gen, n), digits=2) ≈ -519.57
@test round(norm(gradient(model_gen, n)), digits=2) ≈ 63.56

x = pulse_input_DDM.flatten(θ)
@unpack ncells, nparams, f = θ
@test round(loglikelihood(x, data, ncells, nparams, f, n), digits=2) ≈ -519.57

θy0 = vcat(vcat(initialize_θy.(data, f)...)...)
@test round(norm(θy0), digits=2) ≈ 53.56

#deterministic model
options0 = neuraloptions(ncells=ncells,
    fit=vcat(falses(dimz), trues(sum(ncells)*nparams)),
    x0=vcat([0., 30., 0. + eps(), 0., 0., 1. - eps(), 0.008], θy0))

θ0 = unflatten(options0.x0, ncells, nparams, f)
model0 = neuralDDM(θ0, data)

@test round(loglikelihood(model0), digits=2) ≈ -533.09
x0 = pulse_input_DDM.flatten(θ0)
@unpack ncells, nparams, f = θ0
@test round(loglikelihood(x0, data, ncells, nparams, f), digits=2) ≈ -533.09

model, = optimize(data, options0; iterations=2, outer_iterations=1)
@test round(norm(pulse_input_DDM.flatten(model.θ)), digits=2) ≈ 61.28 #new init

@test round(norm(gradient(model)), digits=2) ≈ 2.36

options = neuraloptions(ncells=ncells, x0=pulse_input_DDM.flatten(model.θ))

model, = optimize(data, options, n; iterations=2, outer_iterations=1)
@test round(norm(pulse_input_DDM.flatten(model.θ)), digits=2) ≈ 61.31 #new init

H = Hessian(model, n, chuck_size=4)
@test round(norm(H), digits=2) ≈ 2594.52

CI, HPSD = CIs(H)
@test round(norm(CI), digits=2) ≈ 719.83