// The shared model quantizes its activations after normalization and FastGelu.
// Round the multiply and add separately, as the x64 CPU kernels do. A one-ulp
// change at a quantization boundary can select another character several layers later.
#if defined(__aarch64__)
namespace nc_char_lm_float_ops {

template <typename T>
T AttributeOr(const OrtKernelInfo* info, const char* name, T fallback) {
    try {
        return Ort::ConstKernelInfo(info).GetAttribute<T>(name);
    } catch (const Ort::Exception&) {
        return fallback;
    }
}

struct NormalizationRows {
    const float* input;
    const float* scale;
    const float* bias;
    float* output;
    float* means;
    float* inv_std_devs;
    size_t width;
    float epsilon;

    static void Compute(void* data, size_t row) {
        const auto& p = *static_cast<const NormalizationRows*>(data);
        const float* input = p.input + row * p.width;
        float* output = p.output + row * p.width;
        float sum = 0.0f, sum_squares = 0.0f;
        for (size_t i = 0; i < p.width; ++i) {
            sum += input[i];
            sum_squares += input[i] * input[i];
        }
        const float width = static_cast<float>(p.width);
        const float mean = sum / width;
        const float std_dev = std::sqrt(sum_squares / width - mean * mean + p.epsilon);
        if (p.means) p.means[row] = mean;
        if (p.inv_std_devs) p.inv_std_devs[row] = 1.0f / std_dev;
        for (size_t i = 0; i < p.width; ++i) {
            const float normalized = (input[i] - mean) / std_dev;
            output[i] = normalized * p.scale[i] + (p.bias ? p.bias[i] : 0.0f);
        }
    }
};

class LayerNormalization {
public:
    explicit LayerNormalization(const OrtKernelInfo* info)
        : axis_(AttributeOr<int64_t>(info, "axis", -1)),
          epsilon_(AttributeOr<float>(info, "epsilon", 1e-5f)) {}

    OrtStatusPtr ComputeV2(OrtKernelContext* raw) {
        try {
            Ort::KernelContext context(raw);
            auto input = context.GetInput(0);
            auto shape_info = input.GetTensorTypeAndShapeInfo();
            auto shape = shape_info.GetShape();
            const auto rank = static_cast<int64_t>(shape.size());
            const int64_t axis = axis_ < 0 ? rank + axis_ : axis_;
            if (axis < 0 || axis >= rank)
                throw std::runtime_error("character LM normalization axis is outside the input shape");
            auto output = context.GetOutput(0, shape.data(), shape.size());
            const size_t count = shape_info.GetElementCount();
            if (count == 0) return nullptr;
            size_t width = 1;
            for (auto i = static_cast<size_t>(axis); i < shape.size(); ++i) {
                width *= static_cast<size_t>(shape[i]);
                shape[i] = 1;
            }
            auto scale = context.GetInput(1);
            auto bias = context.GetInputCount() > 2 ? context.GetInput(2) : Ort::ConstValue{nullptr};
            if (scale.GetTensorTypeAndShapeInfo().GetElementCount() != width ||
                (bias && bias.GetTensorTypeAndShapeInfo().GetElementCount() != width))
                throw std::runtime_error("character LM normalization needs one scale and bias per feature");
            auto optional_output = [&](size_t index) -> float* {
                if (index >= context.GetOutputCount()) return nullptr;
                auto value = context.GetOutput(index, shape.data(), shape.size());
                return value ? value.GetTensorMutableData<float>() : nullptr;
            };
            NormalizationRows rows{input.GetTensorData<float>(), scale.GetTensorData<float>(),
                bias ? bias.GetTensorData<float>() : nullptr, output.GetTensorMutableData<float>(),
                optional_output(1), optional_output(2), width, epsilon_};
            const size_t row_count = count / width;
            if (row_count < 4) {
                for (size_t row = 0; row < row_count; ++row) NormalizationRows::Compute(&rows, row);
            } else {
                context.ParallelFor(NormalizationRows::Compute, row_count, 0, &rows);
            }
            return nullptr;
        } catch (const Ort::Exception& error) {
            return Ort::Status(error).release();
        } catch (const std::exception& error) {
            return Ort::Status(error.what(), ORT_FAIL).release();
        }
    }
private:
    int64_t axis_;
    float epsilon_;
};

class FastGelu {
public:
    explicit FastGelu(const OrtKernelInfo* info) : tanh_(nullptr) {
        const char* type_name = "T";
        const ONNXTensorElementDataType type = ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
        tanh_ = Ort::Op::Create(info, "Tanh", "", 13, &type_name, &type, 1, nullptr, 0, 1, 1);
    }

    OrtStatusPtr ComputeV2(OrtKernelContext* raw) {
        try {
            Ort::KernelContext context(raw);
            auto input = context.GetInput(0);
            auto dimensions = input.GetTensorTypeAndShapeInfo();
            const auto shape = dimensions.GetShape();
            auto output = context.GetOutput(0, shape.data(), shape.size());
            const size_t count = dimensions.GetElementCount();
            if (count == 0) return nullptr;
            auto bias = context.GetInputCount() > 1 ? context.GetInput(1) : Ort::ConstValue{nullptr};
            const float* x = input.GetTensorData<float>();
            float* y = output.GetTensorMutableData<float>();
            // FastGelu's optional bias broadcasts along the last dimension.
            // The released character model omits this input.
            std::vector<float> biased;
            if (bias) {
                const size_t width = bias.GetTensorTypeAndShapeInfo().GetElementCount();
                if (shape.empty() || width != static_cast<size_t>(shape.back()) || width == 0)
                    throw std::runtime_error("character LM FastGelu bias shape mismatch");
                const float* b = bias.GetTensorData<float>();
                biased.resize(count);
                for (size_t row = 0; row < count; row += width)
                    for (size_t i = 0; i < width; ++i) biased[row + i] = x[row + i] + b[i];
                x = biased.data();
            }
            constexpr float b = 0.7978845608028654f;    // sqrt(2/pi)
            constexpr float c = 0.035677408136300125f;  // 0.044715 * sqrt(2/pi)
            for (size_t i = 0; i < count; ++i) y[i] = x[i] * ((c * x[i]) * x[i] + b);
            const OrtValue* tanh_input[] = {output};
            OrtValue* tanh_output[] = {output};
            tanh_.Invoke(raw, tanh_input, 1, tanh_output, 1);
            for (size_t i = 0; i < count; ++i) y[i] = (0.5f * x[i]) * (1.0f + y[i]);
            return nullptr;
        } catch (const Ort::Exception& error) {
            return Ort::Status(error).release();
        } catch (const std::exception& error) {
            return Ort::Status(error.what(), ORT_FAIL).release();
        }
    }
private:
    Ort::Op tanh_;
};

template <typename Kernel>
struct FloatOperator : Ort::CustomOpBase<FloatOperator<Kernel>, Kernel, true> {
    const char* name;
    size_t inputs, required_inputs, outputs;
    FloatOperator(const char* name_, int since, size_t inputs_, size_t required_, size_t outputs_)
        : name(name_), inputs(inputs_), required_inputs(required_), outputs(outputs_) {
        this->start_ver_ = since;
    }
    const char* GetName() const { return name; }
    size_t GetInputTypeCount() const { return inputs; }
    size_t GetOutputTypeCount() const { return outputs; }
    ONNXTensorElementDataType GetInputType(size_t) const { return ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT; }
    ONNXTensorElementDataType GetOutputType(size_t) const { return ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT; }
    OrtCustomOpInputOutputCharacteristic GetInputCharacteristic(size_t i) const {
        return i < required_inputs ? INPUT_OUTPUT_REQUIRED : INPUT_OUTPUT_OPTIONAL;
    }
    OrtCustomOpInputOutputCharacteristic GetOutputCharacteristic(size_t i) const {
        return i == 0 ? INPUT_OUTPUT_REQUIRED : INPUT_OUTPUT_OPTIONAL;
    }
    OrtStatusPtr CreateKernelV2(const OrtApi&, const OrtKernelInfo* info, void** kernel) const {
        try {
            *kernel = new Kernel(info);
            return nullptr;
        } catch (const Ort::Exception& error) {
            return Ort::Status(error).release();
        } catch (const std::exception& error) {
            return Ort::Status(error.what(), ORT_FAIL).release();
        }
    }
};

inline void Register(OrtSessionOptions* options) {
    static FloatOperator<LayerNormalization> norm("LayerNormalization", 17, 3, 2, 3);
    static FloatOperator<FastGelu> gelu("FastGelu", 1, 2, 1, 1);
    static Ort::CustomOpDomain onnx = [] { Ort::CustomOpDomain d(""); d.Add(&norm); return d; }();
    static Ort::CustomOpDomain microsoft = [] { Ort::CustomOpDomain d("com.microsoft"); d.Add(&gelu); return d; }();
    Ort::UnownedSessionOptions session(options);
    session.Add(onnx);
    session.Add(microsoft);
}
}  // namespace nc_char_lm_float_ops
#endif
