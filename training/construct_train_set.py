# The idea is to construct a simple training set for the model to learn from. 
#   There are three kernels used to construct the waveforms

import numpy as np
from scipy.io.wavfile import write
import scipy.signal as signal
import matplotlib.pyplot as plt
import pandas as pd
import os


def sawtooth():
    t = np.linspace(0,1,80) 
    x = signal.sawtooth(0.5*np.pi * t + 0.5*np.pi, 0.5)
    x = x - np.mean(x) # Center the signal around zero
    return x/np.linalg.norm(x)


def square():
    x = np.ones(30)
    return x/np.linalg.norm(x)


def sinusoid():    
    t = np.linspace(0,1,80) 
    x = np.sin(10*np.pi*t)
    return x/np.linalg.norm(x)


if __name__ == "__main__":  
    os.makedirs(os.path.join("training", "simple_train_set"), exist_ok=True)

    # Construct the training set
    kernels = [sawtooth(), square(), sinusoid()]
    N_train_set = 2000
    paths = []
    for i in range(N_train_set):
        Nkernels = np.random.randint(1,5)
        Nsamples = np.random.randint(600,1000)
        
        x = np.zeros(1000)
        for _ in range(Nkernels):
            kernel = kernels[np.random.randint(0,3)]
            scale = np.random.uniform(-2.0, 2.0)
            kernel = scale * kernel
            t_shift = np.random.randint(0, Nsamples - 2*len(kernel))
            x[t_shift:t_shift+len(kernel)] += kernel    

        #x = x + 0.002 * np.random.randn(len(x)) # Add some noise
        
        path = os.path.join("training", "simple_train_set", f"train_{i}.wav")
        write(path, 16000, x.astype(np.float32))  
        full_path = os.path.abspath(path)
        paths.append({"path_wav": full_path})

    df = pd.DataFrame(paths)
    df.to_csv(os.path.join("training", "simple_train_set.tsv"), index=False, sep="\t")