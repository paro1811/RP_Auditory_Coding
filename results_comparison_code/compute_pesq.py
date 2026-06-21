import os
import csv
import numpy as np
import soundfile as sf
from pesq import pesq

audio_dir = os.path.join(os.path.dirname(__file__), "..", "Listening_Test_Audio_devpod")
models = ["Opt_32", "Opt_64_dropout", "Opt_128", "Opt_256"]
output_csv = os.path.join(os.path.dirname(__file__), "..", "result_plots", "pesq_scores.csv")

results = []

for i in range(1, 9):
    folder = os.path.join(audio_dir, "Audio_{}".format(i))
    ref, fs_ref = sf.read(os.path.join(folder, "0_Original.wav"))

    for model in models:
        deg, fs_deg = sf.read(os.path.join(folder, "{}.wav".format(model)))

        min_len = min(len(ref), len(deg))
        r = ref[:min_len].astype(np.float32)
        d = deg[:min_len].astype(np.float32)

        score_wb = pesq(fs_ref, r, d, "wb")
        score_nb = pesq(fs_ref, r, d, "nb")

        results.append({
            "audio_item": "Audio_{}".format(i),
            "model": model,
            "pesq_wb": round(score_wb, 3),
            "pesq_nb": round(score_nb, 3),
        })

        print("{:<15} {:<20} WB={:.3f}  NB={:.3f}".format(
            "Audio_{}".format(i), model, score_wb, score_nb))

with open(output_csv, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["audio_item", "model", "pesq_wb", "pesq_nb"])
    writer.writeheader()
    writer.writerows(results)

print("\nSaved: {}".format(output_csv))

print("\n=== Mean PESQ Scores ===")
for model in models:
    wb = [r["pesq_wb"] for r in results if r["model"] == model]
    nb = [r["pesq_nb"] for r in results if r["model"] == model]
    print("{:<20} WB={:.3f} +/- {:.3f}  NB={:.3f} +/- {:.3f}".format(
        model, np.mean(wb), np.std(wb, ddof=1), np.mean(nb), np.std(nb, ddof=1)))
