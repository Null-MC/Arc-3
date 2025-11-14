public module matrix;

float4x4 BuildOrthoProjectionMatrix(const in float width, const in float height, const in float zNear, const in float zFar) {
    return float4x4(
        float4(2.0 / width, 0.0, 0.0, 0.0),
        float4(0.0, 2.0 / height, 0.0, 0.0),
        float4(0.0, 0.0, -2.0 / (zFar - zNear), -(zFar + zNear)/(zFar - zNear)),
        float4(0.0, 0.0, 0.0, 1.0));
}

float4x4 BuildTranslationMatrix(const in float3 delta) {
    return float4x4(
        float4(1.0, 0.0, 0.0, delta.x),
        float4(0.0, 1.0, 0.0, delta.y),
        float4(0.0, 0.0, 1.0, delta.z),
        float4(0.0, 0.0, 0.0, 1.0));
}

float4x4 BuildScalingMatrix(const in float3 scale) {
    return float4x4(
        float4(scale.x, 0.0, 0.0, 0.0),
        float4(0.0, scale.y, 0.0, 0.0),
        float4(0.0, 0.0, scale.z, 0.0),
        float4(0.0, 0.0, 0.0, 1.0));
}

float3x3 rotateX(const in float theta) {
    float c = cos(theta);
    float s = sin(theta);

    return float3x3(
        float3(1.0, 0.0, 0.0),
        float3(0.0,   c,   s),
        float3(0.0,  -s,   c)
    );
}

float3x3 rotateY(const in float theta) {
    float c = cos(theta);
    float s = sin(theta);

    return float3x3(
        float3(  c, 0.0,  -s),
        float3(0.0, 1.0, 0.0),
        float3(  s, 0.0,   c)
    );
}

float3x3 rotateZ(const in float theta) {
    float c = cos(theta);
    float s = sin(theta);

    return float3x3(
        float3(  c,   s, 0.0),
        float3( -s,   c, 0.0),
        float3(0.0, 0.0, 1.0)
    );
}
