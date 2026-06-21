"""
    Script for testing functions in mp_utils:
    - short_time_matching_pursuit
    - matching_pursuit
    - reconstruct_matching_pursuit
    - reconstruct_matching_pursuit_and_get_residue_norm

    And also for testing the extra functions:
    - load_kernels_from_jld2
    - save_kernels_to_jld2

    It is worth noting that this script does not test all possible options of the functions.
    Also, the different matching pursuit functions and their parameters are still quite chaotic.
    The struct MPparams is defined to make this a bit cleaner, but i'm not sure how to incorporate the different options cleanly...
"""

# Activate the current environment to ensure the correct dependencies are used
import Pkg
if VERSION < v"1.11"
    println("Julia Version ", VERSION, " detected. No environment activation possible...")
else
    Pkg.activate("MPenvironment")
    println("Julia Version ", VERSION, " detected. Activating MPenvironment...")
end
include(joinpath(@__DIR__, "../mp_utils.jl"))  	# Load the file containing the MP functions


import .mp_utils
using WAV
using LinearAlgebra
using Plots


function load_audio(path)
    local x, fs_read, successLoadFlag
    try
        x, fs_read = wavread(path)
        successLoadFlag = true
    catch e
        x = nothing
        fs_read = nothing
        successLoadFlag = false
        println("Failed reading: ", path)
    end
    if isnothing(x) || isempty(x)
        println("Empty audio file: ", path)
        successLoadFlag = false
    end
    return x, fs_read, successLoadFlag
end


function preprocess(audio, fs)
    # Do any appropriate preprocessing here
    return audio, fs
end


function get_audio()
    # Load audio which needs to be encoded
    x, fs_read, succesLoadFlag = load_audio("tests/data/test_audio.wav")
    if !succesLoadFlag
        error("Failed loading audio file")
    end
    x, fs = preprocess(x, fs_read) # This does nothing in this example
    return x, fs
end


function test_load_and_store_kernels(kernel_path = "tests/data/kernels_TIMIT.jld2")
    println("Testing loading and storing kernels to/from JLD2 files")
    println(" Expected output: a plot with 32 kernels should be displayed twice. We also expect a watning about abs_amp")
    println("---------------------------------------------------")
    println(" ")

    # Load a dictionary and plot it
    # This will generate a warning because the file was saved with a somehwat different version of this code
    kernels = mp_utils.load_kernels_from_jld2(kernel_path) 
    println("Type of kernels: ", typeof(kernels)) 
    println(" ")
    mp_utils.plot_kernels(kernels)


    # We will also test the function to store the kernels (and reload them)
    mp_utils.save_kernels_to_jld2("tests/output/kernels_TIMIT_test_save.jld2", kernels)
    kernels = mp_utils.load_kernels_from_jld2("tests/output/kernels_TIMIT_test_save.jld2") 
    println("Type of kernels: ", typeof(kernels)) 
    println(" ")
    mp_utils.plot_kernels(kernels)


    return kernels
end


function test_short_time_matching_pursuit(x, kernels)
    # Define MPparam struct
    frame_length = 2*maximum([length(k.kernel) for k in kernels])
    hop_length = maximum([length(k.kernel) for k in kernels])
    crop_length = frame_length - maximum([length(k.kernel) for k in kernels]) + 1 # crop length is a misnomer, it is the length we keep!!

    MPparam = mp_utils.MPparams(
    "amplitude",         # stop type: "amplitude" or "iterations"
        0.1,                # stop condition: (amplitude threshold or max number of iterations)
        10000,              # Maximum number of iterations (equivalently: selected kernels)
        frame_length,     # Window length for short-time MP
        hop_length,        # Hop length for short-time MP
        crop_length        # Crop length for short-time MP
    )

    @time encoded_waveform, x_res = mp_utils.short_time_matching_pursuit(kernels, x, MPparam.stop_type, MPparam.stop_cond, MPparam.hop_length, MPparam.frame_length, MPparam.crop_length)   
    kernel_list, amp_list, index_list = mp_utils.split_tuple_encoding(encoded_waveform) 
    println("Number of selected kernels: ", length(kernel_list))
    println("Norm of residue: ", norm(x_res))
    println(" ")

    return index_list, kernel_list, amp_list, x_res
end


function test_matching_pursuit(x, kernels)
    MPparam = mp_utils.MPparams(
    "amplitude",         # stop type: "amplitude" or "iterations"
        0.1,                # stop condition: (amplitude threshold or max number of iterations)
        10000,              # Maximum number of iterations (equivalently: selected kernels)
        0,
        0,
        0,          # These last three parameters are not used for normal matching pursuit  
    )

    # With normal (convolutional) matching pursuit
    @time x_res, kernel_list, amp_list, index_list, _ = mp_utils.matching_pursuit(x, MPparam.stop_type, MPparam.stop_cond, kernels, nothing, MPparam.max_iter)
    println("Number of selected kernels: ", length(index_list))
    println("Norm of residue: ", norm(x_res))
    println(" ")

    return index_list, kernel_list, amp_list, x_res
end


function test_reconstruct_matching_pursuit(index_list, kernel_list, amp_list, kernels, x_res, x_ref)
    # Lets check the reconstructions
    x_hat_1 = mp_utils.reconstruct_matching_pursuit(index_list, kernel_list, amp_list, kernels, x_res)
    x_hat_2, residue_norm = mp_utils.reconstruct_matching_pursuit_and_get_residue_norm(index_list, kernel_list, amp_list, kernels, x_ref)
    println("Error of reconstruction 1 (reconstruct_matching_pursuit): ", norm(x_hat_1 + x_res - x_ref))
    println("Error of reconstruction 2 (reconstruct_matching_pursuit_and_get_residue_norm): ", norm(x_hat_2 + x_res - x_ref))
    
    # For short-time matching pursuit, the residue norm can look odd, so we also try sorting it
    INDX = sortperm(abs.(amp_list), rev=true)
    _, residue_norm_sort = mp_utils.reconstruct_matching_pursuit_and_get_residue_norm(index_list[INDX], kernel_list[INDX], amp_list[INDX], kernels, x_ref)

    p = plot(20*log10.(norm(x_ref)./residue_norm), label="unsorted")   # Plot the SRR in dB --> note: the SRR is not concave because of the windowing
    plot!(20*log10.(norm(x_ref)./residue_norm_sort), label="sorted")  # Plot the sorted SRR in dB
    display(p)
    return
end


function test_store_encoding(x_res, kernel_list, amp_list, index_list)
    file_name = "test_encoding.jld2"
    dir_name = "tests/output"
    kernel_path = "tests/data/kernels_TIMIT.jld2"
    mp_utils.store_encoded_waveform_jld2(x_res, kernel_list, amp_list, index_list, file_name, dir_name, kernel_path)
end
    
# Test if loading and storing kernels works
kernels = test_load_and_store_kernels()

# Load audio
x, fs = get_audio()
x_ref = copy(x)

# Test short-time matching pursuit and the reconstruction and the storing
index_list, kernel_list, amp_list, x_res = test_short_time_matching_pursuit(x, kernels)
test_reconstruct_matching_pursuit(index_list, kernel_list, amp_list, kernels, x_res, x_ref)
test_store_encoding(x_res, kernel_list, amp_list, index_list)


# Test normal matching pursuit and the reconstruction and the storing
index_list, kernel_list, amp_list, x_res = test_matching_pursuit(x, kernels)
test_reconstruct_matching_pursuit(index_list, kernel_list, amp_list, kernels, x_res, x_ref)


