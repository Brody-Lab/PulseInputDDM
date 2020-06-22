"""
    synthetic_clicks(ntrials, rng)

Computes randomly timed left and right clicks for ntrials.
rng sets the random seed so that clicks can be consistently produced.
Output is bundled into an array of 'click' types.
"""
function synthetic_clicks(ntrials::Int, rng::Int;
    tmin::Float64=0.2, tmax::Float64=1.0, clicktot::Int=40)

    Random.seed!(rng)

    T = tmin .+ (tmax-tmin).*rand(ntrials)
    T = ceil.(T, digits=2)

    ratetot = clicktot./T
    Rbar = ratetot.*rand(ntrials)
    Lbar = ratetot .- Rbar

    R = cumsum.(rand.(Exponential.(1 ./Rbar), clicktot))
    L = cumsum.(rand.(Exponential.(1 ./Lbar), clicktot))

    R = map((T,R)-> vcat(0,R[R .<= T]), T,R)
    L = map((T,L)-> vcat(0,L[L .<= T]), T,L)

    clicks.(L, R, T)

end


"""
    rand(θz, inputs)

Generate a sample latent trajecgtory,
given parameters of the latent model θz and clicks for one trial, contained
within inputs.
"""
function rand(θz::θz{T}, inputs, i_0) where T <: Real

    @unpack B, λ, σ2_i, σ2_a, σ2_s, ϕ, τ_ϕ = θz
    @unpack clicks, binned_clicks, centered, dt = inputs
    @unpack nT, nL, nR = binned_clicks
    @unpack L, R = clicks

    La, Ra = adapt_clicks(ϕ, τ_ϕ, L, R)

    A = Vector{T}(undef,nT)

    if σ2_i > 0.
        a = sqrt(σ2_i)*randn() + i_0
    else
        a = zero(typeof(σ2_i)) + i_0
    end

    for t = 1:nT

        if centered && t == 1
            a = sample_one_step!(a, t, σ2_a, σ2_s, λ, nL, nR, La, Ra, dt/2)
        else
            a = sample_one_step!(a, t, σ2_a, σ2_s, λ, nL, nR, La, Ra, dt)
        end

        abs(a) > B ? (a = B * sign(a); A[t:nT] .= a; break) : A[t] = a

    end

    return A

end


"""
    sample_one_step!(a, t, σ2_a, σ2_s, λ, nL, nR, La, Ra, dt)

Move latent state one dt forward, given parameters defining the DDM.
"""
function sample_one_step!(a::TT, t::Int, σ2_a::TT, σ2_s::TT, λ::TT,
        nL::Vector{Int}, nR::Vector{Int},
        La, Ra, dt::Float64) where {TT <: Any}

    any(t .== nL) ? sL = sum(La[t .== nL]) : sL = zero(TT)
    any(t .== nR) ? sR = sum(Ra[t .== nR]) : sR = zero(TT)
    σ2, μ = σ2_s * (sL + sR), -sL + sR


    if (σ2_a * dt + σ2) > 0.
        η = sqrt(σ2_a * dt + σ2) * randn()
    else
        η = zero(typeof(σ2_a))
    end

    if abs(λ) < 1e-150
        a += μ + η
    else
        h = μ/(dt*λ)
        a = exp(λ*dt)*(a + h) - h + η
    end

    return a

end


function compute_initial_pt(ibias::TT,eta::TT,beta::TT,click_data) where {TT <: Any}
    
    # not respecting session boundaries yet
    
    # ΔLR = diffLR.(click_data)
    # correct = map(ΔLR->sign(ΔLR),ΔLR)
    
    # i_0 = Array{TT}(undef, length(correct))
    # i_0[1] = ibias;
    
    # for i = 2:length(correct)
    #     i_0[i] = ibias + eta*correct[i-1] + beta*i_0[i-1]
    # end

        # return i_0


    ΔLR = diffLR.(click_data)
    correct = map(ΔLR->sign(ΔLR),ΔLR)
    
    η_hat = 1/beta
    β_hat = (ibias*beta)/(1+beta)
    C = (1-ibias)*eta/(1-beta_hat)


    i_0 = Array{TT}(undef, length(correct))
    i_0[1] = eta;
    
    for i = 2:length(correct)
        i_0[i] = C*(1-β_hat) + η_hat*β_hat*correct[i-1] + β_hat*i_0[i-1]
        ibias + eta*correct[i-1] + beta*i_0[i-1]
    end

    return log.(i_0 ./ (1 .- i_0))
    

end