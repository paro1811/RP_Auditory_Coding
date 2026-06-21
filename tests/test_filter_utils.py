""" 
    Test functions in filter utils. At the moment, the following functions have been tested.

        filter_utils.estimate_fir_spectral_spread_and_centroid_frequency
"""

import matplotlib.pyplot as plt
import numpy as np
from utils_python import mp_utils as mp 
from utils_python import filter_utils as fu


def test_load_kernels(filepath, sorting="centroid_frequency"):
    dictionary = mp.create_dictionary_from_JLD2(filepath, sorting = sorting)
    mp.plot_dictionary_elements(dictionary, show=False)
    return dictionary[::-1]


def test_ss_and_centroid(dictionary, dictionary_ref=None, plotting=False):
    features = ["centroid", "spread", "skewness", "kurtosis", "entropy"]
    centroid = []
    spread = []
    skewness = []
    kurtosis = []
    entropy = []
    for k in dictionary:
        results = fu.estimate_fir_params(k.kernel, fs = 16000, plotting = plotting, features=features)
        centroid.append(results["centroid"])
        spread.append(results["spread"])
        skewness.append(results["skewness"])
        kurtosis.append(results["kurtosis"])
        entropy.append(results["entropy"])


    if dictionary_ref:
        centroid_ref = []
        spread_ref = []
        skewness_ref = []
        kurtosis_ref = []
        entropy_ref = []
        for k in dictionary_ref:
            if np.linalg.norm(k.kernel) > 0.001:
                results = fu.estimate_fir_params(k.kernel, fs = 16000, plotting = False, features=features)
                centroid_ref.append(results["centroid"])
                spread_ref.append(results["spread"])
                skewness_ref.append(results["skewness"])
                kurtosis_ref.append(results["kurtosis"])
                entropy_ref.append(results["entropy"])

    # Plot centroid vs spread
    plt.figure()
    plt.scatter(centroid, spread, label='Dictionary', alpha=0.7)
    if dictionary_ref:
        plt.scatter(centroid_ref, spread_ref, color='black', label='Reference Dictionary (noisy)', alpha=0.7, s=10)
    plt.xscale('log')
    plt.yscale('log')
    plt.xlabel('Centroid Frequency (log scale)')
    plt.ylabel('Spectral Spread (log scale)')
    plt.title('Centroid Frequency vs Spectral Spread')
    plt.grid(True, which="both", ls="--", linewidth=0.5)
    plt.legend()

    plt.figure()
    plt.scatter(centroid, kurtosis, label='Dictionary', alpha=0.7)
    if dictionary_ref:
        plt.scatter(centroid_ref, kurtosis_ref, color='black', label='Reference Dictionary (noisy)', alpha=0.7, s=10)
    plt.xscale('log')
    plt.xlabel('Centroid Frequency (log scale)')
    plt.ylabel('Spectral Kurtosis')
    plt.title('Centroid Frequency vs Spectral Kurtosis')
    plt.grid(True, which="both", ls="--", linewidth=0.5)
    plt.legend()

    plt.figure()
    plt.scatter(centroid, entropy, label='Dictionary', alpha=0.7)
    if dictionary_ref:
        plt.scatter(centroid_ref, entropy_ref, color='black', label='Reference Dictionary (noisy)', alpha=0.7, s=10)
    plt.xscale('log')
    plt.xlabel('Centroid Frequency (log scale)')
    plt.ylabel('Spectral Entropy')
    plt.title('Centroid Frequency vs Spectral Entropy')
    plt.grid(True, which="both", ls="--", linewidth=0.5)
    plt.legend()
    plt.show()


# Test loading a dictionary of kernels
dictionary_path = "tests/data/kernels_TIMIT.jld2"
dictionary = test_load_kernels(dictionary_path)

# Load reference dictionary with noisy kernels (measured from cat ears)
dictionary_path_ref = "tests/data/kernels_carney.jld2"
dictionary_ref = test_load_kernels(dictionary_path_ref)

test_ss_and_centroid(dictionary,  plotting=False) # plotting=True to see individual filter plots

test_ss_and_centroid(dictionary, dictionary_ref)
