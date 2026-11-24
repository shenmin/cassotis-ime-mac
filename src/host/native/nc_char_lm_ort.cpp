// Native bridge for the shared character language model.
#define ORT_API_MANUAL_INIT
#include <onnxruntime_cxx_api.h>
#include <algorithm>
#include <array>
#include <cfloat>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <limits>
#include <memory>
#include <map>
#include <mutex>
#include <set>
#include <chrono>
#include <condition_variable>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <tuple>
#include <unordered_map>
#include <utility>
#include <vector>
#if defined(__x86_64__)
#include <xmmintrin.h>
#endif
#define CASSOTIS_EXPORT __attribute__((visibility("default")))

namespace {
std::mutex& InitializationMutex() { static std::mutex mutex; return mutex; }
template <typename T> bool ReadBinary(std::ifstream& stream, T& value) {
    return static_cast<bool>(stream.read(reinterpret_cast<char*>(&value), sizeof(value)));
}
class FloatingPointMaskGuard {
public:
    FloatingPointMaskGuard() {
#if defined(__x86_64__) || defined(__i386__)
        old_mxcsr_ = _mm_getcsr();
        _mm_setcsr(old_mxcsr_ | _MM_MASK_MASK);
#elif defined(__aarch64__)
        asm volatile("mrs %0, fpcr" : "=r"(old_fpcr_));
        asm volatile("mrs %0, fpsr" : "=r"(old_fpsr_));
        constexpr std::uint64_t kExceptionEnableMask =
            (UINT64_C(0x1f) << 8) | (UINT64_C(1) << 15);
        const std::uint64_t masked_fpcr = old_fpcr_ & ~kExceptionEnableMask;
        asm volatile("msr fpcr, %0\n\tisb" : : "r"(masked_fpcr) : "memory");
        asm volatile("msr fpsr, xzr" : : : "memory");
#endif
    }

    ~FloatingPointMaskGuard() {
#if defined(__x86_64__) || defined(__i386__)
        _mm_setcsr(old_mxcsr_);
#elif defined(__aarch64__)
        asm volatile("msr fpsr, %0" : : "r"(old_fpsr_) : "memory");
        asm volatile("msr fpcr, %0\n\tisb" : : "r"(old_fpcr_) : "memory");
#endif
    }

private:
#if defined(__x86_64__) || defined(__i386__)
    unsigned int old_mxcsr_{};
#elif defined(__aarch64__)
    std::uint64_t old_fpcr_{};
    std::uint64_t old_fpsr_{};
#endif
};

Ort::Env& Environment() {
    static Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "cassotis_char_lm");
    return env;
}
void UseReleasableInitializers(Ort::SessionOptions& options) {
    options.AddConfigEntry("session.use_device_allocator_for_initializers", "1");
    options.DisableMemPattern();
    options.DisableCpuMemArena();
    options.AddConfigEntry("session.x64quantprecision", "1");
}
void SetError(char* destination, int capacity, std::string_view message) {
    if (destination == nullptr || capacity <= 0) {
        return;
    }
    const size_t copy_length = std::min(message.size(), static_cast<size_t>(capacity - 1));
    if (copy_length > 0) {
        std::memcpy(destination, message.data(), copy_length);
    }
    destination[copy_length] = '\0';
}

std::string ErrorText(const char* message) {
    if (message == nullptr || *message == '\0') {
        return "unknown ONNX Runtime error";
    }
    return message;
}

}  // namespace

#include "nc_trie_attention.inc"
#include "nc_char_lm_float_ops.inc"
#include "nc_char_lm_ort.inc"
