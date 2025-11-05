import aperture;

static const uint2 WaterDepth_Clear = uint2(uint.maxValue, uint.minValue);

[[vk::image_format("rg32ui")]]
RWTexture2D<uint2> imgWaterVolume;


void WaterDepth_set(const in uint2 uv, const in float depthL) {
    uint depth_min = uint(floor((depthL / ap.camera.far) * uint.maxValue));

    InterlockedMin(imgWaterVolume[uv].x, depth_min);
    InterlockedMax(imgWaterVolume[uv].y, depth_min+1u);
}

float2 WaterDepth_get(const in uint2 uv) {
    uint2 min_max = imgWaterVolume[uv];
    return min_max / float(uint.maxValue) * ap.camera.far;
}
