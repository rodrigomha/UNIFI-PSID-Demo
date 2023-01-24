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

## Continuation Power Flow ##
## 2 Bus Systems ##
## GENROU+SEXS+TGOV1 vs Constant Power Load ##

## Read data from RAW and DYR files!
sys = System("data/OMIB_Load.raw", "data/OMIB_Load.dyr")

## Prepare data for a continuation power flow
# Power Range
P_range = 0:0.01:4.5
load_power_factor = 1.0

# PV Curve Results
P_load_p = Vector{Float64}()
V_load_p = Vector{Float64}()
stability_results = Vector{Bool}()

# Disable Logging
Logging.disable_logging(Logging.Info)
Logging.disable_logging(Logging.Warn)

# Continuation Power Flow + Small Signal Stability
for p in P_range
    # Obtain PV Curve

    # Set Active and Reactive Power of the load
    power = p * 1.0
    load = get_component(PSY.PowerLoad, sys, "load1021")
    set_active_power!(load, power)
    q_power = power * tan(acos(load_power_factor))
    set_reactive_power!(load, q_power)

    # Run Power Flow
    status = run_powerflow!(sys)
    if !status
        break # Finish for loop if no power flow solution
    end
    # Measure Voltage Magnitude at Load Bus: BUS 2
    bus = get_component(Bus, sys, "BUS 2")
    Vm = get_magnitude(bus)
    # Store Results
    push!(V_load_p, Vm)
    push!(P_load_p, power)

    # Initialize Dynamical System
    sim = Simulation(ResidualModel, sys, pwd(), (0.0, 1.0))
    if sim.status == PSID.BUILT
        # Check Small Signal Stability
        sm = small_signal_analysis(sim).stable
        # Push results
        push!(stability_results, sm)
    end
end

# Obtain indices where in the PV Curve the system is small signal stable
true_ixs = findall(x -> x, stability_results)

# Plot PV Curve
plot([scatter(
    x = P_load_p,
    y = V_load_p,
    line_color = :blue,
    name = "PV curve",
),
scatter(
    x = P_load_p[true_ixs],
    y = V_load_p[true_ixs],
    name = "Stable Region",
    mode = "markers"
)],
Layout(title = "PV Curve",
xaxis_title = "Load Power [pu]",
yaxis_title = "Load Bus Voltage [pu]",
))

## Run Bifurcation

# Critical Load is around 1.17
P_critical_genrou = 1.168922

# Change Load Power
load = get_component(PSY.PowerLoad, sys, "load1021")
set_active_power!(load, P_critical_genrou)
q = P_critical_genrou * tan(acos(load_power_factor))
set_reactive_power!(load, q)
status = run_powerflow!(sys)

## Unstable Cycle
# State 5 is the transient EMF eq_p of the generator that we perturb at time 1.0 by increasing it 0.05 pu.
pert_state = PSID.PerturbState(1.0, 5, 0.05)

sim = Simulation(ResidualModel, sys, pwd(), (0.0, 10.0), pert_state)
sm = small_signal_analysis(sim)
summary_eigs = summary_eigenvalues(sm)
show(summary_eigs)

# Run the Simulation
execute!(sim, IDA(), abstol = 1e-9, reltol = 1e-9)
results = read_results(sim)

# Read state time series
_, eq_p = get_state_series(results, ("generator-101-1", :eq_p))
_, Vf = get_state_series(results, ("generator-101-1", :Vf))

# Plot a phase portrait transient EMF (eq_p) vs Field Voltage E_fd (or Vf)
plot(
    scatter(x = eq_p, y = Vf, line_width = 2, name = "Shift 0.05"),
    Layout(
        xaxis_title = "eq_p",
        yaxis_title = "E_fd",
        )
)

## Limit Cycle
pert_state = PSID.PerturbState(1.0, 5, -0.01)

sim = Simulation(ResidualModel, sys, pwd(), (0.0, 50.0), pert_state)
sm = small_signal_analysis(sim)

execute!(sim, IDA(), abstol = 1e-9, reltol = 1e-9)
results = read_results(sim)

_, eq_p2 = get_state_series(results, ("generator-101-1", :eq_p))
_, Vf2 = get_state_series(results, ("generator-101-1", :Vf))

plot(
    [scatter(x = eq_p, y = Vf, line_width = 2, name = "Shift 0.05"),
    scatter(x = eq_p2, y = Vf2, line_width = 2, name = "Shift -0.01")],
    Layout(
        xaxis_title = "eq_p",
        yaxis_title = "E_fd",
        )
)

## Limit Cycle2
pert_state = PSID.PerturbState(1.0, 5, -0.005)

sim = Simulation(ResidualModel, sys, pwd(), (0.0, 100.0), pert_state)
sm = small_signal_analysis(sim)

execute!(sim, IDA(), abstol = 1e-9, reltol = 1e-9)
results = read_results(sim)

_, eq_p3 = get_state_series(results, ("generator-101-1", :eq_p))
_, Vf3 = get_state_series(results, ("generator-101-1", :Vf))

plot(
    [scatter(x = eq_p, y = Vf, line_width = 2, name = "Shift 0.05 Unstable"),
    scatter(x = eq_p2, y = Vf2, line_width = 2, name = "Shift -0.01 Stable"),
    scatter(x = eq_p3, y = Vf3, line_width = 2, name = "Shift -0.005 Limit Cycle")],
    Layout(
        xaxis_title = "eq_p",
        yaxis_title = "E_fd",
        )
)
