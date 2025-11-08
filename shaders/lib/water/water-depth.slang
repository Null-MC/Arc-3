import aperture;

[[vk::image_format("r32ui")]]
RWTexture2D<uint> imgWaterDepth;

// [[vk::image_format("r32ui")]]
// RWTexture2D<uint> imgWaterDepth2;

[[vk::image_format("rgba16f")]]
RWTexture2D<half4> imgWaterFinal;

[[vk::image_format("r32ui")]]
RWTexture2D<uint> imgWaterNormal;

Sampler2D<uint> texWaterDepth;
// Sampler2D<uint> texWaterDepth2;
Sampler2D<half4> texWaterFinal;
Sampler2D<uint> texWaterNormal;


void WaterDepth_clear(const in uint2 uv) {
    imgWaterDepth[uv] = uint.maxValue;
    // imgWaterDepth2[uv] = uint.maxValue;
}

bool WaterDepth_set(const in uint2 uv, const in float distance) {
    float distNorm = saturate(distance / ap.camera.far);
    uint depthInt = uint(distNorm * uint.maxValue);
    // InterlockedMin(imgWaterDepth[uv], depthInt);
    uint depthLast = __atomic_min(imgWaterDepth[uv], depthInt);
    bool result = depthLast > depthInt;
    // if (result && depthLast < uint.maxValue) __atomic_min(imgWaterDepth2[uv], depthLast);
    return result;
}

float WaterDepth_get(const in uint2 uv) {
    float distNorm = texWaterDepth[uv] / float(uint.maxValue);
    // float2 distNorm = float2(texWaterDepth[uv], texWaterDepth2[uv]) / float(uint.maxValue);
    return distNorm * ap.camera.far;
}
