module pulse_input_DDM

using StatsBase, Distributions, Optim, LineSearches, JLD2
using ForwardDiff, Distributed, LinearAlgebra
using SpecialFunctions, MAT, Random
using DSP, Discretizers
import StatsFuns: logistic, logit, softplus, xlogy
using ImageFiltering
using ForwardDiff: value

include("latent_variable_model_functions.jl")
include("analysis_functions.jl")
include("optim_funcs.jl")
include("sample_model_functions.jl")
include("choice_model/choice_observation_model.jl")
include("choice_model/wrapper_functions.jl")
include("choice_model/sample_model_functions.jl")
include("choice_model/manipulate_data_functions.jl")
include("neural_model/poisson_neural_observation.jl")
include("neural_model/wrapper_functions.jl")
include("neural_model/mapping_functions.jl")
include("neural_model/sample_model_functions.jl")
include("neural_model/manipulate_data_functions.jl")
include("neural_model/load_and_optimize.jl")
include("neural_model/deterministic_model.jl")
include("neural_model/sample_model_functions_FP.jl")

export dimz
export compute_H_CI!, optimize_model, compute_LL, compute_Hessian, compute_gradient
export sample_inputs_and_choices, sample_choices_all_trials, default_parameters
export LL_all_trials
export bin_clicks!, load_choice_data, bounded_mass_all_trials

#=

export neural_null
export regress_init, init_pz_py, optimize_and_errorbars, compute_ΔLL

export choice_null

export compute_LL_and_prior
export sample_input_and_spikes_multiple_sessions, sample_inputs_and_spikes_single_session
export sample_spikes_single_session, sample_spikes_single_trial, sample_expected_rates_single_session

export sample_choices_all_trials
export aggregate_spiking_data, bin_clicks_spikes_and_λ0!

export diffLR, rate_mat_func_filt, nanmean, nanstderr

export filter_data_by_cell!

=#

end
