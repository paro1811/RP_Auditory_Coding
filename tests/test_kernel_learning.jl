"""
    Script for testing functions in mp_utils used for kernel learning:
    - short_time_matching_pursuit (as matching pursuit backend)
    - update_kernels!
    - trim_and_expand_kernels! 	--> not yet added. Note that it requires changing the parameters of short_time_matching_pursuit
    - initialise_kernels	

    And..
    - save_kernels_to_jld2 --> not yet added
    - arrayPlot
    - TrainParams
    - MPparams

    It is worth noting that this script does not test all possible options of the functions.
    Also, the different matching pursuit functions and their parameters are still quite chaotic.
    The struct MPparams is defined to make this a bit cleaner, but i'm not sure how to incorporate the different options cleanly...
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

include(joinpath(@__DIR__, "../mp_utils.jl"))  	# Load the file containing the MP functions
include(joinpath(@__DIR__, "../train_utils.jl"))  	# Load the file containing the MP functions
include(joinpath(@__DIR__, "../filter_utils.jl"))  	# Load the file containing the MP functions
using .mp_utils
using .train_utils
using .filter_utils
using Random
using CSV, DataFrames
using ProgressBars
using Plots


function orthogonalise_kernels(kernels, ortho_flag)
    if ortho_flag
        mp_utils.orthogonalise_kernels!(kernels)
    end
end


function plot_and_store(kernels, epochCount, itCount, ID, nStore)
    if mod(itCount, nStore) == 0
        p = mp_utils.plot_kernels(kernels)

        figure_path = "tests/output/kernels_epoch"*string(epochCount)*"_it"*string(itCount)*".svg"
        kernel_path = "tests/output/kernels_"*ID*"_epoch"*string(epochCount)*"_it"*string(itCount)*".jld2"
        
        savefig(p, figure_path)
        mp_utils.save_kernels_to_jld2(kernel_path, kernels)
    end
end


function expand_kernels(kernels, TrainParam, itCount, MPparam)
    if mod(itCount, TrainParam.exp_update) == 0
        if TrainParam.exp_threshold <= 0
            return nothing
        end
        mp_utils.trim_and_expand_kernels!(kernels, TrainParam.exp_threshold, TrainParam.exp_range)
        lengths = train_utils.get_kernel_lengths(kernels)
        MPparam.frame_length = 2*maximum(lengths)
        MPparam.hop_length = maximum(lengths)
        MPparam.crop_length =  maximum(lengths) + 1
        println("  Expanded kernels. New kernel lengths: ", lengths)
        flush(stdout)
    end
end


###################
# Input Arguments #
###################
ID = "TIMIT"
tsv_file = "tests/data/TIMIT_train.tsv"


##########################################
# Arguments which would usually be fixed #
##########################################
# Parameters for kernel learning
Ng = 32
random_seed = 42
step_size = 0.0025
exp_threshold = 0.025
initial_type = "gaussian"
ortho_flag = false
use_vad = false # There is no VAD implemented 
nTrainIts = 10000
fs = 16000  # Target sampling frequency


TrainParam = mp_utils.TrainParams(
    Ng,             # Ng (number of kernels)
    100,            # The initial kernel length (does not apply when using gammatones)
    random_seed,    # The random seed
    step_size,      # The update step size
    1, 	        	# Clamp value gradient
    0.7,            # The weight with which the gradients is smoothed
    exp_threshold,  # The norm for which to expand the kernels [ARGS[3])
    1/10,           # The range on which the above norm should be computed
    100,             # After how many iterations the expansion is done
    50,             # nStore    
    4,              # maxEpochs (in practice we might hit 5 or something)    
    [1, 2, 3, 4],                       # epoch_schedule 
    step_size*[1, 2, 1, 1], 	        # step_size_schedule
    exp_threshold*[-1, 1, 1, 1],   # exp_threshold_schedule (higher=less expansion; <0 means no expansion)
    nTrainIts,      # nTrainIts (ARGS[4])
    use_vad,        # use_vad (embedded in .tsv files)
    ortho_flag,     # orthogonalise_kernels
    initial_type ,  # initialise_type: "gaussian", "gammatone", "dirac"
)

Random.seed!(TrainParam.random_seed)  # Set the random seed for reproducibility

Filterparam = filter_utils.Filterparams(
    80,         # f_low
    7000,       # f_high
    16000,      # fs
    3001,       # length_filter
    4096,       # length_freq_ax (only relevant for plotting)
)
f = filter_utils.initialise_FIR(Filterparam, true, false)  # plot_flag, saveflag


"""
Initialize kernels and plot them
"""
kernels = mp_utils.initialise_kernels(TrainParam.initialise_type, TrainParam.kernel_size, TrainParam.Ng, false)
mp_utils.plot_kernels(kernels)


"""
Set parameters for the matching pursuit algorithm
"""
lengths = train_utils.get_kernel_lengths(kernels)
MPparam = mp_utils.MPparams(
    "amplitude",    # stop_type
    0.1,            # stop_cond
    40000,          # max_iter
    2*maximum(lengths),   # frame_length
    maximum(lengths),     # hop_length
    maximum(lengths)+1    # crop_length           
)


"""
option to load existing kernels
"""
#kernels = mp_utils.load_kernels_from_jld2("tests/data/kernels_TIMIT.jld2")


"""
Go into training loop. Assume that a .tsv file containing paths to the training data is available at tsv_file.
Here we start training from scratch. If you have previous kernels, you can load them using load_kernels_from_jld2 and continue from there.
"""

begin
    itCount = 0 
    for epochCount in 1:TrainParam.maxEpochs
        df_tsv = train_utils.get_paths(tsv_file, true, false)  # shuffle the .tsv file each epoch
        println("Starting epoch ", epochCount, " of ", TrainParam.maxEpochs)
        println(" Number of training examples: ", nrow(df_tsv))
        flush(stdout)

        # Update step size and exp_threshold if needed
        train_utils.update_training_params!(epochCount, TrainParam)

        # Inner loop: loop over audio files.
        for row in ProgressBar(eachrow(df_tsv))
            if itCount >= TrainParam.nTrainIts
                @goto terminate_loops
            end

            # Check if loading was successful
            loadVal = train_utils.load_row_and_check_validity(row)
            if isnothing(loadVal)
                continue
            end
            
            global itCount += 1

            x, fs_read = loadVal
            x = train_utils.preprocess_audio(x, fs_read, fs, f, true) # Preprocess audio (e.g. resampling, filtering, normalisation. Filtering is not done at the moment)

            train_utils.run_training_iter!(x, MPparam, TrainParam, kernels, fs, true)

            # Orthogonlise kernels if needed
            orthogonalise_kernels(kernels, TrainParam.ortho_kernels)
 
            # Store kernels and plot them every nStore iterations     
            plot_and_store(kernels, epochCount, itCount, ID, TrainParam.nStore) 
        
            # Expand kernels every so often --> take care to update MPparam.frame_length, hop_length and crop_length if kernels are expanded
            expand_kernels(kernels, TrainParam, itCount, MPparam)
        end
    end
    @label terminate_loops    


    path_store =  "tests/output/kernels_epoch"*string(epochCount)*"_it"*string(itCount)*".jld2"
    println("Finished training the kernels. Storing final result to ", path_store)
    mp_utils.save_kernels_to_jld2(kernels, "tests/output/kernels_epoch"*string(epochCount)*"_it"*string(itCount)*".jld2")
end

println("Exiting...")
exit()

