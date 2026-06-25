# Research Project: Scaling Auditory Kernel Dictionaries: The Sparsity-Fidelity Trade-off in Speech Reconstruction

This repository supports the [Bachelor Research Project](https://github.com/TU-Delft-CSE/Research-Project?tab=readme-ov-file) titled
**"Scaling Auditory Kernel Dictionaries: The Sparsity-Fidelity Trade-off in Speech Reconstruction"** at TU Delft (2026).

It investigates how scaling auditory kernel dictionaries beyond the 32-kernel baseline of Smith and Lewicki (2006) impacts the trade-off between coding sparsity and reconstruction fidelity in human speech, using Matching Pursuit with learned dictionaries of 32, 64, 128, and 256 kernels.

## Project Overview

**Goal:** Determine the optimal dictionary size for sparse auditory coding of speech using Matching Pursuit with learned kernels.

**Approach:**
- Train auditory kernel dictionaries (32, 64, 128, 256 kernels) on the TIMIT speech corpus
- Apply regularisation strategies: kernel dropout, adaptive stopping conditions, decaying step-size schedules
- Evaluate using rate-fidelity curves (SRR vs. kernel activations per second)
- Compare learned kernels to cat auditory nerve revcor filters for biological resemblance
- Analyse spectral coverage and pairwise redundancy across dictionary sizes
- Conduct a MUSHRA listening test (n=30) and PESQ evaluation at matched bit rates

**Key Finding:** The optimised 128-kernel dictionary achieves a 3.6 dB SRR improvement over baselines, while further scaling to 256 kernels yields no improvement due to spectral imbalance and greedy selection limitations.

## Repository Structure

### Core Training and Encoding

| File / Folder | Description |
|---|---|
| `kernel_learning.jl` | Main training script for learning auditory kernels via gradient ascent |
| `utils_julia/mp_utils.jl` | Matching Pursuit implementation, kernel I/O, and related utilities |
| `utils_julia/train_utils.jl` | Training helper functions |
| `utils_julia/filter_utils.jl` | Signal filtering utilities |
| `utils_julia/Par_measure.jl` | Auditory distortion measure (port of Van de Par et al.) |
| `utils_python/` | Python implementations of matching pursuit and utilities |
| `MPenvironment/` | Julia project environment (dependencies) |
| `training/` | Dataset construction and training shell scripts |

### Results and Analysis Scripts

All scripts for generating paper figures and computing evaluation metrics are in `results_comparison_code/`:

| File | Description |
|---|---|
| `generate_paper_plots.jl` | Generates the two main results figures: hero rate-fidelity plot and 128-kernel comparison |
| `generate_appendix_ratefidelity.jl` | Generates appendix rate-fidelity comparisons for 32, 64, and 256 kernels |
| `generate_revcor_comparison.jl` | Generates revcor overlay plots (top 20 kernels vs. cat auditory nerve fibres) |
| `generate_rq3_analysis.jl` | Generates spectral coverage and pairwise redundancy plots |
| `generate_mushra_barchart.py` | Generates MUSHRA listening test bar chart |
| `compute_pesq.py` | Computes PESQ scores (wideband and narrowband) for reconstructed audio |
| `reconstruct_audio.jl` | Reconstructs TIMIT test set audio using trained dictionaries |
| `create_hybrid.jl` | Creates the hybrid 256-kernel dictionary (128 pretrained + 128 Gaussian) |
| `generate_timit_tsv.py` | Generates TSV file listing TIMIT test set audio paths |
| `check_active_copy.jl` | Checks kernel activity across dictionaries |

### Trained Model Results

| Folder | Description |
|---|---|
| `ResultsTIMIT_Baseline_*` | Baseline models (32, 64, 128, 256 kernels), 6 epochs, θ=0.1 |
| `ResultsTIMIT_Optimized_Ng*` | Optimised models with dropout + adaptive stopping + step decay |
| `ResultsTIMIT_Optimized_Ng*_dropout_only` | Dropout-only ablation models (64, 128 kernels) |
| `ResultsTIMIT_Optimized_Ng*_revcor` | Revcor-trained models with relaxed trimming |
| `ResultsTIMIT_Hybrid_*` | Hybrid 256-kernel experiment |
| `result_plots/` | All generated figures used in the paper |


## Setup

### Requirements

- **Julia 1.11+** with the environment defined in `MPenvironment/`
- **Python 3.8+** for PESQ computation and MUSHRA plotting

### Activating the Julia Environment

```bash
julia --project=MPenvironment
```
```julia
using Pkg
Pkg.instantiate()
```

### Training Kernels

```bash
julia --threads 8 kernel_learning.jl TIMIT TIMIT_train.tsv --logpath training_log.tsv --Ng 128 --max_epochs 8
```

See the options section below for the full list of training parameters.

### Generating Paper Figures

```bash
cd results_comparison_code
julia generate_paper_plots.jl
julia generate_rq3_analysis.jl
julia generate_revcor_comparison.jl
julia generate_appendix_ratefidelity.jl
python3 generate_mushra_barchart.py
```

## Training Options

The training script `kernel_learning.jl` accepts the following key arguments:

| Argument | Default | Description |
|---|---|---|
| `--Ng` | 32 | Number of kernels in the dictionary |
| `--step_size` | 0.0025 | Base gradient step size |
| `--mp_stop_cond` | 0.05 | Matching Pursuit stopping threshold |
| `--max_epochs` | 6 | Maximum number of training epochs |
| `--max_train_iterations` | 100000 | Maximum iterations per epoch |
| `--kernel_dropout` | 0 | Number of kernels to drop per MP pass |
| `--init_length` | 100 | Initial kernel length in samples |
| `--storage_frequency` | 500 | Save kernels every N iterations |
| `-c` / `--continue_count` | 0 | Resume from a previous iteration |

Epoch-level schedules can be set via `--stepsize_schedule`, `--kernel_dropout_schedule`, and `--exp_threshold_schedule`.

## Reproducibility

- All models were trained on the TIMIT acoustic-phonetic corpus (16 kHz)
- Training configurations for all model variants are listed in Table A.II of the thesis
- The MUSHRA listening test was conducted in compliance with TU Delft HREC protocols
- Anonymised listening test data is available on the 4TU.ResearchData repository

## Contact
**Prarthana Badiger**

TU Delft – Bachelor Research Project

email: P.S.Badiger@student.tudelft.nl
