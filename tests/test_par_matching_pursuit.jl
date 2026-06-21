import Pkg
Pkg.activate("MPenvironment")

# Import the `par_measure.jl` file and the functions it contains
include("../par_measure.jl")
include("../mp_utils.jl")

import .mp_utils

using FFTW
using WAV
using LinearAlgebra
using Plots
using DSP
using Base.Threads


function load_kernels(kernel_path = "tests/data/kernels_TIMIT_test_save.jld2")
    kernels = mp_utils.load_kernels_from_jld2(kernel_path) 
    return kernels
end


function preprocess(audio, fs)
    # Do any appropriate preprocessing here
    return audio, fs
end


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


function get_audio()
    # Load audio which needs to be encoded
    x, fs_read, succesLoadFlag = load_audio("tests/data/test_audio.wav")
    if !succesLoadFlag
        error("Failed loading audio file")
    end
    x, fs = preprocess(x, fs_read) # This does nothing in this example
    return x, fs
end


# Short-time matching pursuit main function
function short_time_matching_pursuit_par(
    Par_measure::ParMeasure,
    dictionary::AbstractVector,
    x::Matrix{<:Real},
    stop_type::String,
    stop_condition::Union{Float64, Int, Int32},
    hop_length::Union{Int, Int32, Nothing} = nothing,
    frame_length::Union{Int, Int32, Nothing} = nothing, #window for rectangular segmentation
    crop_length::Union{Int, Int32, Nothing} = nothing, 
    window_length::Union{Int, Int32, Nothing} = nothing, #window for windowing signal end
    plot_flag::Bool = false)


    if stop_type != "par_disturbance"
        println("Warning: in short_time_matching_pursuit_par - stop_type should be par_disturbance")
    end

    function delay_vector(N::Union{Int32, Int}, d::Union{Int, Real})
        k = 0:N-1
        return exp.(-im * 2π * d .* k ./ N)
    end


    function get_window(N::Union{Int32, Int, Nothing}, rectangular_length::Union{Int32, Int})
        # Create a window which is rectangular, apart from the righthand side which is the right side of a Hamming window
        window = ones(rectangular_length,1)
        if !isnothing(N)
            w = hamming(N*2) # Select a hamming window of twice the length specified by the user
            window[end-N+1:end] = window[end-N+1:end].*w[end-N+1:end]
        end
        return window
    end

    # Handle default parameters using max kernel length
    if hop_length === nothing || frame_length === nothing || crop_length === nothing
        kernel_lengths = [length(k.kernel) for k in dictionary]
    end


    if frame_length === nothing
        frame_length = 2*Par_measure.Nparam
        println("Warning: No frame_length specified. Using default value of Par_measure.Nparam*2=", frame_length)
    end

    if hop_length === nothing
        hop_length =  frame_length- maximum(kernel_lengths)
        println("Warning: No hop_length specified. Using default value of frame_length - (maximum kernel_length) =", hop_length)
    end

    if crop_length === nothing
        crop_length = frame_length - maximum(kernel_lengths) + 1
        println("Warning: No crop_length specified. Using default value of frame_length - maximum kernel length + 1=", crop_length)
    end

    
    # Copy the input to avoid modifying the original signal
    x_res = copy(x)  

    # Delay-Vec
    delay_vec = delay_vector(frame_length, 1)

    # Window 
    window = get_window(window_length, frame_length)

    # Kernels will be used in Discrete-Fourier domain
    dictionary_hat = [mp_utils.KernelFourier(rfft([d.kernel; zeros(frame_length - length(d.kernel))])) for d in dictionary]

    # Initialize variables
    encoded_waveform = Vector{Tuple{Int, Float64, Int}}()  
    n_frame = -1
    while true
        n_frame += 1
        indx_start = n_frame * hop_length + 1
        indx_end = indx_start + frame_length - 1

        if indx_end > length(x)
            break
        end

        masker = x - x_res        

        if plot_flag
            p = plot(x[indx_start:indx_end], label="input")
            plot!(masker[indx_start:indx_end], label="initial masker")
            plot!(x_res[indx_start:indx_end].*window, label="residue")
            ylims!(-1,1)
            display(p)
            p = []
        end


        x_res, encoded_waveform_frame = short_time_matching_pursuit_par_iter(
            dictionary, Par_measure, copy(masker), x_res, indx_start, indx_end,
            stop_condition, crop_length, window, delay_vec
        )

        if !isempty(encoded_waveform_frame)
            encoded_adjusted = [(k, a, i + indx_start - 1) for (k, a, i) in encoded_waveform_frame]
            append!(encoded_waveform, encoded_adjusted)
        end

        masker = x - x_res
        if plot_flag
            p = plot(x[indx_start:indx_end], label="input")
            plot!(masker[indx_start:indx_end], label="final masker")
            plot!(x_res[indx_start:indx_end], label="residue")
            ylims!(-1,1)
            display(p)
            p = []
        end
    end

    return encoded_waveform, x_res
end


function short_time_matching_pursuit_par_iter(
    dictionary::Union{Vector{Main.mp_utils.Kernel}, Vector{Any}},
    Par_measure::ParMeasure, 
    masker::Matrix{<:Real},
    x_res::Matrix{<:Real},
    indx_start::Int,
    indx_end::Int,
    stop_condition,
    crop_length::Union{Int, Int32},
    window::Matrix{<:Real},
    delay_vec)

    # Extract a copy of the segment to process
    x_seg = copy(x_res[indx_start:indx_end])            
    x_seg = x_seg.*window
    masker = masker[indx_start:indx_end]    

    amp_list = Float64[]
    index_list = Int[]
    kernel_list = Int[]
    norm_list = [LinearAlgebra.norm(x_seg)]
   
    # global best values
    cost_best = Inf
    amp_val = nothing
    index_val = nothing
    kernel_val = nothing

    stop = false
    while stop == false
        _, _, p_par = comp_maskcurve(Par_measure, masker)
        
        x_res_hat = rfft(x_seg)
        p_par = p_par[1:length(x_res_hat)] # We are making use of conjugate symmetry
        vec1 = vec(p_par.*x_res_hat)  

        cost_best = norm(vec1)^2
        if cost_best < stop_condition 
            @goto lbl_cost_eval
        end

        local_results = Vector{Tuple{Float64, Union{Float64, ComplexF64}, Int, Int}}(undef, length(dictionary))
        @threads for kernel_count in eachindex(dictionary)
            k = dictionary[kernel_count]
            N = length(k.kernel)
        
            vec2 = nothing
            kernel_hat = nothing
            delay_set = collect(0:1:(Par_measure.Nframe - N))
        
            local_cost_best = Inf
            local_amp, local_index = nothing, nothing
      
            for (_, delay) in enumerate(delay_set)
                if delay == 0
                    kernel_padded = vcat(k.kernel, zeros(frame_length - length(k.kernel)))
                    kernel_hat = vec(rfft(kernel_padded))
                else
                    kernel_hat = kernel_hat .* delay_vec[1:length(kernel_hat)]
                end
        
                vec2 = p_par.*kernel_hat
                alpha = real(vec2' * vec1 / (norm(vec2)^2))
                cost = norm(vec1 - alpha * vec2)^2
        
                if cost < local_cost_best
                    local_cost_best = cost
                    local_amp = alpha
                    local_index = delay + 1
                end
            end
            # store best for this kernel in thread-local slot
            local_results[kernel_count] = (
                local_cost_best, local_amp, local_index, kernel_count
            )
        end

        println(cost_best)
        for r in local_results
            #println(r)
            if r !== nothing && r[1] < cost_best
                cost_best, amp_val, index_val, kernel_val = r
            end
        end

        kernel_tmp = real(amp_val)*dictionary[kernel_val].kernel
        x_seg[index_val:index_val+length(kernel_tmp)-1] .-= kernel_tmp
        masker[index_val:index_val+length(kernel_tmp)-1] .+= kernel_tmp

        push!(amp_list, real(amp_val))
        push!(index_list, index_val)
        push!(kernel_list, kernel_val)
        push!(norm_list, LinearAlgebra.norm(x_seg))

        @label lbl_cost_eval
        if cost_best < stop_condition
            stop = true
        end
       
    end

    if isempty(kernel_list)
        encoded_waveform = []  
    else
        encoded_waveform = mp_utils.crop_encoded_waveform(kernel_list, amp_list, index_list; crop_indx=Par_measure.Nframe)
        if !all(isempty, encoded_waveform)
            kernel_list, amp_list, index_list = mp_utils.split_tuple_encoding(encoded_waveform)

            x_rec = mp_utils.reconstruct_matching_pursuit(index_list, kernel_list, amp_list, dictionary, x_seg)

            x_res[indx_start:indx_start+length(x_rec)-1] = x_res[indx_start:indx_start+length(x_rec)-1]  .- x_rec
        else
            encoded_waveform = []  
        end
    end
    return x_res, encoded_waveform
end


# Get kernels
kernels = load_kernels()
kernel_len = [length(k.kernel) for k in kernels]


# Define settings Par-measure
Fs = 16000      # [Hz] Sampling frequency
Tframe = 2*maximum(kernel_len)/Fs # [s] Frame duration
x_ref = 1.0     # [-] Digital reference amplitude
x_dB_ref = 70.0 # [dB SPL] Physical reference level
F_cal = 1000.0  # [Hz] Calibration frequency
Ng_par = 64     # [-] Number of gammatone filters used in Par-measure


# Create the ParMeasure object
Par_measure = ParMeasure(Fs, Tframe, x_ref, x_dB_ref, F_cal, Ng_par)


# Set window length, crop length and hop_length for short-time matching pursuit (both including Par-measure and excluding Par-measure)
frame_length = Par_measure.Nframe
hop_length = Int(Par_measure.Nframe - 3*Par_measure.Nframe/4)
crop_length = frame_length # No cropping
println("hop length: ", hop_length)
println("crop length: ", crop_length)
println("frame_length: ", frame_length)


MPparam = mp_utils.MPparams(
        "par_disturbance",  # stop type: "amplitude", "iterations", or "par_disturbance"
        20,                  # stop condition: (amplitude threshold or max number of iterations)
        10000,              # Maximum number of iterations (equivalently: selected kernels)
        frame_length,       # Window length for short-time MP
        hop_length,         # Hop length for short-time MP
        crop_length         # Crop length for short-time MP
    )


# Run short-time MP using the Par-measure
x, fs = get_audio()
println("Loaded audio")
windowing_length = Int(round(Par_measure.Fs*5e-3))


@time encoded_waveform, x_res = short_time_matching_pursuit_par(Par_measure, kernels, x, MPparam.stop_type, MPparam.stop_cond, 
                                                                MPparam.hop_length, MPparam.frame_length, MPparam.crop_length,
                                                                windowing_length)   
kernel_list, amp_list, index_list = mp_utils.split_tuple_encoding(encoded_waveform) 


println("Number of selected kernels: ", length(kernel_list))
println("Norm of residue: ", norm(x_res))
println(" ")

file_name = "test_encoding_par.jld2"
dir_name = "tests/output"
kernel_path = "tests/data/kernels_TIMIT.jld2"
mp_utils.store_encoded_waveform_jld2(x_res, kernel_list, amp_list, index_list, file_name, dir_name, kernel_path)

