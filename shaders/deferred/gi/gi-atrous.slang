import aperture;
import buffers.ObjectData;
import lib.common;


extern static const int ATrousLevel;

static const int ATrous_StepWidth = (1 << ATrousLevel);

Sampler2D<half3> texSource;

Sampler2D<float> texDepth;
Sampler2D<uint2> texNormalGB;

#define W(x) (x/256.0)

static const float atrousKernel[25] = float[](
    W( 1), W( 4), W( 6), W( 4), W( 1),
    W( 4), W(16), W(24), W(16), W( 4),
    W( 6), W(24), W(36), W(24), W( 6),
    W( 4), W(16), W(24), W(16), W( 4),
    W( 1), W( 4), W( 6), W( 4), W( 1));

static const int2 atrousOffsets[25] = int2[](
    int2(-2, -2), int2(-1, -2), int2(0, -2), int2(1, -2), int2(2, -2),
    int2(-2, -1), int2(-1, -1), int2(0, -1), int2(1, -1), int2(2, -1),
    int2(-2,  0), int2(-1,  0), int2(0,  0), int2(1,  0), int2(2,  0),
    int2(-2,  1), int2(-1,  1), int2(0,  1), int2(1,  1), int2(2,  1),
    int2(-2,  2), int2(-1,  2), int2(0,  2), int2(1,  2), int2(2,  2));

half3 atrous_GetTexNormal(const in uint2 uv) {
    return ObjectData_Normals.unpackTex(texNormalGB[uv].g);
}

float3 atrous_GetViewPosition(const in uint2 uv) {
    float depth = texDepth[uv];
    float3 clipPos = float3(uv / float2(ap.game.screenSize), depth) * 2.0 - 1.0;
    return project(ap.camera.projectionInv, clipPos);
}

float3 filter_ATrous(const in float2 texcoord) {
    uint2 uv = uint2(texcoord * ap.game.screenSize);

    half3 cval = texSource[uv];
    half3 nval = atrous_GetTexNormal(uv);
    float3 pval = atrous_GetViewPosition(uv);

    const float c_phi = 0.1;
    const float n_phi = 0.1;
    const float p_phi = 0.1;

    float total_weight = 0.0;
    float3 sum = 0.0;

    [ForceUnroll]
    for (int i = 0; i < 25; i++) {
        int2 sample_uv = atrousOffsets[i] * ATrous_StepWidth + uv;

        float dist2;
        float3 t;

        half3 ctmp = texSource[sample_uv];
        // float3 t = cval - ctmp;
        // float dist2 = dot(t,t);
        // float c_w = 1.0;//min(exp(-(dist2)/c_phi), 1.0);

        half3 ntmp = atrous_GetTexNormal(sample_uv);
        t = nval - ntmp;
        // dist2 = max(dot(t,t)/(stepwidth*stepwidth),0.0);
        dist2 = max(dot(t, t), 0.0);
        float n_w = min(exp(-(dist2)/n_phi), 1.0);

        float3 ptmp = atrous_GetViewPosition(sample_uv);
        t = pval - ptmp;
        dist2 = dot(t, t);
        float p_w = min(exp(-(dist2)/p_phi), 1.0);

        // float kernel_weight = c_w * n_w * p_w * atrousKernel[i];
        float kernel_weight = n_w * p_w * atrousKernel[i];
        sum += ctmp * kernel_weight;
        total_weight += kernel_weight;
    }

    return sum / max(total_weight, EPSILON);
}


[[shader("fragment")]]
half4 atrousFilter(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];
    half3 diffuse = (half)0.0;
    
    if (depth < 1.0) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        diffuse = (half3)filter_ATrous(texcoord);
    }

    // DEBUG
    // imgDebug[uv] = half4(diffuse * 0.02, (half)1.0);

    diffuse = clamp(diffuse, (half)0.0, (half)65000.0);

    return half4(diffuse, 1);
}
