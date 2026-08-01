import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

print("=" * 70)
print(" 🎨 PLOTTING BENCHMARK RESULTS & JULIA SET")
print("=" * 70)

# 1. อ่านข้อมูลเวลาจาก benchmark_summary.dat
metrics = {}
with open("benchmark_summary.dat", "r") as f:
    for line in f:
        if line.startswith("#") or not line.strip():
            continue
        key, val = line.strip().split("\t")
        metrics[key] = float(val) if "." in val else int(val)

width = metrics["Grid_Width"]
height = metrics["Grid_Height"]
ranks = metrics["MPI_Ranks"]
numba_t = metrics["Numba_CPU_s"]
gpu_t = metrics["Single_GPU_s"]
dynamic_t = metrics["Dynamic_Queue_s"]

print(f" Dataset Size : {width}x{height}")
print(f" MPI Ranks    : {ranks}")
print(f" Numba CPU    : {numba_t:.4f} s")
print(f" Single GPU   : {gpu_t:.4f} s")
print(f" Dynamic Queue: {dynamic_t:.4f} s")

# 2. อ่าน Matrix Julia Set จาก julia_matrix.npy
final_image = np.load("julia_matrix.npy")

# 3. วาดรูปเปรียบเทียบ Side-by-Side
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))

# --- Graph 1: Bar Chart เปรียบเทียบเวลา ---
labels = ['Numba CPU\n(Multi-Core)', 'Single GPU\n(OpenCL)', f'Dynamic Queue\n(MPI {ranks} Ranks)']
times = [numba_t, gpu_t, dynamic_t]
colors = ['#4c72b0', '#55a868', '#c44e52']

bars = ax1.bar(labels, times, color=colors, width=0.45)
ax1.set_ylabel('Execution Time (Seconds) - Lower is Better', fontsize=11)
ax1.set_title(f'Performance Benchmark ({width}x{height})', fontsize=13, fontweight='bold')
ax1.grid(axis='y', linestyle='--', alpha=0.7)

# แสดงตัวเลขบนหัวเสากราฟ
for bar in bars:
    h = bar.get_height()
    ax1.annotate(f'{h:.3f}s',
                xy=(bar.get_x() + bar.get_width() / 2, h),
                xytext=(0, 4), textcoords="offset points",
                ha='center', va='bottom', fontweight='bold')

# --- Graph 2: Render ภาพ Julia Set ---
im = ax2.imshow(final_image, cmap='twilight_shifted', extent=[-1.5, 1.5, -1.5, 1.5])
ax2.set_title(f'Julia Set High-Res Image ({width}x{height})', fontsize=13, fontweight='bold')
fig.colorbar(im, ax=ax2, label='Iteration Count')

plt.tight_layout()
output_png = "julia_final_benchmark_plot.png"
plt.savefig(output_png, dpi=200)
plt.close('all')

print(f"\n[Success] Generated plot saved cleanly to '{output_png}'\n")
