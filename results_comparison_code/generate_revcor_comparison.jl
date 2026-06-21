import Pkg
if VERSION < v"1.11"
    Pkg.activate("MPenvironment10")
else
    Pkg.activate("MPenvironment")
end

using Plots
using DSP
using FFTW
using LinearAlgebra
using Statistics

include("../utils_julia/mp_utils.jl")
using .mp_utils

# ==============================================================================
# Load and preprocess cat revcor data
# ==============================================================================

function load_cat_revcors(cat_dir::String, Fs_orig::Float64, Fs_new::Float64)
    all_files = filter(f -> endswith(f, ".txt"), readdir(cat_dir, join=true))
    processed = []

    for file in all_files
        cat_time_orig = Float64[]
        cat_mag_orig = Float64[]

        for line in eachline(file)
            parts = split(strip(line))
            if length(parts) >= 2
                t_val = tryparse(Float64, parts[1])
                m_val = tryparse(Float64, parts[2])
                if t_val !== nothing && m_val !== nothing
                    push!(cat_time_orig, t_val)
                    push!(cat_mag_orig, m_val)
                end
            end
        end

        if isempty(cat_mag_orig) continue end

        # Spectral centroid filter — skip fibers above 8 kHz
        fft_vals = abs.(fft(cat_mag_orig))
        freqs = fftfreq(length(cat_mag_orig), Fs_orig)
        pos_idx = freqs .> 0
        cat_centroid = sum(freqs[pos_idx] .* (fft_vals[pos_idx].^2)) / sum(fft_vals[pos_idx].^2)
        if cat_centroid > 8000.0 continue end

        # Resample to match TIMIT rate
        resample_ratio = Fs_new / Fs_orig
        cat_mag_16k = resample(cat_mag_orig, resample_ratio)

        # Normalize for plotting
        cat_mag_plot = cat_mag_16k ./ maximum(abs.(cat_mag_16k))
        cat_time_16k = (0:(length(cat_mag_16k)-1)) .* (1000.0 / Fs_new)

        # L2-normalized for correlation matching
        cat_zero = cat_mag_16k .- mean(cat_mag_16k)
        n = norm(cat_zero)
        if n < 1e-12 continue end
        cat_L2 = cat_zero ./ n

        push!(processed, (file, cat_time_16k, cat_mag_plot, cat_L2))
    end

    return processed
end

# ==============================================================================
# Compute best correlation for every kernel, then plot top N
# ==============================================================================

function match_and_plot_top_kernels(kernels, processed_cats, Fs_new, top_n;
                                    kernel_color=:firebrick, ncols=5)

    N = length(kernels)

    # Phase 1: compute best correlation for ALL kernels
    all_matches = []  # (kernel_idx, best_corr, best_cat_idx, best_phase_shift)

    for k_idx in 1:N
        k = kernels[k_idx].kernel
        k_zero = k .- mean(k)
        k_norm_val = norm(k_zero)
        if k_norm_val < 1e-12
            push!(all_matches, (k_idx, 0.0, 1, 1))
            continue
        end
        k_L2 = k_zero ./ k_norm_val

        best_cat_idx = 1
        max_r = -Inf
        best_shift = 1

        for (c_idx, cat) in enumerate(processed_cats)
            _, _, _, cat_L2 = cat
            corr_array = xcorr(cat_L2, k_L2)
            r_max = maximum(corr_array)
            if r_max > max_r
                max_r = r_max
                best_cat_idx = c_idx
                best_shift = argmax(corr_array)
            end
        end

        push!(all_matches, (k_idx, max_r, best_cat_idx, best_shift))
    end

    # Phase 2: sort by correlation, pick top N
    sort!(all_matches, by = x -> x[2], rev=true)
    selected = all_matches[1:min(top_n, length(all_matches))]

    # Sort selected by kernel length (frequency proxy) for visual ordering
    sort!(selected, by = x -> length(kernels[x[1]].kernel))

    all_corrs = [m[2] for m in all_matches]

    # Phase 3: plot
    subplots = []
    plot_corrs = Float64[]

    for (k_idx, max_r, best_cat_idx, best_shift) in selected
        k = kernels[k_idx].kernel

        best_file, cat_time, cat_mag, _ = processed_cats[best_cat_idx]

        k_mag_plot = k ./ maximum(abs.(k))
        shift_amount = best_shift - length(k)
        k_time_raw = ((0:(length(k)-1)) .+ shift_amount) .* (1000.0 / Fs_new)

        alignment_offset = 1.0 - k_time_raw[1]
        k_time_centered = k_time_raw .+ alignment_offset
        cat_time_centered = cat_time .+ alignment_offset

        r_str = string(round(max_r, digits=2))
        push!(plot_corrs, max_r)

        p = plot(cat_time_centered, cat_mag,
                 linewidth = 1.8,
                 color = RGB(0/255, 114/255, 178/255),
                 alpha = 0.7,
                 legend = false,
                 grid = false,
                 ticks = false,
                 framestyle = :none,
                 xlims = (0, 12),
                 margin = 0Plots.mm)

        plot!(p, k_time_centered, k_mag_plot,
              linewidth = 1.8,
              color = kernel_color)

        annotate!(p, [(10.5, 0.85, text("r=$r_str", 6, :right, :grey))])

        push!(subplots, p)
    end

    nrows = ceil(Int, length(subplots) / ncols)
    height = nrows * 140 + 60

    grid_plot = plot(subplots...,
                     layout = (nrows, ncols),
                     size = (1000, height),
                     dpi = 300)

    println("  Top $top_n — mean r = $(round(mean(plot_corrs), digits=3)), median r = $(round(median(plot_corrs), digits=3))")
    println("  All kernels — mean r = $(round(mean(all_corrs), digits=3)), median r = $(round(median(all_corrs), digits=3))")

    return grid_plot, all_corrs
end

# ==============================================================================
# MAIN
# ==============================================================================

function main()
    println("=" ^ 60)
    println("Revcor Comparison — Top 20 Kernels by Correlation")
    println("=" ^ 60)

    Fs_orig = 20000.0
    Fs_new  = 16000.0
    cat_dir = "../CarneyEarlabRevcorData"

    println("\nLoading cat auditory nerve fiber data...")
    processed_cats = load_cat_revcors(cat_dir, Fs_orig, Fs_new)
    println("  Loaded $(length(processed_cats)) valid cat fibers.")

    models = [
        ("32-Kernel",  "../ResultsTIMIT_Optimized_Ng32_revcor/epoch_2.jld2",  "revcor_32"),
        ("64-Kernel",  "../ResultsTIMIT_Optimized_Ng64_revcor/epoch_2.jld2",  "revcor_64"),
        ("128-Kernel", "../ResultsTIMIT_Optimized_Ng128_revcor/epoch_2.jld2", "revcor_128"),
    ]

    all_corr_stats = []

    for (label, path, outname) in models
        println("\n--- $label Dictionary ---")
        kernels = mp_utils.load_kernels_from_jld2(path)
        println("  Loaded $(length(kernels)) kernels")

        grid, corrs = match_and_plot_top_kernels(
            kernels, processed_cats, Fs_new, 20;
            kernel_color = RGB(213/255, 94/255, 0/255),
            ncols = 5)

        savefig(grid, "../result_plots/$outname.png")
        println("  Saved: result_plots/$outname.png")

        push!(all_corr_stats, (label, corrs))
    end

    println("\n" * "=" ^ 60)
    println("SUMMARY (all kernels)")
    for (label, corrs) in all_corr_stats
        println("  $label: mean r = $(round(mean(corrs), digits=3)), median r = $(round(median(corrs), digits=3))")
    end
    println("=" ^ 60)
end

main()
