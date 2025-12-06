import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.water.wetness;

Sampler2D<half3> texSource;
Sampler2D<half3> texReflect_final;
Sampler2D<half3> texAlbedoGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<half2> texWetnessGB;


[[shader("fragment")]]
half4 overlayReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    // float2 texcoord = pos / ap.game.screenSize;

    half3 final = texSource[uv];
    half3 reflect = texReflect_final[uv];
    
    half3 albedo = texAlbedoGB[uv];
    ApplyInputTransform(albedo);

    ObjectData_MatLit mat_lit;
    mat_lit.unpackSpecular(texMatLightGB[uv].r);

    half roughness = mat_roughness(mat_lit.specular.r);
    half f0_metal = mat_f0_metal(mat_lit.specular.g);
    half metalness = (half)mat_metalness(f0_metal);

    if (World_HasSky) {
        half2 wetness_puddle = texWetnessGB[uv];
        Wetness_ApplyRoughness(roughness, wetness_puddle.x);
    }

    half roughL = pow2(roughness);

    // float3 localDir = localPos / viewDist;
    // float NoVm = max(dot(reflectNormal, -localDir), 0.0);
    // half3 F_NoV = lazanyi.F(NoVm);

    reflect *= (half)1.0 - roughL;

    half3 specularTint = mat_specularTint(albedo.rgb, f0_metal, metalness);

    return half4(final + reflect * specularTint, (half)0.0);
}
