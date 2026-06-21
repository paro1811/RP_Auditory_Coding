"""
    module to be used together with main_encode_and_store.jl
    defines some functions that are handy when training
"""


module train_utils
    using CSV, DataFrames
    using WAV
    using Random
    using LinearAlgebra
    using DSP
    using DelimitedFiles

    using Statistics
    using Plots
    using GLM

    include(joinpath(@__DIR__, "mp_utils.jl"))  	# Load the file containing the MP functions
    using .mp_utils

    export get_paths


    function get_paths(csv_file, flag_shuffle=false, flag_reverse=false)
        df = CSV.read(csv_file, DataFrame)
        if flag_shuffle
            df = df[shuffle(1:nrow(df)), :]  # Shuffle the DataFrame rows
        end
        if flag_reverse
            reverse!(df)  # Reverse the DataFrame rows
        end
        return df
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
        return x, fs_read, successLoadFlag
    end

    
    function load_row_and_check_validity(df_row, df_col::AbstractString, verbose=true)
        path = df_row[Symbol(df_col)]  
        if verbose
            println(" Loading audio file: ", path)
        end
        x, fs_read, succesLoadFlag = load_audio(path)
        if succesLoadFlag == false
            println("Failed to load audio file: ", path)
            return nothing
        end
        return x, fs_read, path
    end


    function load_row_and_check_validity_broken(df_row, df_col::AbstractString, verbose=true)
        path = df_row[Symbol(df_col)]  
        path = "/home/dimme/Documents/Databases/BEANS_egyptian_fruit_bats/audio/4100.wav"
        if verbose
            println(" Loading audio file: ", path)
        end
        x, fs_read, succesLoadFlag = load_audio(path)
        if succesLoadFlag == false
            println("Failed to load audio file: ", path)
            return nothing
        end
        return x, fs_read
    end
    

    function get_kernel_lengths(kernels)
        return [length(k.kernel) for k in kernels]
    end
    
    
    function run_training_iter!(x, path_wav, MPparam, TrainParam, kernels, fs, epoch, iteration, log_path=nothing, verbose=true, log_buffer=nothing, weightscheme="uniform", α=0.7)
         # Perform short-time matching pursuit
        encoded_waveform, x_res = mp_utils.short_time_matching_pursuit(kernels, x, MPparam.stop_type, MPparam.stop_cond, MPparam.hop_length, MPparam.frame_length, MPparam.crop_length)   
    	kernel_list, amp_list, index_list = mp_utils.split_tuple_encoding(encoded_waveform) 
    	if isempty(kernel_list)
    		return nothing
		end
        mp_utils.update_kernels!(index_list, kernel_list, amp_list, kernels, x_res, TrainParam.step_size, TrainParam.smoothing_weight, TrainParam.clamp_val)
        mp_utils.set_kernel_weights!(kernels, weightscheme, α)

         # Compute metrics
        num_kernels_per_sec = length(kernel_list) / (length(x_res) / fs)
        SRR = 20 * log10(norm(x) / norm(x_res))

        if !isnothing(log_buffer)
            push!(log_buffer, (epoch, path_wav, iteration, SRR, num_kernels_per_sec))

            if iteration%50 == 0
                # Append results to file
                if !isnothing(log_path)
                    if !isfile(log_path)
                        # Write header if file doesn’t exist
                        writedlm(log_path, ["epoch" "path" "iteration" "SRR" "kernels_per_sec"], '\t')
                    end
                    open(log_path, "a") do io
                        for (e, p, it, srr, kps) in log_buffer
                            writedlm(io, [e p it srr kps], '\t')
                        end
                    end
                end
                empty!(log_buffer)
            end
        end
        
        # Print debug information
        if verbose
            println("  Number of selected kernels/second: ", length(kernel_list)/(length(x_res)/fs))
            println("  SRR: ", 20*log10(norm(x)/norm(x_res)))
            println("  Length x_res: ", length(x_res)/fs, " seconds")
            flush(stdout)
        end
  		return nothing
    end
    

    function update_training_params!(epochCount, TrainParam)
        if epochCount in TrainParam.epoch_schedule
            idx = findfirst(==(epochCount), TrainParam.epoch_schedule)
            if idx !== nothing
                TrainParam.step_size = TrainParam.step_size_schedule[idx]
                TrainParam.exp_threshold = TrainParam.exp_threshold_schedule[idx]
                TrainParam.kernel_dropout = TrainParam.kernel_dropout_schedule[idx]*TrainParam.kernel_dropout
                println(" Setting TrainParam.stepsize: ", TrainParam.step_size)
                println(" Setting TrainParam.exp_threshold: ", TrainParam.exp_threshold)
                println(" Setting TrainParam.kernel_dropout: ", TrainParam.kernel_dropout)
                flush(stdout)
            end
        end
    end


    function preprocess_audio(x, fs_read, target_fs=16000, f=nothing, filter_flag=false, normalise_flag=true, normrange=nothing, verbose=false)
        # Resample if needed
        if fs_read != target_fs
            x = DSP.Filters.resample(x, target_fs//fs_read, dims=1)
            fs_read = target_fs
        end

        # Filter if needed
        if filter_flag
            if isnothing(f)
                error("filter_flag is true but no filter provided") 
            else
                x = DSP.Filters.filtfilt(f, x)
            end
        end

        # Normalise if needed
        if normalise_flag
            if isnothing(normrange)
                normfac = maximum(abs.(x))
            else
                normfac = maximum(abs.(x[normrange[1]:normrange[2]]))
            end
            x = x/normfac
        end

        if verbose
            println(" Norm x: ", norm(x))
            println(" Length x: ", length(x)/fs_read, " seconds")
        end
        return x
    end


    function plot_epoch_stats(filename::String)
        # === Read CSV file ===
        df = CSV.read(filename, DataFrame)
        @assert all(col -> col ∈ names(df), ["epoch", "SRR", "kernels_per_sec"]) "Missing required columns!"

    
        # === Compute stats per epoch ===
        stats = combine(groupby(df, :epoch),
            :SRR => mean => :mean_SRR,
            :SRR => std => :std_SRR,
            :kernels_per_sec => mean => :mean_kernels,
            :kernels_per_sec => std => :std_kernels,
            nrow => :count
        )
    
        println("\n=== Summary statistics per epoch ===")
        show(stats, allrows=true, allcols=true)
    
        # === Create scatter plot (but don't display yet) ===
        epochs = unique(df.epoch)
        colors = Plots.PlotThemes.palette(:tab10)

        p = plot(title="SRR vs Kernels/sec by Epoch",
                 xlabel="Kernels per Second",
                 ylabel="SRR",
                 legend=:topright,
                 grid=true,
                 size=(900,600))
    
        for (i, ep) in enumerate(epochs)
            sub = df[df.epoch .== ep, :]
            color = colors[(i - 1) % length(colors) + 1]

            # Scatter points
            scatter!(p, sub.kernels_per_sec, sub.SRR,
                     label="Epoch $ep",
                     color=color,
                     alpha=0.6,
                     markersize=3,
                     rasterize=true)
        end
    
        for (i, ep) in enumerate(epochs)
            sub = df[df.epoch .== ep, :]
            color = colors[(i - 1) % length(colors) + 1]

            # Trendline (simple linear regression)
            if nrow(sub) > 1
                model = lm(@formula(SRR ~ kernels_per_sec), sub)
                x_vals = range(minimum(sub.kernels_per_sec), stop=maximum(sub.kernels_per_sec), length=100)
                y_pred = predict(model, DataFrame(kernels_per_sec=x_vals))
                plot!(p, x_vals, y_pred, color=color, linestyle=:dash, label="")
            end
        end
            
        return p
    end
end
