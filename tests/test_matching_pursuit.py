'''
This script tests the matching pursuit implementation in mp_utils.py
(1) It loads a dictionary of kernels from a .jld2 file, reads an audio file, performs matching pursuit encoding and reconstruction, and evaluates the results.
(2) It also tests loading an encoding from a .jld2 file and reconstructs the audio.    
'''

import numpy as np
from scipy.io.wavfile import read as wavread
from scipy.io.wavfile import write as wavwrite
import matplotlib.pyplot as plt
from pesq import pesq


from utils_python import mp_utils as mp 

def test_load_kernels(filepath, sorting="centroid_frequency"):
    dictionary = mp.create_dictionary_from_JLD2(filepath, sorting = sorting)
    mp.plot_dictionary_elements(dictionary, show=False)
    return dictionary



flag_speed = True # If true: dont run some parts which take longer (normal matching pursuit)


# Read the WAV file
sample_rate, audio_data = wavread('tests/data/test_audio.wav')
audio_data = audio_data/np.abs(np.max(audio_data))
print(f"The audio takes {len(audio_data)/sample_rate} seconds")


'''
Test loading a dictionary of kernels
'''
dictionary_path = "tests/data/kernels_TIMITopti.jld2"
dictionary = test_load_kernels(dictionary_path)
dictionary_unsrtd = test_load_kernels(dictionary_path, sorting=None)


'''
Test short-time MP; let the code set hop_length, window_length and crop_length; plot a part of the encoding (original+reconstructed)
'''
encoded_waveform_full, residual = mp.short_time_matching_pursuit(dictionary, audio_data.copy(), "abs_amplitude", 0.1) 
reconstructed_waveform = mp.reconstruct(dictionary, encoded_waveform_full, output_length = len(audio_data))  
print("Length of encoding: ", len(encoded_waveform_full))
print("SRR: ", 20*np.log10(np.linalg.norm(audio_data)/np.linalg.norm(residual)) )
print("Objective speech quality: ", pesq(16000, reconstructed_waveform/max(abs(reconstructed_waveform)), audio_data))
wavwrite("tests/output/short_time_mp_og.wav", 16000, reconstructed_waveform)
mp.plot_encoding(audio_data, sample_rate, encoded_waveform_full, 
                 time_range = (1.4, 1.8), min_abs_amplitude = 0.1, 
                 show = False, x_reconstructed=reconstructed_waveform)


'''Test normal MP; Reconstructing the waveform; and plot a part of the encoding (original+reconstructed)
'''
if not flag_speed:
    encoded_waveform_full, residual = mp.matching_pursuit(dictionary, audio_data.copy(), "abs_amplitude", 0.1)
    reconstructed_waveform = mp.reconstruct(dictionary, encoded_waveform_full, output_length = len(audio_data))
    mp.plot_encoding(audio_data, sample_rate, encoded_waveform_full, 
                    time_range = (1.4, 1.8), min_abs_amplitude = 0.1, show = False, 
                    x_reconstructed=reconstructed_waveform)


'''
Also test loading an encoding from a .jld2 file; and plot a part of this encoding
Important: the julia kernels are not sorted, so the indexing is slightly different.
'''
encoded_waveform_full, residual = mp.read_encoded_waveform_from_jld2("tests/output/test_encoding.jld2")
print(len(encoded_waveform_full))
reconstructed_waveform = mp.reconstruct(dictionary_unsrtd, encoded_waveform_full, output_length = len(audio_data))
print(pesq(16000, reconstructed_waveform, audio_data))
wavwrite("tests/output/short_time_mp.wav", 16000, reconstructed_waveform)
mp.plot_encoding(audio_data, sample_rate, encoded_waveform_full, 
                 time_range = (1.4, 1.8), min_abs_amplitude = 0.0001, show = False, 
                 x_reconstructed=reconstructed_waveform)


''' 
here the encoding was made using Par-measure...
Also test loading an encoding from a .jld2 file; and plot a part of this encoding
Important: the julia kernels are not sorted, so the indexing is slightly different.
'''
encoded_waveform_full, residual = mp.read_encoded_waveform_from_jld2("tests/output/test_encoding_par.jld2")
print(len(encoded_waveform_full))
reconstructed_waveform = mp.reconstruct(dictionary_unsrtd, encoded_waveform_full, output_length = len(audio_data))
print(pesq(16000, reconstructed_waveform/max(abs(reconstructed_waveform)), audio_data))
wavwrite("tests/output/short_time_mp_par.wav", 16000, reconstructed_waveform)
mp.plot_encoding(audio_data, sample_rate, encoded_waveform_full, 
                 time_range = (1.4, 1.8), min_abs_amplitude = 0.0001, show = False, 
                 x_reconstructed=reconstructed_waveform)


# show plots
plt.show()



