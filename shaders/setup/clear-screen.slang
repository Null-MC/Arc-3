import aperture;


[[vk::image_format("rgba16f")]]
RWTexture2D<half4> imgReflect_OpaquePrev;


[[shader("compute")]]
[numthreads(16, 16, 1)]
void clearScreen(uint3 globalPos : SV_DispatchThreadID) {
    if (any(globalPos.xy >= ap.game.screenSize)) return;

    imgReflect_OpaquePrev[globalPos.xy] = half4(0.0);
}
