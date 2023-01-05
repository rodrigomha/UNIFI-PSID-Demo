include(joinpath(dirname(@__FILE__), "../data/dynamic_data.jl"))
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