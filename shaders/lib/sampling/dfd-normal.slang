public module dfd_normal;

import lib.common;

float3 getSurfaceNormal(const in float3 position, const in float3 fallbackNormal) {
    // #ifdef GL_ARB_derivative_control
    //     float3 dX = ddx_fine(position);
    //     float3 dY = ddyFine(position);
    // #else
        float3 dX = ddx_fine(position);
        float3 dY = ddy_fine(position);
    // #endif

    float3 normal = cross(dX, dY);

    if (dot(normal, normal) > 0.0) {
        normal = normalize(normal);
    }
    else {
        normal = fallbackNormal;
    }

    return normal;
}
