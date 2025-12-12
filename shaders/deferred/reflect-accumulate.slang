import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.material.pbr;
import lib.water.wetness;

extern static const int MaxFrames;

Sampler2D<float> texDepth;
Sampler2D<half4> texSource;
Sampler2D<half4> texSource_prev;
Sampler2D<half3> texReprojection;
Sampler2D<half2> texVelocity;

Sampler2D<uint2> texMatLightGB;
Sampler2D<half2> texWetnessGB;


float3 reproject(const in float3 screenPos, const in float parallaxOffset, const in bool isHand) {
    // float2 texcoord = pos / ap.game.screenSize;
    // if (TAA_Enabled) texcoord -= scene[0].taa_jitter;
    // // if (TAA_Enabled) texcoord.xy += scene[0].taa_jitter_prev;

    // float3 screenPos = float3(texcoord, depth);
    float3 ndcPos = screenPos * 2.0 - 1.0;

    if (isHand) {
        ndcPos.z /= MC_HAND_DEPTH;
    }

    // float3 localPos = project(scene[0].viewProjectionInv, ndcPos);
    float3 viewPos = project(ap.camera.projectionInv, ndcPos);
    viewPos += parallaxOffset * normalize(viewPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);

    float3 prev_localPos = localPos + (ap.camera.position - ap.temporal.position);

    // float3 prev_clipPos = project(scene[0].viewProjectionLast, prev_localPos);
    float3 prev_viewPos = mul3(ap.temporal.view, prev_localPos);
    prev_viewPos -= parallaxOffset * normalize(prev_viewPos);
    float3 prev_clipPos = project(ap.temporal.projection, prev_viewPos);
    float3 prev_screenPos = prev_clipPos * 0.5 + 0.5;
    // TODO: apply prev-frame TAA jitter?
    // if (TAA_Enabled) prev_screenPos.xy += scene[0].taa_jitter_prev;

    return prev_screenPos;

    // prev_screenPos.xy -= 0.5*texVelocity[uv];
    // offset = prev_screenPos.xy - screenPos.xy;
}


[[shader("fragment")]]
half4 accumulateReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];

    half3 color = half3(0.0);
    half counter = 0;
    
    if (depth < 1.0) {
        // color = texSource.Sample(texcoord);
        half4 traceData = texSource[uv];

        float3 reproj = texReprojection[uv];
        // float2 texcoord = pos / float2(ap.game.screenSize);
        
        // float2 prev_texcoord = texcoord + reproj.xy;
        // if (TAA_Enabled) texcoord -= scene[0].taa_jitter_prev;

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        half roughness = mat_roughness(mat_lit.specular.r);
        bool isHand = mat_lit.blockMapId == BLOCK_HAND;

        float2 texcoord = pos / ap.game.screenSize;
        // if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 screenPos = float3(texcoord, depth);
        float parallaxDist = traceData.a * pow2(1.0 - roughness);
        float3 screenPos_prev = reproject(screenPos, parallaxDist, isHand);

        screenPos_prev.xy -= 0.5*texVelocity[uv];

        // TODO: make this work again
        float rejectPass = step(0.6, reproj.z);



        half4 color_prev = texSource_prev.Sample(screenPos_prev.xy);

        // ObjectData_MatLit mat_lit;
        // mat_lit.unpackSpecular(texMatLightGB[uv].r);
        // half roughness = mat_roughness(mat_lit.specular.r);

        if (World_HasSky) {
            half2 wetness_puddle = texWetnessGB[uv];
            Wetness_ApplyRoughness(roughness, wetness_puddle.x);
        }

        float roughL = pow2(roughness);

        float _maxFrames = lerp(2.0, float(MaxFrames), roughL);
        counter = clamp(color_prev.a * rejectPass, 0, _maxFrames) + 1;

        color = lerp(color_prev.rgb, traceData.rgb, rcp(counter));
    }

    return half4(color, counter);
}
