import aperture;

float2 GetLinearCoords(const in float2 texcoord, const in float2 texSize, out float2 uv[4]) {
    float2 f = fract(texcoord * texSize);
    float2 pixelSize = 1.0 / texSize;

    uv[0] = texcoord - f*pixelSize;
    uv[1] = uv[0] + float2(1.0, 0.0)*pixelSize;
    uv[2] = uv[0] + float2(0.0, 1.0)*pixelSize;
    uv[3] = uv[0] + float2(1.0, 1.0)*pixelSize;

    return f;
}

float2 GetLinearCoords(const in float2 texcoordFull, out int2 uv[4]) {
    float2 f = fract(texcoordFull);

    int2 iuv[4];
    iuv[0] = int2(texcoordFull - f);
    iuv[1] = iuv[0]+int2(1, 0);
    iuv[2] = iuv[0]+int2(0, 1);
    iuv[3] = iuv[0]+int2(1, 1);

    return f;
}

float LinearBlend4(const in float4 samples, const in float2 f) {
    float x1 = lerp(samples[0], samples[1], f.x);
    float x2 = lerp(samples[2], samples[3], f.x);
    return lerp(x1, x2, f.y);
}

float3 LinearBlend4(const in float3 samples[4], const in float2 f) {
    float3 x1 = lerp(samples[0], samples[1], f.x);
    float3 x2 = lerp(samples[2], samples[3], f.x);
    return lerp(x1, x2, f.y);
}

// float4 LinearBlend4(const in float4 samples[4], const in float2 f) {
//     float4 x1 = lerp(samples[0], samples[1], f.x);
//     float4 x2 = lerp(samples[2], samples[3], f.x);
//     return lerp(x1, x2, f.y);
// }

// T mix<T>(const in vector<T> A, const in vector<T> B, const in float f) where T: IFloat {
//     //return lerp(A, B, T(f));
//     return A * (1.0 - f) + B * f;
// }

// T LinearBlend4<T>(const in T samples[4], const in float2 f) where T: ITexelElement, IFloat {
//     T x1 = mix(samples[0], samples[1], f.x);
//     T x2 = mix(samples[2], samples[3], f.x);
//     return mix(x1, x2, f.y);
// }

extension<T:ISampler> T {
    // static float3 LinearSampleBiasRGB(const in Sampler2D samplerName, const in float2 uv[4], const in float bias, const in float2 f) {
    //     float3 samples[4];
    //     samples[0] = samplerName.SampleBias(uv[0], bias).rgb;
    //     samples[1] = samplerName.SampleBias(uv[1], bias).rgb;
    //     samples[2] = samplerName.SampleBias(uv[2], bias).rgb;
    //     samples[3] = samplerName.SampleBias(uv[3], bias).rgb;
    //     return LinearBlend4(samples, f);
    // }

    // static float3 LinearSampleBiasRGB(const in Sampler2D samplerName, const in float2 texcoord, const in float2 texSize, const in int bias) {
    //     float2 uv[4];
    //     float2 f = GetLinearCoords(texcoord, texSize, uv);
    //     return LinearSampleBiasRGB(samplerName, uv, bias, f);
    // }

    static float SampleLevelLinear(const in float2 uv[4], const in float lod, const in float2 f, const in int comp) {
        float4 samples;
        samples[0] = this.SampleLevel(uv[0], lod)[comp];
        samples[1] = this.SampleLevel(uv[1], lod)[comp];
        samples[2] = this.SampleLevel(uv[2], lod)[comp];
        samples[3] = this.SampleLevel(uv[3], lod)[comp];
        return LinearBlend4(samples, f);
    }

    static float SampleLevelLinear(const in float2 texcoord, const in float2 texSize, const in float lod, const in int comp) {
        float2 uv[4];
        float2 f = GetLinearCoords(texcoord, texSize, uv);
        return this.SampleLevelLinear(uv, lod, f, comp);
    }

    static float SampleGradLinear(const in float2 uv[4], const in float2x2 dFdXY, const in float2 f, const in int comp) {
        float4 samples;
        samples[0] = this.SampleGrad(uv[0], dFdXY[0], dFdXY[1])[comp];
        samples[1] = this.SampleGrad(uv[1], dFdXY[0], dFdXY[1])[comp];
        samples[2] = this.SampleGrad(uv[2], dFdXY[0], dFdXY[1])[comp];
        samples[3] = this.SampleGrad(uv[3], dFdXY[0], dFdXY[1])[comp];
        return LinearBlend4(samples, f);
    }

    static float SampleGradLinear(const in float2 texcoord, const in float2 texSize, const in float2x2 dFdXY, const in int comp) {
        float2 uv[4];
        float2 f = GetLinearCoords(texcoord, texSize, uv);
        return this.SampleGradLinear(uv, dFdXY, f, comp);
    }

    // float TexelGatherLinear(const in vec2 texcoordFull, const in int comp) {
    //     vec2 f = fract(texcoordFull);
    //     vec4 samples = textureGather(samplerName, texcoordFull, comp);
    //     return LinearBlend4(samples, f);
    // }

    static float3 SampleLevelLinearRGB(const in float2 uv[4], const in float lod, const in float2 f) {
        float3 samples[4];
        samples[0] = this.SampleLevel(uv[0], lod).rgb;
        samples[1] = this.SampleLevel(uv[1], lod).rgb;
        samples[2] = this.SampleLevel(uv[2], lod).rgb;
        samples[3] = this.SampleLevel(uv[3], lod).rgb;
        return LinearBlend4(samples, f);
    }

    static float3 SampleLevelLinearRGB(const in float2 texcoord, const in float2 texSize, const in float lod) {
        float2 uv[4];
        float2 f = GetLinearCoords(texcoord, texSize, uv);
        return this.SampleLevelLinearRGB(uv, lod, f);
    }

    static float3 TextureGradLinearRGB(const in float2 uv[4], const in float2x2 dFdXY, const in float2 f) {
        float3 samples[4];
        samples[0] = this.SampleGrad(uv[0], dFdXY[0], dFdXY[1]).rgb;
        samples[1] = this.SampleGrad(uv[1], dFdXY[0], dFdXY[1]).rgb;
        samples[2] = this.SampleGrad(uv[2], dFdXY[0], dFdXY[1]).rgb;
        samples[3] = this.SampleGrad(uv[3], dFdXY[0], dFdXY[1]).rgb;
        return LinearBlend4(samples, f);
    }

    static float3 TextureGradLinearRGB(const in float2 texcoord, const in float texSize, const in float2x2 dFdXY) {
        float2 uv[4];
        float2 f = GetLinearCoords(texcoord, texSize, uv);
        return this.TextureGradLinearRGB(uv, dFdXY, f);
    }

    // static float3 TexelFetchLinearRGB(const in int2 iuv[4], const in int lod, const in float2 f) {
    //     float3 samples[4];
    //     samples[0] = this.mips[lod].tex[iuv[0]];
    //     samples[1] = this.mips[lod].tex[iuv[1]];
    //     samples[2] = this.mips[lod].tex[iuv[2]];
    //     samples[3] = this.mips[lod].tex[iuv[3]];
    //     return LinearBlend4(samples, f);
    // }

    // static float3 TexelFetchLinearRGB(const in float2 texcoordFull, const in int lod) {
    //     int2 iuv[4];
    //     float2 f = GetLinearCoords(texcoordFull, iuv);
    //     return this.TexelFetchLinearRGB(iuv, lod, f);
    // }
}
