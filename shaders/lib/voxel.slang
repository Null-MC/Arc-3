public module voxel;

import aperture;
import lib.common;

static const int BLOCK_FACE_DOWN = 0;
static const int BLOCK_FACE_UP = 1;
static const int BLOCK_FACE_NORTH = 2;
static const int BLOCK_FACE_SOUTH = 3;
static const int BLOCK_FACE_WEST = 4;
static const int BLOCK_FACE_EAST = 5;


bool voxel_isInBounds(const in int3 localPos) {
    float renderDistSq = pow2(ap.world.renderDistance);
    float3 worldPos = localPos + ap.camera.position;

    return worldPos.y > -64 && worldPos.y < 320 && dot(localPos, localPos) < renderDistSq;
}
