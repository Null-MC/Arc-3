import aperture;
import lib.common;
import lib.material.pbr;
import lib.wind_waving;

extern static const bool EmissionMask;
// extern static const bool RENDER_TERRAIN = false;

struct VertexOutput {
    float4 position : SV_Position;

    float3 modelPos;
    nointerpolation int blockId;
    float2 uv;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    output.uv = input.uv();
    output.modelPos = input.pos().xyz;

    output.blockId = input.blockId().orElse(-1);

    PointLight light = ap.lights[input.currentInstance()];

    if (Sky_WindEnabled && output.blockId >= 0) {
        float3 midBlock = input.midBlock().orElse(0.0);
        float3 originPos = output.modelPos + midBlock;
        uint blockTags = ap.blocks[output.blockId].tags;

        float3 origin_worldPos = floor(originPos + ap.camera.position);
        output.modelPos += GetWavingOffset(origin_worldPos, midBlock, blockTags, ap.timing.timeElapsed);

        // shadowViewPos = mul3(ap.celestial.view, localPos);
    }

    float3 shadowViewPos = mul3(input.viewMatrix(), output.modelPos);

    // if (SKY_WIND_ENABLED) {
    //     float3 localPos = output.modelPos + light.position;

    //     float3 midPos = input.midBlock().value / 64.0;
    //     float3 originPos = localPos + midPos;
    //     float3 wavingOffset = GetWavingOffset(originPos, midPos, output.blockId);

    //     output.modelPos += wavingOffset;
    //     shadowViewPos = mul3(input.viewMatrix(), output.modelPos);
    // }

    output.position = mul(input.projectionMatrix(), float4(shadowViewPos, 1.0));

    return output;
}


[[shader("fragment")]]
float fragmentMain(VertexOutput input) : SV_Depth {
    float finalDist = length(input.modelPos);
    float fragDepth = (finalDist - ap.lights.nearPlane) / (ap.lights.farPlane - ap.lights.nearPlane);

    float alpha = albedoTex.SampleLevel(input.uv, 0).a;

    if (EmissionMask) {
        if (all(clamp(input.modelPos, -0.5, 0.5) == input.modelPos)) {
            float4 specularData = specularTex.SampleLevel(input.uv, 0);
            float emission = mat_emission(specularData);
            if (emission > 0.0) alpha = 0.0;
        }
    }
    else {
        bool isFull = input.blockId >= 0 && ap.blocks[input.blockId].isFullBlock;
        float near = isFull ? 0.5 : 0.49999;

        if (all(clamp(input.modelPos, -near, near) == input.modelPos)) alpha = 0.0;
    }

    const float alphaThreshold = 0.2;
    if (alpha < alphaThreshold) discard;

    return fragDepth;
}
