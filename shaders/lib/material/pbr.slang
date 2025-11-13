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


half3 mat_normal_lab(const in half2 data) {
    half2 normal_xy = fma(data.xy, half2(2.0), half2(-1.0));
    half normal_z = sqrt(max((half)1.0 - dot(normal_xy, normal_xy), (half)0.0));
    return half3(normal_xy, normal_z);
}

half3 mat_normal_old(const in half3 data) {
    return normalize(fma(data, half3(2.0), half3(-1.0)));
}

half3 mat_normal(const in half3 normalData) {
    if (MATERIAL_NORMAL_FORMAT == MAT_LABPBR) {
        return mat_normal_lab(normalData.xy);
    }
    else if (MATERIAL_NORMAL_FORMAT == MAT_OLDPBR) {
        return mat_normal_old(normalData);
    }
    else {
        return half3(0.0);
    }
}

half mat_roughness(const in half data) {
    return (half)1.0 - data;
}

half mat_emission_lab(const in half data) {
    return fract(data);
}

half mat_emission_old(const in half data) {
    return data;
}

half mat_emission(const in half4 specularData) {
    if (MATERIAL_EMISSION_FORMAT == MAT_LABPBR) {
        return mat_emission_lab(specularData.a);
    }
    else if (MATERIAL_EMISSION_FORMAT == MAT_OLDPBR) {
        return mat_emission_old(specularData.b);
    }
    else {
        return (half)0.0;
    }
}

half mat_porosity_lab(const in half data) {
    return data * (half)(255.0/64.0) * step(data, (half)(64.5/255.0));
}

half mat_porosity_old(const in half roughness, const in half f0_metal) {
    half metalInv = (half)1.0 - saturate(unmix((half)0.04, (half)(229.0/255.0), f0_metal));
    return sqrt(roughness) * metalInv;
}

float mat_porosity(const in half data, const in half roughness, const in half f0_metal) {
    if (MATERIAL_POROSITY_FORMAT == MAT_LABPBR) {
        return mat_porosity_lab(data);
    }
    else {
        return mat_porosity_old(roughness, f0_metal);
    }
}

half mat_sss_lab(const in half data) {
    return max(data - (half)(64.0/255.0), (half)0.0) * (half)(255.0/191.0);
}

half mat_sss(const in half data) {
    if (MATERIAL_SSS_FORMAT == MAT_LABPBR) {
        return mat_sss_lab(data);
    }
    else {
        return (half)0.0;
    }
}

half mat_f0_metal(const in half data) {
    if (MATERIAL_METALS_FORMAT != MAT_NONE) {
        if (data == 0.0) return (half)0.04;
        return min(data, (half)0.9);
    }
    else {
        return (half)0.04;
    }
}

half mat_metalness_lab(const in half f0_metal) {
    return step((half)(229.5/255.0), f0_metal);
}

half mat_metalness_old(const in half f0_metal) {
    return f0_metal;
}

half mat_metalness(const in half f0_metal) {
    if (MATERIAL_METALS_FORMAT == MAT_LABPBR) {
        return mat_metalness_lab(f0_metal);
    }
    else if (MATERIAL_METALS_FORMAT == MAT_OLDPBR) {
        return mat_metalness_old(f0_metal);
    }
    else {
        return (half)0.0;
    }
}

bool mat_isMetal(const in half f0_metal) {
    if (MATERIAL_METALS_FORMAT == MAT_LABPBR) {
        return f0_metal > (half)(229.5/255.0);
    }
    else if (MATERIAL_METALS_FORMAT == MAT_OLDPBR) {
        return f0_metal > (half)0.5;
    }
    else {
        return false;
    }
}

half mat_occlusion(const in half data) {
    if (MATERIAL_NORMAL_FORMAT == MAT_LABPBR) {
        return data;
    }
    else {
        return (half)1.0;
    }
}
