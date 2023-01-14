##################################
######## Generator Data ##########
##################################

Marconato_ex() = MarconatoMachine(
    0.0, # R
    1.8, #Xd
    1.7, #Xq
    0.3, #Xd_p
    0.55, #Xq_p
    0.25, #Xd_pp
    0.25, #Xq_pp
    8.00, #Td0_p
    0.4, #Tq0_p
    0.03, #Td0_pp
    0.05, #Tq0_pp
    0.0, #T_AA
)

shaft_ex() = SingleMass(H = 6.175, D = 0.05)

avr_sexs() = SEXS(Ta_Tb = 0.4, Tb = 5.0, K = 20.0, Te = 1.0, V_lim = (-999.0, 999.0))
tg_tgov1() = SteamTurbineGov1(
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
pss_none() = PSSFixed(0.0)

function dyn_marconato(gen)
    return PSY.DynamicGenerator(
        name = get_name(gen),
        ω_ref = 1.0,
        machine = Marconato_ex(),
        shaft = shaft_ex(),
        avr = avr_sexs(),
        prime_mover = tg_tgov1(),
        pss = pss_none(),
    )
end

##################################
######## Inverter Data ###########
##################################

# VSM
function outer_control_vsm()
    function virtual_inertia()
        return VirtualInertia(Ta = 0.397887, kd = 0.0, kω = 50.0)
    end
    function reactive_droop()
        return ReactivePowerDroop(kq = 0.05, ωf = 2 * pi * 20)
    end
    return OuterControl(virtual_inertia(), reactive_droop())
end

######## Inner Controls #########
inner_control() = VoltageModeControl(
    kpv = 0.59,     #Voltage controller proportional gain
    kiv = 736.0,    #Voltage controller integral gain
    kffv = 0.0,     #Binary variable enabling the voltage feed-forward in output of current controllers
    rv = 0.0,       #Virtual resistance in pu
    lv = 0.2,       #Virtual inductance in pu
    kpc = 1.27,     #Current controller proportional gain
    kic = 14.3,     #Current controller integral gain
    kffi = 0.0,     #Binary variable enabling the current feed-forward in output of current controllers
    ωad = 50.0,     #Active damping low pass filter cut-off frequency
    kad = 0.2,      #Active damping gain
)

######## PLL Data ########
no_pll() = PSY.FixedFrequency()

######## Filter Data ########
filt() = LCLFilter(lf = 0.08, rf = 0.003, cf = 0.074, lg = 0.2, rg = 0.01)

####### DC Source Data #########
stiff_source() = FixedDCSource(voltage = 690.0)

####### Converter Model #########
average_converter() = AverageConverter(rated_voltage = 690.0, rated_current = 9999.0)

# VSM
function inv_vsm(static_device)
    return PSY.DynamicInverter(
        get_name(static_device), # name
        1.0, #ω_ref
        average_converter(), # converter
        outer_control_vsm(), # outer control
        inner_control(), # inner control
        stiff_source(), # dc source
        no_pll(), # pll
        filt(), # filter
    )
end
