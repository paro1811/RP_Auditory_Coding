import Pkg
if VERSION < v"1.11"
    println("Julia Version ", VERSION, " detected. No environment activation possible...")
else
    Pkg.activate("FUenvironment")
    println("Julia Version ", VERSION, " detected. Activating MPenvironment...")
end
include(joinpath(@__DIR__, "../filter_utils.jl"))  	# Load the file containing the filter functions


import .filter_utils
using WAV
using Plots
using LinearAlgebra
using FFTW


function filter_and_resample_audio(x, f, fs_read, fs, filter_flag=false, normalise_flag=true, normrange=nothing)
    x = filter_utils.resample(x, fs_read, fs)
 
    if filter_flag
        x = filter_utils.filtfilt(x, f)
    end

    if normalise_flag
        x = filter_utils.normalise(x, normrange)
    end
    println("Norm x: ", norm(x))
    println("Length x: ", length(x)/Filterparam.fs, " seconds")
     
    return x
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


function plot_fft(signal, fs, p=nothing)
    N = length(signal)
    f = fs * (0:(N ÷ 2)) / N
    fft_vals = abs.(fft(signal)[1:(N ÷ 2 + 1)])
    if isnothing(p)
        p = plot(f, fft_vals, xlabel="Frequency (Hz)", ylabel="Amplitude")
    else
        plot!(p, f, fft_vals, xlabel="Frequency (Hz)", ylabel="Amplitude")
    end
    return p
end


Filterparam = filter_utils.Filterparams(
    500,        # f_low
    nothing,    # f_high
    16000,      # fs
    2049,       # length_filter
    4096,       # length_freq_ax (only relevant for plotting)
)

f = filter_utils.initialise_FIR(Filterparam, true, false)  # plot_flag, saveflag

x, fs_read = get_audio()

x1 = filter_and_resample_audio(x, f, fs_read, Filterparam.fs, false, true) 
x2 = filter_and_resample_audio(x, f, fs_read, Filterparam.fs, true, true)


p = plot_fft(x1, Filterparam.fs)
plot_fft(x2, Filterparam.fs, p)
display(p)
