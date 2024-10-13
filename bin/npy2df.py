#!/usr/bin/env python3
import argparse
import pickle
import pandas as pd
import numpy as np
import os
import glob

def load_pickle(file_path):
    with open(file_path, 'rb') as f:
        data = pickle.load(f)
    return data

def npy2df(array, rnames, id, output, write=False):
    df = pd.DataFrame(data=array, columns=['core', 'accessory'], index=rnames)
    df = df.rename_axis("id").reset_index()
    if write:
        df.to_csv(output, sep='\t', index=False)
    return df

def main(pkl_file, npy_file, output):
    pkl = load_pickle(pkl_file)
    npy = np.load(npy_file)
    for i in range(len(pkl[0])):
        steps = len(pkl[1])
        l = range(0, len(npy), steps)
        start = l[i]
        end = l[i] + steps
        print(' '.join([str(start), str(end)]))
        df = npy2df(npy[start:end], pkl[1], pkl[0][i], output, write=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process some files.")
    parser.add_argument('--pkl', type=str, help='Path to pp-sketchlib pickle file')
    parser.add_argument('--npy', type=str, help='Path to pp-sketchlib numpy file')
    parser.add_argument('--output', type=str, help='Path to save output tsv')
    args = parser.parse_args()
    main(args.pkl, args.npy, args.output)
