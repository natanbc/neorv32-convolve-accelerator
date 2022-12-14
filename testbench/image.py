import argparse
import ctypes
import imageio
import numpy as np
import scipy.signal
import struct

parser = argparse.ArgumentParser()
parser.add_argument("image", help="Which image to work on")
parser.add_argument("which", help="Which image to generate (reference, cxxrtl-serial, cxxrtl-parallel) or 'check' to verify if they match")
parser.add_argument("mode", help="Which mode should the results of the two convolutions be merged with (sum_abs, sqrt, bor, avg)")
args = parser.parse_args()

which = args.which
image_name = args.image
mode = args.mode

mode_native_values = {
    "sum_abs": 0,
    "sqrt":    1,
    "bor":     2,
    "avg":     3,
}

if which not in ["reference", "cxxrtl-serial", "cxxrtl-parallel", "check"]:
    raise Exception("Invalid task '{}'".format(which))
if mode not in mode_native_values.keys():
    raise Exception("Invalid mode '{}'".format(mode))

vertical_kernel = np.array([
    [1, 0, -1],
    [2, 0, -2],
    [1, 0, -1],
]).astype(np.int8)
horizontal_kernel = np.array([
    [-1, -2, -1],
    [ 0,  0,  0],
    [ 1,  2,  1],
]).astype(np.int8)

def reference(img):
    out1 = -scipy.signal.convolve2d(img, vertical_kernel, mode="same").astype(np.int32)
    out2 = -scipy.signal.convolve2d(img, horizontal_kernel, mode="same").astype(np.int32)

    if mode == "sum_abs":
        res = (np.abs(out1) + np.abs(out2)) / 4
    elif mode == "sqrt":
        res = np.sqrt(np.square(out1) + np.square(out2)) / 4
    elif mode == "bor":
        res = np.bitwise_or(out1, out2) / 4
    elif mode == "avg":
        res = (out1 + out2) / 2 / 4
    else:
        raise Exception("unreachable")
    res = res.astype(np.uint8)

    return res

def cxxrtl(img, lib):
    height, width = img.shape

    dll = ctypes.CDLL(lib)

    pixel_buffer = ctypes.create_string_buffer(bytes([x & 0xFF for x in img.ravel()]))
    img_buffer = ctypes.create_string_buffer(4 * height * width)
    conv1_buffer = ctypes.create_string_buffer(4 * height * width)
    conv2_buffer = ctypes.create_string_buffer(4 * height * width)
    kernel1_buffer = ctypes.create_string_buffer(bytes([x & 0xFF for x in vertical_kernel.ravel()]))
    kernel2_buffer = ctypes.create_string_buffer(bytes([x & 0xFF for x in horizontal_kernel.ravel()]))

    dll.sim_apply(
        img_buffer,           conv1_buffer,          conv2_buffer,
        kernel1_buffer,       kernel2_buffer,        pixel_buffer,
        ctypes.c_uint(width), ctypes.c_uint(height), ctypes.c_ubyte(mode_native_values[mode]),
    )

    out1 = np.array([struct.unpack("={}i".format(width*height), conv1_buffer.raw)]).reshape(height, width).astype(np.uint8)
    out2 = np.array([struct.unpack("={}i".format(width*height), conv2_buffer.raw)]).reshape(height, width).astype(np.uint8)

    res = np.array([struct.unpack("={}i".format(width*height), img_buffer.raw)]).reshape(height, width).astype(np.uint8)

    return res

reference_name = "build/{}-{}-reference.png".format(image_name, mode)
cxxrtl_serial_name = "build/{}-{}-cxxrtl-serial.png".format(image_name, mode)
cxxrtl_parallel_name = "build/{}-{}-cxxrtl-parallel.png".format(image_name, mode)


img = imageio.imread("testbench/{}.png".format(image_name))[:, :, 0].astype(np.uint8)
if which == "reference":
    imageio.imwrite(reference_name, reference(img))
elif which == "cxxrtl-serial":
    imageio.imwrite(cxxrtl_serial_name, cxxrtl(img, "build/testbench-ffi-serial.so"))
elif which == "cxxrtl-parallel":
    imageio.imwrite(cxxrtl_parallel_name, cxxrtl(img, "build/testbench-ffi-parallel.so"))
elif which == "check":
    ref = imageio.imread(reference_name)
    serial = imageio.imread(cxxrtl_serial_name)
    parallel = imageio.imread(cxxrtl_parallel_name)

    ok = True
    if not np.allclose(ref, serial):
        print("{} Serial differs".format(str([image_name, mode])))
        ok = False
    if not np.allclose(ref, parallel):
        print("{} Parallel differs".format(str([image_name, mode])))
        ok = False
    if not ok:
        exit(1)
else:
    raise Exception("Unknown type '{}'".format(which))
