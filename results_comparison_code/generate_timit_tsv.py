import os

timit_root = "/Users/pbadiger/Downloads/TIMIT16kHz/TEST"
output_file = "../TIMIT_test_local_rp.tsv"

with open(output_file, "w") as f:
    f.write("path_wav\tsegments\n")

    for root, dirs, files in os.walk(timit_root):
        dirs.sort()   
        files.sort()   

        for file in files:
            if file.lower().endswith(".wav"):
                wav_path = os.path.join(root, file)

                phn_path = wav_path.replace(".WAV", ".PHN").replace(".wav", ".PHN")

                if not os.path.exists(phn_path):
                    print("Missing PHN:", phn_path)
                    continue

                with open(phn_path, "r") as phn_file:
                    lines = phn_file.readlines()

                    non_silence = [
                        line.strip().split()
                        for line in lines
                        if "h#" not in line
                    ]

                    if len(non_silence) == 0:
                        continue

                    start = int(non_silence[0][0])
                    end = int(non_silence[-1][1])

                    segment_str = f'"[{{""start"": {start}, ""end"": {end}}}]"'

                    f.write(f"{wav_path}\t{segment_str}\n")

print("Done! TSV file created:", output_file)