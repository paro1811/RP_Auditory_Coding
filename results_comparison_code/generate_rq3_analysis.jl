import Pkg
if VERSION < v"1.11"
    Pkg.activate("MPenvironment10")
else
    Pkg.activate("MPenvironment")
end

using Plots
using Statistics
using LinearAlgebra
using FFTW
using DSP
using JLD2

include("../utils_julia/mp_utils.jl")
using .mp_utils

const CB_BLUE   = RGB(0/255, 114/255, 178/255)
const CB_ORANGE = RGB(230/255, 159/255, 0/255)
const CB_RED    = RGB(213/255, 94/255, 0/255)
const CB_GREY   = RGB(136/255, 136/255, 136/255)

# ==============================================================================
# Pairwise max cross-correlation for all kernel pairs
# ==============================================================================

function pairwise_max_correlation(kernels)
    N = length(kernels)

    # L2-normalize each kernel
    normalized = []
    for k in kernels
        v = k.kernel .- mean(k.kernel)
        n = norm(v)
        if n < 1e-12
            push!(normalized, zeros(length(v)))
        else
            push!(normalized, v ./ n)
        end
    end

    max_corrs = Float64[]

    for i in 1:N
        for j in (i+1):N
            c = xcorr(normalized[i], normalized[j])
            push!(max_corrs, maximum(abs.(c)))
        end
    end

    return max_corrs
end

# ==============================================================================
# Spectral centroid for each kernel
# ==============================================================================

function kernel_centroids(kernels, fs::Float64)
    centroids = Float64[]
    for k in kernels
        sig = k.kernel
        N = length(sig)
        fft_vals = abs.(fft(sig))
        freqs = collect(range(0, fs, length=N+1)[1:N])
        half_N = div(N, 2)
        fft_pos = fft_vals[1:half_N]
        freq_pos = freqs[1:half_N]
        power = fft_pos .^ 2
        total = sum(power)
        if total < 1e-12
            push!(centroids, 0.0)
        else
            push!(centroids, sum(freq_pos .* power) / total)
        end
    end
    return centroids
end

function main()
    println("=" ^ 60)
    println("RQ3 Analysis — Spectral Coverage & Pairwise Redundancy")
    println("=" ^ 60)

    fs = 16000.0

    models = [
        ("Optimized 32",  "../ResultsTIMIT_Optimized_Ng32/epoch_8.jld2",  CB_BLUE),
        ("Optimized 64",  "../ResultsTIMIT_Optimized_Ng64_dropout_only/epoch_6.jld2", CB_ORANGE),
        ("Optimized 128", "../ResultsTIMIT_Optimized_Ng128/epoch_8.jld2", CB_RED),
        ("Optimized 256", "../ResultsTIMIT_Optimized_Ng256/epoch_8.jld2", CB_GREY),
    ]

    # =====================================================
    # 1. PAIRWISE REDUNDANCY HISTOGRAM
    # =====================================================
    println("\n--- Pairwise Redundancy Analysis ---")

    p_hist = plot(
        xlabel = "Maximum Pairwise Cross-Correlation",
        ylabel = "Proportion of Kernel Pairs",
        title = "Pairwise Kernel Redundancy Across Dictionary Sizes",
        legend = :topright,
        size = (900, 500),
        framestyle = :box,
        grid = true,
        left_margin = 10Plots.mm,
        bottom_margin = 8Plots.mm,
        top_margin = 5Plots.mm,
        dpi = 300,
        guidefontsize = 11,
        titlefontsize = 12,
        legendfontsize = 9,
        ylim = (0, 0.55)
    )

    for (label, path, color) in models
        kernels = mp_utils.load_kernels_from_jld2(path)
        println("  $label: $(length(kernels)) kernels")

        corrs = pairwise_max_correlation(kernels)
        n_pairs = length(corrs)

        # Proportion above thresholds
        above_05 = count(c -> c > 0.5, corrs) / n_pairs * 100
        above_07 = count(c -> c > 0.7, corrs) / n_pairs * 100
        above_09 = count(c -> c > 0.9, corrs) / n_pairs * 100
        println("    Pairs: $n_pairs | >0.5: $(round(above_05, digits=1))% | >0.7: $(round(above_07, digits=1))% | >0.9: $(round(above_09, digits=1))%")
        println("    Mean: $(round(mean(corrs), digits=3)) | Median: $(round(median(corrs), digits=3)) | Max: $(round(maximum(corrs), digits=3))")

        bins = range(0, 1, length=31)
        histogram!(p_hist, corrs,
                   bins = bins,
                   normalize = :probability,
                   label = label,
                   color = color,
                   alpha = 0.5,
                   linecolor = color,
                   linewidth = 1.5)
    end

    savefig(p_hist, "../result_plots/rq3_pairwise_redundancy.png")
    println("  Saved: result_plots/rq3_pairwise_redundancy.png")

    # =====================================================
    # 2. SPECTRAL COVERAGE
    # =====================================================
    println("\n--- Spectral Coverage Analysis ---")

    band_edges = [100, 500, 1000, 2000, 3000, 4000, 5000, 6000]
    band_labels = ["100-500", "500-1k", "1k-2k", "2k-3k", "3k-4k", "4k-5k", "5k-6k"]
    n_bands = length(band_labels)

    p_bars = plot(
        xlabel = "Frequency Band (Hz)",
        ylabel = "Number of Kernels",
        title = "Spectral Coverage Across Dictionary Sizes",
        legend = :topleft,
        size = (900, 500),
        framestyle = :box,
        grid = true,
        left_margin = 10Plots.mm,
        bottom_margin = 10Plots.mm,
        top_margin = 5Plots.mm,
        dpi = 300,
        guidefontsize = 11,
        titlefontsize = 12,
        legendfontsize = 9,
        ylim = (0, 105)
    )

    bar_width = 0.2
    offsets = [-1.5, -0.5, 0.5, 1.5] .* bar_width

    for (idx, (label, path, color)) in enumerate(models)
        kernels = mp_utils.load_kernels_from_jld2(path)
        centroids = kernel_centroids(kernels, fs)

        counts = zeros(Int, n_bands)
        for c in centroids
            for b in 1:n_bands
                if c >= band_edges[b] && c < band_edges[b+1]
                    counts[b] += 1
                    break
                end
            end
        end

        println("  $label: $(counts) (total=$(sum(counts)))")

        x_pos = (1:n_bands) .+ offsets[idx]
        bar!(p_bars, x_pos, counts,
             bar_width = bar_width,
             label = label,
             color = color,
             linecolor = :white,
             linewidth = 0.5)
    end

    xticks!(p_bars, 1:n_bands, band_labels)

    savefig(p_bars, "../result_plots/rq3_spectral_coverage.png")
    println("  Saved: result_plots/rq3_spectral_coverage.png")

    println("\nDone!")
end

main()
