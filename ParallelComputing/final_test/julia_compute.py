import sys
import time
import gc
import numpy as np
import pyopencl as cl
from numba import njit, prange
from mpi4py import MPI

# ---------------------------------------------------------
# --- MPI INITIALIZATION ---
# ---------------------------------------------------------
comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
MAX_ITER = 500
WIDTH, HEIGHT = SIZE, SIZE
c_real, c_imag = np.float32(-0.7), np.float32(0.27015)
TILE_SIZE = 512

if size < 2:
    if rank == 0:
        print("[Error] Dynamic Master-Worker requires at least 2 MPI Ranks.")
    sys.exit(0)

# =========================================================
# --- [1] BASELINE BENCHMARKS (Rank 0 Only) ---
# =========================================================
numba_time = 0.0
gpu_time = 0.0

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

if rank == 0:
    print("=" * 70)
    print(f" 🚀 PURE COMPUTE BENCHMARK: Julia Set ({WIDTH}x{HEIGHT})")
    print(f" Total MPI Ranks : {size} (Rank 0 = Master, Ranks 1..{size-1} = Workers)")
    print("=" * 70)

    # 1. Numba CPU Multi-Core
    print("\n[1/3] Computing Numba CPU Multi-Core...")
    _ = julia_numba_parallel(10, 10, 10, c_real, c_imag)
    start_n = time.time()
    numba_out = julia_numba_parallel(WIDTH, HEIGHT, MAX_ITER, c_real, c_imag)
    numba_time = time.time() - start_n
    print(f"  --> Numba Time : {numba_time:.4f} s")
    del numba_out
    gc.collect()

    # 2. Single GPU OpenCL
    print("\n[2/3] Computing Single OpenCL GPU...")
    try:
        platforms = cl.get_platforms()
        ctx = cl.Context([platforms[0].get_devices()[0]])
        queue = cl.CommandQueue(ctx)
        N = WIDTH * HEIGHT
        res_g = cl.Buffer(ctx, cl.mem_flags.WRITE_ONLY, N * 4)

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
        start_g = time.time()
        program.julia_set(queue, (N,), None, np.int32(WIDTH), np.int32(HEIGHT),
                          np.int32(MAX_ITER), c_real, c_imag, res_g)
        queue.finish()
        gpu_time = time.time() - start_g
        res_g.release()
        print(f"  --> Single GPU Time : {gpu_time:.4f} s")
    except Exception as e:
        print(f"  --> OpenCL Error: {e}")

comm.Barrier()

# =========================================================
# --- [2] DYNAMIC MASTER-WORKER ENGINE ---
# =========================================================
TAG_WORK = 1
TAG_RESULT = 2
TAG_STOP = 3

if rank == 0:
    print("\n[3/3] Computing Dynamic Master-Worker Queue...")
    start_dyn = time.time()

    tiles = []
    for y in range(0, HEIGHT, TILE_SIZE):
        for x in range(0, WIDTH, TILE_SIZE):
            w = min(TILE_SIZE, WIDTH - x)
            h = min(TILE_SIZE, HEIGHT - y)
            tiles.append((x, y, w, h))

    num_tiles = len(tiles)
    final_image = np.zeros((HEIGHT, WIDTH), dtype=np.int32)
    
    active_workers = size - 1
    tile_idx = 0

    for w_rank in range(1, size):
        if tile_idx < num_tiles:
            comm.send(tiles[tile_idx], dest=w_rank, tag=TAG_WORK)
            tile_idx += 1
        else:
            comm.send(None, dest=w_rank, tag=TAG_STOP)
            active_workers -= 1

    status = MPI.Status()
    while active_workers > 0:
        result_data = comm.recv(source=MPI.ANY_SOURCE, tag=TAG_RESULT, status=status)
        worker_id = status.Get_source()

        x, y, w, h, tile_matrix = result_data
        final_image[y:y+h, x:x+w] = tile_matrix

        if tile_idx < num_tiles:
            comm.send(tiles[tile_idx], dest=worker_id, tag=TAG_WORK)
            tile_idx += 1
        else:
            comm.send(None, dest=worker_id, tag=TAG_STOP)
            active_workers -= 1

    dynamic_time = time.time() - start_dyn
    print(f"  --> Dynamic Master-Worker Time : {dynamic_time:.4f} s")

else:
    # WORKER LOGIC
    platforms = cl.get_platforms()
    ctx = cl.Context([platforms[0].get_devices()[0]])
    queue = cl.CommandQueue(ctx)

    kernel_tile = """
    __kernel void julia_tile(const int start_x, const int start_y, 
                             const int width, const int height,
                             const int global_w, const int global_h,
                             const int max_iter, const float c_re, const float c_im,
                             __global int *output) {
        int local_x = get_global_id(0);
        int local_y = get_global_id(1);
        if (local_x >= width || local_y >= height) return;

        int global_x_idx = start_x + local_x;
        int global_y_idx = start_y + local_y;

        float zx = -1.5f + (3.0f * global_x_idx) / (float)global_w;
        float zy = -1.5f + (3.0f * global_y_idx) / (float)global_h;
        int iter = 0;
        while ((zx * zx + zy * zy) < 4.0f && iter < max_iter) {
            float tmp = zx * zx - zy * zy + c_re;
            zy = 2.0f * zx * zy + c_im;
            zx = tmp;
            iter++;
        }
        output[local_y * width + local_x] = iter;
    }
    """
    prog = cl.Program(ctx, kernel_tile).build()
    knl = cl.Kernel(prog, "julia_tile")

    while True:
        status = MPI.Status()
        work_item = comm.recv(source=0, tag=MPI.ANY_TAG, status=status)

        if status.Get_tag() == TAG_STOP:
            break

        x, y, w, h = work_item
        tile_N = w * h
        res_buf = cl.Buffer(ctx, cl.mem_flags.WRITE_ONLY, tile_N * 4)

        knl(queue, (w, h), None, 
            np.int32(x), np.int32(y), np.int32(w), np.int32(h),
            np.int32(WIDTH), np.int32(HEIGHT), np.int32(MAX_ITER),
            c_real, c_imag, res_buf)

        tile_res = np.empty((h, w), dtype=np.int32)
        cl.enqueue_copy(queue, tile_res, res_buf)
        queue.finish()
        res_buf.release()

        comm.send((x, y, w, h, tile_res), dest=0, tag=TAG_RESULT)

# =========================================================
# --- [3] SAVE DATA TO DISK (.DAT & .NPY) ---
# =========================================================
if rank == 0:
    print("\n" + "=" * 70)
    print(f" 📊 SAVING BENCHMARK DATA ({WIDTH}x{HEIGHT})")
    print("=" * 70)

    # 1. บันทึกสรุปเวลาเป็นไฟล์ .dat
    with open("benchmark_summary.dat", "w") as f:
        f.write("# BENCHMARK EXECUTION TIME SUMMARY\n")
        f.write(f"Grid_Width\t{WIDTH}\n")
        f.write(f"Grid_Height\t{HEIGHT}\n")
        f.write(f"MPI_Ranks\t{size}\n")
        f.write(f"Numba_CPU_s\t{numba_time:.6f}\n")
        f.write(f"Single_GPU_s\t{gpu_time:.6f}\n")
        f.write(f"Dynamic_Queue_s\t{dynamic_time:.6f}\n")
    print(" [Done] Saved execution metrics to 'benchmark_summary.dat'")

    # 2. บันทึก Matrix ภาพ Julia Set เป็น Binary File (.npy) เล็กและเร็วกว่า
    np.save("julia_matrix.npy", final_image)
    print(" [Done] Saved Matrix data to 'julia_matrix.npy'")
    print("=" * 70)
