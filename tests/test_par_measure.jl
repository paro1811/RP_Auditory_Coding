import Pkg
Pkg.activate("ParEnvironment")

# Import the `par_measure.jl` file and the functions it contains
include("../par_measure.jl")


function test_Par_measure()
    # Define settings
    Fs = 48000              # [Hz] Sampling frequency
    Tframe = 0.4            # [s] Frame duration
    x_ref = 1.0             # [-] Digital reference amplitude
    x_dB_ref = 70.0         # [dB SPL] Physical reference level
    F_cal = 1000.0          # [Hz] Calibration frequency
    Ng = 64                 # Number of gammatone filters

    # Create the ParMeasure object
    Par_measure = ParMeasure(Fs, Tframe, x_ref, x_dB_ref, F_cal, Ng)

    # Define example signals
    A70 = physical_to_digital(Par_measure, 70.0)
    A52 = physical_to_digital(Par_measure, 52.0)
    A50 = physical_to_digital(Par_measure, 50.0)

    Nframe = Par_measure.Nframe
    t = range(0, step=1/Fs, length=Nframe)

    masker70_1000 = A70 .* sin.(2π*1000 .* t)
    masker50_1000 = A50 .* sin.(2π*1000 .* t)
    masker50_1200 = A50 .* sin.(2π*1200 .* t)

    masker0 = zeros(length(t))
    disturbance52_1000 = A52 .* sin.(2π*1000 .* t)
    disturbance52_1200 = A52 .* sin.(2π*1200 .* t)

    masker_noise = randn(length(t))
    masker_noise = masker_noise*physical_to_digital(Par_measure, 30.0)*sqrt(Fs) # this is not entirely correct, but a quick test. 

    # Test case: 52 dB SPL disturbance and 70 dB SPL masker
    maskcurve_70, maskcurve_spl70, p_par70 = comp_maskcurve(Par_measure, masker70_1000)

    println()
    println("For a 52 dB SPL 1 kHz disturbance (amplitude: ", A52, ") and a 70 dB SPL 1 kHz masker, the Par measure evaluates to: ",
        norm(p_par70 .* fft(disturbance52_1000))^2, " (should be about one)")

    println("For a 70  dB SPL 1 kHz disturbance (amplitude: ", A70, ") and a 70 dB SPL 1 kHz masker, the Par measure evaluates to: ",
        norm(p_par70 .* fft(masker70_1000))^2, " (should be more than one)")

    println("The maskcurve should, up to a normalization, be equal to p_par. Validation: ",
        norm(p_par70 * Nframe .- 1.0 ./ maskcurve_70), " (should be about zero)")

    # Plotting masking curves
    plt = plot_maskcurve(Par_measure, masker70_1000)
    title!("Predicted masking curve for a 70 dB SPL masker (1000 Hz)", titlefont = 12)
    display(plt)

    plt = plot_maskcurve(Par_measure, masker50_1000)
    title!("Predicted masking curve for a 50 dB SPL masker (1000 Hz)", titlefont = 12)
    display(plt)

    plt = plot_maskcurve(Par_measure, masker50_1200)
    title!("Predicted masking curve for a 50 dB SPL masker (1200 Hz)", titlefont = 12)
    display(plt)

    plt = plot_maskcurve(Par_measure, masker0)
    title!("Predicted masking curve when no masker is present.", titlefont = 12)
    display(plt)

    plt = plot_maskcurve(Par_measure, masker70_1000, disturbance52_1000)
    title!("Predicted masking curve with 70 dB SPL masker (1000 Hz)\nJust (un)noticeable disturbance.", titlefont = 12)
    display(plt)

    plt = plot_maskcurve(Par_measure, masker70_1000, disturbance52_1200)
    title!("Predicted masking curve with 70 dB SPL masker (1000 Hz)\nAudible disturbance.", titlefont = 12)
    display(plt)

    plt = plot_maskcurve(Par_measure, masker_noise)
    title!("Predicted masking curve with noise as masker.", titlefont = 12)
    display(plt)
end


# Run the `test_par_measure` function
test_Par_measure() # This function is defined in `par_measure.jl`





