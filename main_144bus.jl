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

## Params
tspan=(0.0, 1.0) # Time duration of simualtion (Not-ML)
tripTime = 0.1

# Build System
sys = construct_144bus_system()

# Explore System
#show_components(sys, ThermalStandard)
#show_components(sys, GenericBattery)

syncGen = collect(get_components(ThermalStandard, sys));
gen = [gen for gen in syncGen if occursin("Trip", gen.name)][1]
genTrip = GeneratorTrip(tripTime, PSY.get_component(PSY.DynamicGenerator, sys, gen.name))

sim = Simulation(
        ResidualModel, 
        sys,         
        pwd(),       
        tspan, 
        genTrip,
        all_lines_dynamic = true,
    )

# Run Small Signal Analysis
sm = small_signal_analysis(sim)

# Show eigenvalue statistics
summary_eigenvalues(sm)

# Run Perturbation
execute!(sim, IDA(), abstol = 1e-9)

# Get Results
results = read_results(sim)

voltage = get_voltage_magnitude_series(results, 3)

plotlyjs()
# Bus will most likely increase because generator being tripped is consuming reactive power
plot(voltage)

