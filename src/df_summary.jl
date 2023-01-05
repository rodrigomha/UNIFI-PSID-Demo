function summary_participation_factors(pf::Dict{String, Dict{Symbol, Array{Float64}}}, eigs::Vector{ComplexF64})
    pf_ord = sort(OrderedDict(pf))
    names = ["λ_$(k)" for k in 1:length(eigs)]
    names = vcat(["Name"], names)
    df = DataFrame([name => [] for name in names])

    for (device, dict_pfs) in pf_ord
        ord_dict_pfs = sort(OrderedDict(dict_pfs))
        for (state, state_pf) in ord_dict_pfs
            row = vcat(device*" "*String(state), round.(state_pf, digits = 8))
            push!(df, row)
        end
    end
    return df
end

function summary_participation_factors(sm::PowerSimulationsDynamics.SmallSignalOutput)
    eigs = sm.eigenvalues
    pf = sm.participation_factors
    return summary_participation_factors(pf,eigs)
end

function summary_eigenvalues(pf::Dict{String, Dict{Symbol, Array{Float64}}}, eigs::Vector{ComplexF64})
    df = summary_participation_factors(pf, eigs)
    df_noname = df[!, 2:end]
    most_associated = Vector{Int}(undef, length(eigs))
    for (ix, col_pfs) in enumerate(eachcol(df_noname))
        most_associated[ix] = findfirst(==(maximum(col_pfs)), col_pfs)
    end
    col_names = ["Most Associated", "Part. Factor", "Real Part", "Imag. Part", "Damping", "Freq [Hz]"]
    df_summary = DataFrame([name => [] for name in col_names])
    for (ix, eig) in enumerate(eigs)
        eig_associated = most_associated[ix]
        state_name = df[ix, "Name"]
        pf_val = df_noname[eig_associated, ix]
        freq_rad = abs(eig)
        damping = - real(eig) / freq_rad
        row = [state_name, pf_val, real(eig), imag(eig), damping, freq_rad / (2pi)]
        push!(df_summary, row)
    end
    return df_summary
end

function summary_eigenvalues(sm::PowerSimulationsDynamics.SmallSignalOutput)
    eigs = sm.eigenvalues
    pf = sm.participation_factors
    return summary_eigenvalues(pf, eigs)
end

