public module IGN;

import aperture;
import lib.common;

static const float3 IGN_magic = float3(0.06711056, 0.00583715, 52.9829189);


float InterleavedGradientNoise(const in float2 pixel) {
    float x = dot(pixel, IGN_magic.xy);
    return fract(IGN_magic.z * fract(x));
}

float InterleavedGradientNoiseTime(const in float2 pixel) {
    float2 uv = pixel + ap.timing.frameCounter * 5.588238;
    return fract(IGN_magic.z * fract(dot(IGN_magic.xy, uv)));
}

float IGN_TAA(in float2 pixel) {
    if (TAA_Enabled) pixel += ap.timing.frameCounter * 5.588238;
    return fract(IGN_magic.z * fract(dot(IGN_magic.xy, pixel)));
}
