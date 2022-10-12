import argparse
import ctypes
import imageio
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument("which", help="Which image to generate (reference, cxxrtl-single, cxxrtl-pipelined) or 'check' to verify if they match")
which = parser.parse_args().which

def get(img, y, x):
    if y < 0 or y >= img.shape[0]:
        return 0
    if x < 0 or x >= img.shape[1]:
        return 0
    return img[y, x]

def apply_kernel(img, process_pixels):
    out = np.zeros(img.shape).astype(np.int32)
    for y in range(img.shape[0]):
        for x in range(img.shape[1]):
            pixels = [
                get(img, y - 1, x - 1), get(img, y - 1, x), get(img, y - 1, x + 1),
                get(img, y,     x - 1), get(img, y,     x), get(img, y,     x + 1),
                get(img, y + 1, x - 1), get(img, y + 1, x), get(img, y + 1, x + 1),
            ]
            out[y, x] = process_pixels(pixels)
    return out

def scaffolding(img, load_kernel, process_pixels):
    load_kernel([
        1, 0, -1,
        2, 0, -2,
        1, 0, -1,
    ])
    out1 = apply_kernel(img, process_pixels) / 4
    load_kernel([
        -1, -2, -1,
         0,  0,  0,
         1,  2,  1
    ])
    out2 = apply_kernel(img, process_pixels) / 4
    
    res = np.sqrt(np.square(out1) + np.square(out2))
    return res.astype(np.uint8)

def reference(img):
    kernel = [[]]
    return scaffolding(img, lambda k: kernel.append(k), lambda p: sum(a*b for a,b in zip(kernel[-1], p)))

def cxxrtl(img, lib):
    dll = ctypes.CDLL(lib)
    ptr = dll.sim_new()

    is_done = dll.sim_is_done
    is_done.restype = ctypes.c_bool
    get_out = dll.sim_get_output
    get_out.restype = ctypes.c_int

    def load_kernel(k):
        buffer = ctypes.create_string_buffer(bytes([x & 0xFF for x in k]))
        dll.sim_set_matrix(ptr, buffer)

    def process_pixels(p):
        buffer = ctypes.create_string_buffer(bytes([x & 0xFF for x in p]))
        dll.sim_set_pixels(ptr, buffer)
        dll.sim_set_start(ptr, ctypes.c_bool(True))
        dll.sim_clock(ptr)
        dll.sim_set_start(ptr, ctypes.c_bool(False))
        for i in range(6):
            dll.sim_clock(ptr)
            if is_done(ptr):
                return get_out(ptr)
        raise Exception("Did not finish in time")

    out = scaffolding(img, load_kernel, process_pixels)
    dll.sim_free(ptr)
    return out

img = imageio.imread("testbench/input.png")[:, :, 0].astype(np.uint8)
if which == "reference":
    imageio.imwrite("build/reference.png", reference(img))
elif which == "cxxrtl-single":
    imageio.imwrite("build/cxxrtl-single_cycle.png", cxxrtl(img, "build/testbench-ffi-single_cycle.so"))
elif which == "cxxrtl-pipelined":
    imageio.imwrite("build/cxxrtl-pipelined.png", cxxrtl(img, "build/testbench-ffi-pipelined.so"))
elif which == "check":
    ref = imageio.imread("build/reference.png")
    single = imageio.imread("build/cxxrtl-single_cycle.png")
    pipelined = imageio.imread("build/cxxrtl-pipelined.png")

    ok = True
    if not np.allclose(ref, single):
        print("Single cycle differs")
        ok = False
    if not np.allclose(ref, pipelined):
        print("Pipelined differs")
        ok = False
    if not ok:
        exit(1)
else:
    raise Exception("Unknown type '{}'".format(which))
