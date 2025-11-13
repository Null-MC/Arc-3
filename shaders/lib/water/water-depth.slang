import aperture;

[[vk::image_format("r32ui")]]
RWTexture2D<uint> imgDepth_water;

[[vk::image_format("rgba8")]]
RWTexture2D<half4> imgAlbedoGB_water;

[[vk::image_format("r32ui")]]
RWTexture2D<uint2> imgNormalGB_water;

[[vk::image_format("rg32ui")]]
RWTexture2D<uint2> imgMatLightGB_water;

Sampler2D<uint> texDepth_water;
Sampler2D<half4> texAlbedoGB_water;
Sampler2D<uint2> texNormalGB_water;
Sampler2D<uint2> texMatLightGB_water;


void WaterDepth_clear(const in uint2 uv) {
    imgDepth_water[uv] = uint.maxValue;
}

bool WaterDepth_set(const in uint2 uv, const in float distance) {
    uint depthInt = uint(saturate(distance / ap.camera.far) * uint.maxValue);
    return __atomic_min(imgDepth_water[uv], depthInt) > depthInt;
}

float WaterDepth_get(const in uint2 uv) {
    return (texDepth_water[uv] / float(uint.maxValue)) * ap.camera.far;
}
