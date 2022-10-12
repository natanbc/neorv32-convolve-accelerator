#include <cstdint>
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

static cxxrtl_design::TOP* T(void* ptr) {
    return static_cast<cxxrtl_design::TOP*>(ptr);
}

extern "C" {
    void* sim_new() {
        auto top = new cxxrtl_design::TOP;
        top->step();
        top->p_rst.set(false);
        top->step();
        top->p_rst.set(true);
        top->step();
        return static_cast<void*>(top);
    }

    void sim_free(void* ptr) {
        delete T(ptr);
    }

    void sim_clock(void* ptr) {
        auto top = T(ptr);
        top->p_clk.set(true);
        top->step();
        top->p_clk.set(false);
        top->step();
    }

    void sim_set_matrix(void* ptr, uint8_t* matrix) {
        set_arr(T(ptr)->p_input__matrix, matrix);
    }
    
    void sim_set_pixels(void* ptr, uint8_t* pixels) {
        set_arr(T(ptr)->p_input__pixels, pixels);
    }

    void sim_set_start(void* ptr, bool value) {
        T(ptr)->p_input__start.set(value);
    }

    bool sim_is_done(void* ptr) {
        return T(ptr)->p_output__done.get<bool>();
    }

    uint32_t sim_get_output(void* ptr) {
        return T(ptr)->p_output__pixel.get<uint32_t>();
    }
}

