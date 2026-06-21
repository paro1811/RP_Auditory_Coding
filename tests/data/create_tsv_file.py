import os
import argparse
import csv

"""
input: the path to a folder from which all .wav's should be listed in a .tsv
output: a .tsv file

Example usage:
    python create_tsv_file.py /home/dimme/Documents/Databases/TIMIT16-8kHz/TIMIT16kHz/TRAIN/ TIMIT_train.tsv
"""

def list_wavs_to_tsv(input_folder, output_tsv):
    print("input folder:", input_folder)
    # Recursively get absolute paths of all .wav files in the folder and subfolders
    wav_files = [os.path.abspath(os.path.join(root, file))
                 for root, _, files in os.walk(input_folder)
                 for file in files if file.lower().endswith('.wav')]

    print(f"Found {len(wav_files)} .wav files.")
    # Write the paths to a .tsv file
    with open(output_tsv, mode='w', newline='') as tsv_file:
        writer = csv.writer(tsv_file, delimiter='\t')
        writer.writerow(['path_wav'])  # Header
        for wav in wav_files:
            writer.writerow([wav])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="List all .wav files in a folder and save to a .tsv file.")
    parser.add_argument("input_folder", type=str, help="Path to the input folder containing .wav files.")
    parser.add_argument("output_tsv", type=str, help="Path to the output .tsv file.")
    args = parser.parse_args()

    list_wavs_to_tsv(args.input_folder, args.output_tsv)