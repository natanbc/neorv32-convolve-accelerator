#include <cmath>
#include <cstdint>
#include <iostream>
#include "top.cpp"

const int8_t  matrix1[9] = {1, 0, -1, 2, 0, -2, 1, 0, -1};
const int8_t  matrix2[9] = {-1, -2 , -1, 0, 0, 0, 1, 2, 1};
const uint8_t pixels1[9] = {0, 0, 0, 0, 0xff, 0xff, 0, 0xff, 0xff};
const uint8_t pixels2[9] = {183, 112, 37, 166, 159, 64, 250, 96, 186};
const uint8_t pixels3[9] = {35, 224, 27, 192, 189, 58, 167, 235, 175};

template<size_t i, typename T>
static void setb(value<72>& v, const T vals[9]) {
    v.slice<8*(i+1) - 1, 8*i>() = value<8> { static_cast<uint8_t>(vals[i]) };
}

template<typename T>
static void set_arr(value<72>& v, const T vals[9]) {
    setb<0>(v, vals);
    setb<1>(v, vals);
    setb<2>(v, vals);
    setb<3>(v, vals);
    setb<4>(v, vals);
    setb<5>(v, vals);
    setb<6>(v, vals);
    setb<7>(v, vals);
    setb<8>(v, vals);
}

uint32_t cycles = 0;
static void clock(cxxrtl_design::TOP& top) {
    cycles++;
    top.p_clk.set(true);
    top.step();
    top.p_clk.set(false);
    top.step();
}

static int32_t conv(const uint8_t pixels[9], const int8_t matrix[9]) {
    int32_t res = 0;
    for(size_t i = 0; i < 9; i++) {
        res += matrix[i] * pixels[i];
    }
    return res;
}

template<typename T>
static bool check_out(const char* name, T expected, T actual) {
    std::cout << name << std::endl;
    std::cout << "Output:   " << std::hex << actual << std::endl;
    std::cout << "Expected: " << std::hex << expected << std::endl;

    if(actual != expected) {
        std::cout << "FAIL: output did not match" << std::endl;
        return false;
    }
    return true;
}

static int test(cxxrtl_design::TOP& top, const uint8_t pixels[9]) {
    int32_t expected_conv1 = conv(pixels, matrix1);
    int32_t expected_conv2 = conv(pixels, matrix2);
    int16_t expected_pixel = std::sqrt(expected_conv1 * expected_conv1 + expected_conv2 * expected_conv2);

    set_arr(top.p_input__matrix1, matrix1);
    set_arr(top.p_input__matrix2, matrix2);
    set_arr(top.p_input__pixels, pixels);

    top.p_input__start.set(true);
    clock(top);
    top.p_input__start.set(false);

    uint32_t start = cycles;
    for(int i = 0; i < 40; i++) {
        clock(top);
        std::cout << "[cycle " << std::dec << cycles << "]:";
        std::cout << " conv1 = " << std::hex << top.p_output__conv1.get<uint32_t>();
        std::cout << " conv2 = " << std::hex << top.p_output__conv2.get<uint32_t>();
        std::cout << " pixel = " << std::hex << top.p_output__pixel.get<uint32_t>();
        std::cout << std::endl;
        if(top.p_output__done.get<bool>()) {
            std::cout << "Done in " << std::dec << cycles - start << " cycles" << std::endl;
            break;
        }
    }

    if(!top.p_output__done.get<bool>()) {
        std::cout << "FAIL: did not finish in a reasonable amount of time" << std::endl;
        return 1;
    }

    bool ok = true;
    ok &= check_out("conv1", (uint32_t)expected_conv1, top.p_output__conv1.get<uint32_t>());
    ok &= check_out("conv2", (uint32_t)expected_conv2, top.p_output__conv2.get<uint32_t>());
    ok &= check_out("pixel", (uint32_t)expected_pixel, top.p_output__pixel.get<uint32_t>());
    if(!ok) {
        for(int i = 0; i < 20; i++) {
            clock(top);
            std::cout << "[cycle " << std::dec << cycles << "]:";
            std::cout << " conv1 = " << std::hex << top.p_output__conv1.get<uint32_t>();
            std::cout << " conv2 = " << std::hex << top.p_output__conv2.get<uint32_t>();
            std::cout << " pixel = " << std::hex << top.p_output__pixel.get<uint32_t>();
            std::cout << std::endl;
        }
        return 1;
    }
    return 0;
}

int main() {
    cxxrtl_design::TOP top;
    top.step();
    top.p_rst.set(false);
    top.step();
    top.p_rst.set(true);
    top.step();

    int r;
    if((r = test(top, pixels1)) != 0) return r;
    if((r = test(top, pixels2)) != 0) return r;
    if((r = test(top, pixels3)) != 0) return r;

}

