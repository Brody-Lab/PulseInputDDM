# # Fitting a choice model
# Blah blah blah

using pulse_input_DDM

# ### Generate some data
# Blah blah blah

θ_syn, data = synthetic_data(;ntrials=10);

# ### Optimize stuff
# Blah blah blah

n = 53

options = choiceoptions(fit = vcat(trues(9)),
    lb = vcat([0., 8., -5., 0., 0., 0.01, 0.005], [-30, 0.]),
    ub = vcat([2., 30., 5., 100., 2.5, 1.2, 1.], [30, 1.]),
    x0 = vcat([0.1, 15., -0.1, 20., 0.5, 0.8, 0.008], [0.,0.01]))

model = optimize(data, options, n; iterations=5, outer_iterations=1)

# ### Compute Hessian and the confidence interavls
# Blah blah blah

H = Hessian(model, n)
CI, HPSD = CIs(H);