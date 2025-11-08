// half3x3 GetTBN(const in half3 normal, in half3 tangent, const in half tangentW) {
//     half3 binormal = normalize(cross(tangent, normal)) * sign(tangentW);
//     return half3x3(tangent, binormal, normal);
// }

float3x3 GetTBN(const in float3 normal, in float3 tangent, const in float tangentW) {
    float3 binormal = normalize(cross(tangent, normal)) * sign(tangentW);
    return float3x3(tangent, binormal, normal);
}

float3x3 generate_tbn(float3 n) {
    float3x3 tbn;
    tbn[2] = n;
    if (n.z < -0.9) {
        tbn[0] = float3(0.0, -1, 0);
        tbn[1] = float3(-1, 0, 0);
    } else {
        float a = 1.0 / (1.0 + n.z);
        float b = -n.x * n.y * a;
        tbn[0] = float3(1.0 - n.x * n.x * a, b, -n.x);
        tbn[1] = float3(b, 1.0 - n.y * n.y * a, -n.y);
    }
    return tbn;
}
