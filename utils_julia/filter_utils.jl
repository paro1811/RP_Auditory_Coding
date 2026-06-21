module filter_utils

    using DSP
    using Plots
    using LinearAlgebra

    export filterParams, getFIRfilter, plotFIRresponse, initialise_FIR

    mutable struct Filterparams
        """
            mutable struct Filterparams

        A structure to hold parameters for filter design and processing.

        # Fields
        - `f_low::Float64`: The lower cutoff frequency of the filter in Hz.
        - `f_high::Float64`: The upper cutoff frequency of the filter in Hz.
        - `fs::Int32`: The sampling frequency in Hz.
        - `length_filter::Int32`: The length of the filter in samples.
        - `length_freq_ax::Int32`: The length of the frequency axis for analysis.
        """    
        f_low::Union{Float64, Nothing}
        f_high::Union{Float64, Nothing}
        fs::Int32
        length_filter::Int32
        length_freq_ax::Int32
    end


    function initialise_FIR(Filterparam, plot_flag=false, saveflag=false, savedir="Kernels")
        f = filter_utils.getFIRfilter(Filterparam.f_low, Filterparam.f_high, Filterparam.fs, Filterparam.length_filter)
        if plot_flag
            filter_utils.plotFIRresponse(f, Filterparam.fs, Filterparam.length_freq_ax, saveflag, plot_flag, savedir)
        end
        return f
    end


    function getFIRfilter(f_low, f_high, fs, length_filter)
        if !isnothing(f_low) && !isnothing(f_high)
            println("Creating bandpass filter with f_low = $f_low, f_high = $f_high")
            responsetype = Bandpass(f_low, f_high)
        elseif isnothing(f_low) && !isnothing(f_high)
            println("Creating lowpass filter with f_high = $f_high")
            responsetype = Lowpass(f_high)
        elseif !isnothing(f_low) && isnothing(f_high)
            println("Creating highpass filter with f_low = $f_low and fs = $fs")
            responsetype = Highpass(f_low)
        else
            error("Both f_low and f_high cannot be nothing.")
        end
        designmethod = FIRWindow(hamming(length_filter))
        f = digitalfilter(responsetype, designmethod; fs)
        return f
    end


    function resample(x, fs_read, fs)
        """
            resample(x, fs_read, fs)

            Resamples the input array `x` sampled at `fs_read` to the target sampling frequency `fs`.

            # Arguments
            - `x::AbstractArray`: The input array to be resampled.
            - `fs_read::Real`: The original sampling frequency of the input array.
            - `fs::Real`: The target sampling frequency.

            # Returns
            - `AbstractArray`: The resampled array if downsampling was performed; otherwise, 
            returns the original array.

            # Notes
            - If `fs_read` is greater than `fs`, the function performs downsampling using 
            `DSP.Filters.resample`.
            - If `fs_read` is less than `fs`, an error is raised indicating that upsampling 
            is not implemented.
        """
        fs_read = Int(fs_read)
        if fs_read > fs
            println("Downsampling to ", fs, " Hz")
            x = DSP.Filters.resample(x, fs/fs_read, dims=1)
        elseif fs_read < fs
            error("fs_read < fs (upsampling) not implemented yet")
        end
        return x
    end
    

    function normalise(x, normrange::Union{Nothing, Tuple{Int, Int}}=nothing)
        """
            normalise(x; normrange=nothing)

            Normalizes the input array `x` by dividing it by the maximum absolute value in the array. 
            If `normrange` is provided, normalization is performed using the maximum absolute value 
            within the specified range.

            # Arguments
            - `x::AbstractArray`: The input array to be normalized.
            - `normrange::Union{Nothing, Tuple{Int, Int}}`: An optional tuple specifying the range 
            of indices `(start, end)` to consider for normalization. If `nothing` (default), the 
            entire array is used.

            # Returns
            - `AbstractArray`: The normalized array.
        """
        if isnothing(normrange)
            normfac = maximum(abs.(x))
        else
            normfac = maximum(abs.(x[normrange[1]:normrange[2]]))
        end
        return x
    end


    function filtfilt(x, f)
        """
            filtfilt(x, f)

            Applies zero-phase digital filtering to the input array `x` using the filter `f`. 
            This is achieved by processing the input in both the forward and reverse directions.

            # Arguments
            - `x::AbstractArray`: The input array to be filtered.
            - `f::DSP.Filters.DigitalFilter`: The digital filter to be applied.

            # Returns
            - `AbstractArray`: The filtered array.
        """
        x = DSP.Filters.filtfilt(f, x)
        return x
    end


    function plotFIRresponse(f, fs, length_freq_ax, saveflag=false, plotflag=true, savedir="Kernels")
        println("Plotting FIR filter response")
        w = collect(range(0, pi, length=length_freq_ax))
        w = w[2:end]  # Exclude the first element to avoid division by zero in phase response
        H = FIRfreqz(f, w)
        HdB = 20*log10.(abs.(H))
        ws = w/pi*fs/2
        p = plot(
            ws, HdB,
            xaxis=:log10,
            xlims=(20, fs/2),
            ylims=(-10, 2),
            xlabel = "Frequency (Hz)", 
            ylabel = "Magnitude (dB)",
            legend = false
        )

        # Custom vertical grid lines
        vlines = vcat(
            10:10:90,        # Every 10 between 10 and 100
            100:100:900,     # Every 100 between 100 and 1000
            1000:1000:9000   # Every 1000 between 1000 and 10000
        )
        for xg in vlines
            vline!(p, [xg], lw=0.5, lc=:gray, alpha=0.4)
        end

        if plotflag
            display(p)
        end
        if saveflag
            savefig(p, savedir*"/FIR_magnitude_response.png")
        end

        H_phase = unwrap(-atan.(imag(H),real(H)))
        
        p = plot(
            ws, H_phase,
            xlims=(20, 8000),
            xlabel = "Frequency (Hz)",
            ylabel = "Phase (radians)",
            legend = false
        )
        for xg in vlines
            vline!(p, [xg], lw=0.5, lc=:gray, alpha=0.4)
        end
        if saveflag
            savefig(p, savedir*"/FIR_phase_response.png")
        end
        if plotflag
            display(p)
        end
    end


    function FIRfreqz(b::Array, w = range(0, stop=π, length=1024))
        # Based on: https://weavejl.mpastell.com/v0.2/examples/FIR_design.html , used for plotting
        n = length(w)
        h = Array{ComplexF32}(undef, n)
        sw = 0
        for i = 1:n
            for j = 1:length(b)
                sw += b[j]*exp(-im*w[i])^-j
            end
            h[i] = sw
            sw = 0
        end
        return h
    end
    

    function spectral_features(b::AbstractVector, fs::Real; nfreqs::Int=1024)
        N = max(length(b), nfreqs)
        bpad = vcat(b, zeros(N - length(b)))
        B = DSP.rfft(bpad)
        mags = abs.(B).^2


        # Compute features in normalized frequency domain
        f_norm = collect(0:(length(mags)-1)) ./ length(mags) * fs/2
        centroid_norm = sum(f_norm .* mags) / sum(mags)
        bandwidth_norm = sqrt(sum(((f_norm .- centroid_norm).^2) .* mags)/sum(mags))
    
        # Scale results to Hz
        centroid = centroid_norm
        bandwidth = bandwidth_norm 
    
        #println("Centroid: ", centroid)
        return centroid, bandwidth, f_norm, mags
    end

        #     num_frames = Int(floor((length(signal) - frame_len) / hop_len)) - 2
            
        #     # Initialize VAD arrays
        #     vad_indx = []
        #     vad_val = []
            
        #     # Initialize frame indices
        #     indx_low = 1
        #     indx_high = frame_len
        
        #     # Loop through frames
        #     for i = 1:num_frames
        #         frame = signal[indx_low:indx_high]
        #         indx_low += hop_len
        #         indx_high += hop_len
        #         e = LinearAlgebra.norm(frame)
        #         if LinearAlgebra.norm(frame)^2 < threshold
        #             push!(vad_val, e)
        #             push!(vad_indx, indx_low + round(frame_len/2))
        #         end
        #     end
        #     return vad_val, Int.(vad_indx)
        # end
end
