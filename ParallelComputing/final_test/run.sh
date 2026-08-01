#!/bin/bash
mpirun --oversubscribe -np 5 python julia_compute.py 8000 && 
python plot_results.py && 
xdg-open julia_final_benchmark_plot.png
