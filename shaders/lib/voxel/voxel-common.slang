public module voxel_common;

import aperture;
import lib.common;

extern static const int Voxel_Resolution;

static const uint3 Voxel_BufferCenter = Voxel_Resolution / 2;


float3 Voxel_GetCenter(const in float3 cameraPos) {
    return Voxel_BufferCenter + fract(cameraPos);
}

float3 Voxel_GetBufferPosition(const in float3 localPos) {
    return localPos + Voxel_GetCenter(ap.camera.position);
}

float3 Voxel_GetLocalPosition(const in float3 bufferPos) {
    return bufferPos - Voxel_GetCenter(ap.camera.position);
}

uint Voxel_GetBufferIndex(int3 bufferPos) {
	const int3 flatten = int3(1, Voxel_Resolution, Voxel_Resolution*Voxel_Resolution);
	return sumOf(bufferPos * flatten);
}

bool Voxel_InBufferBounds(const in int3 bufferPos) {
    return all(clamp(bufferPos, 0, Voxel_Resolution-1) == bufferPos);
}

bool ap_voxel_isInBounds(const in float3 localPos) {
    float renderDistSq = pow2(ap.world.renderDistance);
    float3 worldPos = localPos + ap.camera.position;

    return worldPos.y > -64 && worldPos.y < 320 && dot(localPos, localPos) < renderDistSq;
}
