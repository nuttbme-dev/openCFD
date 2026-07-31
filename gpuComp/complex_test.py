import sys
import time
import numpy as np
import pyopencl as cl
import matplotlib.pyplot as plt

# Default resolution: 2000 x 2000
SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
MAX_ITER = 500

WIDTH, HEIGHT = SIZE, SIZE
N = WIDTH * HEIGHT

print("=" * 60)
print(f" COMPUTE BENCHMARK: Julia Set Fractal ({WIDTH}x{HEIGHT})")
print("=" * 60)

# Complex constants for Julia set
c_real, c_imag = np.float32(-0.7), np.float32(0.27015)

# --- 1. CPU EXECUTION ---
print("\n[1/2] Computing on CPU...")
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
print(f" CPU Time : {cpu_time:.4f} seconds")

# --- 2. GPU EXECUTION ---
print("\n[2/2] Computing on GPU (GT 730 / OpenCL)...")
try:
    ctx = cl.create_some_context(interactive=False)
    queue = cl.CommandQueue(ctx)
    mf = cl.mem_flags

    start_gpu = time.time()

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
    print(f" GPU Time : {gpu_time:.4f} seconds")

except Exception as e:
    gpu_success = False
    print(f" OpenCL Error: {e}")

# --- RESULTS SUMMARY ---
print("\n" + "=" * 60)
if gpu_success:
    speedup = cpu_time / gpu_time
    print(f" 🚀 GPU Speedup: {speedup:.2f}x FASTER than CPU!")
print("=" * 60)

# --- PLOT AND SAVE FRACTAL IMAGE ---
print("\nGenerating fractal plot...")
fractal_matrix = gpu_output.reshape((HEIGHT, WIDTH)) if gpu_success else cpu_output.reshape((HEIGHT, WIDTH))

plt.figure(figsize=(10, 10))
plt.imshow(fractal_matrix, cmap='twilight_shifted', extent=[-1.5, 1.5, -1.5, 1.5])
plt.colorbar(label='Iteration Count')
plt.title(f"Julia Set Fractal ({WIDTH}x{HEIGHT})\nGPU Time: {gpu_time:.4f}s vs CPU Time: {cpu_time:.4f}s")
plt.axis('off')

# Save to file
output_file = "julia_fractal.png"
plt.savefig(output_file, bbox_inches='tight', dpi=300)
print(f" Image saved successfully as '{output_file}'!")

# Display on screen (if GUI is available)
try:
    plt.show()
except Exception:
    pass
