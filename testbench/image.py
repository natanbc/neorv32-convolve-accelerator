import argparse
import ctypes
import imageio
import numpy as np
import scipy.signal
import struct

parser = argparse.ArgumentParser()
parser.add_argument("which", help="Which image to generate (reference, cxxrtl-single, cxxrtl-pipelined) or 'check' to verify if they match")
which = parser.parse_args().which

def reference(img):
    out1 = scipy.signal.convolve2d(img, np.array([
        [1, 0, -1],
        [2, 0, -2],
        [1, 0, -1],
    ]), mode="same") / 4
    out2 = scipy.signal.convolve2d(img, np.array([
        [-1, -2, -1],
        [ 0,  0,  0],
        [ 1,  2,  1],
    ]), mode="same") / 4

    res = np.sqrt(np.square(out1) + np.square(out2))
    return res.astype(np.uint8)

def cxxrtl(img, lib):
    height, width = img.shape

    dll = ctypes.CDLL(lib)

    pixel_buffer = ctypes.create_string_buffer(bytes([x & 0xFF for x in img.ravel()]))
    def apply(kernel):
        img_buffer = ctypes.create_string_buffer(height * width * 4)
        kernel_buffer = ctypes.create_string_buffer(bytes([x & 0xFF for x in kernel]))
        dll.sim_apply(img_buffer, kernel_buffer, pixel_buffer, ctypes.c_uint(width), ctypes.c_uint(height))
        return np.array([struct.unpack("={}i".format(width*height), img_buffer.raw)]).reshape(height, width)
    out1 = apply([
        1, 0, -1,
        2, 0, -2,
        1, 0, -1,
    ]) / 4
    out2 = apply([
        -1, -2, -1,
         0,  0,  0,
         1,  2,  1,
    ]) / 4

    res = np.sqrt(np.square(out1) + np.square(out2))
    return res.astype(np.uint8)

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
