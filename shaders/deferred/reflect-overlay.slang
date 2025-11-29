import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;

Sampler2D<half3> texSource;
Sampler2D<half3> texReflect_final;
Sampler2D<uint2> texMatLightGB;


[[shader("fragment")]]
half4 overlayReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    // float2 texcoord = pos / ap.game.screenSize;

    half3 color = texSource[uv];
    half3 reflect = texReflect_final[uv];

    ObjectData_MatLit mat_lit;
    mat_lit.unpackSpecular(texMatLightGB[uv].r);

    // half3 albedo = RgbToLinear(colorData.rgb);
    half roughness = mat_roughness(mat_lit.specular.r);
    half roughL = pow2(roughness);
    // half f0_metal = mat_f0_metal(mat_lit.specular.g);
    // half metalness = (half)mat_metalness(f0_metal);

    // half3 f0 = lerp(half3(f0_metal), albedo.rgb, metalness);
    // half NoVm = max(dot(reflectNormal, -localDir), (half)0.0);
    // half3 F_NoV = F_Lazanyi2019(NoVm, f0);

    reflect *= (half)1.0 - roughL;

    return half4(color + reflect, (half)0.0);
}
