import lib.common;

extern static const int MATERIAL_FORMAT;
extern static const int MATERIAL_NORMAL_FORMAT = MATERIAL_FORMAT;
extern static const int MATERIAL_METALS_FORMAT = MATERIAL_FORMAT;
extern static const int MATERIAL_EMISSION_FORMAT = MATERIAL_FORMAT;
extern static const int MATERIAL_POROSITY_FORMAT = MATERIAL_FORMAT;
extern static const int MATERIAL_SSS_FORMAT = MATERIAL_FORMAT;

static const int MAT_LABPBR = 2;
static const int MAT_OLDPBR = 1;
static const int MAT_NONE = 0;


float3 mat_normal_lab(const in float2 data) {
    float2 normal_xy = fma(data.xy, float2(2.0), float2(-1.0));
    float normal_z = sqrt(max(1.0 - dot(normal_xy, normal_xy), 0.0));
    return float3(normal_xy, normal_z);
}

float3 mat_normal_old(const in float3 data) {
    return normalize(fma(data, float3(2.0), float3(-1.0)));
}

float3 mat_normal(const in float3 normalData) {
    if (MATERIAL_NORMAL_FORMAT == MAT_LABPBR) {
        return mat_normal_lab(normalData.xy);
    }
    else if (MATERIAL_NORMAL_FORMAT == MAT_OLDPBR) {
        return mat_normal_old(normalData);
    }
    else {
        return 0.0;
    }
}

float mat_roughness(const in float data) {
    return 1.0 - data;
}

float mat_emission_lab(const in float data) {
    return fract(data);
}

float mat_emission_old(const in float data) {
    return data;
}

float mat_emission(const in float4 specularData) {
    if (MATERIAL_EMISSION_FORMAT == MAT_LABPBR) {
        return mat_emission_lab(specularData.a);
    }
    else if (MATERIAL_EMISSION_FORMAT == MAT_OLDPBR) {
        return mat_emission_old(specularData.b);
    }
    else {
        return 0.0;
    }
}

float mat_porosity_lab(const in float data) {
    return data * (255.0/64.0) * step(data, (64.5/255.0));
}

float mat_porosity_old(const in float roughness, const in float f0_metal) {
    float metalInv = 1.0 - saturate(unmix(0.04, (229.0/255.0), f0_metal));
    return sqrt(roughness) * metalInv;
}

float mat_porosity(const in float data, const in float roughness, const in float f0_metal) {
    if (MATERIAL_POROSITY_FORMAT == MAT_LABPBR) {
        return mat_porosity_lab(data);
    }
    else {
        return mat_porosity_old(roughness, f0_metal);
    }
}

float mat_sss_lab(const in float data) {
    return max(data - (64.0/255.0), 0.0) * (255.0/191.0);
}

float mat_sss(const in float data) {
    if (MATERIAL_SSS_FORMAT == MAT_LABPBR) {
        return mat_sss_lab(data);
    }
    else {
        return 0.0;
    }
}

float mat_f0_metal(const in float data) {
    if (MATERIAL_METALS_FORMAT != MAT_NONE) {
        if (data == 0.0) return 0.04;
        return min(data, 0.9);
    }
    else {
        return 0.04;
    }
}

float mat_metalness_lab(const in float f0_metal) {
    return step((229.5/255.0), f0_metal);
}

float mat_metalness_old(const in float f0_metal) {
    return f0_metal;
}

float mat_metalness(const in float f0_metal) {
    if (MATERIAL_METALS_FORMAT == MAT_LABPBR) {
        return mat_metalness_lab(f0_metal);
    }
    else if (MATERIAL_METALS_FORMAT == MAT_OLDPBR) {
        return mat_metalness_old(f0_metal);
    }
    else {
        return 0.0;
    }
}

bool mat_isMetal(const in float f0_metal) {
    if (MATERIAL_METALS_FORMAT == MAT_LABPBR) {
        return f0_metal > (229.5/255.0);
    }
    else if (MATERIAL_METALS_FORMAT == MAT_OLDPBR) {
        return f0_metal > 0.5;
    }
    else {
        return false;
    }
}

float mat_occlusion(const in float data) {
    if (MATERIAL_NORMAL_FORMAT == MAT_LABPBR) {
        return data;
    }
    else {
        return 1.0;
    }
}
