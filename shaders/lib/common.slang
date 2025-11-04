import aperture;
import buffers.scene;
import buffers.settings;

ConstantBuffer<SettingsBuffer> settings;
StructuredBuffer<SceneBuffer> scene;

extern static const bool TAA_Enabled;

static const float PI = 3.14159265358;
static const float EPSILON = 1.0e-6;

static const int DIM_NETHER = -1;
static const int DIM_OVERWORLD = 0;
static const int DIM_END = 1;

static const int Reflect_SkyOnly = 1;
// static const int Reflect_ScreenSpace = 2;


float minOf(float x, float y, float z) {
    return min(x, min(y, z));
}

half3 minOf(half3 x, half3 y, half3 z) {
    return min(x, min(y, z));
}

float3 minOf(float3 x, float3 y, float3 z) {
    return min(x, min(y, z));
}

// T minOf<T>(const in T x, const in T y, const in T z) where T: IComparable {
//     return min(x, min(y, z));
// }

float maxOf(float x, float y, float z) {
    return max(x, max(y, z));
}

half3 maxOf(half3 x, half3 y, half3 z) {
    return max(x, max(y, z));
}

float3 maxOf(float3 x, float3 y, float3 z) {
    return max(x, max(y, z));
}

// T maxOf<T>(const in T x, const in T y, const in T z) where T: IArithmetic {
//     return max(x, max(y, z));
// }

T pow2<T>(const in T value) where T: IArithmetic {
    return value*value;
}

T pow3<T>(const in T value) where T: IArithmetic {
    return value*value*value;
}

T pow4<T>(const in T value) where T: IArithmetic {
    T sq = value*value;
    return sq*sq;
}

T sumOf<T>(const in vector<T, 3> vec) where T: IArithmetic {
    return vec.x + vec.y + vec.z;
}

T unmix<T>(const in T valueMin, const in T valueMax, const in T value) where T: IFloat {
    return (value - valueMin) / (valueMax - valueMin);
}

float3 mul3(const in float4x4 matrix, const in float3 vector) {
    return mul(matrix, float4(vector, 1.0)).xyz;
    // TODO: transpose translation?
    //return mul(vector, float3x3(matrix)) + matrix[3].xyz;
}

// float3 project(const in float4 pos) {
//     return pos.xyz / pos.w;
// }

// float3 project(const in float4x4 matProj, const in float3 pos) {
//     return project(mul(float4(pos, 1.0), matProj));
// }

float3 project(const in float4x4 matrix, const in float3 vector) {
    float4 result = mul(matrix, float4(vector, 1.0));
    return result.xyz / result.w;
}

float luminance(const in float3 color) {
    static const float3 L = float3(0.2126, 0.7152, 0.0722);
    return dot(color, L);
}

float3 LinearToRgb(const in float3 color) {
    float3 is_high = step(0.00313066844250063, color);
    float3 higher = 1.055 * pow(color, float3(1.0/2.4)) - 0.055;
    float3 lower = color * 12.92;

    return lerp(lower, higher, is_high);
}

float3 RgbToLinear(const in float3 color) {
    float3 is_high = step(0.0404482362771082, color);
    float3 higher = pow((color + 0.055) / 1.055, float3(2.4));
    float3 lower = color / 12.92;

    return lerp(lower, higher, is_high);
}

half3 RgbToLinear(const in half3 color) {
    half3 is_high = step(half3(0.0404482362771082), color);
    half3 higher = pow((color + half3(0.055)) / half3(1.055), half3(2.4));
    half3 lower = color / half3(12.92);

    return lerp(lower, higher, is_high);
}
