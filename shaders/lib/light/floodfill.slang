import aperture;

extern static const int FloodFill_BufferSize;
extern static const float FloodFill_FrustumOffsetF = 0.0;//VOXEL_FRUSTUM_OFFSET * 0.01;

static const uint3 FloodFill_BufferCenter = FloodFill_BufferSize / 2;

static const uint BLOCK_FACE_UP = 1;
static const uint BLOCK_FACE_DOWN = 0;
static const uint BLOCK_FACE_NORTH = 2;
static const uint BLOCK_FACE_SOUTH = 3;
static const uint BLOCK_FACE_EAST = 5;
static const uint BLOCK_FACE_WEST = 4;

[[vk::image_format("rgba16f")]]
RWTexture3D<half3> imgFloodFill_write;

Sampler3D<half3> texFloodFill_read;
Sampler3D<half3> texFloodFill_write;


bool FloodFill_InBounds(const in int3 bufferPos) {
    return all(clamp(bufferPos, 0, FloodFill_BufferSize-1) == bufferPos);
}

bool FloodFill_InBounds(const in float3 bufferPos) {
    return all(clamp(bufferPos, 0.5, FloodFill_BufferSize-0.5) == bufferPos);
}

// float3 GetVoxelCenter(const in float3 viewPos, const in float3 viewDir) {
//     int3 offset = int3(floor(viewDir * FloodFill_BufferCenter * FloodFill_FrustumOffsetF));
//     return (FloodFill_BufferCenter + offset) + fract(viewPos);
// }

float3 GetVoxelCenter(const in float3 viewPos) {
    return FloodFill_BufferCenter + fract(viewPos);
}

float3 FloodFill_GetBufferPosition(const in float3 localPos) {
    // return position + GetVoxelCenter(ap.camera.position, ap.camera.viewInv[2].xyz);
    return localPos + GetVoxelCenter(ap.camera.position);
}

float3 FloodFill_GetLocalPosition(const in float3 bufferPos) {
    // return bufferPos - GetVoxelCenter(ap.camera.position, ap.camera.viewInv[2].xyz);
    return bufferPos - GetVoxelCenter(ap.camera.position);
}

half3 floodfill_sample(const in float3 bufferPos) {
    if (!FloodFill_InBounds(bufferPos)) return half3(0.0);

    float3 texcoord = bufferPos / FloodFill_BufferSize;
    return texFloodFill_write.Sample(texcoord);
}
