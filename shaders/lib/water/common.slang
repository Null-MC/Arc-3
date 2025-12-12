public module common;

import lib.common;
import lib.light.HG;

// static const float Water_ScatterColor = 0.036;


// C [chlorophyll] = mg/m3 [0.0, 50.0]
float3 GetWaterAbsorbColor(const in float C) {
    // rgb = 630, 530, 460
    const float3 aw = float3(0.320, 0.051, 0.016);
    const float3 ac = float3(0.317, 0.474, 0.917);
    const float3 W = float3(190, 90, 20);

    float3 p1 = aw + 0.06 * ac * pow(C, 0.65);
    float3 p2 = 1.0 + 0.2 * exp(-0.014 * W);
    return p1 * p2;
}

float3 GetWaterScatterColor(const in float C) {
    // float3 bsw = float3(0.0011, 0.0022, 0.0041);

    return float3(0.873, 1.038, 1.196) * 0.3 * pow(C, 0.65);
}

// float3 GetWaterScatterColor2(const in float C) {
//     float vs = ;
//     float vl = ;

//     float3 p1 = 0.0017 * pow(float3(), 4.3);
//     float3 p2 = 1.34 * vs * pow(float3(), 1.7);
//     float3 p3 = 0.312 * vl * pow(float3(), 0.3);
//     return p1 + p2 + p3;
// }

float GetWaterPhase(const in float VoL) {
    const float g1 = 0.85;   // forward
    const float g2 = -0.31;  // backward
    float a = 0.11;//(g2 * (1.0 + g2)) / ((g1 + g2) * (1.0 + g2 - g1));
    return DHG(VoL, g2, g1, saturate(a));
}
