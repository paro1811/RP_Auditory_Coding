import Pkg
if VERSION < v"1.11"
    Pkg.activate("MPenvironment10")
else
    Pkg.activate("MPenvironment")
end

using CSV
using DataFrames
using Plots
using Statistics

# ==============================================================================
# CONFIGURATION
# ==============================================================================

col_epoch = "epoch"
col_rate  = "kernels_per_sec"
col_srr   = "SRR"

const CB_BLUE    = RGB(0/255, 114/255, 178/255)
const CB_ORANGE  = RGB(230/255, 159/255, 0/255)
const CB_GREEN   = RGB(0/255, 158/255, 115/255)
const CB_RED     = RGB(213/255, 94/255, 0/255)
const CB_PURPLE  = RGB(204/255, 121/255, 167/255)
const CB_GREY    = RGB(136/255, 136/255, 136/255)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

function load_epoch_data(folder::String, target_epoch::Int)
    log_path = joinpath(folder, "training_log.tsv")
    if !isfile(log_path)
        error("Could not find $log_path")
    end
    df = CSV.read(log_path, DataFrame, delim='\t')
    sub_df = filter(row -> row[col_epoch] == target_epoch, df)
    if nrow(sub_df) < 2
        error("Not enough data for $folder epoch $target_epoch")
    end
    return sub_df[!, col_rate], sub_df[!, col_srr]
end

function fit_log_trendline(X, Y)
    log_X = log.(X)
    m = cov(log_X, Y) / var(log_X)
    b = mean(Y) - m * mean(log_X)
    return m, b
end

function plot_trendline!(p, X, Y, label; color, linestyle, linewidth=3, marker=:none, cap_x=nothing)
    m, b = fit_log_trendline(X, Y)

    x_min = minimum(X)
    x_max = cap_x !== nothing ? min(maximum(X), cap_x) : maximum(X)

    # 200 points for a smooth curve
    x_trend = collect(range(x_min, x_max, length=200))
    y_trend = m .* log.(x_trend) .+ b

    # Place markers at 5 evenly spaced indices within the 200 points
    marker_indices = round.(Int, range(1, 200, length=5))
    markers_vec = fill(:none, 200)
    sizes_vec = fill(0, 200)
    for i in marker_indices
        markers_vec[i] = marker
        sizes_vec[i] = 7
    end

    plot!(p, x_trend, y_trend,
          label = label,
          color = color,
          linestyle = linestyle,
          linewidth = linewidth,
          markershape = markers_vec,
          markersize = sizes_vec,
          markercolor = color,
          markerstrokecolor = :white,
          markerstrokewidth = 1.5)
end

function make_base_plot(; title="", ylims_range=(8, 24))
    plot(
        title = title,
        xlabel = "Kernel Activations per Second",
        ylabel = "Reconstruction Fidelity (SRR in dB)",
        legend = :bottomright,
        size = (900, 600),
        grid = true,
        minorgrid = false,
        framestyle = :box,
        ylims = ylims_range,
        left_margin = 10Plots.mm,
        bottom_margin = 8Plots.mm,
        top_margin = 5Plots.mm,
        right_margin = 5Plots.mm,
        dpi = 300,
        legendfontsize = 9,
        guidefontsize = 11,
        titlefontsize = 12,
        tickfontsize = 9,
        background_color = :white,
        foreground_color = :black
    )
end

# ==============================================================================
# FIGURE 1: HERO PLOT — Best model per dictionary size
# ==============================================================================

function generate_hero_plot()
    println("Generating Figure 1: Hero Rate-Fidelity Plot...")

    models = [
        ("../ResultsTIMIT_Optimized_Ng32",                 7,  "Optimized 32",        CB_BLUE,   :solid,  :circle),
        ("../ResultsTIMIT_Optimized_Ng64_dropout_only",    6,  "Optimized 64",        CB_ORANGE, :dash,   :utriangle),
        ("../ResultsTIMIT_Optimized_Ng128",                8,  "Optimized 128",       CB_RED,    :solid,  :diamond),
        ("../ResultsTIMIT_Hybrid_Eval_Ng256",              1,  "Hybrid 256",          CB_GREY,   :dot,    :square),
    ]

    # Pass 1: load all data, find common x-range
    all_data = []
    smallest_max_x = Inf

    for (folder, epoch, label, color, ls, marker) in models
        X, Y = load_epoch_data(folder, epoch)
        x_max = maximum(X)
        if x_max < smallest_max_x
            smallest_max_x = x_max
        end
        push!(all_data, (X, Y, label, color, ls, marker))
        println("  Loaded: $label (Epoch $epoch) — $(length(X)) points, rate range [$(round(minimum(X), digits=0)), $(round(x_max, digits=0))]")
    end

    # Pass 2: plot
    p = make_base_plot(title="Rate-Fidelity Comparison Across Dictionary Sizes")

    for (X, Y, label, color, ls, marker) in all_data
        plot_trendline!(p, X, Y, label,
                        color=color, linestyle=ls, marker=marker,
                        cap_x=smallest_max_x)
    end

    xlims!(p, minimum([minimum(d[1]) for d in all_data]), smallest_max_x)

    save_path = "../result_plots/hero_rate_fidelity.png"
    savefig(p, save_path)
    println("  Saved: $save_path")

    save_path_svg = "../result_plots/hero_rate_fidelity.svg"
    savefig(p, save_path_svg)
    println("  Saved: $save_path_svg")

    return p
end

# ==============================================================================
# FIGURE 2: 128-KERNEL COMPARISON
# ==============================================================================

function generate_128_comparison()
    println("\nGenerating Figure 2: 128-Kernel Comparison...")

    models = [
        ("../ResultsTIMIT_Baseline_128",                   6,  "Baseline 128",        CB_GREY,   :dash,   :square),
        ("../ResultsTIMIT_Optimized_Ng128_dropout_only",   6,  "Dropout-only 128",    CB_BLUE,   :dot,    :utriangle),
        ("../ResultsTIMIT_Optimized_Ng128",                8,  "Optimized 128",       CB_RED,    :solid,  :diamond),
    ]

    all_data = []
    smallest_max_x = Inf

    for (folder, epoch, label, color, ls, marker) in models
        X, Y = load_epoch_data(folder, epoch)
        x_max = maximum(X)
        if x_max < smallest_max_x
            smallest_max_x = x_max
        end
        push!(all_data, (X, Y, label, color, ls, marker))
        println("  Loaded: $label (Epoch $epoch) — $(length(X)) points, rate range [$(round(minimum(X), digits=0)), $(round(x_max, digits=0))]")
    end

    p = make_base_plot(title="Rate-Fidelity Comparison: 128-Kernel Training Strategies")

    for (X, Y, label, color, ls, marker) in all_data
        plot_trendline!(p, X, Y, label,
                        color=color, linestyle=ls, marker=marker,
                        cap_x=smallest_max_x)
    end

    xlims!(p, minimum([minimum(d[1]) for d in all_data]), smallest_max_x)

    save_path = "../result_plots/128_comparison.png"
    savefig(p, save_path)
    println("  Saved: $save_path")

    save_path_svg = "../result_plots/128_comparison.svg"
    savefig(p, save_path_svg)
    println("  Saved: $save_path_svg")

    return p
end

# ==============================================================================
# RUN
# ==============================================================================

println("=" ^ 60)
println("Paper Plot Generator — Section IV Figures")
println("=" ^ 60)

generate_hero_plot()
generate_128_comparison()

println("\nDone! All plots saved to result_plots/")
