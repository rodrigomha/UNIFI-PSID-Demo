using Revise
using PowerSystems
using PowerSimulationsDynamics
using Sundials
using Plots
using PowerFlows
using Logging
using DataFrames
using OrderedCollections

const PSID = PowerSimulationsDynamics
const PSY = PowerSystems

include("src/construct_systems.jl")
include("src/df_summary.jl")

sys = construct_threebus_system()

sim = Simulation(ResidualModel, sys, pwd(), (0.0, 1.0), all_lines_dynamic = true)
sm = small_signal_analysis(sim)

pf_summary = summary_participation_factors(sm)
show(pf_summary, allrows=true)
pretty_table(pf_summary)

eig_summary = summary_eigenvalues(sm)
pretty_table(eig_summary)