H_min = 5.0
D_min = 1.8
#######################
##### Generators ######
#######################

machine_anderson() = AndersonFouadMachine(
    0.0, #R
    0.8979, #Xd
    0.646, #Xq
    0.2995, #Xd_p
    0.646, #Xq_p
    0.23, #Xd_pp
    0.4, #Xq_pp
    3.0, #Td0_p
    0.1, #Tq0_p
    0.01, #Td0_pp
    0.033, #Tq0_pp
)

machine_genrou() = RoundRotorExponential(
    R = 0.0,
    Td0_p = 8.0,
    Td0_pp = 0.03,
    Tq0_p = 0.4,
    Tq0_pp = 0.05,
    Xd = 1.8,
    Xq = 1.7,
    Xd_p = 0.3,
    Xq_p = 0.55,
    Xd_pp = 0.25,
    Xl = 0.2,
    Se = (0.0, 0.0),
)

machine_sauerpai() = SauerPaiMachine(
    R = 0.0,
    Xd = 0.8979,
    Xq = 0.646,
    Xd_p = 0.2995,
    Xq_p = 0.646,
    Xd_pp = 0.23,
    Xq_pp = 0.4,
    Xl = 0.2,
    Td0_p = 3.0,
    Tq0_p = 0.1,
    Td0_pp = 0.01,
    Tq0_pp = 0.033,
)

# Shaft
heterogeneous_shaft(H, D) = SingleMass(
    H,
    D,
)

# AVR and TG
avr_sexs_ex() = SEXS(Ta_Tb = 0.4, Tb = 5.0, K = 20.0, Te = 1.0, V_lim = (-999.0, 999.0))

avr_type1() = AVRTypeI(
    20.0, #Ka - Gain
    1.0, #Ke
    0.001, #Kf
    0.02, #Ta
    0.7, #Te
    1, #Tf
    0.001, #Tr
    (min = -5.0, max = 5.0),
    0.0006, #Ae - 1st ceiling coefficient
    0.9,
) #Be - 2nd ceiling coefficient

tg_type1() = TGTypeI(
    0.02, #R
    0.1, #Ts
    0.45, #Tc
    0.0, #T3
    0.0, #T4
    50.0, #T5
    (min = 0.3, max = 1.2), #P_lims
)

tg_tgov1_ex() = SteamTurbineGov1(
    R = 0.05,
    T1 = 0.2,
    valve_position_limits = (-999.0, 999.0),
    T2 = 0.3,
    T3 = 0.8,
    D_T = 0.0,
    DB_h = 0.0,
    DB_l = 0.0,
    T_rate = 0.0,
)

function add_Thermal(sys, name, bus_name, capacity, P, Q)
    return ThermalStandard(
        name= name,
        available= true,
        status= true,
        bus = get_component(Bus, sys, bus_name),
        active_power= P,
        reactive_power= Q,
        rating= 39.61163465447999,
        active_power_limits= (min = 0.0, max = 0.96),
        reactive_power_limits= (min = -39.6, max = 39.6),
        ramp_limits= (up = 2.4, down = 2.4),
        base_power= capacity,
        operation_cost=ThreePartCost(nothing),
    )
end

function dyn_gen_second_order(generator, H, D)
    return DynamicGenerator(
        name = get_name(generator),
        ω_ref = 1.0, # ω_ref,
        machine = machine_anderson(), #machine
        shaft = heterogeneous_shaft(H, D), #shaft
        avr = avr_sexs_ex(), #avr
        prime_mover = tg_tgov1_ex(), #tg
        pss = pss_none(), #pss
    )
end

function dyn_gen_genrou(generator, H, D)
    return PSY.DynamicGenerator(
        name = get_name(generator),
        ω_ref = 1.0, #ω_ref
        machine = machine_genrou(), #machine
        shaft = heterogeneous_shaft(H, D), #shaft
        avr = avr_type1(), #avr
        prime_mover = tg_type1(), #tg
        pss = pss_none(),
    ) #pss
end

function dyn_gen_sauerpai(generator, H, D)
    return PSY.DynamicGenerator(
        name = get_name(generator),
        ω_ref = 1.0, #ω_ref
        machine = machine_sauerpai(), #machine
        shaft = heterogeneous_shaft(H, D), #shaft
        avr = avr_sexs_ex(), #avr
        prime_mover = tg_tgov1_ex(), #tg
        pss = pss_none(),
    ) #pss
end

######################
##### Inverters ######
######################

####### Outer Control #######
function outer_control_droop()
    function active_droop()
        return PSY.ActivePowerDroop(Rp = 0.05, ωz = 2 * pi * 5)
    end
    function reactive_droop()
        return ReactivePowerDroop(kq = 0.01, ωf = 2 * pi * 5)
    end
    return OuterControl(active_droop(), reactive_droop())
end

function outer_control_gfoll()
    function active_pi()
        return ActivePowerPI(Kp_p = 2.0, Ki_p = 30.0, ωz = 0.132 * 2 * pi * 50)
    end
    function reactive_pi()
        return ReactivePowerPI(Kp_q = 2.0, Ki_q = 30.0, ωf = 0.132 * 2 * pi * 50)
    end
    return OuterControl(active_pi(), reactive_pi())
end

###### PLL Data ######
pll_ex() = KauraPLL(
    ω_lp = 500.0, #Cut-off frequency for LowPass filter of PLL filter.
    kp_pll = 0.84,  #PLL proportional gain
    ki_pll = 4.69,   #PLL integral gain
)

no_pll_ex() = PSY.FixedFrequency()

######## Inner Control ######
inner_control_ex() = VoltageModeControl(
    kpv = 0.59,     #Voltage controller proportional gain
    kiv = 736.0,    #Voltage controller integral gain
    kffv = 0.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
    rv = 0.0,       #Virtual resistance in pu
    lv = 0.2,       #Virtual inductance in pu
    kpc = 1.27,     #Current controller proportional gain
    kic = 14.3,     #Current controller integral gain
    kffi = 0.0,     #Binary variable enabling the current feed-forward in output of current controllers
    ωad = 50.0,     #Active damping low pass filter cut-off frequency
    kad = 0.2,
)

current_mode_inner_ex() = CurrentModeControl(
kpc = 0.37,     #Current controller proportional gain
kic = 0.7,     #Current controller integral gain
kffv = 0,#1.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
)

###### Filter Data ######
filt_ex() = LCLFilter(lf = 0.08, rf = 0.003, cf = 0.074, lg = 0.2, rg = 0.01)

function add_grid_forming(storage, capacity)
    return DynamicInverter(
        name = get_name(storage),
        ω_ref = 1.0, # ω_ref,
        converter = AverageConverter(rated_voltage = 138.0, rated_current = (capacity*1e3)/138.0), #converter
        outer_control = outer_control_droop(), #outer control
        inner_control = inner_control_ex(), #inner control voltage source
        dc_source = FixedDCSource(voltage = 600.0), #dc source
        freq_estimator = no_pll_ex(), #pll
        filter = filt_ex(), #filter
    )
end

function add_grid_following(storage, capacity)
    return DynamicInverter(
        name = get_name(storage),
        ω_ref = 1.0, # ω_ref,
        converter = AverageConverter(rated_voltage = 138.0, rated_current = (capacity*1e3)/138.0), #converter
        outer_control = outer_control_gfoll(), #outer control
        inner_control = current_mode_inner_ex(), #inner control current source
        dc_source = FixedDCSource(voltage = 600.0), #dc source
        freq_estimator = pll_ex(), #pll
        filter = filt_ex(), #filter
    )
end

function add_battery(sys, battery_name, bus_name, capacity, P, Q)
    return GenericBattery(
        name = battery_name,
        bus = get_component(Bus, sys, bus_name),
        available = true,
        prime_mover = PrimeMovers.BA,
        active_power = P,
        reactive_power = Q,
        rating = 1.1,
        base_power = capacity,
        initial_energy = 50.0,
        state_of_charge_limits = (min = 5.0, max = 100.0),
        input_active_power_limits = (min = 0.0, max = 1.0),
        output_active_power_limits = (min = 0.0, max = 1.0),
        reactive_power_limits = (min = -1.0, max = 1.0),
        efficiency = (in = 0.80, out = 0.90),
    )
end