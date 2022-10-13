#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include "top.cpp"

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

static inline void clock(cxxrtl_design::TOP& top) {
    top.p_clk.set(true);
    top.step();
    top.p_clk.set(false);
    top.step();
}

static inline uint32_t run_once(cxxrtl_design::TOP& top) {
    top.p_input__start.set(true);
    clock(top);
    top.p_input__start.set(false);
    clock(top);
    for(size_t i = 0; i < 10; i++) {
        if(top.p_output__done.get<bool>()) {
            return top.p_output__pixel.get<uint32_t>();
        }
        clock(top);
    }
    std::cout << "Did not finish in time" << std::endl;
    std::abort();
}

static inline void shift(uint8_t* data, uint8_t next) {
    std::memmove(data, data + 1, 2 * sizeof(*data));
    data[2] = next;
}

extern "C" {
    void sim_apply(int32_t* out, const int8_t* kernel, const uint8_t* image, uint32_t width, uint32_t height) {
        cxxrtl_design::TOP top;

        top.step();
        top.p_rst.set(false);
        top.step();
        top.p_rst.set(true);
        top.step();

        set_arr(top.p_input__matrix, kernel);

        uint8_t pixel_data[9] = {0};
        for(uint32_t y = 0; y < height; y++) {
            std::memset(pixel_data, 0, sizeof(pixel_data));
            if(y > 0) shift(&pixel_data[0], image[width*(y-1)]);
            shift(&pixel_data[3], image[width*(y)]);
            if(y < height - 1) shift(&pixel_data[6], image[width*(y+1)]);
            for(uint32_t x = 0; x < width; x++) {
                if(x < width - 1) {
                    if(y > 0) shift(&pixel_data[0], image[width*(y-1) + x + 1]);
                    shift(&pixel_data[3], image[width*(y) + x + 1]);
                    if(y < height - 1) shift(&pixel_data[6], image[width*(y+1) + x + 1]);
                } else {
                    shift(&pixel_data[0], 0);
                    shift(&pixel_data[3], 0);
                    shift(&pixel_data[6], 0);
                }
                set_arr(top.p_input__pixels, pixel_data);
                out[width*y + x] = run_once(top);
            }
        }
    }
}

