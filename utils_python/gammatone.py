import numpy as np
import scipy.signal as signal


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
        w, h = signal.freqz(self.kernel, worN = max(len(self.kernel), 2048), fs=fs)  # w in Hz
        mag_db = 20 * np.log10(np.maximum(abs(h), 1e-10))
        peak_idx = np.argmax(mag_db)
        center_freq = w[peak_idx]
        return center_freq


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


