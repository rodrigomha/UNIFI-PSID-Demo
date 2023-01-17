include(joinpath(dirname(@__FILE__), "../data/dynamic_data.jl"))
include(joinpath(dirname(@__FILE__), "../data/144Bus_dynamic_data.jl"))
include("utils.jl")

function construct_threebus_system()
    threebus_file_dir = joinpath(dirname(@__FILE__), "../data/ThreeBusInverter.raw")
    threebus_sys = System(threebus_file_dir, runchecks = false)
    add_source_to_ref(threebus_sys)

    for g in get_components(Generator, threebus_sys)
        if get_number(get_bus(g)) == 102
            case_gen = dyn_marconato(g)
            add_component!(threebus_sys, case_gen, g)
        elseif get_number(get_bus(g)) == 103
            case_inv = inv_vsm(g)
            add_component!(threebus_sys, case_inv, g)
        end
    end

    for l in get_components(PSY.PowerLoad, threebus_sys)
        PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
    end

    return threebus_sys
end


function construct_144bus_system()
    sys_dir = joinpath(dirname(@__FILE__), "../data/144Bus.raw")
    sys = System(sys_dir, runchecks = false)
    set_units_base_system!(sys, "DEVICE_BASE")

    df = solve_powerflow(sys)
    total_power=sum(df["bus_results"].P_gen)
    
    # Reallocate Power
    # Grid Following
    Gf=0.15
    # Grid Forming
    GF=0.02

    syncGen = collect(get_components(Generator, sys));
    # Trip Capacity
    trip_gen=0.04
    trip_cap=total_power*trip_gen/0.7
    # Assign new base powers to update Power Flow
    for g in syncGen
        if g.bus.number == 3
            set_base_power!(g, trip_cap)
        end
        if get_base_power(g) == 500.000
            set_base_power!(g, 200.00)
        elseif get_base_power(g) == 250.000
            set_base_power!(g, 175.00)
        end
    end
    
    bus_capacity = Dict()
    for g in syncGen
        bus_capacity[g.bus.name] = get_base_power(g)
    end
    
    total_capacity=sum(values(bus_capacity))

    active_pu = ((1-trip_gen)*total_power)/(total_capacity-trip_cap)

    # Create Generators
    for gen in syncGen
        if gen.bus.number != 3
            set_active_power!(gen, active_pu)
        end 
        H = H_min #+ rand(1)[1] #no randomness
        D = D_min #+ 0.5*rand(1)[1] #no randomness
        #case_gen = dyn_gen_second_order(gen, H, D)
        case_gen = dyn_gen_sauerpai(gen, H, D)
        add_component!(sys, case_gen, gen)
    end
    
    trip_capPU=trip_cap/total_capacity
    for g in syncGen
        if g.bus.number == 3
            set_base_power!(g, trip_cap)
            set_base_power!(g.dynamic_injector, trip_cap)
            set_active_power!(g, 0.7)
        elseif g.bus.number != 1 && g.bus.number != 3
            set_base_power!(g, bus_capacity[g.bus.name]*(1-GF-Gf))
            set_base_power!(g.dynamic_injector, bus_capacity[g.bus.name]*(1-GF-Gf))
        end
    
        if g.bus.number != 1
            storage=add_battery(sys, join(["GF_Battery-", g.bus.number]), g.bus.name, GF*bus_capacity[g.bus.name], get_active_power(g), get_reactive_power(g))
            add_component!(sys, storage)
            inverter=add_grid_forming(storage, GF*bus_capacity[g.bus.name])
            add_component!(sys, inverter, storage)
    
            storage=add_battery(sys, join(["Gf_Battery-", g.bus.number]), g.bus.name, Gf*bus_capacity[g.bus.name], get_active_power(g), get_reactive_power(g))
            add_component!(sys, storage)
            inverter=add_grid_following(storage, Gf*bus_capacity[g.bus.name])
            add_component!(sys, inverter, storage)
        end
    
    end 

    if !isfile(joinpath(dirname(@__FILE__), "../json_files/144Bus/144Bus.json"))
        to_json(sys, joinpath(dirname(@__FILE__), "../json_files/144Bus/144Bus.json"))
    end
    for l in get_components(PSY.PowerLoad, sys)
        PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
    end
    return sys
end