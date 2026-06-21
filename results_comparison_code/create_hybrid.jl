import Pkg
if VERSION < v"1.11"
    Pkg.activate("MPenvironment10")
else
    Pkg.activate("MPenvironment")
end

include("../utils_julia/mp_utils.jl")
using .mp_utils
using Random

function main()
    path_256 = "../ResultsTIMIT_Optimized_Ng256/epoch_8.jld2"
    path_128 = "../ResultsTIMIT_Optimized_Ng128/epoch_8.jld2"
    
    output_path = "../ResultsTIMIT_Hybrid_Ng256/epoch1.jld2"
    out_dir = dirname(output_path)
    if !isdir(out_dir)
        mkpath(out_dir)
    end

    println("Loading dictionaries...")

    kernels_256 = mp_utils.load_kernels_from_jld2(path_256)
    kernels_128 = mp_utils.load_kernels_from_jld2(path_128)

    len_256 = length(kernels_256)
    len_128 = length(kernels_128)
    println(" -> Found $len_256 kernels in the 256-set.")
    println(" -> Found $len_128 kernels in the 128-set.")

    if len_256 <= len_128
        error("The '256' set must be strictly larger than the '128' set for replacement to work!")
    end

    println("Randomly replacing $len_128 kernels in the larger set...")

    num_to_keep = len_256 - len_128

    Random.seed!(42) 

    shuffled_256 = shuffle(kernels_256)
    kept_from_256 = shuffled_256[1:num_to_keep]

    hybrid_kernels = vcat(kept_from_256, kernels_128)

    println("Created hybrid dictionary with $(length(hybrid_kernels)) kernels.")
    
    mp_utils.save_kernels_to_jld2(output_path, hybrid_kernels)
    println("✅ Saved successfully to $output_path")
end

main()