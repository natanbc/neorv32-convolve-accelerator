#include <cstdint>
#include <iostream>
#include "top.cpp"

const int8_t  matrix[9] = {1, 0, -1, 2, 0, -2, 1, 0, -1};
const uint8_t pixels[9] = {10, 20, 30, 40, 50, 60, 70, 80, 90};

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

int main() {
    cxxrtl_design::TOP top;
    top.step();
    top.p_rst.set(false);
    top.step();
    top.p_rst.set(true);
    top.step();


    int32_t expected_out = 0;
    for(size_t i = 0; i < 9; i++) {
        expected_out += matrix[i] * pixels[i];
    }

    set_arr(top.p_input__matrix, matrix);
    set_arr(top.p_input__pixels, pixels);

    top.p_input__start.set(true);
    clock(top);
    cycles--; //ignore the start cycle, since it's the write to the CFS register;
              //other cycles are the real time until the value is available
    top.p_input__start.set(false);

    for(int i = 0; i < 3; i++) {
        clock(top);
        std::cout << "[cycle " << std::dec << i << "]: out = " << std::hex << top.p_output__pixel.get<uint32_t>() << std::endl;
        if(top.p_output__done.get<bool>()) {
            std::cout << "Done in " << cycles << " cycles" << std::endl;
            break;
        }
    }

    if(!top.p_output__done.get<bool>()) {
        std::cout << "FAIL: did not finish in a reasonable amount of time" << std::endl;
        return 1;
    }

    const auto out = top.p_output__pixel.get<uint32_t>();
    std::cout << "Output:   " << std::hex << out << std::endl;
    std::cout << "Expected: " << std::hex << expected_out << std::endl;

    if(out != expected_out) {
        std::cout << "FAIL: output did not match" << std::endl;
        return 1;
    }
}

