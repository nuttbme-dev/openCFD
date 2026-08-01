import sys
import time
import numpy as np
import pyopencl as cl

# 1. ALLOW DYNAMIC MATRIX SIZE VIA COMMAND LINE
# Usage: python3 gpu_test.py [SIZE]  (e.g., python3 gpu_test.py 2000)
if len(sys.argv) > 1:
    SIZE = int(sys.argv[1])
else:
    SIZE = 1000  # Default size: 1000x1000

ROWS, COLS = SIZE, SIZE
N = ROWS * COLS

print("=" * 55)
print(f" MATRIX SIZE: {ROWS} x {COLS} ({N:,} total elements)")
print("=" * 55)

# Generate Random Test Data (float32)
np.random.seed(42)
matrix_a = np.random.rand(ROWS, COLS).astype(np.float32)
matrix_b = np.random.rand(ROWS, COLS).astype(np.float32)

# --- CPU EXECUTION (NumPy) ---
print("\n[1/2] Running CPU computation (NumPy)...")
start_cpu = time.time()
result_cpu = np.sin(matrix_a) * np.cos(matrix_b)
cpu_time = time.time() - start_cpu

# --- GPU EXECUTION (PyOpenCL / Rusticl) ---
print("[2/2] Running GPU computation (Mesa Rusticl OpenCL)...")
try:
    ctx = cl.create_some_context(interactive=False)
    queue = cl.CommandQueue(ctx)
    mf = cl.mem_flags

    start_gpu = time.time()

    # Allocate & copy memory to GPU VRAM
    a_g = cl.Buffer(ctx, mf.READ_ONLY | mf.COPY_HOST_PTR, hostbuf=matrix_a)
    b_g = cl.Buffer(ctx, mf.READ_ONLY | mf.COPY_HOST_PTR, hostbuf=matrix_b)
    res_g = cl.Buffer(ctx, mf.WRITE_ONLY, matrix_a.nbytes)

    # C-like OpenCL Kernel
    kernel_code = """
    __kernel void compute_matrix(
        __global const float *A,
        __global const float *B,
        __global float *C)
    {
        int gid = get_global_id(0);
        C[gid] = sin(A[gid]) * cos(B[gid]);
    }
    """

    program = cl.Program(ctx, kernel_code).build()
    program.compute_matrix(queue, (N,), None, a_g, b_g, res_g)

    result_gpu = np.empty_like(matrix_a)
    cl.enqueue_copy(queue, result_gpu, res_g)

    gpu_time = time.time() - start_gpu
    gpu_success = True

except Exception as e:
    gpu_success = False
    print(f"\nOpenCL Error: {e}")

# --- TIMING COMPARISON & RESULTS ---
print("\n" + "=" * 55)
print(" PERFORMANCE COMPARISON RESULTS")
print("=" * 55)
print(f" CPU Time (NumPy)    : {cpu_time:.6f} seconds")

if gpu_success:
    print(f" GPU Time (PyOpenCL) : {gpu_time:.6f} seconds")
    
    # Check numerical accuracy
    diff = np.abs(result_cpu - result_gpu).max()
    print(f" Max Error Difference: {diff:.2e}")
    print("-" * 55)
    
    if cpu_time > gpu_time:
        speedup = cpu_time / gpu_time
        print(f" RESULT: GPU is {speedup:.2f}x FASTER than CPU")
    else:
        slowdown = gpu_time / cpu_time
        print(f" RESULT: CPU is {slowdown:.2f}x FASTER than GPU")
        print(" (Note: Small sizes suffer from PCIe transfer overhead!)")
print("=" * 55)
