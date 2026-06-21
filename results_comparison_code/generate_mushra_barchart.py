import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
import numpy as np

df = pd.read_csv('../mushra_results_anonymized.csv')

df_models = df[df['rating_stimulus'] != 'reference'].copy()

label_map = {
    'Opt_32': 'Optimized 32',
    'Opt_64_dropout': 'Dropout-only 64',
    'Opt_128': 'Optimized 128',
    'Opt_256': 'Optimized 256',
}
df_models['label'] = df_models['rating_stimulus'].map(label_map)

model_order = ['Optimized 32', 'Dropout-only 64', 'Optimized 128', 'Optimized 256']

means = df_models.groupby('label')['rating_score'].mean()
stds = df_models.groupby('label')['rating_score'].std()
means = means.reindex(model_order)
stds = stds.reindex(model_order)

fig, ax = plt.subplots(figsize=(8, 5))

colors = ['#4C72B0', '#55A868', '#C44E52', '#8172B2']
bars = ax.bar(model_order, means, yerr=stds, capsize=6, color=colors,
              edgecolor='black', linewidth=0.8, width=0.6, zorder=3)

for bar, mean in zip(bars, means):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + stds.max() + 1.5,
            f'{mean:.1f}', ha='center', va='bottom', fontsize=13, fontweight='bold')

ax.axhspan(20, 40, alpha=0.08, color='red', zorder=1)
ax.text(3.55, 21, '"Poor"\nquality\nrange', fontsize=9, color='#888888',
        ha='right', va='bottom', style='italic')

ax.set_ylabel('MUSHRA Score (0–100)', fontsize=13)
ax.set_title('No perceptual quality difference between dictionary sizes\nat matched bit rate (23.4 kbps, n=30)',
             fontsize=14, fontweight='bold', pad=12)
ax.set_ylim(0, 75)
ax.set_xticklabels(model_order, fontsize=11)
ax.yaxis.set_tick_params(labelsize=11)
ax.grid(axis='y', alpha=0.3, zorder=0)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

plt.tight_layout()
plt.savefig('../result_plots/mushra_barchart.png', dpi=300, bbox_inches='tight')
print('Saved: ../result_plots/mushra_barchart.png')
