import Pkg
if VERSION < v"1.11"
    Pkg.activate("MPenvironment10")
else
    Pkg.activate("MPenvironment")
end

using CSV
using DataFrames
using WAV
using LinearAlgebra

BLAS.set_num_threads(1)

include("../utils_julia/mp_utils.jl")
using .mp_utils

# ==============================================================================
# 1. SETUP — EQUAL BIT RATE VIA BINARY SEARCH ON STOP CONDITION
# ==============================================================================
num_test_files = 8

test_dataset_tsv = "reconstruction_dataset.tsv"
output_dir       = "Listening_Test_Audio"

# Target bit rate in bits per second (same for all models).
# Each spike costs: log2(Ng) + 16 (amplitude) + 16 (position) bits.
# ~23.4 kbps ≈ 600 spikes/sec for Ng=128, the natural operating point at 0.1.
target_bit_rate = 23400.0

# Bits per spike independent of dictionary size
bits_amplitude = 16
bits_position  = 16

# Binary search parameters
bisect_tol      = 0.05   # converge within 5% of target
bisect_max_iter = 12

models_to_test = [
    "Opt_32"          => ("ResultsTIMIT_Optimized_Ng32/epoch_8.jld2",              32),
    "Opt_64_dropout"  => ("ResultsTIMIT_Optimized_Ng64_dropout_only/epoch_6.jld2", 64),
    "Opt_128"         => ("ResultsTIMIT_Optimized_Ng128/epoch_8.jld2",            128),
    "Opt_256"         => ("ResultsTIMIT_Optimized_Ng256/epoch_8.jld2",            256),
]

if !isdir(output_dir)
    mkdir(output_dir)
end

spike_log = DataFrame(
    Audio_File       = String[],
    Model            = String[],
    Ng               = Int[],
    Duration_sec     = Float64[],
    Bits_Per_Spike   = Float64[],
    Target_Bitrate   = Float64[],
    Target_Spikes    = Int[],
    Actual_Spikes    = Int[],
    Stop_Cond_Found  = Float64[],
    Achieved_Bitrate = Float64[],
    Bisect_Iters     = Int[]
)

# ==============================================================================
# 2. BINARY SEARCH HELPERS
# ==============================================================================
function count_spikes_stmp(kernels, signal, stop_cond)
    encoded, _ = mp_utils.short_time_matching_pursuit(
        kernels, signal, "amplitude", stop_cond
    )
    return length(encoded)
end

function find_stop_cond(kernels, signal, target_spikes; tol=0.05, max_iter=12)
    lo = 0.005
    hi = 0.5

    n_lo = count_spikes_stmp(kernels, signal, lo)
    n_hi = count_spikes_stmp(kernels, signal, hi)

    if n_lo <= target_spikes
        return lo, n_lo, 0
    end
    if n_hi >= target_spikes
        return hi, n_hi, 0
    end

    best_cond   = lo
    best_spikes = n_lo
    for iter in 1:max_iter
        mid = (lo + hi) / 2.0
        n_mid = count_spikes_stmp(kernels, signal, mid)

        rel_err = abs(n_mid - target_spikes) / target_spikes
        best_cond   = mid
        best_spikes = n_mid

        if rel_err < tol
            return mid, n_mid, iter
        end

        if n_mid > target_spikes
            lo = mid
        else
            hi = mid
        end
    end

    return best_cond, best_spikes, max_iter
end

# ==============================================================================
# 3. PROCESS
# ==============================================================================
println("Loading test dataset from: ", test_dataset_tsv)
df = CSV.read(test_dataset_tsv, DataFrame, delim='\t')
total_files = nrow(df)
num_test_files = min(num_test_files, total_files)

println("Target bit rate: ", target_bit_rate, " bps (equal for all models)")
println("Processing ", num_test_files, " files × ", length(models_to_test), " models")
println("==================================================")

for i in 1:num_test_files
    println("\n=== Audio #", i, " / ", num_test_files, " ===")

    audio_subfolder = joinpath(output_dir, "Audio_$i")
    if !isdir(audio_subfolder)
        mkdir(audio_subfolder)
    end

    filepath = "path_wav" in names(df) ? df[i, "path_wav"] : df[i, "path"]
    filepath = replace(filepath, "/Users/pbadiger/Downloads/TIMIT16kHz" => "/home/user/TIMIT16kHz")
    segment_str = df[i, "segments"]

    signal, fs = wavread(filepath)
    signal = vec(signal)

    m = match(r"\"start\":\s*(\d+),\s*\"end\":\s*(\d+)", segment_str)
    if m !== nothing
        start_idx = max(1, parse(Int, m.captures[1]) + 1)
        end_idx   = min(length(signal), parse(Int, m.captures[2]))
        signal = signal[start_idx:end_idx]
    end

    duration_sec = length(signal) / fs

    wavwrite(signal, joinpath(audio_subfolder, "0_Original.wav"), Fs=fs)

    println("  Duration: ", round(duration_sec, digits=2), "s")

    for (model_name, (dict_path, Ng)) in models_to_test
        bits_per_spike = log2(Ng) + bits_amplitude + bits_position
        target_spikes  = round(Int, target_bit_rate * duration_sec / bits_per_spike)

        println("\n  --- ", model_name, " (Ng=", Ng, ") ---")
        println("    bits/spike=", round(bits_per_spike, digits=1),
                " | target=", target_spikes, " spikes (",
                round(target_spikes / duration_sec, digits=1), "/sec)")

        kernels = mp_utils.load_kernels_from_jld2(dict_path)

        t0 = time()
        stop_cond, actual_spikes, n_bisect = find_stop_cond(
            kernels, signal, target_spikes;
            tol=bisect_tol, max_iter=bisect_max_iter
        )

        encoded_waveform, x_res = mp_utils.short_time_matching_pursuit(
            kernels, signal, "amplitude", stop_cond
        )
        actual_spikes = length(encoded_waveform)
        achieved_bitrate = actual_spikes * bits_per_spike / duration_sec

        elapsed = round(time() - t0, digits=1)

        println("    RESULT: stop_cond=", round(stop_cond, digits=5),
                " | ", actual_spikes, " spikes | ",
                round(achieved_bitrate, digits=1), " bps | ",
                elapsed, "s (",  n_bisect, " bisect steps)")

        if actual_spikes == 0
            reconstructed_signal = zeros(length(signal))
        else
            kernel_list, amp_list, index_list = mp_utils.split_tuple_encoding(encoded_waveform)
            reconstructed_signal = mp_utils.reconstruct_matching_pursuit(
                index_list, kernel_list, amp_list, kernels, signal
            )
        end

        push!(spike_log, (
            "Audio_$i", model_name, Ng, duration_sec,
            bits_per_spike, target_bit_rate, target_spikes,
            actual_spikes, stop_cond, achieved_bitrate, n_bisect
        ))

        wavwrite(reconstructed_signal, joinpath(audio_subfolder, "$(model_name).wav"), Fs=fs)
    end
end

spike_log_path = joinpath(output_dir, "spike_counts.csv")
CSV.write(spike_log_path, spike_log)

println("\n==================================================")
println("Done! Spike log: ", spike_log_path)
println("\nPer-model summary (target: ", target_bit_rate, " bps):")
println("Model                | Ng  | bits/spike | mean stop_cond | mean bitrate (bps)")
println("---------------------|-----|------------|----------------|-------------------")
for (model_name, (_, Ng)) in models_to_test
    sub = filter(row -> row.Model == model_name, spike_log)
    if nrow(sub) > 0
        bps = log2(Ng) + bits_amplitude + bits_position
        mean_cond = round(mean(sub.Stop_Cond_Found), digits=5)
        mean_rate = round(mean(sub.Achieved_Bitrate), digits=1)
        pad_name  = rpad(model_name, 21)
        println(pad_name, "| ", lpad(string(Ng), 3), " | ",
                lpad(string(round(bps, digits=1)), 10), " | ",
                lpad(string(mean_cond), 14), " | ",
                lpad(string(mean_rate), 17))
    end
end
