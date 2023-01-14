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

scatter(eigs_static, label = "Static Network")
scatter!(eigs, label = "Dynamic Network", markershape = :xcross)

println("\nNot really useful comparison, 
since there are states that are are insanely fast,
and associated with the network dynamics, both voltages and lines.
At this point is more convenient to directly look at the eigenvalue summary
for both cases and look at the differences there.")

println("\nDynamic Network Summary")
show(eig_summary, allrows = true)

println("\nStatic Network Summary")
show(eig_summary_static, allrows = true)

println(
    "\nIt looks like, eigenvalues for dynamic network 1-10 and 25-26 are clearly associated
with the network so we can remove them to observe differences.",
)

eigs_no_network = vcat(eigs[11:24], eigs[27:end])
scatter(eigs_static, label = "Static Network")
scatter!(
    eigs_no_network,
    label = "Dynamic Network without fast eigvals",
    markershape = :xcross,
)

println(
    "\nNeglecting the network moves eigenvalues, but do not induce instability in this system",
)

# Run Simulation
execute!(sim, IDA(), abstol = 1e-9)

# Read results
results = read_results(sim)

# Plot Change of Power
power = get_activepower_series(results, "generator-103-1")
plot(
    power,
    xlabel = "Time",
    ylabel = "Active Power [pu]",
    label = "Active Power Output GFM VSM Bus 3",
)

# Get Voltage Magnitude at Inverter Bus
voltage = get_voltage_magnitude_series(results, 103)
plot(
    voltage,
    xlabel = "Time",
    ylabel = "Voltage Magnitude [pu]",
    label = "Voltage Magnitude Bus 3",
)

voltage_bus2 = get_voltage_magnitude_series(results, 102)
plot(
    voltage_bus2,
    xlabel = "Time",
    ylabel = "Voltage Magnitude [pu]",
    label = "Voltage Magnitude Bus 2",
)
