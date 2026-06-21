import h5py
import numpy as np
import scipy.signal as signal
import os
from concurrent.futures import ThreadPoolExecutor
import matplotlib.pyplot as plt
import seaborn as sns


"""
This module provides functions for creating a dictionary of kernels from JLD2 files, performing matching pursuit encoding, and reconstructing waveforms from encoded data.
It also includes utilities for padding kernels, sorting dictionaries, and plotting dictionary elements and encoding results.
"""

class Kernel:
    """
    A class to represent a kernel .

    Attributes:
        kernel (numpy.ndarray): A 1D array representing the kernel values.

    Methods:
        __repr__(): Returns a string representation of the Kernel object.

        center_frequency(fs=16000): Computes the center frequency of the kernel using frequency response.
            fs (int): Sampling frequency in Hz. Default is 16000 Hz. 
    """

    def __init__(self, kernel):
        self.kernel = np.asarray(kernel, dtype=np.float64)         # The actual kernel (1D array)


    def __repr__(self):
        return f"Kernel(kernel={self.kernel})"
    

    @ property
    def center_frequency(self, fs=16000):
        # This is a bit of a lazy approach to getting the center frequency. Librosa has a centroid frequency function which might be more appropriate.
        w, h = signal.freqz(self.kernel, worN = max(len(self.kernel), 2048), fs=fs)  # w in Hz
        mag_db = 20 * np.log10(np.maximum(abs(h), 1e-10))
        peak_idx = np.argmax(mag_db)
        center_freq = w[peak_idx]
        return center_freq
    
    @ property
    def centroid_frequency(self, fs=16000):
        """
        Computes the spectral centroid (magnitude-weighted center frequency)
        of the filter kernel's frequency response.
        
        Args:
            fs (int): Sampling frequency in Hz.

        Returns:
            float: The centroid frequency in Hz.
        """
        # Compute the frequency response of the kernel
        w, h = signal.freqz(self.kernel, worN=max(len(self.kernel), 2048), fs=fs)
        mag = np.abs(h)

        # Avoid division by zero
        if np.sum(mag) == 0:
            return 0.0

        # Magnitude-weighted average frequency
        centroid = np.sum(w * mag) / np.sum(mag)
        return centroid


"""
Set of functions for dictionary (dictionary is just a list of Kernel objects):
    - create_dictionary_from_JLD2: Load kernels from a JLD2 file and create a dictionary of Kernel objects.
    - sort_dictionary: Sort the dictionary based on specified criteria (e.g., center frequency or length).
    - pad_dictionary: Pad the kernels in the dictionary to a specified target length.
    - plot_dictionary_elements: Plot the kernels in the dictionary.
"""
def create_dictionary_from_JLD2(filepath, sorting = None):
    """
    Create a dictionary from a JLD2 file containing kernels.
    NOTE: Atm the gradient and abs_amp are not imported from the JLD2 file.
    Parameters:
        filepath (str): Path to the JLD2 file.

    Returns:
        list: A list of Kernel objects representing the kernels in the JLD2 file.
    """

    if not os.path.exists(filepath):
        raise FileNotFoundError(f"File not found: {filepath}")

    dictionary = []
    with h5py.File(filepath, "r") as f:
        kernels = f["kernels"][:]  # Load dataset

        for kernel_entry in kernels:
            kernel_obj = f[kernel_entry]  # First dereference
            kernel_ref = kernel_obj["kernel"]  # Get kernel reference

            if isinstance(kernel_ref, h5py.Reference):  # Ensure it's a reference
                kernel_data = f[kernel_ref][:]  # Second dereference to get actual data
            else:
                kernel_data = kernel_ref[:]  # If it's already data, just extract it

            # Normalize the kernel
            kernel_data = kernel_data / np.linalg.norm(kernel_data)

            # Create a Kernel object
            dictionary.append(Kernel(kernel_data))

    dictionary = sort_dictionary(dictionary, sorting)
    return dictionary


def create_gammatone_dictionary(num_filters=128, fs=16000, f_min=50, f_max=7500, threshold_value=0.01):
    """
    Create a dictionary of gammatone filters spaced linearly on an ERB-rate scale.

    Parameters:
        num_filters (int): Number of gammatone filters.
        fs (float): Sampling frequency in Hz.
        f_min (float): Minimum center frequency in Hz.
        f_max (float): Maximum center frequency in Hz.
        duration (float): Duration of the filters in seconds.
        threshold_value (float): Threshold value for removing small values from the filters.
    Returns:
        list: A list of Kernel objects representing the gammatone filters.
    """

    # Generate center frequencies spaced linearly on an ERB-rate scale
    erb_min = 21.4 * np.log10(4.37e-3 * f_min + 1)
    erb_max = 21.4 * np.log10(4.37e-3 * f_max + 1)
    erb_space = np.linspace(erb_min, erb_max, num_filters)
    center_frequencies = (10 ** (erb_space / 21.4) - 1) / 4.37e-3

    # Create gammatone filters
    dictionary = []
    for cf in center_frequencies:
        kernel, _ = signal.gammatone(cf, 'fir', 4, fs=fs, numtaps=round(0.1*fs))
        threshold = threshold_value * np.max(np.abs(kernel))
        valid_indices = np.where(np.abs(kernel) > threshold)[0]
        if valid_indices.size > 0:
            kernel = kernel[:valid_indices[-1] + 1]
        kernel = kernel/np.linalg.norm(kernel)
        dictionary.append(Kernel(kernel))
    return dictionary


def sort_dictionary(dictionary, sorting="centroid_frequency"):
    if sorting == None:
        return dictionary
    elif sorting == "centroid_frequency":
        sorted_dict = sorted(dictionary, key=lambda x: x.centroid_frequency)
        return sorted_dict
    elif sorting == "center_frequency":
        sorted_dict = sorted(dictionary, key=lambda x: x.center_frequency)
        return sorted_dict
    elif sorting == "length":
        print(dictionary[1].kernel.size)
        sorted_dict = sorted(dictionary, key=lambda x: x.kernel.size)
        return sorted_dict
    else: 
        print("Warning (in mp_utils.sort_dictionary): Invalid sorting condition specified. Returning unsorted dictionary.")
        return dictionary


def pad_dictionary(dictionary, target_length=None):
    """
    Pad the kernels in the dictionary to a target length.

    Parameters:
        dictionary (list): List of Kernel objects.
        target_length (int): The length to which each kernel should be padded.

    Returns:
        list: A list of padded Kernel objects.
    """
    # Calculate the maximum length of kernels in the dictionary
    if target_length is None:  
        print("No target length provided, calculating from dictionary.")
        target_length = max(len(kernel.kernel) for kernel in dictionary)
    
    padded_dictionary = []
    for kernel in dictionary:
        if len(kernel.kernel) < target_length:
            padding = np.zeros(target_length - len(kernel.kernel))
            padded_kernel = np.concatenate((kernel.kernel, padding))
        elif len(kernel.kernel) == target_length:
            padded_kernel = kernel.kernel
        else:
            print(f"Warning: Truncating kernel from length {len(kernel.kernel)} to {target_length}.")
            padded_kernel = kernel.kernel[:target_length]  # Truncate if longer than target_length

        padded_dictionary.append(Kernel(padded_kernel))
    return padded_dictionary


def plot_dictionary_elements(dictionary, title = None, show=True):
    if len(dictionary) <= 32:
        fig, axes = plt.subplots(4, 8, figsize=(12, 6))
        plt.subplots_adjust(wspace=0.3, hspace=0.3)
    elif len(dictionary) <= 64:
        fig, axes = plt.subplots(8, 8, figsize=(12, 6))
        plt.subplots_adjust(wspace=0.3, hspace=0.3)
    elif len(dictionary) <= 80:
        fig, axes = plt.subplots(10, 8, figsize=(12, 6))
        plt.subplots_adjust(wspace=0.3, hspace=0.3)
    else:
        fig, axes = plt.subplots(16, 8, figsize=(12, 6))
        plt.subplots_adjust(wspace=0.3, hspace=0.3)

    for i, ax in enumerate(axes.flat):
        if i < len(dictionary):
            kernel = dictionary[i].kernel
            ax.plot(kernel)
            
            # Add some text indicating the length of the kernel
            kernel_length = len(kernel)
            ax.text(0.5, 0.9, f"{kernel_length} samples", fontsize=8, color='red', transform=ax.transAxes)
            
        ax.axis('off')  # Remove axis labels and ticks
    
    plt.tight_layout()
    if title is not None:
        fig.suptitle(title, fontsize=12, y=1.02)
    if show: 
        plt.show()
    return
    
    
    
"""
Set of functions for computing matching pursuit based encoding
    - correlation: Compute the cross-correlation between a signal and a dictionary element.
    - matching_pursuit_iter: Perform one iteration of the Matching Pursuit algorithm.
    - matching_pursuit: Perform the Matching Pursuit algorithm to encode a waveform using a given dictionary.
    - short_time_matching_pursuit: A version of matching pursuit that operates on short time segments of the waveform. Can likely be optimised further
"""
def correlation(x, Di):
    #y = signal.correlate(x, Di, mode='valid')
    y = np.correlate(x, Di, mode='valid')  # Use numpy for cross-correlation (this appears to be faster than scipy)
    return y


def matching_pursuit_iter(dictionary, x_res):
    """
    Perform one iteration of the Matching Pursuit algorithm.

    This function identifies the best matching kernel from a dictionary to approximate
    the residual signal `x_res`, updates the residual by subtracting the contribution
    of the selected kernel, and returns the updated residual along with details of the match.

    Args:
        dictionary (list): A list of elements, where each element contains a `kernel` attribute
            representing a signal kernel.
        x_res (numpy.ndarray): The residual signal to be approximated.

    Returns:
        tuple: A tuple containing:
            - x_res (numpy.ndarray): The updated residual signal after subtracting the selected kernel.--> !!!x_res is not actually returned, but modified in place!!!
            - ampMax (float): The amplitude of the selected kernel at the best match location.
            - indxMax (int): The index in the residual signal where the best match occurs.
            - dicElement (int): The index of the selected kernel in the dictionary.

    Notes:
        - The function uses a ThreadPoolExecutor to parallelize the computation of cross-correlations
          for each kernel in the dictionary.
        - The kernel with the maximum absolute cross-correlation value is selected.
        - The residual signal is updated by subtracting the scaled kernel at the best match location.

    Example:
        dictionary = [KernelObject1, KernelObject2, ...]
        x_res = np.array([...])
        updated_res, amp, index, kernel_index = matching_pursuit_iter(dictionary, x_res)
    """
    def process_element(index, element):
        x_corr = correlation(x_res, element.kernel)  # Compute the cross-correlation
        indxMax_tmp = np.argmax(abs(x_corr))  # Find the location where the max abs value is largest
        ampMax_tmp = x_corr[indxMax_tmp]  # Find the corresponding amplitude
        return ampMax_tmp, indxMax_tmp, index

    results = []
    if len(x_res) > 2000: # A random guess to determine if we should use multithreading. There are different types of threadpool, so maybe a different one is more appropriate
        max_threads = 8
        with ThreadPoolExecutor(max_workers=max_threads) as executor:
            futures = [executor.submit(process_element, i, element) for i, element in enumerate(dictionary)]
            for future in futures:
                results.append(future.result())
    else:   # dont use multithreading if the signal is small
        for i, element in enumerate(dictionary):
            ampMax_tmp, indxMax_tmp, index = process_element(i, element)
            results.append((ampMax_tmp, indxMax_tmp, index))
            
    # Find the kernel element with the maximum value
    ampMax, indxMax, dicElement = max(results, key=lambda x: abs(x[0]))

    # Subtract the kernel from the residual
    x_res[indxMax:indxMax + len(dictionary[dicElement].kernel)] -= ampMax * dictionary[dicElement].kernel
    return ampMax, indxMax, dicElement


def matching_pursuit(dictionary, x, stop_type, stop_condition):
    """
    Perform the Matching Pursuit algorithm to encode a waveform using a given dictionary.
    Parameters:
    ----------
    dictionary : list
        A list of elements where each element has a `.kernel` attribute representing the kernel.
    x : numpy.ndarray
        The input waveform that needs to be encoded.
    stop_type : str
        The stopping criterion type. Can be either:
        - "amplitude": Stops when the maximum amplitude of the selected kernel is below `stop_condition`.
        - "iterations": Stops after a specified number of iterations.
    stop_condition : float or int
        The value for the stopping criterion:
        - If `stop_type` is "amplitude", this is the amplitude threshold (e.g., 0.1).
        - If `stop_type` is "iterations", this is the maximum number of iterations (e.g., 100).
    Returns:
    -------
    encoded_waveform : list of tuples
        A list of tuples where each tuple contains:
        - dic_element: The dictionary element selected in the iteration.
        - amplitude: The amplitude of the selected dictionary element.
        - time_index: The time index where the dictionary element is applied.
    x_res : numpy.ndarray
        The residual waveform after encoding.
    Notes:
    -----
    - The algorithm iteratively selects dictionary elements that best match the residual signal.
    - The residual signal is updated in each iteration by subtracting the contribution of the selected element.
    - The loop terminates based on the specified stopping criterion or when the residual norm is below a small threshold (1e-8).
    - If an invalid `stop_type` is provided, the function will print an error message and terminate the loop.
    """

    x_res = x.copy()
    encoded_waveform = []
    
    count = 1
    while True:
        ampMax, indxMax, dicElement = matching_pursuit_iter(dictionary, x_res) # x_res is modified in place
        encoded_waveform.append((dicElement, ampMax, indxMax))
        
        # Check stop condition
        if stop_type == 'abs_amplitude': 
            if (abs(ampMax) < stop_condition) or (np.linalg.norm(x_res) < 1e-9):
                break
        elif stop_type == 'amplitude':
            print("Warning (matching_pursuit): 'amplitude' stop condition not working at the moment. Breaking the loop")
        elif stop_type == 'iterations':
            if (count >= stop_condition) or (np.linalg.norm(x_res) < 1e-9): #1e-9 is somewhat arbitrary. Consider adding it as parameter
                break
        else:
            print("Warning (matching_pursuit): Invalid stop condition specified. Breaking the loop")
            break
        count +=1 

    return encoded_waveform, x_res   


def short_time_matching_pursuit_iter(dictionary, x, indx_start, indx_end, stop_type, stop_condition, crop_length):         
    """
    Perform a single iteration of short-time matching pursuit on a segment of the input signal.

    Parameters:
    -----------
    dictionary : array-like
        The dictionary of atoms used for matching pursuit.
    x : array-like
        The input signal to be processed. This array will be modified in-place to store the residual signal.
    indx_start : int
        The starting index of the segment to process.
    indx_end : int
        The ending index of the segment to process.
    stop_type : str
        The stopping criterion type for the matching pursuit algorithm (e.g., 'iterations', 'error').
    stop_condition : int or float
        The stopping condition value corresponding to the `stop_type` (e.g., number of iterations or error threshold).
    crop_length : int
        The length to crop the encoded waveform.

    Returns:
    --------
    x : array-like
        The updated input signal with the processed segment replaced by the residual.
    encoded_waveform : array-like
        The encoded representation of the processed segment.

    Notes:
    ------
    - This function modifies the input signal `x` in-place by replacing the processed segment with its residual.
    - The `matching_pursuit` and `crop_encoded_waveform` functions are assumed to be defined elsewhere.
    - The reconstruction is performed using the `reconstruct` function, which is also assumed to be defined elsewhere.
    """
    
    # Select segment and encode
    x_seg = x[indx_start:indx_end].copy()
    encoded_waveform, _= matching_pursuit(dictionary, x_seg, stop_type, stop_condition)

    # Crop encoding based on crop_length
    encoded_waveform = crop_encoded_waveform(encoded_waveform, crop_indx=crop_length)

    # Reconstruct the segment from the encoding
    x_rec = reconstruct(dictionary, encoded_waveform, output_length=len(x_seg))

    # Update x to residual for next iteration
    x[indx_start:indx_end] = x_seg - x_rec
    return x, encoded_waveform


def short_time_matching_pursuit(dictionary, x_full, stop_type, stop_condition, hop_length=None, window_length=None, crop_length=None):  
    """
    Perform short-time matching pursuit on a signal using a given dictionary of kernels.
    This function decomposes the input signal `x_full` into a sparse representation using a dictionary of kernels.
    The decomposition is performed frame by frame, with each frame being processed independently. The residual
    signal is updated in place after each frame is processed.
    Parameters:
    -----------
    dictionary : list
        A list of kernel objects, where each kernel contains a `kernel` attribute representing the waveform.
    x_full : numpy.ndarray
        The input signal to be decomposed.
    stop_type : str
        The stopping criterion type for the matching pursuit algorithm (e.g., "iterations", "error").
    stop_condition : int or float
        The stopping condition value corresponding to the `stop_type` (e.g., number of iterations or error threshold).
    hop_length : int, optional
        The number of samples to shift between consecutive frames. If not provided, defaults to the maximum kernel length.
    window_length : int, optional
        The length of each frame in samples. If not provided, defaults to twice the maximum kernel length.
    crop_length : int, optional
        The length to crop the encoded waveform. If not provided, defaults to the maximum kernel length.
    Returns:
    --------
    encoded_waveform_full : list
        A list of tuples representing the encoded waveform. Each tuple contains:
        - The kernel index
        - The activation coefficient
        - The adjusted time index (relative to the original signal)
    x : numpy.ndarray
        The residual signal after encoding. Note that this is modified in place.
    Notes:
    ------
    - The function assumes that the `dictionary` contains kernel objects with a `kernel` attribute.
    - The input signal `x` is modified in place to store the residual signal after encoding.
    - The function prints warnings if `hop_length`, `window_length`, or `crop_length` are not provided, and defaults are used.
    - The `matching_pursuit`, `crop_encoded_waveform`, and `reconstruct` functions are assumed to be defined elsewhere.
    Example:
    --------
    >>> encoded_waveform, residual = short_time_matching_pursuit(dictionary, signal, "iterations", 10)
    >>> print(encoded_waveform)
    >>> print(residual)
    """
    # My feeling is that an algorithm like this must have been published somewhere already. I couldn't find it, so I reinvented the wheel
    
    x = x_full.copy()  # Make a copy of the input signal to avoid modifying the original signal
    if hop_length is None or window_length is None or crop_length is None:
        kernel_length = np.array([len(kernel.kernel) for kernel in dictionary])
    
    if hop_length is None:
        print("Warning: No hop_length specified. Using default value of maximum kernel length.")
        hop_length = kernel_length.max()

    if window_length is None:
        print("Warning: No window_length specified. Using default value of 2*(maximum kernel length).")
        window_length = 2 * kernel_length.max()

    if crop_length is None:
        print("Warning: No crop_length specified. Using default value of maximum kernel length.")
        crop_length = kernel_length.max()
    
    # Initialize variables
    n_frame = -1                # Initialize frame counter
    encoded_waveform_full = []  # Hold encoding

    # Loop through the signal in frames
    while True:
        # Increment frame counter
        n_frame += 1

        # Calculate start and end indices for the current frame
        indx_start = n_frame * hop_length
        indx_end = indx_start + window_length
        
        # Check if we have reached the end of the signal
        if indx_start + window_length > len(x):
            #print("Reached the end of the signal.")
            break

        x, encoded_waveform = short_time_matching_pursuit_iter(dictionary, x, indx_start, indx_end, stop_type, stop_condition, crop_length)
        

        # Store the encoded waveform with adjusted indices
        if encoded_waveform:
            encoded_waveform_adjusted = [(activation[0], activation[1], activation[2] + indx_start) for activation in encoded_waveform]
            encoded_waveform_full.extend(encoded_waveform_adjusted)

    return encoded_waveform_full, x # Note that x is modified in place, so it is the residual signal after encoding.



"""
 Set of functions for operating on encoded waveforms:
    - crop_encoded_waveform: Crop the encoded waveform based on amplitude and index thresholds.
    - plot_encoding: Plot the waveform and encoding scatterplot.
    - reconstruct_iter: Reconstruct the waveform iteratively from the encoded waveform.
    - reconstruct: Reconstruct the waveform from the encoded waveform.
"""
def reconstruct_iter(indx, kernel, amp, reconstructed_waveform, output_length, npad):
    indx = indx + npad
    if indx < 0:
        print("need to define lower edgecase. Amp ", amp, "Indx undershoot: ", indx)
    elif indx+len(kernel) > output_length:
        print("Need to define upper edgecase. Amp ", amp,  "Indx overshoot: ", indx + len(kernel) - output_length)
    else:
        reconstructed_waveform[indx:indx+len(kernel)] += amp*kernel    
    return reconstructed_waveform   


def reconstruct(dictionary, encoded_waveform, output_length = None, npad = 0):
    if output_length == None:
        print("Should implement a way to get an output_length here (mp_utils.reconstruct)")
    
    reconstructed_waveform = np.zeros(2*npad + output_length)
    output_length = output_length + 2*npad
    
    for (dicElement, amp, indx) in encoded_waveform:  
        kernel = dictionary[dicElement].kernel
        reconstructed_waveform = reconstruct_iter(indx, kernel, amp, reconstructed_waveform, output_length, npad)
        
    #reconstructed_waveform = reconstructed_waveform[npad:-npad]
    return reconstructed_waveform


# Decode (reconstruct) the waveform based on the encoded waveform
def reconstruct_and_get_norm(dictionary, encoded_waveform, waveform):
    norm_list = []
    reconstructed_waveform = np.zeros(len(waveform))
    for (dicElement, amp, indx) in encoded_waveform:
        kernel = dictionary[dicElement].kernel
        reconstructed_waveform[indx:indx+len(kernel)] += amp*kernel
        norm_list.append(np.linalg.norm(waveform - reconstructed_waveform))

    return reconstructed_waveform, norm_list
    

def crop_encoded_waveform(encoded_waveform, crop_indx=None, crop_amp=None):
    """
    Crops an encoded waveform based on amplitude and/or index thresholds.

    Parameters:
    -----------
    encoded_waveform : list of tuples
        A list where each entry is a tuple representing the encoded waveform. 
        The second element of the tuple is assumed to be the amplitude, and 
        the third element is assumed to be the index.

    crop_indx : int, optional
        The maximum index threshold. Entries with an index greater than this 
        value will be excluded. Defaults to None, meaning no index-based cropping.

    crop_amp : float, optional
        The minimum amplitude threshold. Entries with an absolute amplitude 
        less than this value will be excluded. Defaults to None, meaning no 
        amplitude-based cropping.

    Returns:
    --------
    list of tuples
        The cropped encoded waveform, containing only the entries that satisfy 
        the specified amplitude and/or index thresholds.
    """

    if crop_amp is not None:
        encoded_waveform = [entry for entry in encoded_waveform if abs(entry[1]) >= crop_amp]

    if crop_indx is not None:
        encoded_waveform = [entry for entry in encoded_waveform if entry[2] <= crop_indx]

    return encoded_waveform


def plot_encoding(x, sr, encoded_waveform, time_range = None, min_abs_amplitude = 0.1, x_reconstructed = None, show = True, dictionary=None, N_highlights=0, poster=False):
    """
    Plot waveform and encoding scatterplot.

    Parameters:
        x (np.ndarray): The waveform.
        sr (int or float): Sampling rate.
        encoded_waveform (list of tuples): Each tuple is (dictionary_element, amplitude, sample_nbr).
        time_range (tuple): (start_time, end_time) in seconds.
        min_abs_amplitude (float): Minimum absolute amplitude for an encoding event to be included.
    """
    # Time axis for full signal
    time_axis = np.arange(len(x)) / sr
    time_axis = time_axis*1000

    # Unpack time range
    if time_range != None:
        t_start, t_end = time_range
        t_start_ms = t_start*1000
        t_end_ms = t_end*1000

        # Convert time range to sample indices
        s_start = int(t_start * sr)
        s_end = int(t_end * sr)

        # Extract waveform portion
        x_segment = x[s_start:s_end]
        t_segment = time_axis[s_start:s_end]
    else:
        x_segment = x
        s_start = 0
        s_end = len(x)
        t_segment = time_axis
        t_start = time_axis[0]
        t_end = time_axis[-1]
    
    # --- Collect data for scatter (activation) plot ---
    scatter_data = [
        (dict_elem, amp, sample)
        for dict_elem, amp, sample in encoded_waveform
        if (t_start <= sample / sr <= t_end) and (abs(amp) >= min_abs_amplitude)
    ]
    # Quick hack to always get all atoms (nice for plotting).
    for i in range(0,32):
        scatter_data.append((i, 0, -1000)) # atom i, amplitude 0, time at -1000

    # ---- Set up the plots ---
    if poster:
        fig, axs = plt.subplots(2, 1, figsize=(15, 7.5), sharex=True)
        label_fontsize = 24
        tick_fontsize = 20
        title_fontsize = 28
        legend_fontsize = 18
    else: # two-col paper
        fig, axs = plt.subplots(2, 1, figsize=(3.5, 2.0), sharex=True)  # width ~1 column
        label_fontsize = 10
        tick_fontsize = 8
        title_fontsize = 12
        legend_fontsize = 8        
        
    # --- Plot 1: Waveform --
    # (1) Add some highlights. These are not labelled but show contribution of individual kernels.
    highlights=[]
    if N_highlights>0: 
        # Sort by absolute amplitude (descending)
        sorted_data = sorted(scatter_data, key=lambda x: abs(x[1]), reverse=True)
        # Collect up to N_higlights highlights with unique dict_elems
        highlights = []
        seen = set()
        for dict_elem, amp, sample in sorted_data:
            if dict_elem not in seen:
                highlights.append((dict_elem, amp, sample))
                seen.add(dict_elem)
                seen.add(dict_elem+1)
                seen.add(dict_elem+2)
            if len(highlights) == N_highlights:
                break
    
    # (2) Add the plot of the original data
    sns.lineplot(x=t_segment, y=x_segment, ax=axs[0], label="original")
    
    # (3) Add the plot of the reconstructed waveform
    if x_reconstructed is not None:
        try:
            sns.lineplot(x=t_segment, y=x_reconstructed[s_start:s_end], ax=axs[0], label="reconstructed")
            axs[0].legend(fontsize=legend_fontsize)
        except:
            print("Warning in mp_utils.plot_encoding. The code does not yet support cutting off the encoding")
      
    # (4) Add the plot of the highlights (highlight = (dic_elem, amp, sample)
    for highlight in highlights:
        kernel_ax = highlight[1]*dictionary[highlight[0]].kernel
        time_ax = np.arange(0, len(kernel_ax))/sr + highlight[2]/sr
        time_ax = time_ax*1000
        print(time_ax[0])
        print(kernel_ax)
        sns.lineplot(x=time_ax, y=kernel_ax, ax=axs[0], color="green")
    
    # (5) Other stuff
    axs[0].set_ylabel("Amplitude", fontsize=label_fontsize)
    axs[0].grid(which="major", axis="both", linestyle="--", alpha=0.6)
    axs[0].tick_params(axis='both', which='major', labelsize=tick_fontsize)
    #axs[0].set_title("Selected Waveform Segment")


    # --- Plot 2: Scatterplot of encoding ---
    # scatter data was made before - scatter_data=[(dict_elem, amp, sample)] in range of amplitudes and time;
    if scatter_data:
        dict_elems, amps, samples = zip(*scatter_data)
        times = np.array(samples) / sr * 1000
        sizes = np.abs(amps) * 50  # scale for visibility
        ###
        if dictionary:
            centroid_freqs = [dictionary[elem].centroid_frequency for elem in dict_elems]
            sns.scatterplot(
                x=times,
                y=centroid_freqs,
                size=sizes,
                hue=centroid_freqs,  # or another identifier
                ax=axs[1],
                palette="deep",
                sizes=(100, 500),
                legend=False
            )
            axs[1].set_yscale("log")     # make y-axis logarithmic
            yticks = [500, 1000, 2000, 4000]
            #yticks = np.round(centroid_freqs)
            axs[1].set_yticks(yticks)
            axs[1].set_yticklabels([str(y) for y in yticks])
            # Enable grid for both axes
            axs[1].grid(which="major", axis="both", linestyle="--", alpha=0.6)
            axs[1].tick_params(axis='both', which='major', labelsize=tick_fontsize)
            axs[1].set_ylabel("Centr. freq. [Hz]", fontsize=label_fontsize)
            axs[1].grid(True)
        else:
            # Map dictionary elements to unique atom numbers
            unique_atoms = {name: i for i, name in enumerate(sorted(set(dict_elems)))}
            atom_ids = [unique_atoms[name] for name in dict_elems]

            sns.scatterplot(
                x=times,
                y=atom_ids,
                size=sizes,
                hue=dict_elems,
                ax=axs[1],
                legend=False,
                palette="deep",
                sizes=(20, 200)
            )
            axs[1].set_ylabel("Auditory kernel #", fontsize=label_fontsize)
            axs[1].set_yticks(list(unique_atoms.values()))
            axs[1].set_yticklabels(list(unique_atoms.keys()))

        
        #axs[1].set_title("Encoding Events Scatterplot")
    else:
        axs[1].text(0.5, 0.5, "No events in selected range", ha='center', va='center')
        #axs[1].set_title("Encoding Events Scatterplot")

    axs[1].set_xlim(t_start_ms, t_end_ms)
    axs[1].set_xlabel("Time (ms)", fontsize=label_fontsize)
    plt.tight_layout()
    
    if show:
        plt.show()


def read_encoded_waveform_from_jld2(filepath):
    """
    Reads an encoded waveform from a JLD2 file and returns the encoded waveform and residual.

    Parameters:
        filepath (str): Path to the JLD2 file.

    Returns:
        tuple: A tuple containing:
            - encoded_waveform (list): A list of tuples (dicElement, ampMax, indxMax).
            - x_res (numpy.ndarray): The residual waveform.
    """

    def load_dataset_or_dereference(f, dataset_name):
        """Load dataset and automatically dereference if needed."""
        dataset = f[dataset_name][:]
        
        if isinstance(dataset.flat[0], h5py.Reference):
            # It's a list of references: dereference each one
            return [f[ref][()] for ref in dataset]
        else:
            # It's direct values: just return the dataset
            return dataset
        
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"File not found: {filepath}")

    with h5py.File(filepath, "r") as f:
        kernel_list = load_dataset_or_dereference(f, "kernel_list")
        amp_list = load_dataset_or_dereference(f, "amp_list")
        index_list = load_dataset_or_dereference(f, "index_list")
        x_res = load_dataset_or_dereference(f, "x_res")

        # Construct the encoded waveform
        encoded_waveform = []
        for dicElement, ampMax, indxMax in zip(kernel_list, amp_list, index_list):
            encoded_waveform.append((int(dicElement-1), float(ampMax), int(indxMax-1))) # Python is 0-indexed, so we subtract 1 from indxMax

    return encoded_waveform, np.squeeze(x_res)
    
    
# --- Extra functions for explainer ---

# Construct a dictionary. Takes kernels as input
def create_dictionary(*kernels):
    dictionary = []
    for i, kernel in enumerate(kernels):
        gradient = np.zeros_like(kernel) # Outdated (for python code)
        abs_amp = 0.0 # Outdated (for python code)
        dictionary.append(Kernel(kernel))
    return dictionary


def plot_dictionary_elements(dictionary, sampling_rate=None):
    fig, axes = plt.subplots(4, 8, figsize=(12, 6))
    plt.subplots_adjust(wspace=0.3, hspace=0.3)
    
    for i, ax in enumerate(axes.flat):
        if i < len(dictionary):
            kernel = dictionary[i].kernel
            ax.plot(kernel)
            
            # Add some text indicating the length of the kernel
            kernel_length = len(kernel)
            if sampling_rate:
                kernel_length = kernel_length/sampling_rate*1000
                ax.text(0.5, 0.9, f"{kernel_length} ms", fontsize=8, color='red', transform=ax.transAxes)
            else:
                ax.text(0.5, 0.9, f"{kernel_length} samples", fontsize=8, color='red', transform=ax.transAxes)
            
        ax.axis('off')  # Remove axis labels and ticks
    
    plt.tight_layout()
    plt.show()


# Construct simple example waveform
def get_simple_waveform(slct=1):
    if slct == 1:
        x = np.zeros(400)

        # The square
        x[30:60] = 1 

        # The sawtooth
        t = np.linspace(0,1,80) 
        x[120:200] = -0.9*signal.sawtooth(0.5*np.pi * t + 0.5*np.pi, 0.5)

        # The sinusoid
        x[300:380] = 1.3*np.sin(10*np.pi*t)
        
    elif slct == 2:
        x = np.zeros(400)

        # The square
        x[30:60] = 0.2 

        # The sawtooth
        t = np.linspace(0,1,80) 
        x[120:200] = -0.9*signal.sawtooth(0.5*np.pi * t + 0.5*np.pi, 0.5)

        # The sinusoid
        x[300:380] = 1.3*np.sin(10*np.pi*t)
        
    elif slct == 3:
        x = np.zeros(500)

        # The square
        x[30:60] = 0.7

        # The sawtooth
        t = np.linspace(0,1,80) 
        x[120:200] = -0.9*signal.sawtooth(0.5*np.pi * t + 0.5*np.pi, 0.5)

        # The sinusoid
        x[300:380] = 1.3*np.sin(10*np.pi*t)
    
        # Extra square 
        x[400:430] = 1
    else:
        print("Selected invalid waveform. Choose from 1 to 3")
    
    return x


# Plotting functions
def plot_simple_dictionary_and_waveform(dictionary_element_1, dictionary_element_2, dictionary_element_3, x):
    # Plot the elements
    fig = plt.figure(figsize=(5, 3))
    gs = fig.add_gridspec(2, 3, height_ratios=[1, 1.2])

    # Top row (3 plots side-by-side)
    ax1 = fig.add_subplot(gs[0, 0])
    ax2 = fig.add_subplot(gs[0, 1], sharey=ax1)
    ax3 = fig.add_subplot(gs[0, 2], sharey=ax1)

    ax1.plot(dictionary_element_1)
    ax2.plot(dictionary_element_2)
    ax3.plot(dictionary_element_3)

    ax1.set_title("Element 1")
    ax2.set_title("Element 2")
    ax3.set_title("Element 3")
    
    # Bottom row (Single plot spanning all columns)
    ax4 = fig.add_subplot(gs[1, :])
    ax4.plot(x)
    ax4.set_title("The waveform (plotted again for comparison)")

    plt.tight_layout()
    plt.show()


def plot_correlations(corr1, corr2, corr3, x, dict_elem1, dict_elem2, dict_elem3, highlighted_positions):
    fig = plt.figure(figsize=(8, 6))
    gs = fig.add_gridspec(4, 2, width_ratios=[5, 1], height_ratios=[1, 1, 1, 1])
    
    # Plotting the waveform at the bottom spanning the full width of the left column
    ax4 = fig.add_subplot(gs[3, 0])
    ax4.plot(x)
    ax4.set_ylabel('Waveform')
    ax4.grid(True)
    ax4.set_xlabel('Index')
    
    # Plotting the correlations with shared x-axis (corr1, corr2, corr3)
    ax1 = fig.add_subplot(gs[0, 0], sharex=ax4)
    ax1.plot(corr1)
    ax1.tick_params('x', labelbottom=False)
    ax1.set_ylim([-10, 10])
    ax1.set_title('Cross-correlations between waveform and dictionary elements')
    ax1.set_ylabel('Elem. 1')
    ax1.grid(True)
    
    ax2 = fig.add_subplot(gs[1, 0], sharex=ax4)
    ax2.plot(corr2)
    ax2.tick_params('x', labelbottom=False)
    ax2.set_ylim([-10, 10])
    ax2.set_ylabel('Elem. 2')
    ax2.grid(True)

    ax3 = fig.add_subplot(gs[2, 0], sharex=ax4)
    ax3.plot(corr3)
    ax3.tick_params('x', labelbottom=False)
    ax3.set_ylim([-10, 10])
    ax3.set_ylabel('Elem. 3')
    ax3.grid(True)

    # Plotting dictionary elements in the right column (small subplots)
    ax1_dict = fig.add_subplot(gs[0, 1])
    ax1_dict.plot(dict_elem1)
    ax1_dict.set_xticks([])
    
    ax2_dict = fig.add_subplot(gs[1, 1])
    ax2_dict.plot(dict_elem2)
    ax2_dict.set_xticks([])
    
    ax3_dict = fig.add_subplot(gs[2, 1])
    ax3_dict.plot(dict_elem3)
    ax3_dict.set_xticks([])

    for ax in [ax1, ax2, ax3, ax4]:
        for pos in highlighted_positions:
            ax.axvline(x=pos, color='red', linestyle='--', linewidth=1)

    plt.tight_layout()
    plt.show()
    
    
def plot_mp_iters(original, res0, res1, res2, res3, res4, dic1, dic2, dic3, dic4, dictionary):
    fig = plt.figure(figsize=(8, 6))
    gs = fig.add_gridspec(5, 2, width_ratios=[5, 1], height_ratios=[1, 1, 1, 1, 1])
    
    # Plotting the waveform at the bottom spanning the full width of the left column
    ax5 = fig.add_subplot(gs[4, 0])
    ax5.plot(original, alpha=0.3)
    ax5.plot(res4)
    ax5.set_ylabel('Res. 4')
    ax5.set_ylim([-1.5, 1.5])
    ax5.grid(True)
    ax5.set_xlabel('Index')
    
    ax1 = fig.add_subplot(gs[0, 0], sharex=ax5)
    ax1.plot(original, alpha=0.3)
    ax1.plot(res0)
    ax1.tick_params('x', labelbottom=False)
    ax1.set_title('Iterations of matching pursuit')
    ax1.set_ylabel('Res. 0')
    ax1.set_ylim([-1.5, 1.5])
    ax1.grid(True)
    
    ax2 = fig.add_subplot(gs[1, 0], sharex=ax5)
    ax2.plot(original, alpha=0.3)
    ax2.plot(res1)
    ax2.tick_params('x', labelbottom=False)
    ax2.set_ylabel('Res. 1')
    ax2.set_ylim([-1.5, 1.5])
    ax2.grid(True)
    
    ax3 = fig.add_subplot(gs[2, 0], sharex=ax5)
    ax3.plot(original, alpha=0.3)
    ax3.plot(res2)
    ax3.tick_params('x', labelbottom=False)
    ax3.set_ylabel('Res. 2')
    ax3.set_ylim([-1.5, 1.5])
    ax3.grid(True)
    
    ax4 = fig.add_subplot(gs[3, 0], sharex=ax5)
    ax4.plot(original, alpha=0.3)
    ax4.plot(res3)
    ax4.tick_params('x', labelbottom=False)
    ax4.set_ylabel('Res. 3')
    ax4.set_ylim([-1.5, 1.5])
    ax4.grid(True)

    ax7 = fig.add_subplot(gs[0, 1])
    ax7.plot(dictionary[dic1].kernel)
    ax7.tick_params('x', labelbottom=False)

    ax8 = fig.add_subplot(gs[1, 1])
    ax8.plot(dictionary[dic2].kernel)
    ax8.tick_params('x', labelbottom=False)
    
    ax9 = fig.add_subplot(gs[2, 1])
    ax9.plot(dictionary[dic3].kernel)
    ax9.tick_params('x', labelbottom=False)
    
    ax10 = fig.add_subplot(gs[3, 1])
    ax10.plot(dictionary[dic4].kernel)
    ax10.tick_params('x', labelbottom=False)
    
    plt.tight_layout()
    plt.show()
     
    
def simple_method_to_encode_an_decode_waveform(waveform, dictionary_element_1, dictionary_element_2, dictionary_element_3, length):
    corr_1 = correlation(waveform, dictionary_element_1)
    corr_2 = correlation(waveform, dictionary_element_2)
    corr_3 = correlation(waveform, dictionary_element_3)
    
    indxMax_1 = np.argmax(abs(corr_1))
    ampMax_1 = corr_1[indxMax_1]

    indxMax_2 = np.argmax(abs(corr_2))
    ampMax_2 = corr_2[indxMax_2]

    indxMax_3 = np.argmax(abs(corr_3))
    ampMax_3 = corr_3[indxMax_3]

    rec_waveform = np.zeros(length)
    
    rec_waveform[indxMax_1:indxMax_1+len(dictionary_element_1)] += ampMax_1*dictionary_element_1
    rec_waveform[indxMax_2:indxMax_2+len(dictionary_element_2)] += ampMax_2*dictionary_element_2
    rec_waveform[indxMax_3:indxMax_3+len(dictionary_element_3)] += ampMax_3*dictionary_element_3
    return rec_waveform
    
    
def create_dictionary_from_mat(filepath):
    """
    Create a dictionary from a .mat file containing kernels in a struct H.
    Parameters:
        filepath (str): Path to the .mat file.

    Returns:
        list: A list of Kernel objects representing the kernels in the .mat file.

    Can be used to load the kernels I got from Lewicki ("Kernels_TIMIT.mat")
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"File not found: {filepath}")


    # Load the .mat file
    mat_data = loadmat(filepath)

    if "H" not in mat_data:
        raise ValueError("The .mat file does not contain the required struct H with field Phi.")

    # Extract kernels from H.Phi
    H = mat_data["H"]
  
    Phi = H["Phi"][0, 0]  # Access the Phi field of the struct H
    L = H["L"][0, 0]  # Extract the number of relevant entries

    dictionary = []
    for i in range(Phi.shape[1]):  # Iterate over columns of Phi
        kernel_data = Phi[:, i].flatten()  # Extract and flatten the kernel
        kernel_data = kernel_data[:int(L[:,i])]  # Keep only the first L entries
        
        kernel_data = kernel_data / np.linalg.norm(kernel_data)  # Normalize the kernel
        gradient = np.zeros_like(kernel_data)
        abs_amp = 0.0
        dictionary.append(Kernel(kernel_data, gradient, abs_amp))

    return dictionary
