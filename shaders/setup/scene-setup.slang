import aperture;
import buffers.sky;
import buffers.scene;
import lib.common;
import lib.sky.common;


RWStructuredBuffer<SceneBuffer> scene_writer;


[[shader("compute")]]
[numthreads(1,1,1)]
void setupScene() {
    scene_writer[0].exposure = 1.0;
    // scene_writer[0].taa_jitter = 0.0;

    if (DIMENSION == DIM_END) {
        scene_writer[0].sky = skyEnd;
        scene_writer[0].SunColor = InputTransform(float3(0.780, 0.196, 0.620)) * 60.0;
        scene_writer[0].MoonColor = half3(0.0);
    }
    else {
        scene_writer[0].sky = skyClear;
        scene_writer[0].SunColor = InputTransform(float3(1.0, 0.98, 0.92)) * SUN_LUMINANCE;
        scene_writer[0].MoonColor = InputTransform(float3(0.92, 0.94, 1.0)) * MOON_LUMINANCE;
    }

    if (DIMENSION != DIM_END && DIMENSION != DIM_NETHER) {
        scene_writer[0].WetnessGround = ap.world.rainStrength;
    }
    else {
        scene_writer[0].WetnessGround = 0.0;
    }
}
