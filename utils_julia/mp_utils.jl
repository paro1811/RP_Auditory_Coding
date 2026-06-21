"""
    module for matching pursuit and kernel learning
"""


module mp_utils

    import LinearAlgebra
    import DSP
    using Base.Threads
    using FileIO: load, save, loadstreaming, savestreaming
    using JLD2
    using Plots
    using CSV, DataFrames
    try
        using PyCall
    catch
        println("PyCall not available, gammatone initialisation will not work")
    end

    export Kernel, MPparams, TrainParams		                                            # structures
    export matching_pursuit, short_time_matching_pursuit                                    # matching pursuit
    export reconstruct_matching_pursuit, reconstruct_matching_pursuit_and_get_residue_norm	# matching pursuit - reconstruction
    export load_kernels_from_jld2                                                           # loading kernels
    export load_encoded_waveform_from_jld2, store_encoded_waveform_jld2                     # loading and storing encoded waveforms


    # These functions are used for kernel learning
    export update_kernels!, trim_and_expand_kernels! 		# kernel learning
    export save_kernels_to_jld2, arrayPlot                  # logging and storing


    # Define a struct to hold kernel data
    #   kernel: the actual kernel
    #   gradient: the gradient of the kernel
    mutable struct Kernel
        kernel::Vector{Float64}         # The actual kernel (1D array)
        gradient::Vector{Float64}       # The gradient of the kernel (1D array)
        weight::Float64                 # The weight of the kernel (not used currently)
    end

    # Default constructor (no args)
    Kernel() = Kernel(Float64[], Float64[], 1.0)

    # Constructor with missing weight (for backward compatibility)
    Kernel(kernel::Vector{Float64}, gradient::Vector{Float64}) = Kernel(kernel, gradient, 1.0)

    function JLD2.convert(::Type{Kernel}, x::JLD2.ReconstructedMutable{:Kernel, (:kernel, :gradient), Tuple{Any, Any}})
        Kernel(x.kernel, x.gradient, 1.0)
    end

    mutable struct KernelFourier
        kernel::Vector{ComplexF64}       # The frequency domain kernel (1D array)
    end


    # Define a struct for matching pursuit parameters
    #   kernel: the actual kernel
    #   gradient: the gradient of the kernel
    mutable struct MPparams
        stop_type::String       # The type for which matching pursuit runs "amplitude" vs "iterations"
        stop_cond::Float64      # The point at which to stop the stop type (it is int for iterations, so not sure how that works)
        max_iter::Int32         # The maximum allowed number of iterations
        frame_length::Int32   # The window length for short-time matching pursuit
        hop_length::Int32      # The hop length for short-time matching pursuit
        crop_length::Int32     # The crop length for short-time matching pursuit
        stable_MP_param::Bool  # If true, do not change the MP parameters during training
    end


    # Define a struct to hold parameters related to training
    mutable struct TrainParams
        Ng::Int32               # The number of kernels
        kernel_size::Int32      # The initial kernel length
        random_seed::Int32      # The random seed
        step_size::Float64      # The update step size
        clamp_val::Float64      # Clamp value for gradient
        smoothing_weight::Float64   # The weight with which the gradients is smoothed
        exp_threshold::Float64  # The norm for which to expand the kernels
        exp_range::Float64      # The range on which the norm should be computed
        exp_update::Int32       # After how many iterations the expansion is done
        max_length::Int32       # Maximum length of the kernels
        min_length::Int32       # Minimum length of the kernels
        nStore::Int32           # How often to store the kernels
        maxEpochs::Int32        # Maximum number of epochs
        epoch_schedule::Vector{Int32}           # Schedule for updating step_size and exp_threshold
        step_size_schedule::Vector{Float64}     # Schedule for updating step_size
        exp_threshold_schedule::Vector{Float64} # Schedule for updating exp_threshold
        nTrainIts::Int32        # Number of training iterations
        use_segmentation::Bool  # Use of segments (embedded in tsv file)
        segment_col::Union{String, Nothing}     # Name of the column in the .tsv file containing the segments (if use_segmentation=true)
        big_segment::Bool
        ortho_kernels::Bool     # Orthogonalise kernels
        initialise_type::String # Type of initialisation for kernels
        kernel_dropout::Int		# Kernel dropout: if kernel_dropout=12, 12 kernels are dropped during each training iteration (randomly selected).
        kernel_dropout_schedule::Vector{Int32}           # Schedule for updating kernel_dropout (1=dropout (nbr based on kernel_dropout), 0=no dropout)
    end


    # A single convolution + maximum selection. This is used in the threaded loop below.
    @inline function process_kernel(kernel, x_res_flip)
        tmp = similar(x_res_flip, length(x_res_flip) + length(kernel) - 1)
        DSP.conv!(tmp, x_res_flip, kernel)
        # Find argmax of abs without allocating abs.(tmp)
        best_idx = 1
        best_val = abs(tmp[1])
        @inbounds for i in 2:length(tmp)
            v = abs(tmp[i])
            if v > best_val
                best_val = v
                best_idx = i
            end
        end
        return tmp[best_idx], best_idx
    end


    # Single iteration of matching pursuit
    function matching_pursuit_iter(x_res, kernels)
        Ng = length(kernels)  # number of kernels
        a = zeros(Ng)           # actual amplitude
        c = zeros(Ng)           # Weighted amplitudes
        b = zeros(Int, Ng)      # actual indices

        # Reverse in-place into preallocated buffer to avoid allocating every iteration
        x_res_flip = Vector{Float64}(undef, length(x_res))
        @inbounds for i in eachindex(x_res)
            x_res_flip[i] = x_res[length(x_res) - i + 1]
        end

        # Preallocate results array
        results = Vector{Tuple{Float64, Int}}(undef, Ng)
        @threads for j in 1:Ng
            results[j] = process_kernel(kernels[j].kernel, x_res_flip)
        end

        # Unpack results and find best kernel without allocating abs.(c)
        best_kernel = 1
        best_c = -Inf
        for (j, (a_j, b_j)) in enumerate(results)
            a[j] = a_j
            b[j] = b_j
            cj = abs(a_j) * kernels[j].weight
            c[j] = cj
            if cj > best_c
                best_c = cj
                best_kernel = j
            end
        end
        kernel_val = best_kernel
        index_val = length(x_res) - b[kernel_val] + 1
        amp_val = a[kernel_val]

        # Get the kernel to subtract
        kernel_tmp = amp_val * kernels[kernel_val].kernel

        # Try to subtract the kernel from the signal
        try
            x_res[index_val:index_val+length(kernel_tmp)-1] .-= kernel_tmp
        catch
            # Handle case where kernel is larger than the remaining signal length
            if index_val > 0
                x_res[index_val:end] .-= kernel_tmp[1:length(x_res[index_val:end])]
            elseif index_val < 1
                index_end = index_val + length(kernel_tmp) - 1
                x_res[1:index_end] .-= kernel_tmp[end-length(x_res[1:index_end])+1:end]
            end
        end

        return amp_val, index_val, kernel_val, x_res
    end


    # Main matching pursuit function
    function matching_pursuit(x, stop_type, stop_cond, kernels, x_res=nothing, max_iter=nothing)
        if isnothing(x_res)
            x_res = copy(x)
        end
        if isnothing(max_iter)
            max_iter = -1
        end

        stop_type = string(stop_type)

        # Initial conditions
        amp_list = Float64[]
        index_list = Int[]
        kernel_list = Int[]
        nIt = 0
        norm_list = [LinearAlgebra.norm(x_res)]

        if stop_type == "amplitude"
            # MP iterations
            while true
                # amp_val, index_val, kernel_val, x_res = matching_pursuit_iter_jit(x_res, typed_kernels)
                amp_val, index_val, kernel_val, x_res = matching_pursuit_iter(x_res, kernels)
                push!(amp_list, amp_val)
                push!(index_list, index_val)
                push!(kernel_list, kernel_val)
                push!(norm_list, LinearAlgebra.norm(x_res))
                if abs(amp_val) < stop_cond
                    break
                end
                #println(amp_list[end])

                if max_iter > 0
                    if nIt > max_iter
                        println("Maximum number of MP iterations reached")
                        break
                    end
                end
                nIt += 1
            end

        elseif stop_type == "iterations"
            # MP iterations
            while nIt < stop_cond
                amp_val, index_val, kernel_val, x_res = matching_pursuit_iter(x_res, kernels)
                push!(amp_list, amp_val)
                push!(index_list, index_val)
                push!(kernel_list, kernel_val)
                push!(norm_list, LinearAlgebra.norm(x_res))
                nIt += 1
            end
        else
            println("Invalid stop condition specified, choose 'iterations' or 'amplitude'")
        end

        return x_res, kernel_list, amp_list, index_list, norm_list
    end


    # Short-time matching pursuit iteration
    function short_time_matching_pursuit_iter(
        dictionary::Union{Vector{Main.mp_utils.Kernel}, Vector{Any}},
        x_res::Union{Vector{Float64}, Matrix{<:Real}},
        indx_start::Int,
        indx_end::Int,
        stop_type::String,
        stop_condition,
        crop_length::Union{Int, Int32})

        # Extract a copy of the segment to process
        x_seg = copy(x_res[indx_start:indx_end]) # here we could do a window if needed

        # Encode segment
        _, kernel_list, amp_list, index_list, _ = matching_pursuit(x_seg, stop_type, stop_condition, dictionary)

        if isempty(kernel_list)
            encoded_waveform = []
        elseif stop_type == "amplitude" && abs(amp_list[1]) < stop_condition
            encoded_waveform = []
        else
            if stop_type == "amplitude"
                encoded_waveform = crop_encoded_waveform(kernel_list, amp_list, index_list; crop_indx=crop_length, crop_amp=stop_condition)
            else
                encoded_waveform = crop_encoded_waveform(kernel_list, amp_list, index_list; crop_indx=crop_length)
            end

            if !isempty(encoded_waveform)
                kernel_list, amp_list, index_list = split_tuple_encoding(encoded_waveform)

	            # Reconstruct signal from encoding (needed due to cropping)
	            x_rec = reconstruct_matching_pursuit(index_list, kernel_list, amp_list, dictionary, x_seg)

	            # Update residual signal
	            x_res[indx_start:indx_start+length(x_rec)-1] = x_res[indx_start:indx_start+length(x_rec)-1]  .- x_rec
            else
                encoded_waveform = []
            end
        end

        return x_res, encoded_waveform
    end


    # Short-time matching pursuit main function
    function short_time_matching_pursuit(
        dictionary::AbstractVector,
        x::Union{Vector{Float64}, Matrix{<:Real}},
        stop_type::String,
        stop_condition,
        hop_length::Union{Int, Int32, Nothing} = nothing,
        frame_length::Union{Int, Int32, Nothing} = nothing,
        crop_length::Union{Int, Int32, Nothing} = nothing,
        plot_flag::Bool = false)

        # Copy the input to avoid modifying the original signal
        x_res = copy(x)

        # Handle default parameters using max kernel length
        if hop_length === nothing || frame_length === nothing || crop_length === nothing
            kernel_lengths = [length(k.kernel) for k in dictionary]
        end

        if hop_length === nothing
            hop_length = maximum(kernel_lengths)
            println("Warning: No hop_length specified. Using default value of maximum kernel length=", hop_length)
        end

        if frame_length === nothing
            frame_length = 2 * maximum(kernel_lengths)
            println("Warning: No frame_length specified. Using default value of 2*(maximum kernel length)=", frame_length)
        end

        if crop_length === nothing
            crop_length = frame_length - maximum(kernel_lengths) + 1
            println("Warning: No crop_length specified. Using default value of frame_length - maximum kernel length + 1=", crop_length)
        end

        # Initialize variables
        n_frame = -1
        encoded_waveform = Vector{Tuple{Int, Float64, Int}}()  # Adjust type as needed

        while true
            n_frame += 1
            indx_start = n_frame * hop_length + 1
            indx_end = indx_start + frame_length - 1

            if indx_end > length(x)
                break
            end

            if plot_flag
                p = plot(x[indx_start:indx_end], label="input")
                plot!(x_res[indx_start:indx_end], label="residue")
                ylims!(-1,1)
                display(p)
                p = []
            end

            x_res, encoded_waveform_frame = short_time_matching_pursuit_iter(
                dictionary, x_res, indx_start, indx_end,
                stop_type, stop_condition, crop_length
            )

            if !isempty(encoded_waveform_frame)
                encoded_adjusted = [(k, a, i + indx_start - 1) for (k, a, i) in encoded_waveform_frame]
                append!(encoded_waveform, encoded_adjusted)
            end

            if plot_flag
                p = plot(x[indx_start:indx_end], label="input")
                plot!(x_res[indx_start:indx_end], label="final residue")
                ylims!(-1,1)
                display(p)
                p = []
            end
        end

        return encoded_waveform, x_res
    end


    # Function to crop encoded waveform based on amplitude and/or index thresholds
    function crop_encoded_waveform(kernel_list::Vector{Int}, amp_list::Vector{Float64}, index_list::Vector{Int}; crop_indx::Union{Int,Int32, Nothing}=nothing, crop_amp::Union{Float64,Nothing}=nothing)
        """
        Crops encoded waveform components based on amplitude and/or index thresholds.

        Parameters:
        -----------
        kernel_list : Vector
            List of kernel values (first element of each tuple in Python version).
        amp_list : Vector
            List of amplitude values (second element in original tuple).
        index_list : Vector
            List of index values (third element in original tuple).

        crop_indx : Int, optional
            Maximum index threshold. Values with index > crop_indx will be excluded.

        crop_amp : Float64, optional
            Minimum absolute amplitude threshold. Values with |amp| < crop_amp will be excluded.

        Returns:
        --------
        Vector of Tuples
            Filtered list of (kernel, amplitude, index) tuples.
        """

        cropped = []

        for (k, a, i) in zip(kernel_list, amp_list, index_list)
            if (crop_amp === nothing || abs(a) ≥ crop_amp) && (crop_indx === nothing || i ≤ crop_indx && i > 0)
                push!(cropped, (k, a, i))
            end
        end

        return cropped
    end


    function split_tuple_encoding(tuple_encoding::Union{AbstractVector})
    	try
    		if isempty(tuple_encoding)
    			return Int[], Float64[], Int[]
    		else
				kernel_list = getindex.(tuple_encoding, 1)::Vector{Int}
				amp_list    = getindex.(tuple_encoding, 2)::Vector{Float64}
				index_list  = getindex.(tuple_encoding, 3)::Vector{Int}
		        return kernel_list, amp_list, index_list
			end
	    catch e
		    println("\nDebug info:")
		    println("tuple_encoding = ", tuple_encoding)
   			flush(stdout)
	      	@error "split_tuple_encoding crashed" exception=e

		    # exit the entire program
		    exit(1)
	    end
    end


    # Function to reconstruct the signal from the matching pursuit results
    function reconstruct_iter(index, amp, kernel, x_hat)
        local_kernel = copy(kernel)
        Nk = length(local_kernel)

        Indx1 = index
        Indx2 = Indx1 + Nk - 1

        try
            x_hat[Indx1:Indx2] .+= amp * kernel
        catch e
            if Indx1 <= 0
           	 	println("mp_utils.reconstruct: Index out of bounds: Indx1 = $Indx1")  # Handle exception
            	if Indx2 <= 0
            		println("mp_utils.reconstruct_uter: Index out of bounds: Indx2 = $Indx2")
        		else
		        	deleteat!(local_kernel, 1:abs(Indx1)+1)
		        	x_hat[1:Indx2] .+= amp * local_kernel
	        	end
            else
                println("mp_utils.reconstruct_uter: Index out of bounds: Indx2 = $Indx2")
            	N = length(x_hat)
            	if Indx1 > N
        			println("mp_utils.reconstruct_uter: Index out of bounds: Indx1 = $Indx1")
        		else
		        	x_hat[Indx1:N] .+= amp * local_kernel[1:length(Indx1:N)]
	        	end
            end
        end
        return x_hat
    end


    function reconstruct_matching_pursuit(index_list, kernel_list, amp_list, kernels, x=nothing)
        # Get maximum kernel length
        Nk_list = [length(k.kernel) for k in kernels]  # Preallocate Nk_list
        Nk_max = maximum(Nk_list)

        # Determine the size of x_hat
        if x === nothing
            x_hat = zeros(maximum(index_list) + Nk_max)
        else
            x_hat = zeros(size(x))
        end

        # Reconstruct the signal
        for i in eachindex(amp_list)
            # Reconstruct the signal using the kernel and amplitude
            x_hat = reconstruct_iter(index_list[i], amp_list[i], kernels[kernel_list[i]].kernel, x_hat)
        end

        return x_hat
    end


    function reconstruct_matching_pursuit_and_get_residue_norm(index_list, kernel_list, amp_list, kernels, x)
        # Determine the size of reconstuction x_hat
        x_hat = zeros(size(x))

        residue_norm = Float64[]  # Initialize residue norm as an empty array`
        push!(residue_norm, LinearAlgebra.norm(x-x_hat))  # Store initial residue norm

        # Reconstruct the signal
        for i in eachindex(amp_list)
            # Reconstruct the signal using the kernel and amplitude
            x_hat = reconstruct_iter(index_list[i], amp_list[i], kernels[kernel_list[i]].kernel, x_hat)

            # Update residue norm
            push!(residue_norm, LinearAlgebra.norm(x - x_hat))
        end

        return x_hat, residue_norm
    end


    function store_encoded_waveform_jld2(x_res, kernel_list, amp_list, index_list, file_name, dir_name, kernel_path)
        # x_res: the residual signal after matching pursuit
        # kernel_list: list of kernel indices used in the matching pursuit
        # amp_list: list of amplitudes corresponding to the kernels
        # index_list: list of indices where the kernels were applied

        # file_name: name of the audio. I.e. "audio_segment_1"
        # dir_name: directory where the results are stored, i.e. "Results/Results_<ID>_<FLAG>"
        # kernel_path: path to the kernels, i.e. "Results/Results_ID/kernels_1.jld2"

        # Ensure file_name ends with .jld2
        if !endswith(file_name, ".jld2")
            file_name = file_name * ".jld2"
        end

        # Create directory if it doesn't exist
        if !isdir(dir_name)
            mkdir(dir_name)
        end

        # Construct file path
        file_path = joinpath(dir_name, file_name)

        # Save variables to JLD2 file
        JLD2.@save file_path x_res kernel_list amp_list index_list kernel_path
        println("Stored: ", file_path)
    end


	## Function for loading kernels from a JLD2 file
	function load_encoded_waveform_from_jld2(file_path)
	    try
	        data = jldopen(file_path)

	        return data["x_res"], data["kernel_list"], data["amp_list"], data["index_list"]

	    catch e
	        println("Error loading required data from file: ", file_path)
	        println("Error details: ", e)
	        return []  # Return an empty array if loading fails
	    end
	end


    function update_kernels!(index_list, kernel_list, amp_list, kernels, x_res, step_size, smoothing_weight1, clamp_val)
        # Sort the lists based on kernel number
        sorted_indices = sortperm(kernel_list)
        kernel_list = kernel_list[sorted_indices]
        index_list = index_list[sorted_indices]
        amp_list = amp_list[sorted_indices]

        # Iterate over the kernels
        Ng = length(kernels)
        for ng in 1:Ng
            # Find all indices corresponding to certain type of kernel
            INDX = findall(kernel_list .== ng)

            # If there are any uses for this kernel:
            if !isempty(INDX)
                lKernel = length(kernels[ng].kernel)
                grad = zeros(lKernel)
                for indx in INDX
                    indx1 = index_list[indx]
                    indx2 = index_list[indx] + lKernel - 1

                    if indx1 > 0 && indx2 <= length(x_res)
                        grad_step = amp_list[indx] * x_res[indx1:indx2]
                        grad .+= grad_step
                    else
                        # TODO, include exceptions --> Ignored. The effect of the boundaries on the kernels is likely very limited.
                    end
                end

                # clamp the gradient
                grad = clamp.(grad, -clamp_val, clamp_val)  # Clamp the gradient

                # Note: We use the biased momentum. With smoothing_weight = 0.7, 10 iterations are needed to get to 0.7^10=0.03 (note that for expanded edges the counter restarts)
                kernels[ng].gradient = (1 - smoothing_weight1) * grad + smoothing_weight1 * kernels[ng].gradient
                kernels[ng].kernel += step_size * kernels[ng].gradient
                kernels[ng].kernel /= LinearAlgebra.norm(kernels[ng].kernel)
            end
        end
    end


    function set_kernel_weights!(kernels, weightscheme="uniform", α=0.7)
        Ng = length(kernels)
        if weightscheme == "uniform"
            weights = ones(Ng)
        elseif weightscheme == "preemphasis"
            pre_emp = [1, -1*α]
            weights = zeros(Ng)
            for ng in 1:Ng
                kernel = kernels[ng].kernel
                filtered_kernel = DSP.conv(pre_emp, kernel)
                weights[ng] = LinearAlgebra.norm(filtered_kernel)
            end
        else
            error("Invalid weightscheme specified. Choose 'uniform', 'preemphasis'")
        end


        for ng in 1:Ng
            kernels[ng].weight = weights[ng]
        end
    end

    # Trim and expand kernels with asymmetric trimming.
    # Left (onset) side is trimmed aggressively to keep the attack sharp.
    # Right (decay) side is trimmed permissively to let the gradual decay tail develop.
    # This produces the attack→decay asymmetry seen in biological revcor filters.
    function trim_and_expand_kernels!(kernels, threshold, expansion_range, orthogonalise_kernels=false, max_length=-1, min_length=-1)
        if orthogonalise_kernels
            orthogonalise_kernels!(kernels)
        end

        Ng = length(kernels)

        # Expanding kernels — capped at 10 per side
        for ng in 1:Ng
            Lg = length(kernels[ng].kernel)
            nPad = min(floor(Int, expansion_range * Lg), 10)

            if max_length > 0 && Lg + 2*nPad > max_length
                nPad = max(0, floor(Int, (max_length - Lg)/2))
            end

            if nPad > 0
                kernels[ng].kernel = vcat(zeros(nPad), kernels[ng].kernel, zeros(nPad))
                kernels[ng].gradient = vcat(zeros(nPad), kernels[ng].gradient, zeros(nPad))
            end
        end

        # Asymmetric trimming
        # Left threshold: aggressive (default 0.02) — removes slow buildup before attack
        # Right threshold: 10x more permissive — preserves gradual decay tail
        left_threshold = threshold
        right_threshold = threshold * 0.1

        for ng in 1:Ng
            kernel = kernels[ng].kernel
            gradient = kernels[ng].gradient
            L = length(kernel)
            exp_indx = max(1, ceil(Int, L * expansion_range))

            # Trim leading (onset) side — aggressive
            trim_l = 0
            while trim_l + exp_indx <= L && (L - trim_l) > min_length
                window = (trim_l+1):(trim_l+exp_indx)
                ke = sum(abs2, @view(kernel[window]))
                ge = sum(abs2, @view(gradient[window]))
                if ke < left_threshold && ge < left_threshold
                    trim_l += 1
                else
                    break
                end
            end

            # Trim trailing (decay) side — permissive
            trim_r = 0
            while trim_r + exp_indx <= L && (L - trim_l - trim_r) > min_length
                window = (L-trim_r-exp_indx+1):(L-trim_r)
                ke = sum(abs2, @view(kernel[window]))
                ge = sum(abs2, @view(gradient[window]))
                if ke < right_threshold && ge < right_threshold
                    trim_r += 1
                else
                    break
                end
            end

            if trim_l > 0 || trim_r > 0
                keep = (trim_l+1):(L-trim_r)
                kernel = kernel[keep]
                gradient = gradient[keep]
            end

            kernel = kernel / LinearAlgebra.norm(kernel)
            kernels[ng].kernel = kernel
            kernels[ng].gradient = gradient
        end
    end


    # This function orthogonalises the kernels using Modified Gram-Schmidt process. Note that it does not first shift the
    # kernels to be maximally correlated. I.e. a dirac[n] and dirac[n+1] are considered orthogonal, which does not necessarily make a lot of sense
    function orthogonalise_kernels!(kernels)
        # Sort kernels and gradients by length
        sorted_indices = sortperm([length(k.kernel) for k in kernels])
        kernels = kernels[sorted_indices]

        # Pad so that all kernels have equal length
        max_length = maximum(length(k.kernel) for k in kernels)
        for k in kernels
            k.kernel = vcat(k.kernel, zeros(max_length - length(k.kernel)))
            k.gradient = 0*vcat(k.gradient, zeros(max_length - length(k.gradient)))
        end

        # Collect all kernels into a matrix
        Nkernel = length(kernels)
        kernel_matrix = zeros(Float64, max_length, Nkernel)
        #gradient_matrix = zeros(Float64, max_length, Nkernel)
        for (i, k) in enumerate(kernels)
            kernel_matrix[:,i] = k.kernel
            #gradient_matrix[:,i] = gradient_matrix.kernel
        end

        # Perform Modified Gram-Schmidt orthogonalization
        Q =  LinearAlgebra.qr(kernel_matrix).Q
        #Qgrad = LinearAlgebra.qr(kernel_matrix).Q
        # Update kernels with orthogonalized versions
        for (i, k) in enumerate(kernels)
            k.kernel = Q[:, i]
            #k.gradient = Qgrad[:,i]
        end


        for k in kernels
            # Remove trailing zeros from kernel and gradient
            MAX = maximum(abs.(k.kernel))
            INDX = 1:findlast(>(1e-4*MAX), abs.(k.kernel))
            k.kernel = k.kernel[INDX]
            k.gradient = k.gradient[INDX]
        end
    end


    ##  Function for plotting
    function plot_kernels(kernels, display_plot::Bool=true)
        Ng = length(kernels)  # Number of kernels
        if Ng == 16
            rows, cols = 4, 4     # Define layout size
        elseif Ng == 32
            rows, cols = 4, 8     # Define layout size
        elseif Ng == 64
            rows, cols = 8, 8     # Define layout size
        elseif Ng == 80
            rows, cols = 10, 8     # Define layout size
        elseif Ng == 128
            rows, cols = 8, 16
        elseif Ng == 256
            rows, cols = 16, 16
        else
            rows, cols = 4, 8     # Default layout size
        end

        max_plots = rows * cols
        Ng = min(Ng, max_plots)  # Prevent exceeding the number subplots

        # Create plot with a more tightly packed layout
        p = plot(
            layout=(rows, cols),
            size=(1200, 600),
            grid=false,
            legend=false,
            axis=false,
            framestyle=:none,
        )

        # Add each kernel as a subplot (adjusting subplot numbers to fit)
        for j in 1:Ng
            lm = ((j % cols == 1) ? 0Plots.mm : -3Plots.mm)  # no negative left margin for first column
            tm = ((j <= cols)    ?  0Plots.mm : -3Plots.mm)  # no negative top margin for first row
            plot!(p, kernels[j].kernel;
                    subplot=j,
                    showaxis=false, legend=false,
                    left_margin=lm, top_margin=tm,
                    bottom_margin=0Plots.mm, right_margin=0Plots.mm)

            # Place annotation. Indexed with respect to plot content
            len = length(kernels[j].kernel)
            max_y = maximum(kernels[j].kernel)
            min_y = minimum(kernels[j].kernel)
            height = min_y + 0.8*(max_y - min_y)
            annotate!(p, subplot=j, 0, height, text(string(len), 7, :red, :center))

            # Place a line at 0
            hline!(p, [0]; subplot=j, color=:black, linewidth=1)
        end

        if display_plot
            display(p)
        end

        return p
    end


    function plot_kernels_spectral_features(centroids::AbstractVector, bandwidths::AbstractVector; xlim=[20.0, 24000.0], ylim=[20.0, 12000.0])
		powers_of_10 = 10 .^ (1:6)  # [10^1, 10^2, ..., 10^6]

		# Filter for x-axis: only include ticks within xlim
		xticks_positions = powers_of_10[(powers_of_10 .>= xlim[1]) .& (powers_of_10 .<= xlim[2])]
		xtick_labels = ["10^$i" for i in round.(Int, log10.(xticks_positions))]

		# Filter for y-axis: only include ticks within ylim
		yticks_positions = powers_of_10[(powers_of_10 .>= ylim[1]) .& (powers_of_10 .<= ylim[2])]
		ytick_labels = ["10^$i" for i in round.(Int, log10.(yticks_positions))]


        p = scatter(centroids, bandwidths,
            xlabel="Spectral Centroid (Hz)",
            ylabel="Spectral Bandwidth (Hz)",
            title="Kernel Spectral Features",
            xscale=:log10,
            yscale=:log10,
            xlims=xlim,
            ylims=ylim,
            legend=false,
            markersize=3,
       		grid = true,
       		minorgrid = true
        )
        return p
    end

    ## Function for saving kernels to .jld2 file
    function save_kernels_to_jld2(savepath::String, kernels)
        # Save variables to JLD2 file
        JLD2.@save savepath kernels

        println("Saved to: ", savepath)
    end


    ## Function for loading kernels from a .jld2 file
    function load_kernels_from_jld2(file_path)
        try
            data = load(file_path, "kernels")

            kernels = Vector{mp_utils.Kernel}()

            for d in data
                if isa(d, mp_utils.Kernel)
                    # already a proper Kernel (new format)
                    push!(kernels, d)
                elseif isa(d, NamedTuple) || isa(d, JLD2.ReconstructedMutable)
                    # old format (missing weight)
                    kernel = getfield(d, :kernel)
                    gradient = getfield(d, :gradient)
                    push!(kernels, mp_utils.Kernel(kernel, gradient))
                else
                    println("Unknown kernel type: ", typeof(d))
                end
            end

            return kernels
        catch e
            println("Error loading kernels from file: ", file_path)
            println("Error details: ", e)
            return mp_utils.Kernel[]  # Return an empty array if loading fails
        end
    end


    # Function for initialising a dictionary of kernels
    function initialise_kernels(initialise_type, kernel_size, Ng, ortho_kernels, windowing, spacing=nothing, min_length=nothing, max_length=nothing)
        """
            Initialise kernels based on the specified type and parameters.

            Parameters:
            - initialise_type: Type of initialisation for kernels ("gaussian" or "gammatone", or "dirac").
            - kernel_size: Size of each kernel.
            - Ng: Number of kernels to initialise.
            - ortho_kernels: Boolean flag to orthogonalise kernels after initialisation.

            Returns:
            - initial_kernels: Array of initialized Kernel structs.
        """

        initial_kernels = []

        if initialise_type == "gaussian"
            if isnothing(spacing)
                kernel_size_list = fill(kernel_size, Ng)
            else
                kernel_size_list = round.(Int, LinRange(min_length, max_length, Ng))
            end

            for indx in 1:Ng
                kernel_size = kernel_size_list[indx]
                if windowing
                    window = DSP.Windows.hamming(kernel_size)
                else
                    window = ones(kernel_size)
                end

                kernel = window.*randn(kernel_size) # Generate a random kernel of size (100,)
                kernel /= LinearAlgebra.norm(kernel)                      # Normalize the kernel
                gradient = zeros(kernel_size)       # Initialize the gradient as zeros of size (100,)

                push!(initial_kernels, mp_utils.Kernel(kernel, gradient))
            end
            println("Initialised kernels as windowed white gaussian noise. Min length: ", minimum(kernel_size_list),  ". Max length: ", maximum(kernel_size_list))

        elseif initialise_type == "gammatone"
            try
                @eval using PyCall
                pushfirst!(pyimport("sys")."path", ".")  # add current dir to Python's sys.path
                println("Using Python version: ", pyimport("sys").version)
            catch e
                print(e)
                error("PyCall package is required for gammatone kernel initialisation. Please install it using `import Pkg; Pkg.add(\"PyCall\")`.")
            end
            python_gammatone = pyimport("gammatone")
            initial_kernels_py = python_gammatone.create_gammatone_dictionary(num_filters=Ng, fs=16000, f_min=100, f_max=7000, threshold_value=0.03)
            for kernelIndx in 1:Ng
                kernel = initial_kernels_py[kernelIndx].kernel/LinearAlgebra.norm(initial_kernels_py[kernelIndx].kernel)
                gradient = zeros(length(kernel))
                push!(initial_kernels, mp_utils.Kernel(kernel, gradient))
            end

            LEN = [length(k.kernel) for k in initial_kernels]
            println("Initialised kernels as gammatone filter. Max length: ", maximum(LEN))

        elseif initialise_type == "impulse"
            for _ in 1:Ng
                kernel = zeros(kernel_size)
                kernel[floor(Int, kernel_size/2)] = 1.0  # Impulse in the center
                gradient = zeros(kernel_size)       # Initialize the gradient as zeros of size (100,)

                push!(initial_kernels, mp_utils.Kernel(kernel, gradient))
            end
            LEN = [length(k.kernel) for k in initial_kernels]
            println("Initialised kernels as impulses. Max length: ", kernel_size)

        elseif initialise_type == "filtered_gaussian"
            kernel_size_list = fill(kernel_size, Ng)

            f_min = 250
            f_max = 7500
            f_edges = range(f_min, f_max, length = Ng + 1)
            overlap = 1
            fs = 16000
            println("Warning in mp_utils.initialise_kernels: filtered_gaussian is experimental and does assume 16 kHz sampling rate!")

            for indx in 1:Ng
                kernel_size = kernel_size_list[indx]
                if windowing
                    window = DSP.Windows.hamming(kernel_size)
                else
                    window = ones(kernel_size)
                end
                kernel = window.*randn(kernel_size) # Generate a random kernel of size (100,)

                band_width = f_edges[indx+1] - f_edges[indx]
                f_low = max(f_min, f_edges[indx] - overlap * band_width)
                f_high = min(f_max, f_edges[indx+1] + overlap * band_width)

                #println(band_width)

                # --- Band-pass filter ---
                bp_filter = DSP.digitalfilter(
                    DSP.Bandpass(f_low / (fs/2), f_high / (fs/2)),
                    DSP.Butterworth(4)
                )

                kernel = DSP.filtfilt(bp_filter, kernel)
                kernel /= LinearAlgebra.norm(kernel)                      # Normalize the kernel
                gradient = zeros(kernel_size)       # Initialize the gradient as zeros of size (100,)

                push!(initial_kernels, mp_utils.Kernel(kernel, gradient))
            end
            println("Initialised kernels as filtered white gaussian noise. Min length: ", minimum(kernel_size_list),  ". Max length: ", maximum(kernel_size_list))

        else
            println("Warning (initialise_kernels): invalid initialise_type specified. use gaussian or gammatone")
        end



        if ortho_kernels
            println("Orthogonalising kernels")
            orthogonalise_kernels!(initial_kernels)
        end

        return initial_kernels
    end
end
