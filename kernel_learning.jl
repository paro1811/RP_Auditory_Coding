"""
    Script for learning kernels. 
    Basic usage: 
        julia --threads 8 kernel_learning.jl <ID> <TSV_FILE> [options]
    Example:
        julia --threads 8 kernel_learning.jl TIMIT training/TIMIT_train_local.tsv --Ng 32    
"""

# Activate the current environment to ensure the correct dependencies are used
import Pkg
if VERSION < v"1.11"
    Pkg.activate("MPenvironment10")
    println("Julia Version ", VERSION, " detected. Activating MPenvironment10...")
else
    Pkg.activate("MPenvironment")
    println("Julia Version ", VERSION, " detected. Activating MPenvironment...")
end

include(joinpath(@__DIR__, "utils_julia/mp_utils.jl"))  	# Load the file containing the matching pursuit functions
include(joinpath(@__DIR__, "utils_julia/train_utils.jl"))  	# Load the file containing the training utilities functions
include(joinpath(@__DIR__, "utils_julia/filter_utils.jl"))  # Load the file containing the filter utilities functions
using .mp_utils
using .train_utils
using .filter_utils
using Random
using CSV, DataFrames
using ProgressBars
using Plots
using JSON3
using ArgParse
using JLD2
using UUIDs 
using Distributions


function parse_arguments()
    s = ArgParseSettings()

    @add_arg_table s begin
        "ID"
            help = "Dataset ID (e.g., TIMIT). Used for storing results."
            arg_type = String
        "train_tsv_file"
            help = "Path to the TSV file (e.g., TIMIT_train.tsv)"
            arg_type = String

        "--tsv_col_segments"
            help = "Name of the column in the .tsv file containing the segments"
            arg_type = String
            default = nothing
            
        "--tsv_col_path"
            help = "Name of the column in the .tsv file containing the path to the audio"
            arg_type = String
            default = "path_wav"

        "--dev_tsv_file"
            help = "Path to the development TSV file. Does nothing at the moment. (optional)"
            arg_type = String
            default = nothing
        
        "--verbose"
            help = "Whether to print verbose output during training (default: false)"
            arg_type = Bool
            default = false
            
        "--logpath"
            help = "Path to the training log file (default: nothing. Goog use: training_log.tsv)"
            arg_type = String
            default = nothing
        
        "--storage_frequency"
            help = "Frequency (in iterations) at which to store kernels and plots (default: 500)"
            arg_type = Int
            default = 500
            
		"--continue_count", "-c"
            help = "Iteration to continue from (default: 0)"
            arg_type = Int
            default = 0

 		"--initial_kernels", "-k"
            help = "Path to initial kernels (.jld2 format)"
            arg_type = String
            default = nothing
               
        "--random_seed"
            help = "Random seed for kernel initialisation (default: 42)"
            arg_type = Int
            default = 42    

        "--fs"
            help = "Target sampling frequency (default: 16000)"
            arg_type = Int
            default = 16000
            
        "--filter_f_low"
            help = "lowest frequency to keep in Hz [default: 100]"
            arg_type = Int
            default = 100

        "--filter_f_high"
            help = "highest frequency to keep in Hz [default: 7000]"
            arg_type = Int
            default = 7000

        "--filter_length"
            help = "Length of the filter in samples (default: 3001)"
            arg_type = Int
            default = 3001

        "--apply_filtering"
            help = "Whether to apply filtering to the audio (default: true)"
            arg_type = Bool
            default = true

        "--apply_normalization"
            help = "Whether to apply normalization to the audio (default: true)"
            arg_type = Bool
            default = true

        
        ### Matching pursuit parameters
        "--mp_stop_type"
            help = "Matching pursuit stop type (default: amplitude)"
            arg_type = String
            default = "amplitude"
            
        "--mp_stop_cond"
            help = "Matching pursuit stop condition (default: 0.1)"
            arg_type = Float64
            default = 0.1

        "--mp_rand_stop"
            help = "randomise the MP stopping condition (default: false). If true, consider setting --mp_stop_min and --mp_stop_max"
            arg_type = Bool
            default = false

        "--mp_stop_min"
            help = "minimal stop condition for random stopping during mp (default: 0.02)"
            arg_type = Float64
            default = 0.02

        "--mp_stop_max"
            help = "maximal stop condition for random stopping during mp (default: 0.1)"
            arg_type = Float64
            default = 0.1
    
    	"--mp_max_iter"
            help = "Matching pursuit maximum iterations (default: 40000)"
            arg_type = Int
            default = 40000
            
        "--fixed_MP_param"
            help = "Whether to use fixed MP parameters (default: true)"
            arg_type = Bool
            default = true
            
     	### Kernel initialisation
      	"--Ng"
            help = "Number of kernels"
            arg_type = Int
            default = 32
 		
 		"--initial_type"
            help = "Initial kernel type (default: gaussian)"
            arg_type = String
            default = "gaussian"

        "--window_initial_kernels"
            help = "Whether to apply a window to the initial kernels (default: false)"
            arg_type = Bool
            default = false
            
        "--init_length"
            help = "Initial kernel length in samples (default: 100)"
            arg_type = Int
            default = 100

        "--init_spacing"
            help = "Initial kernel spacing (default: nothing (all kernels equal length); options: linear)"
            arg_type = String
            default = nothing
            
        "--init_min_length"
            help = "Minimum initial kernel length in samples (used if --init_spacing True) (default: 64)"
            arg_type = Int
            default = 64

        "--init_max_length"
            help = "Maximum initial kernel length in samples (used if --init_spacing is set) (default: 256)"
            arg_type = Int
            default = 256

        "--ortho_initial_flag"
            help = "Whether to orthogonalise initial kernels (default: false)"
            arg_type = Bool
            default = false
           
		### Kernel updates      
	 	"--min_length"
            help = "Minimum kernel length in samples (default: 32)"
            arg_type = Int
            default = 32
        
        "--max_length"
            help = "Maximum kernel length in samples (default: 256)"
            arg_type = Int
            default = 256

		"--exp_range"   
            help = "Expansion range for kernel learning (default: 10 percent (0.1))"
            arg_type = Float64
            default = 0.1
            
        "--exp_threshold"
            help = "Expansion threshold for kernel learning (default: 0.02)"
            arg_type = Float64
            default = 0.02

        "--exp_frequency"
            help = "Frequency (in iterations) at which to check for expansion (default: 100)"
            arg_type = Int
            default = 100
            
		"--kernel_dropout"
			help = "Optional argument: dropout kernels during each training iteration. (default: 0). To drop 18 kernels each iteration, --kernel_dropout = 18"
			arg_type = Int
			default = 0

        "--ortho_flag"
            help = "Whether to orthogonalise kernels during training (default: false)"
            arg_type = Bool
            default = false
            
        # Training stuff
        "--step_size"
            help = "Step size for kernel updates (default: 0.0025)"
            arg_type = Float64
            default = 0.0025

        "--clamp_gradient"
            help = "Clamp value for gradient updates (default: 1.0)"
            arg_type = Float64
            default = 1.0

        "--smooth_gradient"
            help = "Smoothing factor for gradient updates (default: 0.0)"
            arg_type = Float64
            default = 0.0
        
        "--max_train_iterations"
            help = "Maximum number of training iterations (default: 100000)"
            arg_type = Int
            default = 100000

        "--max_epochs"
            help = "Maximum number of epochs (default: 6)"
            arg_type = Int
            default = 6
        
        ### Scheduling
   		"--epoch_schedule"
            help = "Epoch schedule as comma-separated integers (epochs at which to change step size and expansion threshold)"
            arg_type = String
            default = "1,2,3,4,5,6,7,8"
    
        "--step_size_schedule"
            help = "Step size schedule as comma-separated floats (factor by which to change step size)"
            arg_type = String
            default = "1,1,1,1,1,1,1,1"
    
        "--exp_threshold_schedule"
            help = "Expansion threshold schedule as comma-separated floats (factor by which to change expansion threshold --> negative means no expansion)"
            arg_type = String
            default = "1,1,1,1,1,1,1,1"

        "--kernel_dropout_schedule"
            help = "Dropout schedule as comma-separated binary values (1=dropout, 0=no dropout). Number of drops is set by --kernel_dropout"
            arg_type = String
            default = "1,1,1,1,0,0,0,0"
            
       	### Other     
		"--big_segment"
	      	help = "Selects if you want to use a single big segment (from the start of the first to the end of the last segment) or sepearete segments (false, default)"
            arg_type = Bool
            default = false
			
        "--weightscheme"
            help = "Weight scheme for kernel selection (default: uniform; options: 'uniform', 'preemphasis')"
            arg_type = String
            default = "uniform"

        "--weightcoeff"
            help = "Weight coefficient for preemphasis weighting scheme (default: 0.7)"
            arg_type = Float64
            default = 0.7
    end 

    args = parse_args(s)

    # some more complicated parsing
    epoch_schedule = parse.(Int, split(args["epoch_schedule"], ","))
    step_size_schedule = parse.(Float64, split(args["step_size_schedule"], ","))
    exp_threshold_schedule = parse.(Float64, split(args["exp_threshold_schedule"], ","))
    kernel_dropout_schedule = parse.(Int, split(args["kernel_dropout_schedule"], ","))

    if args["tsv_col_segments"] === nothing
        segment_flag = false
    else
        segment_flag = true
    end
    
    if args["init_min_length"] > args["init_max_length"] || args["init_min_length"] < args["min_length"] || args["init_min_length"] > args["max_length"] 
        error("Error: --init_min_length  not valid (check --max_length and --min_length)")
    end
    if args["init_max_length"] < args["init_min_length"] || args["init_max_length"] > args["max_length"] || args["init_max_length"] < args["min_length"] 
        error("Error: --init_max_length  not valid (check --max_length and --min_length)")
    end
	if args["kernel_dropout"] > args["Ng"]-1
		error("Error: --kernel_dropout not valid. Dropping too many kernels (>Ng-1)")
	end

    # Return a clean named tuple
    return (
        ID = args["ID"],
        train_tsv_file = args["train_tsv_file"],
        tsv_col_path = args["tsv_col_path"],
        tsv_col_segments = args["tsv_col_segments"],
        big_segment = args["big_segment"],
        dev_tsv_file = args["dev_tsv_file"],
        logpath = args["logpath"],
        verbose = args["verbose"],
        continue_count = args["continue_count"],
      	storage_frequency = args["storage_frequency"],      
      	random_seed = args["random_seed"],
        Ng = args["Ng"],
        step_size = args["step_size"],  
        exp_threshold = args["exp_threshold"],
        exp_range = args["exp_range"],
        exp_frequency = args["exp_frequency"],
        min_length = args["min_length"],
        max_length = args["max_length"],
        initial_type = args["initial_type"],
        init_length = args["init_length"],
        init_min_length = args["init_min_length"],
        init_max_length = args["init_max_length"],
        init_spacing = args["init_spacing"],
        path_initial_kernels = args["initial_kernels"],
        clamp_gradient = args["clamp_gradient"],
        smooth_gradient = args["smooth_gradient"],
        max_train_iterations = args["max_train_iterations"],
        max_epochs = args["max_epochs"],
        epoch_schedule = epoch_schedule,
        stepsize_schedule = step_size_schedule,    
        exp_threshold_schedule = exp_threshold_schedule,
        kernel_dropout_schedule = kernel_dropout_schedule,
        ortho_flag = args["ortho_flag"],
        segment_flag = segment_flag,
        fs = args["fs"],
        filter_f_low = args["filter_f_low"],
        filter_f_high = args["filter_f_high"],
        filter_length = args["filter_length"],
        apply_filtering = args["apply_filtering"],
        apply_normalization = args["apply_normalization"],
        ortho_initial_flag = args["ortho_initial_flag"],
        mp_stop_type = args["mp_stop_type"],
        mp_stop_cond = args["mp_stop_cond"],
        mp_max_iter = args["mp_max_iter"],
        mp_rand_stop = args["mp_rand_stop"],
        mp_stop_min = args["mp_stop_min"],
        mp_stop_max = args["mp_stop_max"],
        kernel_dropout = args["kernel_dropout"],
        window_initial_kernels = args["window_initial_kernels"],
        stable_MP_param = args["fixed_MP_param"],
        weightscheme = args["weightscheme"],
        weightcoeff = args["weightcoeff"],
    )
end


function init_program(args)
    TrainParam = mp_utils.TrainParams(
        args.Ng,                # Ng (number of kernels)
        args.init_length,       # The initial kernel length (does not apply when using gammatones)
        args.random_seed,       # The random seed
        args.step_size,         # The update step size
        args.clamp_gradient,    # Clamp value gradient
        args.smooth_gradient,   # The weight with which the gradients is smoothed
        args.exp_threshold,     # The norm for which to expand the kernels 
        args.exp_range,         # The range on which the above norm should be computed
        args.exp_frequency,     # After how many iterations the expansion is done
        args.max_length,        # maximum length of the kernels
        args.min_length,        # minimum length of the kernels
        args.storage_frequency, # nStore    
        args.max_epochs,        # maxEpochs (in practice we might hit 5 or something)    
        args.epoch_schedule,                       # epoch_schedule 
        args.step_size*args.stepsize_schedule, 	       # step_size_schedule
        args.exp_threshold*args.exp_threshold_schedule, # exp_threshold_schedule (higher=less expansion; <0 (e.g. -1) means no expansion)
        args.max_train_iterations,                  # nTrainIts       
        args.segment_flag,                      # use_segmentation (e.g. for VAD; embedded in .tsv files)
        args.tsv_col_segments,                 # Name of the column in the .tsv file containing the segments (if use_segmentation=true)
        args.big_segment,						# Signle big segment or multiple small ones
        args.ortho_flag,            # orthogonalise_kernels
        args.initial_type ,         # initialise_type: "gaussian", "gammatone", "dirac"
        args.kernel_dropout, 		# kernel_dropout. 
        args.kernel_dropout_schedule, # kernel_dropout_schedule 
    )

    Filterparam = filter_utils.Filterparams(
        args.filter_f_low,        # f_low
        args.filter_f_high,       # f_high
        args.fs,                  # fs
        args.filter_length,                       # length_filter
        2^ceil(Int, log2(args.filter_length)),  # length_freq_ax (set to nearest power of 2 of filter_length, only relevant for plotting)
    )

    savedir = "Results"*args.ID
    if !isdir(savedir)
        mkpath(savedir)
    end

    Random.seed!(TrainParam.random_seed)  # Set the random seed for reproducibility

    MPparam = mp_utils.MPparams(
        args.mp_stop_type,          # stop_type
        args.mp_stop_cond,          # stop_cond
        args.mp_max_iter,           # max_iter
        2*TrainParam.max_length,    # window_length
        TrainParam.max_length,      # hop_length
        TrainParam.max_length+1,    # crop_length      
        args.stable_MP_param,      # stable_MP_param: if true, dont change the paramaters      
    )
    return TrainParam, Filterparam, MPparam, savedir 
end


function init_kernels(args, MPparam, TrainParam)
    """
    Code to initialise new kernels or to load existing kernels based on args. Updates MPparam and TrainParam accordingly.
    """
    # Initialize kernels (keeps random seed proper, so is always done first)
    kernels = mp_utils.initialise_kernels(TrainParam.initialise_type, TrainParam.kernel_size, TrainParam.Ng, args.ortho_initial_flag, args.window_initial_kernels, args.init_spacing, args.init_min_length, args.init_max_length)
    
    # load initial kernels if needed  (path_initial_kernels overrides continue_count)
    if !isnothing(args.path_initial_kernels)
        kernels = mp_utils.load_kernels_from_jld2(args.path_initial_kernels)
    elseif args.continue_count > 0  
        println("Loading existing kernels from Results"*args.ID*"/kernels_it"*string(args.continue_count)*".jld2")
        kernels = mp_utils.load_kernels_from_jld2("Results"*args.ID*"/kernels_it"*string(args.continue_count)*".jld2")
    end

    # Update lengths in MPparam if needed
    lengths = train_utils.get_kernel_lengths(kernels)
    if maximum(lengths) > MPparam.frame_length/2 || args.stable_MP_param == false
        println(" --> Adjusting MP parameters to fit loaded/initialised kernels")
        if MPparam.stable_MP_param
            println(" --> Note that this is despite stable_MP_param=true (which usually fixes the MP parameters) ")
        end
        MPparam.frame_length = 2*maximum(lengths)
        MPparam.hop_length = maximum(lengths)
        MPparam.crop_length =  maximum(lengths) + 1
        TrainParam.Ng = length(kernels)
        flush(stdout)
    end

    return MPparam, TrainParam, kernels
end


function update_MPparam!(MPparam, mp_rand_stop, mp_stop_min, mp_stop_max, verbose=false)
    if mp_rand_stop
        if MPparam.stop_type == "amplitude"
            MPparam.stop_cond = rand(Uniform(mp_stop_min, mp_stop_max)) # Draw uniformly on a log scale
            if verbose
                println(" Updated MPparam. New parameters: ")
                @show MPparam
                println(" ")
            end
        else
            error("mp_rand_stop=true not implemented if mp_stop_type is not amplitude")
        end
    else
        if verbose
            println(" mp_rand_stop is false. Keeping stopping condition constant.")
        end
    end
end


function orthogonalise_kernels(kernels, ortho_flag)
    if ortho_flag
        mp_utils.orthogonalise_kernels!(kernels)
    end
end


function plot_and_store(kernels, itCount, ID, nStore, fs=16000, store_spec_feats=true, savename=nothing)
    if mod(itCount, nStore) == 0
        # Store kernels
        p = mp_utils.plot_kernels(kernels)
        if isnothing(savename)
        	figure_path = "Results"*ID*"/kernels_it"*string(itCount)*".svg"
    	else
    		figure_path = "Results"*ID*"/"*savename*".svg"
		end
        savefig(p, figure_path)

        # Store spectral centroid-spread
        if store_spec_feats
            centroids = Float64[]
            bandwidths = Float64[]
            for k in kernels
                c, b, _, _ = filter_utils.spectral_features(k.kernel, fs; nfreqs=1024)
                push!(centroids, c)
                push!(bandwidths, b)
            end
            p = mp_utils.plot_kernels_spectral_features(centroids, bandwidths, xlim=[30, fs/2], ylim=[30, fs/4])
            figure_dist_path = "Results"*ID*"/kernels_dist_it"*string(itCount)*".svg"
            savefig(p, figure_dist_path)
        end
        if isnothing(savename)
        	kernel_path = "Results"*ID*"/kernels_it"*string(itCount)*".jld2"
		else
			kernel_path = "Results"*ID*"/"*savename*".jld2"
		end
        mp_utils.save_kernels_to_jld2(kernel_path, kernels)
    end
end


function expand_kernels(kernels, TrainParam, itCount, MPparam, verbose=false)
    if mod(itCount, TrainParam.exp_update) == 0
        if TrainParam.exp_threshold <= 0
            return nothing
        end
        mp_utils.trim_and_expand_kernels!(kernels, TrainParam.exp_threshold, TrainParam.exp_range, TrainParam.ortho_kernels, TrainParam.max_length, TrainParam.min_length)
        lengths = train_utils.get_kernel_lengths(kernels)
        
        if !MPparam.stable_MP_param
            MPparam.frame_length = 2*maximum(lengths)
            MPparam.hop_length = maximum(lengths)
            MPparam.crop_length =  maximum(lengths) + 1
        end

        if verbose
            println("  Expanded kernels. New kernel lengths: ", lengths)
            flush(stdout)
        end
    end
end


function main()
    # Parse arguments
    args = parse_arguments()
    println("Arguments parsed:")
    println(args)

    TrainParam, Filterparam, MPparam, save_dir = init_program(args)

    # initalise filter
    f = filter_utils.initialise_FIR(Filterparam, true, true, save_dir)  # plot_flag, saveflag, savedir

    # Initialise kernels
    MPparam, TrainParam, kernels = init_kernels(args, MPparam, TrainParam)

    
    # Store initial data
    save_path_initial = joinpath(save_dir, "initial_setup_$(string(uuid4())).jld2")
    @save save_path_initial TrainParam Filterparam MPparam kernels args

    # Store kernels and plot them every nStore iterations     
    plot_and_store(kernels, 0, args.ID, TrainParam.nStore, args.fs) 

    """
    Go into training loop. Assume that a .tsv file containing paths to the training data is available at tsv_file.
    Here we start training from scratch. If you have previous kernels, you can load them using load_kernels_from_jld2 and continue from there.
    """
    begin
        global itCount = 0 
        log_buffer = Vector{Tuple{Int,String, Int,Float64,Float64}}()

        for epochCount in 1:TrainParam.maxEpochs
            df_tsv = train_utils.get_paths(args.train_tsv_file, true, false)  # shuffle the .tsv file each epoch
            println("Starting epoch ", epochCount, " of ", TrainParam.maxEpochs)
            println(" Number of training examples: ", nrow(df_tsv))
            flush(stdout)

            # Update step size and exp_threshold if needed
            train_utils.update_training_params!(epochCount, TrainParam)

            # Inner loop: loop over audio files.
            for row in ProgressBar(eachrow(df_tsv))
                if itCount >= TrainParam.nTrainIts # Break if the maximum number of training iterations is reached
                    @goto terminate_loops
                end
        
                # User info
                itCount += 1
                if args.verbose
                    println(" Epoch: ", epochCount, "; Iteration (total): ", itCount)
                end

                # Option to continue from a certain iteration 
                if itCount < args.continue_count + 1 
                    continue
                end
                
                # Load audio file and check validity
                loadVal = train_utils.load_row_and_check_validity(row, args.tsv_col_path, args.verbose)
                if isnothing(loadVal)
                    continue
                end
                x, fs_read, path_to_wav = loadVal
                
                # If logpath is specified, set up the log path
                if isnothing(args.logpath)
                    log_path = nothing
                else
                    log_path = joinpath(save_dir, args.logpath)
                end

                # Optionally drop some kernels
				if TrainParam.kernel_dropout != 0
                    if args.verbose
                        println(" Dropping ", TrainParam.kernel_dropout, " kernels for this iteration.")
                    end
                    kernel_indices = collect(1:length(kernels))
                    dropped_indices = sample(kernel_indices, TrainParam.kernel_dropout; replace=false)
                    kernels_selected = [kernels[i] for i in 1:length(kernels) if !(i in dropped_indices)]
                    kernels_dropped = [kernels[i] for i in dropped_indices]
                    kernels = kernels_selected
                end
					

                # Preprocess audio and run training iteration
                if TrainParam.use_segmentation
                    if args.verbose
                        println(" Using segments for processing")
                    end 

                    segments = JSON3.read(row[Symbol(TrainParam.segment_col)]) # Time of segments (e.g. voice acitvity detection (VAD) - zero based indexing)
                    if isempty(segments) # Sometimes no voice-acitivy is detected
                        if args.verbose
                            println("  --> No segments found in this file. Skipping...")
                        end
                        
                        # Put back kernels
                       if TrainParam.kernel_dropout != 0
                    		# Reinsert dropped kernels without updating them
                    		append!(kernels, kernels_dropped)
                		end
                        continue
                    end
                    
                    norm_range = [(segments[1].start+1), (segments[end].end)]
                    x = train_utils.preprocess_audio(x, fs_read, args.fs, f, args.apply_filtering, args.apply_normalization, norm_range) # Preprocess audio (e.g. resampling, filtering, normalisation)
                	
                	if TrainParam.big_segment
                		x_seg = x[(segments[1].start+1):(segments[end].end)]
            		 	train_utils.run_training_iter!(x_seg, path_to_wav, MPparam, TrainParam, kernels, args.fs, epochCount, itCount, log_path, args.verbose, log_buffer, args.weightscheme, args.weightcoeff) 
                	else
		                # Loop over each segment
		                for segment in segments
		                    if args.verbose
		                        println(" --> Processing segment from ", segment.start/args.fs, " to ", segment.end/args.fs, " seconds")
		                    end
		                    x_seg = x[(segment.start+1):(segment.end)]            # Grab the segment of interest  
		                    train_utils.run_training_iter!(x_seg, path_to_wav, MPparam, TrainParam, kernels, args.fs, epochCount, itCount, log_path, args.verbose, log_buffer, args.weightscheme, args.weightcoeff) 
		                end
                	end
                else
                    # No VAD
                    x = train_utils.preprocess_audio(x, fs_read, args.fs, f, args.apply_filtering, args.apply_normalization) # Preprocess audio (e.g. resampling, filtering, normalisation)
                    train_utils.run_training_iter!(x, path_to_wav, MPparam, TrainParam, kernels, args.fs, epochCount, itCount, log_path, args.verbose, log_buffer, args.weightscheme, args.weightcoeff)
                end
            
                # Reinsert dropped kernels if needed
                if TrainParam.kernel_dropout != 0
                    # Reinsert dropped kernels without updating them
                    append!(kernels, kernels_dropped)
                end

                # Shuffle MPparam if needed
                update_MPparam!(MPparam, args.mp_rand_stop, args.mp_stop_min, args.mp_stop_max, args.verbose)

                # Orthogonalise kernels if needed
                orthogonalise_kernels(kernels, TrainParam.ortho_kernels)
    
                # Store kernels and plot them every nStore iterations     
                plot_and_store(kernels, itCount, args.ID, TrainParam.nStore, args.fs) 
            
                # Expand kernels every so often --> take care to update MPparam.frame_length, hop_length and crop_length if kernels are expanded
                expand_kernels(kernels, TrainParam, itCount, MPparam, args.verbose)
            end

            println(" Finished epoch ", epochCount, ".")
            
            ##################################
            # TODO: validate on dev set here #
            ##################################
            if !isnothing(args.dev_tsv_file)
                println(" Validating on development set...")
                error("Parameter '--dev_tsv_file' is not implemented yet.")
            end

            # Store epoch stats plot and other stuff
            if !isnothing(args.logpath)
                p = train_utils.plot_epoch_stats("Results"*args.ID*"/"*args.logpath)
                figure_epoch_path = "Results"*args.ID*"/epoch_"*string(epochCount)*".pdf"
                savefig(p, figure_epoch_path)
				savename = "epoch_"*string(epochCount)
             	plot_and_store(kernels, itCount, args.ID, 1, args.fs, true, savename)    
            end
            print(" ")
            flush(stdout)

        end
        @label terminate_loops    

        path_store =  "Results"*args.ID*"/kernels_it"*string(itCount)*".jld2"
        println("Finished training the kernels. Storing final result to ", path_store)
        mp_utils.save_kernels_to_jld2("Results"*args.ID*"/kernels_it"*string(itCount)*".jld2", kernels)
    end
end


if abspath(PROGRAM_FILE) == @__FILE__
    main()
    println("Exiting...")
    exit()
end
