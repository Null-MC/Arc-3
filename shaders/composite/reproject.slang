import aperture;
import lib.common;

Sampler2D<float> texDepth;
Sampler2D<float> texDepthLast;
Sampler2D<half3> texPositionPrev;


struct FragmentOutput {
    half3 offset : SV_Target0;
    half3 position : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput reprojectScene(float2 pos : SV_Position) {
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];

    float2 offset = 0.0;
    float weight = 1.0;

    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene[0].taa_jitter;
    // if (TAA_Enabled) texcoord.xy += scene[0].taa_jitter_prev;

    float3 screenPos = float3(texcoord, depth);
    float3 clipPos = screenPos * 2.0 - 1.0;
    // float3 viewPos = project(ap.camera.projectionInv, clipPos);
    // float3 localPos = mul3(ap.camera.viewInv, viewPos.xyz);
    float3 localPos = project(scene[0].viewProjectionInv, clipPos);

    if (depth < 1.0) {
        float3 prev_localPos = localPos + (ap.camera.position - ap.temporal.position);

        float3 prev_viewPos = mul3(ap.temporal.view, prev_localPos);
        float3 prev_clipPos = project(ap.temporal.projection, prev_viewPos);
        float3 prev_screenPos = prev_clipPos * 0.5 + 0.5;
        // TODO: apply prev-frame TAA jitter?
        // if (TAA_Enabled) prev_screenPos.xy += scene[0].taa_jitter_prev;

        // prev_screenPos.xy -= texVelocity[uv];
        offset = prev_screenPos.xy - screenPos.xy;

        float viewDist = length(localPos);
        float distThreshold = 0.004 * viewDist;
        float3 last_localPos = texPositionPrev.Sample(prev_screenPos.xy);
        float3 localOffset = last_localPos - prev_localPos;
        if (dot(localOffset, localOffset) > distThreshold) weight = 0.5;

        if (!all(saturate(prev_screenPos.xy) == prev_screenPos.xy)) weight = 0.0;
    }

    FragmentOutput output;
    output.offset = half3(float3(offset, weight));
    output.position = half3(localPos);
    return output;
}
