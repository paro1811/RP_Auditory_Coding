import Pkg
if VERSION < v"1.11"
    Pkg.activate("../MPenvironment10")
else
    Pkg.activate("../MPenvironment")
end

using CSV
using DataFrames
using Plots
using Statistics

col_epoch = "epoch"
col_rate  = "kernels_per_sec"
col_srr   = "SRR"

const CB_BLUE    = RGB(0/255, 114/255, 178/255)
const CB_ORANGE  = RGB(230/255, 159/255, 0/255)
const CB_RED     = RGB(213/255, 94/255, 0/255)
const CB_GREY    = RGB(136/255, 136/255, 136/255)
const CB_GREEN   = RGB(0/255, 158/255, 115/255)

function load_epoch_data(folder::String, target_epoch::Int)
    log_path = joinpath(folder, "training_log.tsv")
    df = CSV.read(log_path, DataFrame, delim='\t')
    sub_df = filter(row -> row[col_epoch] == target_epoch, df)
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
    x_trend = collect(range(x_min, x_max, length=200))
    y_trend = m .* log.(x_trend) .+ b

    marker_indices = round.(Int, range(1, 200, length=5))
    markers_vec = fill(:none, 200)
    sizes_vec = fill(0, 200)
    for i in marker_indices
        markers_vec[i] = marker
        sizes_vec[i] = 7
    end

    plot!(p, x_trend, y_trend,
          label = label, color = color, linestyle = linestyle,
          linewidth = linewidth, markershape = markers_vec,
          markersize = sizes_vec, markercolor = color,
          markerstrokecolor = :white, markerstrokewidth = 1.5)
end

function make_base_plot(; title="", ylims_range=(8, 24))
    plot(
        title = title,
        xlabel = "Kernel Activations per Second",
        ylabel = "Reconstruction Fidelity (SRR in dB)",
        legend = :bottomright,
        size = (900, 550),
        framestyle = :box,
        grid = true,
        left_margin = 10Plots.mm,
        bottom_margin = 8Plots.mm,
        top_margin = 5Plots.mm,
        dpi = 300,
        guidefontsize = 11,
        titlefontsize = 12,
        legendfontsize = 9,
        ylims = ylims_range)
end

function generate_comparison(models, title, filename)
    println("\nGenerating: $filename")

    all_data = []
    smallest_max_x = Inf

    for (folder, epoch, label, color, ls, marker) in models
        X, Y = load_epoch_data(folder, epoch)
        x_max = maximum(X)
        if x_max < smallest_max_x
            smallest_max_x = x_max
        end
        push!(all_data, (X, Y, label, color, ls, marker))
        println("  Loaded: $label (Epoch $epoch) — $(length(X)) points")
    end

    p = make_base_plot(title=title)

    for (X, Y, label, color, ls, marker) in all_data
        plot_trendline!(p, X, Y, label,
                        color=color, linestyle=ls, marker=marker,
                        cap_x=smallest_max_x)
    end

    xlims!(p, minimum([minimum(d[1]) for d in all_data]), smallest_max_x)

    savefig(p, "../result_plots/$filename.png")
    println("  Saved: result_plots/$filename.png")
end

println("=" ^ 60)
println("Appendix Rate-Fidelity Comparisons")
println("=" ^ 60)

generate_comparison([
    ("../ResultsTIMIT_Baseline_32",      6, "Baseline 32",    CB_GREY,  :dash,  :square),
    ("../ResultsTIMIT_Optimized_Ng32",   8, "Optimized 32",   CB_RED,   :solid, :diamond),
], "Rate-Fidelity Comparison: 32-Kernel Training Strategies", "appendix_32_comparison")

generate_comparison([
    ("../ResultsTIMIT_Baseline_64",                 6, "Baseline 64",      CB_GREY,   :dash,     :square),
    ("../ResultsTIMIT_Optimized_Ng64_dropout_only",  8, "Dropout-only 64",  CB_BLUE,   :dot,      :utriangle),
    ("../ResultsTIMIT_Optimized_Ng64",              8, "Optimized 64",     CB_RED,    :solid,    :diamond),
], "Rate-Fidelity Comparison: 64-Kernel Training Strategies", "appendix_64_comparison")

generate_comparison([
    ("../ResultsTIMIT_Baseline_256",         6, "Baseline 256",    CB_GREY,   :dash,     :square),
    ("../ResultsTIMIT_Optimized_Ng256",      8, "Optimized 256",   CB_RED,    :solid,    :diamond),
    ("../ResultsTIMIT_Hybrid_Eval_Ng256",    1, "Hybrid 256",      CB_GREEN,  :dashdot,  :utriangle),
], "Rate-Fidelity Comparison: 256-Kernel Training Strategies", "appendix_256_comparison")

println("\nDone!")
