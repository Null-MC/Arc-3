public module PBR;

import lib.common;
import lib.light.fresnel;

extern static const int MATERIAL_FORMAT;
extern static const int MATERIAL_NORMAL_FORMAT = MATERIAL_FORMAT;
extern static const int MATERIAL_METALS_FORMAT = MATERIAL_FORMAT;
extern static const int MATERIAL_EMISSION_FORMAT = MATERIAL_FORMAT;
extern static const int MATERIAL_POROSITY_FORMAT = MAT_OLDPBR;
extern static const int MATERIAL_SSS_FORMAT = MATERIAL_FORMAT;

static const int MAT_LABPBR = 2;
static const int MAT_OLDPBR = 1;
static const int MAT_NONE = 0;


half3 mat_normal_lab(const in half2 normalData) {
    half2 normal_xy = fma(normalData.xy, half2(2.0), half2(-1.0));
    half normal_z = sqrt(max((half)1.0 - dot(normal_xy, normal_xy), (half)0.0));
    return half3(normal_xy, normal_z);
}

half3 mat_normal_old(const in half3 normalData) {
    return normalize(fma(normalData, half3(2.0), half3(-1.0)));
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

half mat_roughness(const in half specular_r) {
    return (half)1.0 - specular_r;
}

half mat_emission_lab(const in half specular_a) {
    return fract(specular_a);
}

half mat_emission_old(const in half specular_b) {
    return specular_b;
}

half mat_emission(const in half4 specularData) {
    half emission;
    if (MATERIAL_EMISSION_FORMAT == MAT_LABPBR) {
        emission = mat_emission_lab(specularData.a);
    }
    else if (MATERIAL_EMISSION_FORMAT == MAT_OLDPBR) {
        emission = mat_emission_old(specularData.b);
    }
    else {
        emission = (half)0.0;
    }

    emission = pow(emission, (half)settings.Emission_Curve) * (half)settings.Emission_Scale;
    
    return emission;
}

half mat_porosity_lab(const in half specular_b) {
    return specular_b * (half)(255.0/64.0) * step(specular_b, (half)(64.5/255.0));
}

half mat_porosity_old(const in half roughness, const in half f0_metal) {
    half metalInv = (half)1.0 - saturate(unmix((half)0.04, (half)(229.0/255.0), f0_metal));
    return sqrt(roughness) * metalInv;
}

half mat_porosity(const in half specular_b, const in half roughness, const in half f0_metal) {
    if (MATERIAL_POROSITY_FORMAT == MAT_LABPBR) {
        return mat_porosity_lab(specular_b);
    }
    else {
        return mat_porosity_old(roughness, f0_metal);
    }
}

half mat_sss_lab(const in half specular_b) {
    return max(specular_b - (half)(64.0/255.0), (half)0.0) * (half)(255.0/191.0);
}

half mat_sss(const in half specular_b) {
    if (MATERIAL_SSS_FORMAT == MAT_LABPBR) {
        return mat_sss_lab(specular_b);
    }
    else {
        return (half)0.0;
    }
}

half mat_f0_metal(const in half specular_g) {
    if (MATERIAL_METALS_FORMAT != MAT_NONE) {
        if (specular_g == 0.0) return (half)0.04;
        // return min(specular_g, (half)0.9);
        return specular_g;
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

// bool mat_isMetal(const in half f0_metal) {
//     if (MATERIAL_METALS_FORMAT == MAT_LABPBR) {
//         return f0_metal > (half)(229.5/255.0);
//     }
//     else if (MATERIAL_METALS_FORMAT == MAT_OLDPBR) {
//         return f0_metal > (half)0.5;
//     }
//     else {
//         return false;
//     }
// }

static const half3 lazanyi_f0[8] = half3[](
    half3(0.78, 0.77, 0.74),
    half3(1.00, 0.90, 0.61),
    half3(1.00, 0.98, 1.00),
    half3(0.77, 0.80, 0.79),
    half3(1.00, 0.89, 0.73),
    half3(0.79, 0.87, 0.85),
    half3(0.92, 0.90, 0.83),
    half3(1.00, 1.00, 0.91));

static const half3 lazanyi_f82[8] = half3[](
    half3(0.74, 0.76, 0.76),
    half3(1.00, 0.93, 0.73),
    half3(0.96, 0.97, 0.98),
    half3(0.74, 0.79, 0.78),
    half3(1.00, 0.90, 0.80),
    half3(0.83, 0.80, 0.83),
    half3(0.89, 0.87, 0.81),
    half3(1.00, 1.00, 0.95));

void mat_f0(const in half3 albedo, const in half f0_metal, const in half metalness, out half3 f0, out half3 f82) {
    if (MATERIAL_FORMAT == MAT_LABPBR) {
        int hcm = int(f0_metal * 255.0 - 229.5);

        if (hcm >= 0 && hcm < 8) {
            f0 = InputTransform(lazanyi_f0[hcm]);
            f82 = InputTransform(lazanyi_f82[hcm]);
            return;
        }
    }
    
    f0 = min(f0_metal, (half)0.9);
    f0 = lerp(f0, albedo.rgb, metalness);
    f82 = get_f82(f0);
}

half mat_occlusion(const in half data) {
    if (MATERIAL_NORMAL_FORMAT == MAT_LABPBR) {
        return data;
    }
    else {
        return (half)1.0;
    }
}
