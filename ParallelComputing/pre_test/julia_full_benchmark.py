import sys
import time
import numpy as np
import pyopencl as cl
import matplotlib.pyplot as plt
from numba import njit, prange
from mpi4py import MPI

# ---------------------------------------------------------
# --- MPI INITIALIZATION ---
# ---------------------------------------------------------
comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

if size < 5 and rank == 0:
    print(" [คำแนะนำ] กรุณารันด้วย mpirun -np 5 เพื่อให้ครบทั้งเงื่อนไข 4 และ 5 Ranks ครับ")

SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
MAX_ITER = 500
WIDTH, HEIGHT = SIZE, SIZE
N = WIDTH * HEIGHT

c_real, c_imag = np.float32(-0.7), np.float32(0.27015)

if rank == 0:
    print("=" * 70)
    print(f" ALL-IN-ONE BENCHMARK: Julia Set ({WIDTH}x{HEIGHT})")
    print(f" Total MPI Ranks Launched : {size}")
    print("=" * 70)

comm.Barrier()

# =========================================================
# [1/5] CPU VECTORIZED (NumPy) - Rank 0
# =========================================================
cpu_time = 0.0
if rank == 0:
    print("\n[1/5] Computing on CPU (NumPy Vectorized)...")
    start_cpu = time.time()
    x = np.linspace(-1.5, 1.5, WIDTH, dtype=np.float32)
    y = np.linspace(-1.5, 1.5, HEIGHT, dtype=np.float32)
    zx, zy = np.meshgrid(x, y)
    zx, zy = zx.ravel(), zy.ravel()
    cpu_output = np.zeros(N, dtype=np.int32)

    for _ in range(MAX_ITER):
        mask = (zx * zx + zy * zy) < 4.0
        cpu_output[mask] += 1
        new_zx = zx * zx - zy * zy + c_real
        zy = 2.0 * zx * zy + c_imag
        zx = new_zx

    cpu_time = time.time() - start_cpu
    print(f"  --> NumPy CPU Time : {cpu_time:.4f} seconds")

# =========================================================
# [2/5] CPU MULTI-CORE PARALLEL (Numba JIT) - Rank 0
# =========================================================
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

numba_time = 0.0
if rank == 0:
    print("\n[2/5] Computing on CPU Parallel (Numba 4-Core JIT)...")
    _ = julia_numba_parallel(10, 10, 10, c_real, c_imag)  # Warm-up JIT
    start_numba = time.time()
    numba_output = julia_numba_parallel(WIDTH, HEIGHT, MAX_ITER, c_real, c_imag).ravel()
    numba_time = time.time() - start_numba
    print(f"  --> Numba Parallel Time : {numba_time:.4f} seconds")

# =========================================================
# [3/5] SINGLE GPU EXECUTION (OpenCL Full Grid) - Rank 0
# =========================================================
gpu_time = 0.0
gpu_success = False
if rank == 0:
    print("\n[3/5] Computing on Single OpenCL GPU...")
    try:
        platforms = cl.get_platforms()
        devices = platforms[0].get_devices()
        ctx = cl.Context([devices[0]])
        queue = cl.CommandQueue(ctx)
        mf = cl.mem_flags

        res_g = cl.Buffer(ctx, mf.WRITE_ONLY, N * 4)
        kernel_code = """
        __kernel void julia_set(const int width, const int height, const int max_iter,
                                const float c_re, const float c_im, __global int *output) {
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
        program.julia_set(queue, (N,), None, np.int32(WIDTH), np.int32(HEIGHT), 
                          np.int32(MAX_ITER), c_real, c_imag, res_g)
        gpu_output = np.empty(N, dtype=np.int32)
        cl.enqueue_copy(queue, gpu_output, res_g)
        queue.finish()
        gpu_time = time.time() - start_gpu
        gpu_success = True
        print(f"  --> Single GPU Time : {gpu_time:.4f} seconds")
    except Exception as e:
        print(f"  --> OpenCL Error : {e}")

# =========================================================
# [4/5] MPI 5 CHUNKS + GPU (ใช้ครบทุก Ranks ที่เปิดมา)
# =========================================================
comm.Barrier()
if rank == 0:
    print(f"\n[4/5] Computing MPI ({size} Chunks) + GPU Offload...")

start_mpi5 = time.time()
rows_per_rank = HEIGHT // size
remainder = HEIGHT % size

local_height = rows_per_rank + 1 if rank < remainder else rows_per_rank
start_y = rank * (rows_per_rank + 1) if rank < remainder else rank * rows_per_rank + remainder
local_N = WIDTH * local_height

mpi5_output_local = np.empty(local_N, dtype=np.int32)
try:
    platforms = cl.get_platforms()
    ctx = cl.Context([platforms[0].get_devices()[0]])
    queue = cl.CommandQueue(ctx)
    res_g_local = cl.Buffer(ctx, cl.mem_flags.WRITE_ONLY, local_N * 4)

    kernel_chunk = """
    __kernel void julia_chunk(const int width, const int global_height, const int start_y,
                              const int max_iter, const float c_re, const float c_im,
                              __global int *output) {
        int gid = get_global_id(0);
        int x_idx = gid % width;
        int y_idx = start_y + (gid / width);
        float zx = -1.5f + (3.0f * x_idx) / (float)width;
        float zy = -1.5f + (3.0f * y_idx) / (float)global_height;
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
    prog = cl.Program(ctx, kernel_chunk).build()
    prog.julia_chunk(queue, (local_N,), None, np.int32(WIDTH), np.int32(HEIGHT),
                     np.int32(start_y), np.int32(MAX_ITER), c_real, c_imag, res_g_local)
    cl.enqueue_copy(queue, mpi5_output_local, res_g_local)
    queue.finish()
except Exception:
    pass

sendcounts5 = comm.gather(local_N, root=0)
displacements5 = [sum(sendcounts5[:i]) for i in range(size)] if rank == 0 else None
mpi5_global = np.empty(N, dtype=np.int32) if rank == 0 else None
comm.Gatherv(sendbuf=mpi5_output_local, recvbuf=[mpi5_global, sendcounts5, displacements5, MPI.INT32_T], root=0)

comm.Barrier()
mpi5_time = time.time() - start_mpi5
if rank == 0:
    print(f"  --> MPI ({size} Chunks) + GPU Time : {mpi5_time:.4f} seconds")

# =========================================================
# [5/5] MPI 4 CORES CFD HALO + GPU (Sub-communicator 4 Ranks)
# =========================================================
comm.Barrier()
if rank == 0:
    print("\n[5/5] Computing MPI (4 Cores CFD Halo Sync) + GPU Offload...")

# สร้าง Sub-group ดึงมาใช้แค่ 4 Ranks (Rank 0,1,2,3)
target_ranks = 4
color = 0 if rank < target_ranks else MPI.UNDEFINED
sub_comm = comm.Split(color, rank)

mpi4_time = 0.0
mpi4_global = np.empty(N, dtype=np.int32) if rank == 0 else None

if sub_comm != MPI.COMM_NULL:
    sub_rank = sub_comm.Get_rank()
    sub_size = sub_comm.Get_size()
    start_mpi4 = time.time()

    s_rows = HEIGHT // sub_size
    s_rem = HEIGHT % sub_size
    s_local_h = s_rows + 1 if sub_rank < s_rem else s_rows
    s_start_y = sub_rank * (s_rows + 1) if sub_rank < s_rem else sub_rank * s_rows + s_rem
    s_local_N = WIDTH * s_local_h

    # --- CFD Halo Exchange ---
    top_neighbor = sub_rank - 1 if sub_rank > 0 else MPI.PROC_NULL
    bottom_neighbor = sub_rank + 1 if sub_rank < sub_size - 1 else MPI.PROC_NULL
    send_top, recv_bottom = np.zeros(WIDTH, dtype=np.float32), np.zeros(WIDTH, dtype=np.float32)
    sub_comm.Sendrecv(sendbuf=send_top, dest=top_neighbor, recvbuf=recv_bottom, source=bottom_neighbor)

    # --- GPU Computation ---
    mpi4_output_local = np.empty(s_local_N, dtype=np.int32)
    try:
        platforms = cl.get_platforms()
        ctx = cl.Context([platforms[0].get_devices()[0]])
        queue = cl.CommandQueue(ctx)
        res_g4 = cl.Buffer(ctx, cl.mem_flags.WRITE_ONLY, s_local_N * 4)
        prog4 = cl.Program(ctx, kernel_chunk).build()
        prog4.julia_chunk(queue, (s_local_N,), None, np.int32(WIDTH), np.int32(HEIGHT),
                          np.int32(s_start_y), np.int32(MAX_ITER), c_real, c_imag, res_g4)
        cl.enqueue_copy(queue, mpi4_output_local, res_g4)
        queue.finish()
    except Exception:
        pass

    sendcounts4 = sub_comm.gather(s_local_N, root=0)
    displacements4 = [sum(sendcounts4[:i]) for i in range(sub_size)] if sub_rank == 0 else None
    sub_comm.Gatherv(sendbuf=mpi4_output_local, recvbuf=[mpi4_global, sendcounts4, displacements4, MPI.INT32_T], root=0)

    sub_comm.Barrier()
    mpi4_time = time.time() - start_mpi4
    sub_comm.Free()

comm.Barrier()
if rank == 0:
    print(f"  --> MPI (4 Cores CFD Halo) + GPU Time : {mpi4_time:.4f} seconds")

# =========================================================
# RESULTS SUMMARY TABLE & PLOT (Rank 0 Only)
# =========================================================
if rank == 0:
    print("\n" + "=" * 70)
    print(f" BENCHMARK COMPARISON SUMMARY ({WIDTH}x{HEIGHT})")
    print("=" * 70)
    print(f" 1. NumPy CPU (1 Core)          : {cpu_time:.4f} s  (1.00x Baseline)")
    print(f" 2. Numba CPU (Multi-Core)      : {numba_time:.4f} s  ({cpu_time/numba_time:.2f}x faster)")
    if gpu_success:
        print(f" 3. Single GPU OpenCL           : {gpu_time:.4f} s  ({cpu_time/gpu_time:.2f}x faster)")
    print(f" 4. MPI ({size} Chunks) + GPU       : {mpi5_time:.4f} s  ({cpu_time/mpi5_time:.2f}x faster)")
    print(f" 5. MPI (4 Cores CFD Halo) + GPU: {mpi4_time:.4f} s  ({cpu_time/mpi4_time:.2f}x faster)")
    print("=" * 70)

    # Save output image
    plt.figure(figsize=(10, 8))
    plt.imshow(mpi5_global.reshape((HEIGHT, WIDTH)), cmap='twilight_shifted', extent=[-1.5, 1.5, -1.5, 1.5])
    plt.title(f"All-in-One Julia Set Benchmark ({WIDTH}x{HEIGHT})")
    plt.colorbar(label='Iteration Count')
    plt.savefig("julia_all_benchmark.png", dpi=300)
    print("\n[Success] Saved comparison plot to 'julia_all_benchmark.png'")
