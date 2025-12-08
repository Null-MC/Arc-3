public module wetness;


half3 Wetness_GetAlbedo(const in half3 albedo, const in float porosity, const in half wetness) {
    float darkenF = wetness * porosity;
    return half3(pow(albedo * (1.0 - 0.3f*darkenF), 1.0 + darkenF));
}

void Wetness_ApplyRoughness(inout half roughness, const in half wetness) {
    roughness = (half)lerp(roughness, 0.06, saturate(wetness));
}

// void Wetness_ApplyNormal(inout half3 src_normal, const in half3 puddle_normal, const in half puddleF) {
//     // float f = smoothstep(0.8, 1.2, wetness);
//     src_normal = (half3)lerp(src_normal, puddle_normal, puddleF);
//     src_normal = normalize(src_normal);
// }
