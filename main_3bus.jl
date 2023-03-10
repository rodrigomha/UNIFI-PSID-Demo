using Revise
using PowerSystems
using PowerSimulationsDynamics
using Sundials
using PlotlyJS
using PowerFlows
using Logging
using DataFrames
using OrderedCollections

const PSID = PowerSimulationsDynamics
const PSY = PowerSystems
include("src/construct_systems.jl")

## Eigenvalue Analysis ##
## 3 Bus Systems ##
## QSP vs EMT ##

# Construct System
sys = construct_threebus_system()

# Declare Perturbation
gen = get_component(ThermalStandard, sys, "generator-103-1")
dyn_gen = get_dynamic_injector(gen)
change_power_setpoint = ControlReferenceChange(1.0, dyn_gen, :P_ref, 1.0)

# Initialize Simulation with Dynamic Lines
sim = Simulation(
    ResidualModel,
    sys,
    pwd(),
    (0.0, 20.0),
    change_power_setpoint,
    all_lines_dynamic = true,
)

# Run Small Signal Analysis
sm = small_signal_analysis(sim)
eigs = sm.eigenvalues

# Show Participation Factor Summary
#pf_summary = summary_participation_factors(sm)
#show(pf_summary, allrows=true)

# Show Eigenvalue Summary
eig_summary = summary_eigenvalues(sm)
#show(eig_summary, allrows = true)

# Compare to system neglecting dynamic Lines
sim_static = Simulation(ResidualModel, sys, pwd(), (0.0, 20.0), change_power_setpoint)
sm_static = small_signal_analysis(sim_static)
eigs_static = sm_static.eigenvalues
eig_summary_static = summary_eigenvalues(sm_static)

plot([scatter(x = real.(eigs_static), y = imag.(eigs_static), name = "Static Network",  mode="markers"),
scatter(x = real.(eigs), y = imag.(eigs), name = "Dynamic Network",  mode="markers", marker_symbol="cross")])

println("\nDynamic Network Summary")
show(eig_summary, allrows = true)

println("\nStatic Network Summary")
show(eig_summary_static, allrows = true)

eigs_no_network = vcat(eigs[11:24], eigs[27:end])
plot([scatter(x = real.(eigs_no_network), y = imag.(eigs_no_network), name = "Static Network",  mode="markers"),
scatter(x = real.(eigs_no_network), y = imag.(eigs_no_network), name = "Dynamic Network",  mode="markers", marker_symbol="cross")])

# Run Simulation
execute!(sim, IDA(), abstol = 1e-9)

# Read results
results = read_results(sim)

# Plot Change of Power
sim_time, power = get_activepower_series(results, "generator-103-1")
plot(scatter(
    x = sim_time,
    y = power),
    Layout(
    xaxis_title = "Time",
    yaxis_title = "Active Power [pu]",
    title = "Active Power Output GFM VSM Bus 3",
))

# Get Voltage Magnitude at Inverter Bus
sim_time, voltage = get_voltage_magnitude_series(results, 103)
plot(scatter(
    x = sim_time,
    y = voltage),
    Layout(
    xaxis_title = "Time",
    yaxis_title = "Active Power [pu]",
    title = "Voltage Magnitude Bus 3",
))

sim_time, voltage_bus2 = get_voltage_magnitude_series(results, 102)
plot(scatter(
    x = sim_time,
    y = voltage_bus2),
    Layout(
    xaxis_title = "Time",
    yaxis_title = "Active Power [pu]",
    title = "Voltage Magnitude Bus 2",
))
