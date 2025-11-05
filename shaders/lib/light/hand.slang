import aperture;
import lib.common;
import lib.material.pbr;
import lib.light.fresnel;
import lib.light.brdf;

extern static const float BLOCK_LUX;

static const float HandLightOffset_main = 0.2;
static const float HandLightOffset_alt = -0.2;


float3 GetHandLightPos(const in float offsetX) {
    float3 pos = float3(offsetX, -0.15, -0.25);
    pos = mul3(ap.camera.viewInv, pos);
    //pos.y -= 0.32;
    return pos;
}

void GetHandLight(inout half3 diffuse, inout half3 specular, const in int blockId, const in float3 lightLocalPos,
                  const in float3 localPos, const in float3 localViewDir, const in float3 localTexNormal, const in float3 localGeoNormal,
                  const in float3 F, const in float roughL) {
//    vec3 lightLocalPos = vec3(0.2, 0.0, 0.0);
    float lightRange = ap.blocks[blockId].emission;
    half3 lightColor = ap.blocks[blockId].lightColor.rgb;
    float lightSize = 0.5;//getLightSize(blockId);

    //            lightColor = RgbToLinear(lightColor);

//    vec3 light_hsv = RgbToHsv(lightColor);
//    lightColor = HsvToRgb(vec3(light_hsv.xy, lightRange/15.0));

    // TODO: before or after HSV?
    lightColor = RgbToLinear(lightColor);

    float3 lightVec = lightLocalPos - localPos;
    float lightDist = length(lightVec);
    float3 lightDir = lightVec / lightDist;

    float lightAtt = GetLightAttenuation(lightDist, lightRange, lightSize);

    float NoLm = max(dot(localTexNormal, lightDir), 0.0);

    //vec3 diffuse = vec3(0.0);
    if (NoLm > 0.0 && dot(localGeoNormal, lightDir) > 0.0) {
        // TODO: trace hand shadows
        // #ifdef HANDLIGHT_TRACE
        //     vec3 traceStart = voxel_GetBufferPosition(lightLocalPos);
        //     vec3 traceEnd = voxel_GetBufferPosition(localPos);
        //     const bool traceSelf = true;
        //     lightColor *= TraceDDA(traceStart, traceEnd, lightRange, traceSelf);
        // #endif

        float3 H = normalize(lightDir + localViewDir);

        float LoHm = max(dot(lightDir, H), 0.0);
        float NoVm = max(dot(localTexNormal, localViewDir), 0.0);
        float NoHm = max(dot(localTexNormal, H), 0.0);
        float VoHm = max(dot(localViewDir, H), 0.0);

        const bool isUnderWater = false;
        //float3 F = material_fresnel(albedo, f0_metal, roughL, VoHm, isUnderWater);
        // float metalness = mat_metalness(f0_metal);
        // float3 F = lerp(f0_metal, albedo, metalness);
        half3 D = SampleLightDiffuse(NoVm, NoLm, LoHm, roughL) * (1.0 - F);
        half3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F, roughL);

        half3 lightFinal = NoLm * BLOCK_LUX * lightAtt * lightColor;
        diffuse += D * lightFinal;
        specular += S * lightFinal;
    }
}
