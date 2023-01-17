# UNIFI-PSID-Demo

The following repository provides a demo for the Julia Package PowerSimulationsDynamics.jl (PSID).

The first case, available in `main_3bus.jl`, showcases the small signal capabilities available in PSID to allow exploration of small signal instabilities and parameter retuning.

The second case, available in `main_continuation_pf.jl`, showcases how a continuation power flow can be run, and small signal stability can be assessed depending on the dynamic components.

The final case, available in `main_144bus.jl`, runs a large 144 bus system, with more than 2500 states, with Sauer-Pai generators, Grid-Following and Droop Grid-Forming Inverter capabilities.