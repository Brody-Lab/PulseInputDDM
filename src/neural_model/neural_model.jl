"""
"""
@with_kw struct neural_options
    fit::Vector{Bool}
    ub::Vector{Float64}
    lb::Vector{Float64}
end



"""
"""
function neural_options(f)
    
    nparams, ncells = nθparams(f)
    fit = vcat(trues(dimz), trues.(nparams)...)
        
    lb = Vector(undef, sum(ncells))
    ub = Vector(undef, sum(ncells))
    
    for i in 1:sum(ncells)
        if vcat(f...)[i] == "Softplus"
            lb[i] = [-10]
            ub[i] = [10]
        elseif vcat(f...)[i] == "Sigmoid"
            lb[i] = [-100.,0.,-10.,-10.]
            ub[i] = [100.,100.,10.,10.]
        end
    end
    lb = vcat([1e-3, 8.,  -5., 1e-3,   1e-3,  1e-3, 0.005], vcat(lb...))
    ub = vcat([100., 100., 5., 400., 10., 1.2,  1.], vcat(ub...));

    neural_options(fit=fit, ub=ub, lb=lb)
    
end
   

"""
"""
function θneural(x::Vector{T}, f::Vector{Vector{String}}) where {T <: Real}
    
    nparams, ncells = nθparams(f)
    
    borg = vcat(dimz,dimz.+cumsum(nparams))
    blah = [x[i] for i in [borg[i-1]+1:borg[i] for i in 2:length(borg)]]
    
    blah = map((f,x) -> f(x...), getfield.(Ref(@__MODULE__), Symbol.(vcat(f...))), blah)
    
    borg = vcat(0,cumsum(ncells))
    θy = [blah[i] for i in [borg[i-1]+1:borg[i] for i in 2:length(borg)]]
    
    θneural(θz(x[1:dimz]...), θy, f)

end


"""
"""
@with_kw struct θy{T1}
    θ::T1
end


"""

    neuraldata

Module-defined class for keeping data organized for the `neuralDDM` model.

Fields:

- `input_data`: stuff related to the input of the accumaltor model, i.e. clicks, etc.
- `spikes`: the binned spikes
- `ncells`: numbers of cells on that trial (should be the same for every trial in a session)
- `choice`: choice on that trial

"""
@with_kw struct neuraldata <: DDMdata
    input_data::neuralinputs
    spikes::Vector{Vector{Int}}
    ncells::Int
    choice::Bool
end


"""
"""
neuraldata(input_data, spikes::Vector{Vector{Vector{Int}}}, ncells::Int, choice) =  neuraldata.(input_data,spikes,ncells,choice)


"""
"""
@with_kw struct Sigmoid{T1} <: DDMf
    a::T1=10.
    b::T1=10.
    c::T1=1.
    d::T1=0.
end


"""
"""
(θ::Sigmoid)(x::Vector{U}, λ0::Vector{T}) where {U,T <: Real} =
    (θ::Sigmoid).(x, λ0)


"""
"""
function (θ::Sigmoid)(x::U, λ0::T) where {U,T <: Real}

    @unpack a,b,c,d = θ

    y = c * x + d
    y = a + b * logistic!(y) + λ0
    y = softplus(y)

end


@with_kw struct Softplussign{T1} <: DDMf
    #a::T1 = 0
    c::T1 = 5.0*rand([-1,1])
end


"""
"""
function (θ::Softplussign)(x::Union{U,Vector{U}}, λ0::Union{T,Vector{T}}) where {U,T <: Real}

    #@unpack a,c = θ
    @unpack c = θ

    #y = a .+ softplus.(c*x .+ d) .+ λ0
     #y = softplus.(c*x .+ a .+ λ0)
     y = softplus.(c .* sign.(x) .+ softplusinv.(λ0))
    #y = max.(eps(), y .+ λ0)
    #y = softplus.(y .+ λ0)
end

"""
   Softplus(c)

``\\lambda(a) = \\ln(1 + \\exp(c * a))``
"""
@with_kw struct Softplus{T1} <: DDMf
    #a::T1 = 0
    c::T1 = 5.0*rand([-1,1])
end


"""
"""
function (θ::Softplus)(x::Union{U,Vector{U}}, λ0::Union{T,Vector{T}}) where {U,T <: Real}

    #@unpack a,c = θ
    @unpack c = θ

    #y = a .+ softplus.(c*x .+ d) .+ λ0
     #y = softplus.(c*x .+ a .+ λ0)
     y = softplus.(c*x .+ softplusinv.(λ0))
    #y = max.(eps(), y .+ λ0)
    #y = softplus.(y .+ λ0)
end

softplusinv(x) = log(expm1(x))


"""
"""
function nθparams(f)
    
    ncells = length.(f)
    nparams = Vector{Int}(undef, sum(ncells));    
    nparams[vcat(f...) .== "Softplussign"] .= 1
    nparams[vcat(f...) .== "Softplus"] .= 1
    nparams[vcat(f...) .== "Sigmoid"] .= 4
    nparams[vcat(f...) .== "Softplus_negbin"] .= 2
    
    return nparams, ncells
    
end


"""
"""
function train_and_test(data; 
        n::Int=53, cross::Bool=false,
        x_tol::Float64=1e-10, f_tol::Float64=1e-9, g_tol::Float64=1e-3,
        iterations::Int=Int(2e3), show_trace::Bool=true, outer_iterations::Int=Int(1e1),
        extended_trace::Bool=false, scaled::Bool=false,
        x0_z::Vector{Float64}=[0.1, 15., -0.1, 20., 0.8, 0.01, 0.008],
        seed::Int=1, σ_B::Float64=1e6, sig_σ::Float64=1.)
    
    ncells = getfield.(first.(data), :ncells)
    f = repeat(["Softplus"], sum(ncells))
    borg = vcat(0,cumsum(ncells))
    f = [f[i] for i in [borg[i-1]+1:borg[i] for i in 2:length(borg)]];
        
    ntrials = length.(data)
    train = map(ntrials -> sample(Random.seed!(seed), 1:ntrials, ceil(Int, 0.9 * ntrials), replace=false), ntrials)
    test = map((ntrials, train)-> setdiff(1:ntrials, train), ntrials, train)
    
    model, options = optimize(map((data, train)-> data[train], data, train), f; 
        n=n, cross=cross,
        x_tol=x_tol, f_tol=f_tol, g_tol=g_tol, 
        iterations=iterations, show_trace=show_trace, 
        outer_iterations=outer_iterations, extended_trace=extended_trace, 
        scaled=scaled, sig_σ=sig_σ, x0_z=x0_z, 
        θprior=θprior(μ_B=40., σ_B=σ_B))
        
    testLL = loglikelihood(neuralDDM(model.θ, map((data, test)-> data[test], data, test), n, cross, θprior(μ_B=40., σ_B=σ_B)))
    LL = loglikelihood(neuralDDM(model.θ, data, n, cross, θprior(μ_B=40., σ_B=σ_B)))

    return σ_B, model, testLL, LL, options
    
end


"""
    flatten(θ)

Extract parameters `neuralDDM` or `noiseless_neuralDDM` model and place in the correct order into a 1D `array`
```
"""
function flatten(θ::Union{θneural, θneural_noiseless})

    @unpack θy, θz = θ
    @unpack σ2_i, B, λ, σ2_a, σ2_s, ϕ, τ_ϕ = θz
    vcat(σ2_i, B, λ, σ2_a, σ2_s, ϕ, τ_ϕ, 
        vcat(collect.(Flatten.flatten.(vcat(θy...)))...))

end


"""
    gradient(model)

Compute the gradient of the negative log-likelihood at the current value of the parameters of a `neuralDDM` or a `noiseless_neuralDDM`.
"""
function gradient(model::Union{neuralDDM, noiseless_neuralDDM})

    @unpack θ = model
    x = flatten(θ)
    ℓℓ(x) = -loglikelihood(x, model)

    ForwardDiff.gradient(ℓℓ, x)::Vector{Float64}

end


"""
    Hessian(model; chunck_size, remap)

Compute the hessian of the negative log-likelihood at the current value of the parameters of a `neuralDDM` or a `noiseless_neuralDDM`.

Arguments:

- `model`: instance of `neuralDDM` or `noiseless_neuralDDM`

Optional arguments:

- `chunk_size`: parameter to manange how many passes over the LL are required to compute the Hessian. Can be larger if you have access to more memory.
- `remap`: For considering parameters in variance of std space.

"""
function Hessian(model::Union{neuralDDM, noiseless_neuralDDM}; chunk_size::Int=4, remap::Bool=false)

    @unpack θ = model
    x = flatten(θ)
    ℓℓ(x) = -loglikelihood(x, model; remap=remap)

    cfg = ForwardDiff.HessianConfig(ℓℓ, x, ForwardDiff.Chunk{chunk_size}())
    ForwardDiff.hessian(ℓℓ, x, cfg)

end


"""
    optimize(data, f)

Optimize model parameters for a `neuralDDM`. Neural tuning parameters ([`θy`](@ref)) are initialized by fitting a the noiseless DDM model first ([`noiseless_neuralDDM`](@ref)).

Arguments:

- `data`: the output of [`load_neural_data`](@ref) with the format as described in its docstring.
- `f`: an `array` of length number of sessions, where each subarray is length number of cells. Each entry is a string, either `Softplus` or `Sigmoid` to describe the nonlinear map between ``a(t)`` and ``\\lambda(a)``, the expected firing rate.

Returns

- `model`: a module-defined type that organizes the `data` and parameters from the fit (as well as a few other things that are necessary for re-computing things the way they were computed here (e.g. `n`)
- `options`: some details related to the optimzation, such as which parameters were fit, and the upper and lower bounds of those parameters.

"""
function optimize(data; f::Vector{Vector{String}}=all_Softplus(data), 
        n::Int=53,
        x_tol::Float64=1e-10, f_tol::Float64=1e-9, g_tol::Float64=1e-3,
        iterations::Int=Int(2e3), show_trace::Bool=true,
        outer_iterations::Int=Int(1e1), scaled::Bool=false,
        extended_trace::Bool=false, cross::Bool=false,
        sig_σ::Float64=1., x0_z::Vector{Float64}=[0.1, 15., -0.1, 20., 0.8, 0.01, 0.008], 
        θprior::θprior=θprior(), remap::Bool=false) 
        
    θy0 = θy.(data, f) 
    x0 = vcat([0., 15., 0. - eps(), 0., 0., 1.0 - eps(), 0.008], vcat(vcat(θy0...)...)) 
    θ = θneural_noiseless(x0, f)
    model0 = noiseless_neuralDDM(θ, data)
        
    model0, = optimize(model0, neural_options_noiseless(f), show_trace=false)
    
    if remap
        x0_z = collect(Flatten.flatten(invθz2(θz(x0_z...))))
    end
       
    x0 = vcat(x0_z, pulse_input_DDM.flatten(model0.θ)[dimz+1:end]) 
    options = neural_options(f)  
    θ = θneural(x0, f)
    model = neuralDDM(θ, data, n, cross, θprior)
    
    model, = optimize(model, options; show_trace=show_trace, f_tol=f_tol, 
        iterations=iterations, outer_iterations=outer_iterations, remap=remap)

    return model, options

end



"""
    optimize(model, options)

Optimize model parameters for a `neuralDDM`.

Arguments: 

- `model`: an instance of a `neuralDDM`.
- `options`: some details related to the optimzation, such as which parameters were fit (`fit`), and the upper (`ub`) and lower (`lb`) bounds of those parameters.

Returns:

- `model`: an instance of a `neuralDDM`.
- `output`: results from [`Optim.optimize`](@ref).

"""
function optimize(model::neuralDDM, options::neural_options;
        x_tol::Float64=1e-10, f_tol::Float64=1e-9, g_tol::Float64=1e-3,
        iterations::Int=Int(2e3), show_trace::Bool=true, outer_iterations::Int=Int(1e1), 
        scaled::Bool=false, extended_trace::Bool=false, sig_σ::Float64=1., remap::Bool=false)
    
    @unpack fit, lb, ub = options
    @unpack θ, data, n, cross, θprior = model
    @unpack f = θ
    
    x0 = PulseInputDDM.flatten(θ)
    lb, = unstack(lb, fit)
    ub, = unstack(ub, fit)
    x0,c = unstack(x0, fit)
    
    #ℓℓ(x) = -(loglikelihood(stack(x,c,fit), model; remap=remap) + logprior(stack(x,c,fit), θprior) 
    #    + sigmoid_prior(stack(x,c,fit), θ; sig_σ=sig_σ))
    
    ℓℓ(x) = -(loglikelihood(stack(x,c,fit), model; remap=remap))
    
    output = optimize(x0, ℓℓ, lb, ub; g_tol=g_tol, x_tol=x_tol,
        f_tol=f_tol, iterations=iterations, show_trace=show_trace,
        outer_iterations=outer_iterations, scaled=scaled,
        extended_trace=extended_trace)

    x = Optim.minimizer(output)
    x = stack(x,c,fit)
    model = neuralDDM(θneural(x, f), data, n, cross, θprior)
    converged = Optim.converged(output)

    return model, output

end


"""
"""
θ2(θ::θneural) = θneural(θz=θz2(θ.θz), θy=θ.θy, f=θ.f)


"""
"""
invθ2(θ::θneural) = θneural(θz=invθz2(θ.θz), θy=θ.θy, f=θ.f)


"""
    loglikelihood(x, model; remap)

Maps `x` into `model`. Used in optimization, Hessian and gradient computation.

Arguments:

- `x`: a vector of mixed parameters.
- `model`: an instance of `neuralDDM`

Optional arguments:

- `remap`: For considering parameters in variance of std space.

"""
function loglikelihood(x::Vector{T}, model::neuralDDM; remap::Bool=false) where {T <: Real}
    
    @unpack data,θ,n,cross,θprior = model
    @unpack f = θ 
    
    if remap
        model = neuralDDM(θ2(θneural(x, f)), data, n, cross, θprior)
    else
        model = neuralDDM(θneural(x, f), data, n, cross, θprior)
    end

    loglikelihood(model)

end


"""
    loglikelihood(model)

Arguments: `neuralDDM` instance

Returns: loglikehood of the data given the parameters.
"""
function loglikelihood(model::neuralDDM)
    
    sum(sum.(loglikelihood_pertrial(model)))

end


"""
    loglikelihood_pertrial(model)

Arguments: `neuralDDM` instance

Returns: loglikehood of the data given the parameters.
"""
function loglikelihood_pertrial(model::neuralDDM)
    
    @unpack data,θ,n,cross = model
    @unpack θz, θy = θ
    @unpack σ2_i, B, λ, σ2_a = θz
    @unpack dt = data[1][1].input_data

    P,M,xc,dx = initialize_latent_model(σ2_i, B, λ, σ2_a, n, dt)

    map((data, θy) -> pmap(data -> loglikelihood(θz,θy,data, P, M, xc, dx, n, cross), data), data, θy)

end


"""
"""
loglikelihood(θz,θy,data::neuraldata, P::Vector{T1}, M::Array{T1,2},
    xc::Vector{T1}, dx::T3, n, cross) where {T1,T3 <: Real} = sum(log.(likelihood(θz,θy,data,P,M,xc,dx,n,cross)[1]))


#=
function likelihood(θz,θy,data::neuraldata,
        P::Vector{T1}, M::Array{T1,2},
        xc::Vector{T1}, dx::T3, n, cross) where {T1,T3 <: Real}

    @unpack λ, σ2_a, σ2_s, ϕ, τ_ϕ = θz
    @unpack spikes, input_data = data
    @unpack binned_clicks, clicks, dt, λ0, centered, delay, pad = input_data
    @unpack nT, nL, nR = binned_clicks
    @unpack L, R = clicks

    #adapt magnitude of the click inputs
    La, Ra = adapt_clicks(ϕ,τ_ϕ,L,R;cross=cross)

    F = zeros(T1,n,n) #empty transition matrix for time bins with clicks
    
    time_bin = (-(pad-1):nT+pad) .- delay
    
    alpha = log.(P)

    @inbounds for t = 1:length(time_bin)
        
        mm = maximum(alpha)
        py = vcat(map(xc-> sum(map((k,θy,λ0)-> logpdf(Poisson(θy(xc,λ0[t]) * dt), k[t]), spikes, θy, λ0)), xc)...)

        if time_bin[t] >= 1
            
            any(t .== nL) ? sL = sum(La[t .== nL]) : sL = zero(T1)
            any(t .== nR) ? sR = sum(Ra[t .== nR]) : sR = zero(T1)
            σ2 = σ2_s * (sL + sR);   μ = -sL + sR

            if (sL + sR) > zero(T1)
                transition_M!(F,σ2+σ2_a*dt,λ, μ, dx, xc, n, dt)
                alpha = log.((exp.(alpha .- mm)' * F)') .+ mm .+ py
            else
                alpha = log.((exp.(alpha .- mm)' * M)') .+ mm .+ py
            end
            
        else
            alpha = alpha .+ py
        end
                       
    end

    return exp(logsumexp(alpha)), exp.(alpha)

end
=#

"""
"""
function likelihood(θz,θy,data::neuraldata,
        P::Vector{T1}, M::Array{T1,2},
        xc::Vector{T1}, dx::T3, n, cross) where {T1,T3 <: Real}

    @unpack λ, σ2_a, σ2_s, ϕ, τ_ϕ = θz
    @unpack spikes, input_data = data
    @unpack binned_clicks, clicks, dt, λ0, centered, delay, pad = input_data
    @unpack nT, nL, nR = binned_clicks
    @unpack L, R = clicks

    #adapt magnitude of the click inputs
    La, Ra = adapt_clicks(ϕ,τ_ϕ,L,R;cross=cross)

    F = zeros(T1,n,n) #empty transition matrix for time bins with clicks
    
    time_bin = (-(pad-1):nT+pad) .- delay
    
    c = Vector{T1}(undef, length(time_bin))

    @inbounds for t = 1:length(time_bin)

        if time_bin[t] >= 1
            P, F = latent_one_step!(P, F, λ, σ2_a, σ2_s, time_bin[t], nL, nR, La, Ra, M, dx, xc, n, dt)
        end

        #weird that this wasn't working....
        #P .*= vcat(map(xc-> exp(sum(map((k,θy,λ0)-> logpdf(Poisson(θy(xc,λ0[t]) * dt),
        #                        k[t]), spikes, θy, λ0))), xc)...)
        
        P = P .* (vcat(map(xc-> exp(sum(map((k,θy,λ0)-> logpdf(Poisson(θy(xc,λ0[t]) * dt),
                        k[t]), spikes, θy, λ0))), xc)...))
        
        c[t] = sum(P)
        P /= c[t]

    end

    return c, P

end


"""
"""
function posterior(model::neuralDDM)
    
    @unpack data,θ,n,cross = model
    @unpack θz, θy = θ
    @unpack σ2_i, B, λ, σ2_a = θz
    @unpack dt = data[1][1].input_data

    P,M,xc,dx = initialize_latent_model(σ2_i, B, λ, σ2_a, n, dt)

    map((data, θy) -> pmap(data -> posterior(θz,θy,data, P, M, xc, dx, n, cross), data), data, θy)

end


"""
"""
function posterior(θz::θz, θy, data::neuraldata,
        P::Vector{T1}, M::Array{T1,2},
        xc::Vector{T1}, dx::T3, n, cross) where {T1,T3 <: Real}
    
    @unpack λ, σ2_a, σ2_s, ϕ, τ_ϕ = θz
    @unpack spikes, input_data = data
    @unpack binned_clicks, clicks, dt, λ0, centered, delay, pad = input_data
    @unpack nT, nL, nR = binned_clicks
    @unpack L, R = clicks
    
    #adapt magnitude of the click inputs
    La, Ra = adapt_clicks(ϕ,τ_ϕ,L,R;cross=cross)
    
    time_bin = (-(pad-1):nT+pad) .- delay

    c = Vector{T1}(undef, length(time_bin))
    F = zeros(T1,n,n) #empty transition matrix for time bins with clicks   
    α = Array{Float64,2}(undef, n, length(time_bin))
    β = Array{Float64,2}(undef, n, length(time_bin))
        
    @inbounds for t = 1:length(time_bin)

        if time_bin[t] >= 1
            P, F = latent_one_step!(P, F, λ, σ2_a, σ2_s, time_bin[t], nL, nR, La, Ra, M, dx, xc, n, dt)
        end
        
        P = P .* (vcat(map(xc-> exp(sum(map((k,θy,λ0)-> logpdf(Poisson(θy(xc,λ0[t]) * dt),
                        k[t]), spikes, θy, λ0))), xc)...))
        
        c[t] = sum(P)
        P /= c[t]
        α[:,t] = P

    end   

    P = ones(Float64,n) #initialze backward pass with all 1's
    β[:,end] = P

    @inbounds for t = length(time_bin)-1:-1:1

        P = P .* (vcat(map(xc-> exp(sum(map((k,θy,λ0)-> logpdf(Poisson(θy(xc,λ0[t+1]) * dt),
                k[t+1]), spikes, θy, λ0))), xc)...))
            
        if time_bin[t] >= 0
            P,F = backward_one_step!(P, F, λ, σ2_a, σ2_s, time_bin[t+1], nL, nR, La, Ra, M, dx, xc, n, dt)
        end
        
        P /= c[t+1]
        β[:,t] = P

    end

    return α, β, xc

end


"""
"""
function logistic!(x::T) where {T <: Any}

    if x >= 0.
        x = exp(-x)
        x = 1. / (1. + x)
    else
        x = exp(x)
        x = x / (1. + x)
    end

    return x

end


"""
"""
neural_null(k,λ,dt) = sum(logpdf.(Poisson.(λ*dt),k))