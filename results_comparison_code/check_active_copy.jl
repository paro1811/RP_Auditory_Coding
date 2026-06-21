import Pkg
if VERSION < v"1.11"
    Pkg.activate("MPenvironment10")
else
    Pkg.activate("MPenvironment")
end

using CSV
using DataFrames
using WAV
using Statistics
using Base.Threads
include("../utils_julia/mp_utils.jl")
using .mp_utils


stop_cond = 0.1  

final_dict_file = "ResultsTIMIT_Baseline_128/epoch_6.jld2" 
dataset_tsv     = "TIMIT_train_local_rp.tsv"

log_summary_txt = "ResultsTIMIT_Baseline_128/health_summary_epoch6.txt"
log_details_csv = "ResultsTIMIT_Baseline_128/kernel_details_epoch6.csv"

println("Loading trained kernels from: ", final_dict_file)
kernels = mp_utils.load_kernels_from_jld2(final_dict_file)
total_kernels = length(kernels)

println("Loading dataset from: ", dataset_tsv)
df = CSV.read(dataset_tsv, DataFrame, delim='\t')
total_files = nrow(df)

println("Total audio files to process: ", total_files)
println("Using Stopping Condition:     ", stop_cond)
println("Running on ", Threads.nthreads(), " threads!")
println("--------------------------------------------------")


activity_sums = [Threads.Atomic{Float64}(0.0) for _ in 1:total_kernels]
usage_counts  = [Threads.Atomic{Int}(0) for _ in 1:total_kernels]

completed_files = Threads.Atomic{Int}(0)

println("Running Multi-Threaded Inference Pass over the entire dataset...")

Threads.@threads for i in 1:total_files

    filepath = "path_wav" in names(df) ? df[i, "path_wav"] : df[i, "path"]
    segment_str = df[i, "segments"]

    signal, fs = wavread(filepath)
    signal = vec(signal)

    m = match(r"\"start\":\s*(\d+),\s*\"end\":\s*(\d+)", segment_str)
    
    if m !== nothing
        start_idx = parse(Int, m.captures[1]) + 1
        end_idx   = parse(Int, m.captures[2])
        
        start_idx = max(1, start_idx)
        end_idx   = min(length(signal), end_idx)
        
        signal = signal[start_idx:end_idx]
    end

    x_res, kernel_list, amp_list, index_list, norm_list = mp_utils.matching_pursuit(signal, "amplitude", stop_cond, kernels) 
    
    for j in 1:length(kernel_list)
        kernel_id = kernel_list[j]
        s_amplitude = amp_list[j]
        
        Threads.atomic_add!(activity_sums[kernel_id], abs(s_amplitude))
        Threads.atomic_add!(usage_counts[kernel_id], 1)
    end

    Threads.atomic_add!(completed_files, 1)
    if completed_files[] % 500 == 0
        println("Processed ", completed_files[], " / ", total_files, " files...")
    end
end

final_activity_sums = [x[] for x in activity_sums]
final_usage_counts  = [x[] for x in usage_counts]

median_activity = median(final_activity_sums)
pruning_threshold = 0.10 * median_activity

active_count = 0
dead_count = 0
statuses = String[] 

for i in 1:total_kernels
    if final_activity_sums[i] < pruning_threshold
        global dead_count += 1
        push!(statuses, "Pruned")
    else
        global active_count += 1
        push!(statuses, "Active")
    end
end

health_pct = round((active_count / total_kernels) * 100, digits=2)


println("--------------------------------------------------")
println("Median Population Activity (Σ|s|): ", round(median_activity, digits=2))
println("10% Pruning Threshold:             ", round(pruning_threshold, digits=2))
println("--------------------------------------------------")
println("Active Kernels (Passed the 10% threshold): ", active_count)
println("Pruned Kernels (Failed the 10% threshold): ", dead_count)
println("--------------------------------------------------")
println("True Biological Dictionary Health: ", health_pct, "% successfully learned")
println("--------------------------------------------------")

open(log_summary_txt, "w") do f
    println(f, "Dictionary Evaluated: ", final_dict_file)
    println(f, "Stopping Condition:   ", stop_cond)
    println(f, "Total Files Processed:", total_files)
    println(f, "--------------------------------------------------")
    println(f, "Median Population Activity (Σ|s|): ", round(median_activity, digits=2))
    println(f, "10% Pruning Threshold:             ", round(pruning_threshold, digits=2))
    println(f, "--------------------------------------------------")
    println(f, "Active Kernels (Passed the 10% threshold): ", active_count)
    println(f, "Pruned Kernels (Failed the 10% threshold): ", dead_count)
    println(f, "--------------------------------------------------")
    println(f, "True Biological Dictionary Health: ", health_pct, "% successfully learned")
end
println("Summary saved to: ", log_summary_txt)

df_kernels = DataFrame(
    Kernel_ID = 1:total_kernels,
    Usage_Count = final_usage_counts,
    Activity_Sum = final_activity_sums,
    Status = statuses
)
CSV.write(log_details_csv, df_kernels)
println("Kernel details saved to: ", log_details_csv)