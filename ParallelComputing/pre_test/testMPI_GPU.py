import sys
import time
import numpy as np
import pyopencl as cl
import matplotlib.pyplot as plt
from numba import njit, prange

SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
MAX_ITER = 500

WIDTH, HEIGHT = SIZE, SIZE
N = WIDTH * HEIGHT

print("=" * 65)
print(f" BENCHMARK: Julia Set ({WIDTH}x{HEIGHT}) - CPU NumPy vs Numba Parallel vs GPU")
print("=" * 65)

# Complex constants for Julia set
c_real, c_imag = np.float32(-0.7), np.float32(0.27015)

# ---------------------------------------------------------
# --- 1. CPU VECTORIZED (NumPy) ---
# ---------------------------------------------------------
print("\n[1/3] Computing on CPU (NumPy Vectorized)...")
start_cpu = time.time()

x = np.linspace(-1.5, 1.5, WIDTH, dtype=np.float32)
y = np.linspace(-1.5, 1.5, HEIGHT, dtype=np.float32)
zx, zy = np.meshgrid(x, y)
zx = zx.ravel()
zy = zy.ravel()

cpu_output = np.zeros(N, dtype=np.int32)

for i in range(MAX_ITER):
    mask = (zx * zx + zy * zy) < 4.0
    cpu_output[mask] += 1
    new_zx = zx * zx - zy * zy + c_real
    zy = 2.0 * zx * zy + c_imag
    zx = new_zx

cpu_time = time.time() - start_cpu
print(f"  NumPy CPU Time : {cpu_time:.4f} seconds")


# ---------------------------------------------------------
# --- 2. CPU MULTI-CORE PARALLEL (NUMBA JIT) ---
# ---------------------------------------------------------
@njit(parallel=True, fastmath=True)
def julia_numba_parallel(width, height, max_iter, c_re, c_im):
    output = np.empty((height, width), dtype=np.int32)
    
    for y_idx in prange(height):
        zy_init = -1.5 + (3.0 * y_idx) / height
        for x_idx in range(width):
            zx = -1.5 + (3.0 * x_idx) / width
            zy = zy_init
            
            iter_count = 0
            while (zx * zx + zy * zy) < 4.0 and iter_count < max_iter:
                tmp = zx * zx - zy * zy + c_re
                zy = 2.0 * zx * zy + c_im
                zx = tmp
                iter_count += 1
                
            output[y_idx, x_idx] = iter_count
            
    return output

print("\n[2/3] Computing on CPU Parallel (Numba JIT)...")

# Warm-up run to exclude JIT compilation time from the benchmark
_ = julia_numba_parallel(10, 10, 10, c_real, c_imag)

start_numba = time.time()
numba_output = julia_numba_parallel(WIDTH, HEIGHT, MAX_ITER, c_real, c_imag).ravel()
numba_time = time.time() - start_numba
print(f"  Numba Parallel Time : {numba_time:.4f} seconds")


# ---------------------------------------------------------
# --- 3. GPU EXECUTION (OpenCL / GT 730) ---
# ---------------------------------------------------------
print("\n[3/3] Computing on GPU (GT 730 / OpenCL)...")
try:
    ctx = cl.create_some_context(interactive=False)
    queue = cl.CommandQueue(ctx)
    mf = cl.mem_flags

    res_g = cl.Buffer(ctx, mf.WRITE_ONLY, N * 4)

    kernel_code = """
    __kernel void julia_set(
        const int width,
        const int height,
        const int max_iter,
        const float c_re,
        const float c_im,
        __global int *output)
    {
        int gid = get_global_id(0);
        int x_idx = gid % width;
        int y_idx = gid / width;

        if (gid >= width * height) return;

        float zx = -1.5f + (3.0f * x_idx) / (float)width;
        float zy = -1.5f + (3.0f * y_idx) / (float)height;

        int iter = 0;
        while ((zx * zx + zy * zy) < 4.0f && iter < max_iter) {
            float tmp = zx * zx - zy * zy + c_re;
            zy = 2.0f * zx * zy + c_im;
            zx = tmp;
            iter++;
        }

        output[gid] = iter;
    }
    """

    program = cl.Program(ctx, kernel_code).build()
    
    start_gpu = time.time()
    program.julia_set(
        queue, 
        (N,), 
        None, 
        np.int32(WIDTH), 
        np.int32(HEIGHT), 
        np.int32(MAX_ITER), 
        c_real, 
        c_imag, 
        res_g
    )

    gpu_output = np.empty(N, dtype=np.int32)
    cl.enqueue_copy(queue, gpu_output, res_g)

    gpu_time = time.time() - start_gpu
    gpu_success = True
    print(f"  GPU Time        : {gpu_time:.4f} seconds")

except Exception as e:
    gpu_success = False
    gpu_time = 0.0
    print(f"  OpenCL Error    : {e}")


# ---------------------------------------------------------
# --- RESULTS SUMMARY TABLE ---
# ---------------------------------------------------------
print("\n" + "=" * 65)
print(" BENCHMARK COMPARISON SUMMARY")
print("=" * 65)
print(f" NumPy CPU (Single Thread) : {cpu_time:.4f} s  (1.00x Baseline)")
print(f" Numba Multi-Core CPU      : {numba_time:.4f} s  ({cpu_time / numba_time:.2f}x faster vs NumPy)")

if gpu_success:
    print(f" GPU (OpenCL / GT 730)     : {gpu_time:.4f} s  ({cpu_time / gpu_time:.2f}x faster vs Single-CPU)")
    print(f"                           : ({numba_time / gpu_time:.2f}x speed difference vs Numba)")
print("=" * 65)


# ---------------------------------------------------------
# --- 4. PLOT AND SAVE FRACTAL IMAGE WITH COMPARISON OVERLAY ---
# ---------------------------------------------------------
print("\nGenerating fractal plot with benchmarking overlaid...")

# Select best matrix available
fractal_matrix = (
    gpu_output.reshape((HEIGHT, WIDTH)) if gpu_success 
    else numba_output.reshape((HEIGHT, WIDTH))
)

fig, ax = plt.subplots(figsize=(12, 10))

# Plot fractal image
img = ax.imshow(fractal_matrix, cmap='twilight_shifted', extent=[-1.5, 1.5, -1.5, 1.5])
fig.colorbar(img, ax=ax, label='Iteration Count', fraction=0.046, pad=0.04)

# Add reference center lines across the axis
ax.axhline(0, color='white', linestyle='--', linewidth=0.8, alpha=0.5)
ax.axvline(0, color='white', linestyle='--', linewidth=0.8, alpha=0.5)

# Build the benchmark comparison text overlay
speedup_numba = cpu_time / numba_time
stats_text = (
    f"PERFORMANCE COMPARISON ({WIDTH}x{HEIGHT})\n"
    f"─────────────────────────────\n"
    f"• NumPy CPU     : {cpu_time:.4f}s  (1.0x)\n"
    f"• Numba 4-Core  : {numba_time:.4f}s  ({speedup_numba:.1f}x faster)\n"
)

if gpu_success:
    speedup_gpu = cpu_time / gpu_time
    vs_numba = numba_time / gpu_time
    stats_text += (
        f"• OpenCL GPU    : {gpu_time:.4f}s  ({speedup_gpu:.1f}x faster)\n"
        f"─────────────────────────────\n"
        f"GPU vs Numba    : {vs_numba:.2f}x speedup"
    )

# Draw text box inside the image (top-left corner)
ax.text(
    0.03, 0.96, stats_text, 
    transform=ax.transAxes, 
    fontsize=10, 
    fontfamily='monospace',
    verticalalignment='top',
    bbox=dict(boxstyle='round,pad=0.6', facecolor='black', alpha=0.75, edgecolor='cyan', lw=1.5),
    color='white'
)

# Plot labels
ax.set_title(f"Julia Set Fractal Benchmark ({WIDTH}x{HEIGHT})", fontsize=14, fontweight='bold', pad=12)
ax.set_xlabel("Re(c)")
ax.set_ylabel("Im(c)")

output_file = "julia_fractal_benchmark.png"
plt.savefig(output_file, bbox_inches='tight', dpi=300)
print(f"Image saved successfully as '{output_file}'!")

try:
    plt.show()
except Exception:
    pass
