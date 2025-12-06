import aperture;
import buffers.sky;
import buffers.scene;
import lib.common;
import lib.sampling.R2;
import lib.light.floodfill;
import lib.light.shadow;
import lib.sky.density;

RWStructuredBuffer<SceneBuffer> scene_writer;


[[shader("compute")]]
[numthreads(1,1,1)]
void beginScene() {
    if (TAA_Enabled) {
        scene_writer[0].taa_jitter_prev = scene_writer[0].taa_jitter;
        
        scene_writer[0].taa_jitter = GetR2_2D(ap.timing.frameCounter) - 0.5;
        scene_writer[0].taa_jitter /= ap.game.screenSize;
    }
    
    scene_writer[0].SunLocalDir = normalize(mul(float3x3(ap.camera.viewInv), ap.celestial.sunPosition));
    scene_writer[0].MoonLocalDir = normalize(mul(float3x3(ap.camera.viewInv), ap.celestial.moonPosition));
    scene_writer[0].SkyLightLocalDir = normalize(mul(float3x3(ap.camera.viewInv), ap.celestial.position));

    for (int i = 0; i < Shadow_CascadeCount; i++) {
        GetShadowProjectionBounds(i, scene_writer[0].shadowViewMin[i], scene_writer[0].shadowViewMax[i]);
    }

    scene_writer[0].WorldFogDensity = GetWorldFogDensity(ap.world.rainStrength);

    if (DIMENSION != DIM_END && DIMENSION != DIM_NETHER) {
        // Weather
        float blend = smoothstep(0.0, 1.0, ap.world.rainStrength);
        lerp(skyClear, skyRain, blend, scene_writer[0].sky);

        // scene_writer[0].sky.mieAbsorptionBase *= scene_writer[0].WorldFogDensity;
        // scene_writer[0].sky.mieScatteringBase *= scene_writer[0].WorldFogDensity;
        //lerp(scene_writer[0].sky, skyThunder, ap.world.thunderStrength, scene_writer[0].sky);

        // Wind
        float2 windFallSpeed = lerp(
            float2(0.10, 0.04),
            float2(0.40, 0.25),
            ap.world.rainStrength);

        float fall_speed = lerp(0.04, 0.25, ap.world.rainStrength);
        scene_writer[0].WeatherOffset -= windFallSpeed * ap.timing.lastFrameTime;

        // Wetness
        // TODO: expand this to ignore dry biomes?
        float wetness_target = ap.world.rainStrength;

        float wetness_diff = wetness_target - scene_writer[0].WetnessGround;
        float wetness_speed = (wetness_diff > 0.0 ? 0.080 : -0.014) * ap.timing.lastFrameTime;

        wetness_speed = wetness_diff > 0.0
            ? min(wetness_speed, wetness_diff)
            : max(wetness_speed, wetness_diff);
        
        scene_writer[0].WetnessGround += wetness_speed;
    }

    scene_writer[0].FloodFillCenter = GetVoxelCenter(ap.camera.position);

    // scene_writer[0].viewProjection = mul(ap.camera.view, ap.camera.projection);
    scene_writer[0].viewProjectionInv = mul(ap.camera.viewInv, ap.camera.projectionInv);
    scene_writer[0].viewProjectionLast = mul(ap.temporal.projection, ap.temporal.view);
}
