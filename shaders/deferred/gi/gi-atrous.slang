import aperture;
import buffers.ObjectData;
import lib.common;

extern static const int AtrousLevel;

Sampler2D<half3> texSource;

Sampler2D<float> solidDepthTex;
Sampler2D<uint2> texNormalGB;

static const float atrousKernel[25] = float[25](
    1.0/256.0,  4.0/256.0,  6.0/256.0,  4.0/256.0,  1.0/256.0,
    4.0/256.0, 16.0/256.0, 24.0/256.0, 16.0/256.0,  4.0/256.0,
    6.0/256.0, 24.0/256.0, 36.0/256.0, 24.0/256.0,  6.0/256.0,
    4.0/256.0, 16.0/256.0, 24.0/256.0, 16.0/256.0,  4.0/256.0,
    1.0/256.0,  4.0/256.0,  6.0/256.0,  4.0/256.0,  1.0/256.0
);

static const float2 atrousOffsets[25] = float2[25](
    float2(-2.0, -2.0), float2(-1.0, -2.0), float2(0.0, -2.0), float2(1.0, -2.0), float2(2.0, -2.0),
    float2(-2.0, -1.0), float2(-1.0, -1.0), float2(0.0, -1.0), float2(1.0, -1.0), float2(2.0, -1.0),
    float2(-2.0,  0.0), float2(-1.0,  0.0), float2(0.0,  0.0), float2(1.0,  0.0), float2(2.0,  0.0),
    float2(-2.0,  1.0), float2(-1.0,  1.0), float2(0.0,  1.0), float2(1.0,  1.0), float2(2.0,  1.0),
    float2(-2.0,  2.0), float2(-1.0,  2.0), float2(0.0,  2.0), float2(1.0,  2.0), float2(2.0,  2.0)
);

float3 atrous_GetTexNormal(const in float2 texcoord) {
    uint2 uv = uint2(texcoord * ap.game.screenSize);
    half3 tex_normal = ObjectData_Normals.unpackTex(texNormalGB[uv].g);
    // return mul(float3x3(ap.camera.view), tex_normal);
    return tex_normal;
}

float3 atrous_GetViewPosition(const in float2 texcoord) {
    uint2 uv = uint2(texcoord * ap.game.screenSize);
    float depth = solidDepthTex[uv];
    float3 clipPos = float3(uv / float2(ap.game.screenSize), depth) * 2.0 - 1.0;
    return project(ap.camera.projectionInv, clipPos);
    // return screenSpaceToViewSpace(vec3(uv, depth));
}

float3 atrous(float2 sampleUV, float c_phi, float n_phi, float p_phi, float stepwidth) {
    float3 sum = 0.0;
    float2 step = rcp(ap.game.screenSize);
    float3 cval = texSource.Sample(sampleUV);
    float3 nval = atrous_GetTexNormal(sampleUV);
    float3 pval = atrous_GetViewPosition(sampleUV);
    float cum_w = 0.0;

    for (int i = 0; i < 25; i++) {
        float2 uv = sampleUV + atrousOffsets[i] * step * stepwidth;
        float3 t;
        float dist2;

        float3 ctmp = texSource.Sample(uv);
        // float3 t = cval - ctmp;
        // float dist2 = dot(t,t);
        float c_w = 1.0;//min(exp(-(dist2)/c_phi), 1.0);

        float3 ntmp = atrous_GetTexNormal(uv);
        t = nval - ntmp;
        // dist2 = max(dot(t,t)/(stepwidth*stepwidth),0.0);
        dist2 = max(dot(t,t),0.0);
        float n_w = min(exp(-(dist2)/n_phi), 1.0);

        float3 ptmp = atrous_GetViewPosition(uv);
        t = pval - ptmp;
        dist2 = dot(t,t);
        float p_w = min(exp(-(dist2)/p_phi),1.0);

        float kernel_weight = c_w * n_w * p_w * atrousKernel[i];
        sum += ctmp * kernel_weight;
        cum_w += kernel_weight;
    }

    return sum / max(cum_w, EPSILON);
}


[[shader("fragment")]]
half4 atrousFilter(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv_full = uint2(pos);
    float depth = solidDepthTex[uv_full];
    half3 diffuse = half3(0.0);
    
    if (depth < 1.0) {
        // float2 texcoord = pos / BufferSize;
        // if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        const float w_color = 0.1;
        const float w_normal = 0.1;
        const float w_pos = 0.1;
        const float step_width = exp2(AtrousLevel);

        float2 texcoord = pos / ap.game.screenSize;
        // float2 texcoord = (uv_full * BufferScale + 0.5) / float2(ap.game.screenSize);
        diffuse = atrous(texcoord, w_color, w_normal, w_pos, step_width);
    }

    // DEBUG
    // imgDebug[uv] = half4(diffuse * 0.02, (half)1.0);

    diffuse = clamp(diffuse, 0.0, 65000.0);

    return half4(diffuse, (half)1.0);
}
