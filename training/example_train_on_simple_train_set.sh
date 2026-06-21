julia --threads 1 kernel_learning.jl SIMPLE training/simple_train_set.tsv \
--Ng 16 \
--apply_filtering false \
--storage_frequency 400 \
--step_size 0.01 \
--exp_threshold 0.01 \
--logpath training_log.tsv \
--max_epochs 4 \
--smooth_gradient 0.7 \
--exp_frequency 50 
