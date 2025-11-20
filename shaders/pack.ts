import {Options, ReflectMode, RefractMode} from "./scripts/Options";
import {BlockMap} from "./scripts/BlockMap";
import {TagBuilder} from "./scripts/TagBuilder";
import {Dimensions} from "./scripts/Dimensions";
import {FloodFill} from "./scripts/FloodFill";
import {BufferFlipper} from "./scripts/BufferFlipper";
import {StreamingBufferBuilder} from "./scripts/StreamingBufferBuilder";
import {ApplyLightColors} from "./scripts/Lights";


const DEBUG = true;
const DEBUG_LIGHT_TILES = false;
// const VOXEL_TEX_ENABLED = true;

let dimension: Dimensions;
let BlockMappings: BlockMap;
let floodfill: FloodFill | undefined;

let texFinalPrevA: BuiltTexture | undefined;
let texFinalPrevB: BuiltTexture | undefined;
let texFinalPrevRef: ActiveTextureReference | undefined;
let imgFinalPrevRef: ActiveTextureReference | undefined;
let settings: BuiltStreamingBuffer | undefined;

let _renderConfig: RendererConfig;


export function configureRenderer(config: RendererConfig): void {
    const options = new Options();

    dimension = new Dimensions(config);

    // HACK: allows realtime settings
    _renderConfig = config;

    config.sunPathRotation = options.Shadow_Angle;
    config.ambientOcclusionLevel = 1.0;
    config.mergedHandDepth = true;
    config.disableShade = true;

    config.render.waterOverlay = false;
    config.render.entityShadow = false;
    config.render.vignette = false;
    config.render.horizon = false;
    config.render.clouds = false;
    config.render.stars = false;
    config.render.moon = false;
    config.render.sun = false;

    config.shadow.enabled = dimension.World_HasSky;
    config.shadow.resolution = options.Shadow_Resolution;
    config.shadow.distance = options.Shadow_Distance;
    // config.shadow.safeZone[0] = 32;
    config.shadow.safeZone[1] = 128;
    config.shadow.near = -800;
    config.shadow.far = 800;
    config.shadow.cascades = 4;
    config.shadow.entityCascadeCount = 2;

    config.pointLight.maxCount = options.Lighting_Point_Enabled ? options.Lighting_Point_MaxCount : 0;
    config.pointLight.resolution = options.Lighting_Point_Resolution;
    config.pointLight.realTimeCount = options.Lighting_Point_RealTime;
    config.pointLight.cacheRealTimeTerrain = false;
    config.pointLight.nearPlane = 0.1;
    config.pointLight.farPlane = 16.0;
}

export function configurePipeline(pipeline: PipelineConfig): void {
    const renderConfig = pipeline.getRendererConfig();
    const options = new Options();

    const globalExports = pipeline.createExportList()
        .addInt('DIMENSION', dimension.Index)
        .addBool('World_HasSky', dimension.World_HasSky)
        .addFloat('BLOCK_LUX', 200)
        .addInt('MATERIAL_FORMAT', options.Material_Format)
        .addInt('Shadow_Resolution', options.Shadow_Resolution)
        .addInt('Shadow_CascadeCount', renderConfig.shadow.cascades)
        .addInt('ReflectMode', options.Lighting_Reflection_Mode)
        .addInt('RefractMode', options.Lighting_Refraction_Mode)
        .addBool('FloodFill_Enabled', options.Lighting_FloodFill_Enabled)
        .addInt('FloodFill_BufferSize', options.Lighting_FloodFill_Size)
        .addBool('PointLight_Enabled', options.Lighting_Point_Enabled)
        .addInt('PointLight_MaxCount', renderConfig.pointLight.maxCount)
        .addInt('Voxel_Resolution', options.Lighting_VoxelResolution)
        .addBool('TAA_Enabled', options.Post_TAA_Enabled)
        .addBool('Debug_WhiteWorld', options.Debug_WhiteWorld);

    BlockMappings = new BlockMap(globalExports)
        .map('water', 'BLOCK_WATER')
        .map('lava', 'BLOCK_LAVA');

    new TagBuilder(pipeline, globalExports)
        .map("TAG_LEAVES", new NamespacedId("minecraft", "leaves"))
        .map("TAG_STAIRS", new NamespacedId("minecraft", "stairs"))
        .map("TAG_SLABS", new NamespacedId("minecraft", "slabs"));
        // .map("TAG_SNOW", new NamespacedId("minecraft", "snow"));
    
    pipeline.setGlobalExport(globalExports.build());

    ApplyLightColors(options.Lighting_ColorCandles);

    pipeline.createBuffer("scene", 1024, false);
    settings = pipeline.createStreamingBuffer("settings", 128);

    if (options.VoxelEnabled) {
        const voxelSize = cubed(options.Lighting_VoxelResolution);
        pipeline.createBuffer('VoxelMaskBuffer', voxelSize, false);
        pipeline.createBuffer('voxelTexBuffer', 8*voxelSize, true);
    }
    
    const texFinalA = pipeline.createImageTexture("texFinalA", "imgFinalA")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .clear(false)
        .build();

    const texFinalB = pipeline.createImageTexture("texFinalB", "imgFinalB")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .clear(false)
        .build();

    const texFinal_translucent = pipeline.createTexture("texFinal_translucent")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .clearColor(0, 0, 0, 0)
        .build();

    const texReprojection = pipeline.createTexture("texReprojection")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGB16F)
        // .clearColor(0, 0, 0, 0)
        .clear(false)
        .build();

    const texPosition = pipeline.createTexture("texPosition")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGB16F)
        .clear(false)
        .build();

    const texPositionPrev = pipeline.createTexture("texPositionPrev")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGB16F)
        .clear(false)
        .build();

    const finalFlipper = new BufferFlipper(texFinalA, texFinalB);

    let texVelocity : BuiltTexture | undefined;
    if (options.Post_TAA_Enabled) {
        texFinalPrevA = pipeline.createImageTexture("texFinalPrevA", "imgFinalPrevA")
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA16F)
            .clear(false)
            .build();

        texFinalPrevB = pipeline.createImageTexture("texFinalPrevB", "imgFinalPrevB")
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA16F)
            .clear(false)
            .build();

        texVelocity = pipeline.createTexture("texVelocity")
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RG16F)
            .build();
    }

    const texAlbedoGB_opaque = pipeline.createTexture('texAlbedoGB_opaque')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA8)
        .clearColor(0, 0, 0, 0)
        .build();

    const texNormalGB_opaque = pipeline.createTexture('texNormalGB_opaque')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RG32UI)
        .clearColor(0, 0, 0, 0)
        .build();

    const texMatLightGB_opaque = pipeline.createTexture('texMatLightGB_opaque')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RG32UI)
        .clearColor(0, 0, 0, 0)
        .build();

    const texAlbedoGB_translucent = pipeline.createTexture('texAlbedoGB_translucent')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA8)
        .clearColor(0, 0, 0, 0)
        .build();

    const texNormalGB_translucent = pipeline.createTexture('texNormalGB_translucent')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RG32UI)
        .clearColor(0, 0, 0, 0)
        .build();

    const texMatLightGB_translucent = pipeline.createTexture('texMatLightGB_translucent')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RG32UI)
        .clearColor(0, 0, 0, 0)
        .build();

    const texTintTranslucent = pipeline.createTexture("texTintTranslucent")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGB8)
        .clearColor(1, 1, 1, 1)
        .build();

    let texShadowColor: BuiltTexture | undefined;
    let texSkyTransmit: BuiltTexture | undefined;
    let texSkyMultiScatter: BuiltTexture | undefined;
    let texSkyView: BuiltTexture | undefined;
    let texSkyIrradiance: BuiltTexture | undefined;
    let texWetnessGB: BuiltTexture | undefined;
    let texShadowGB: BuiltTexture | undefined;
    let texSssGB: BuiltTexture | undefined;
    let texWeather: BuiltTexture | undefined;
    if (dimension.World_HasSky) {
        texWetnessGB = pipeline.createTexture('texWetnessGB')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RG16F)
            .clear(false)
            .build();

        texShadowGB = pipeline.createTexture('texShadowGB')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGB8)
            .clear(false)
            .build();

        pipeline.createImageTexture('texShadowFinal', 'imgShadowFinal')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA8)
            .clear(false)
            .build();

        texSssGB = pipeline.createTexture('texSssGB')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGB8)
            .clear(false)
            .build();

        pipeline.createImageTexture('texSssFinal', 'imgSssFinal')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA8)
            .clear(false)
            .build();

        texShadowColor = pipeline.createArrayTexture('texShadowColor')
            .format(Format.RGBA8)
            .width(renderConfig.shadow.resolution)
            .height(renderConfig.shadow.resolution)
            .clearColor(0, 0, 0, 0)
            .build();

        texWeather = pipeline.createTexture('texWeather')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA16F)
            .clearColor(0, 0, 0, 0)
            .build();

        texSkyTransmit = pipeline.createTexture('texSkyTransmit')
            .format(Format.RGB16F)
            .width(128)
            .height(64)
            .clear(false)
            .build();

        texSkyMultiScatter = pipeline.createTexture('texSkyMultiScatter')
            .format(Format.RGB16F)
            .width(32)
            .height(32)
            .clear(false)
            .build();

        texSkyView = pipeline.createTexture('texSkyView')
            .format(Format.RGB16F)
            .width(256)
            .height(256)
            .clear(false)
            .build();

        texSkyIrradiance = pipeline.createTexture('texSkyIrradiance')
            .format(Format.RGB16F)
            .width(32)
            .height(32)
            .clear(false)
            .build();
    }

    if (options.Lighting_FloodFill_Enabled) {
        floodfill = new FloodFill(pipeline, options.Lighting_FloodFill_Size);
    }

    const texDiffuse = pipeline.createImageTexture('texDiffuse', 'imgDiffuse')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .clearColor(0, 0, 0, 0)
        .build();

    const texSpecular = pipeline.createImageTexture('texSpecular', 'imgSpecular')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .clearColor(0, 0, 0, 0)
        .build();

    const Tracing_scale = Math.pow(2, options.Lighting_Resolution);
    const Tracing_width = Math.ceil(screenWidth / Tracing_scale);
    const Tracing_height = Math.ceil(screenHeight / Tracing_scale);

    const texReflect = pipeline.createTexture('texReflect')
        .width(Tracing_width)
        .height(Tracing_height)
        .format(Format.RGBA16F)
        .clearColor(0, 0, 0, 0)
        .build();

    let texGI_trace: BuiltTexture | undefined;
    let texGI_filter1: BuiltTexture | undefined;
    let texGI_filter2: BuiltTexture | undefined;
    let texGI_flipper: BufferFlipper | undefined;
    let texGI_prev: BuiltTexture | undefined;
    let texGI_final: BuiltTexture | undefined;
    if (options.Lighting_GI_Enabled) {
        texGI_trace = pipeline.createTexture('texGI_trace')
            .width(Tracing_width)
            .height(Tracing_height)
            .format(Format.RGBA16F)
            .clearColor(0, 0, 0, 0)
            .build();

        texGI_filter1 = pipeline.createImageTexture('texGI_filter1', 'imgGI_filter1')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA16F)
            .clearColor(0, 0, 0, 0)
            .build();

        texGI_filter2 = pipeline.createTexture('texGI_filter2')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA16F)
            .clear(false)
            .build();
        
        texGI_flipper = new BufferFlipper(texGI_filter1, texGI_filter2);

        texGI_final = pipeline.createTexture('texGI_final')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA16F)
            .clear(false)
            .build();

        texGI_prev = pipeline.createTexture('texGI_prev')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA16F)
            .clear(false)
            .build();
    }

    pipeline.createImageTexture('texHistogram', 'imgHistogram')
        .format(Format.R32UI)
        .width(256)
        .clear(false)
        .build();

    let texDebug: BuiltTexture | undefined;
    if (DEBUG || DEBUG_LIGHT_TILES) {
        texDebug = pipeline.createImageTexture('texDebug', 'imgDebug')
            .format(Format.RGBA8)
            .width(screenWidth)
            .height(screenHeight)
            .clear(true)
            .build();
    }

    pipeline.importPNGTexture('texBlueNoise', 'textures/blue_noise.png', true, false);

    //if (_dimensions.Index == 0) {
        pipeline.importPNGTexture('texMoon', 'textures/moon.png', true, false);
    //}


    withStage(pipeline, Stage.SCREEN_SETUP, setupStage => {
        setupStage.createCompute("setup-scene")
            .location("setup/scene-setup", "setupScene")
            .workGroups(1, 1, 1)
            .overrideObject('scene_writer', 'scene')
            .compile();

        if (!options.Debug_Histogram) {
            setupStage.createCompute('histogram-clear')
                .location('setup/histogram-clear', "clearHistogram")
                .workGroups(1, 1, 1)
                .compile();
        }

        if (dimension.World_HasSky) {
            setupStage.createComposite('sky-transmit')
                .location('setup/sky-transmit', 'bakeSkyTransmission')
                .target(0, texSkyTransmit)
                .exportInt('BufferWidth', texSkyTransmit.width())
                .exportInt('BufferHeight', texSkyTransmit.height())
                .compile();

            setupStage.createComposite('sky-multi-scatter')
                .location('setup/sky-multi-scatter', 'bakeSkyMultiScattering')
                .target(0, texSkyMultiScatter)
                .compile();
        }
    });


    withStage(pipeline, Stage.PRE_RENDER, beginStage => {
        beginStage.createCompute("begin-scene")
            .location("pre/scene-begin", "beginScene")
            .workGroups(1, 1, 1)
            .overrideObject('scene_writer', 'scene')
            .compile();

        if (options.VoxelEnabled) {
            const voxelSize = options.Lighting_VoxelResolution / 8;
            beginStage.createCompute("begin-voxel-mask")
                .location("pre/voxel-mask", "buildVoxelMask")
                .workGroups(
                    Math.ceil(voxelSize),
                    Math.ceil(voxelSize),
                    Math.ceil(voxelSize))
                .compile();
        }

        // beginStage.createCompute("clear-screen")
        //     .location("pre/clear-screen", "clearScreen")
        //     .workGroups(
        //         Math.ceil(screenWidth / 16),
        //         Math.ceil(screenHeight / 16),
        //         1)
        //     .compile();

        if (dimension.World_HasSky) {
            beginStage.createComposite('sky-view')
                .location('pre/sky-view', 'bakeSkyView')
                .target(0, texSkyView)
                .exportInt('BufferWidth', texSkyView.width())
                .exportInt('BufferHeight', texSkyView.height())
                .compile();

            beginStage.createComposite('sky-irradiance')
                .location('pre/sky-irradiance', 'bakeSkyIrradiance')
                .target(0, texSkyIrradiance)
                .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
                .exportInt('BufferWidth', texSkyIrradiance.width())
                .exportInt('BufferHeight', texSkyIrradiance.height())
                .compile();
        }

        if (options.Lighting_FloodFill_Enabled) {
            floodfill.create(beginStage, options.Lighting_FloodFill_Size);
        }
    });


    function discardShader(name: string, usage: ProgramUsage) {
        pipeline.createObjectShader(name, usage)
            .location('objects/discard').compile();
    }

    function shadowSkyShader(name: string, usage: ProgramUsage) {
        return pipeline.createObjectShader(name, usage)
            .location('objects/shadow_sky');
            // .target(0, texShadowColor).blendOff(0);
    }

    if (dimension.World_HasSky) {
        shadowSkyShader("shadow-sky", Usage.SHADOW).compile();

        shadowSkyShader('shadow-sky-terrain-solid', Usage.SHADOW_TERRAIN_SOLID)
            .exportBool('RENDER_TERRAIN', true)
            .target(0, texShadowColor).blendOff(0)
            .compile();

        shadowSkyShader('shadow-sky-terrain-cutout', Usage.SHADOW_TERRAIN_CUTOUT)
            .exportBool('RENDER_TERRAIN', true)
            .exportBool('ALPHATEST_ENABLED', true)
            .target(0, texShadowColor).blendOff(0)
            .compile();

        shadowSkyShader('shadow-sky-terrain-translucent', Usage.SHADOW_TERRAIN_TRANSLUCENT)
            .exportBool('RENDER_TERRAIN', true)
            .exportBool('ALPHATEST_ENABLED', true)
            .target(0, texShadowColor).blendOff(0)
            .compile();

        type ShadowPass = [string, ProgramUsage];
        [
            // ['shadow-sky-terrain-cutout', Usage.SHADOW_TERRAIN_CUTOUT],
            // ['shadow-sky-terrain-translucent', Usage.SHADOW_TERRAIN_TRANSLUCENT],
            ['shadow-sky-entity-cutout', Usage.SHADOW_ENTITY_CUTOUT],
            ['shadow-sky-entity-translucent', Usage.SHADOW_ENTITY_TRANSLUCENT],
            ['shadow-sky-blockentity-translucent', Usage.SHADOW_BLOCK_ENTITY_TRANSLUCENT],
        ].forEach((pass: ShadowPass) => {
            shadowSkyShader(pass[0], pass[1])
                .exportBool('ALPHATEST_ENABLED', true)
                .target(0, texShadowColor).blendOff(0)
                .compile();
        });
    }

    if (options.Lighting_Point_Enabled) {
        pipeline.createObjectShader('shadow-point', Usage.POINT)
            .location("objects/shadow_point")
            .exportBool('EmissionMask', options.Lighting_Point_EmissionMask)
            .compile();
    }
    
    discardShader("sky-discard", Usage.SKYBOX);
    discardShader("sky-texture-discard", Usage.SKY_TEXTURES);
    discardShader("cloud-discard", Usage.CLOUDS);

    function opaqueObjectShader(name: string, usage: ProgramUsage) {
        const shader = pipeline.createObjectShader(name, usage)
            .location("objects/opaque")
            .exportBool('Parallax_Enabled', options.Material_Parallax_Enabled)
            .exportInt('Parallax_Type', options.Material_Parallax_Type)
            .exportInt('Parallax_SampleCount', options.Material_Parallax_SampleCount)
            .exportBool('Parallax_Optimize', options.Material_Parallax_Optimize)
            .exportBool('Material_SmoothNormals', options.Material_Normals_Smooth)
            .target(0, texAlbedoGB_opaque).blendOff(0)//.blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .target(1, texNormalGB_opaque).blendOff(1)
            .target(2, texMatLightGB_opaque).blendOff(2);

        if (options.Post_TAA_Enabled) shader.target(3, texVelocity).blendOff(3);
        return shader;
    }

    opaqueObjectShader("basic-opaque", Usage.BASIC).compile();
    
    opaqueObjectShader("terrain-solid", Usage.TERRAIN_SOLID)
        .exportBool('RENDER_TERRAIN', true)
        .compile();

    opaqueObjectShader("terrain-cutout", Usage.TERRAIN_CUTOUT)
        .exportBool('RENDER_TERRAIN', true)
        .compile();

    opaqueObjectShader("entity-solid", Usage.ENTITY_SOLID)
        .exportBool('RENDER_ENTITY', true)
        .compile();

    discardShader('shit', Usage.EMISSIVE);
    
    opaqueObjectShader("entity-cutout", Usage.ENTITY_CUTOUT)
        .exportBool('RENDER_ENTITY', true)
        .compile();

    // opaqueObjectShader("entity-translucent", Usage.ENTITY_TRANSLUCENT)
    //     .exportBool('RENDER_ENTITY', true)
    //     .compile();

    opaqueObjectShader("blockentity-cutout", Usage.BLOCK_ENTITY).compile();

    opaqueObjectShader("hand", Usage.HAND).compile();

    opaqueObjectShader("text", Usage.TEXT)
        .exportBool('RENDER_TEXT', true)
        .compile();

    // opaqueObjectShader("basic-opaque", Usage.PARTICLES_TRANSLUCENT)
    //     .exportBool('RENDER_PARTICLES', true)
    //     .compile();

    function translucentObjectShader(name: string, usage: ProgramUsage) {
        const shader = pipeline.createObjectShader(name, usage)
            .location("objects/translucent")
            .exportBool('Parallax_Enabled', options.Material_Parallax_Enabled)
            .exportInt('Parallax_Type', options.Material_Parallax_Type)
            .exportInt('Parallax_SampleCount', options.Material_Parallax_SampleCount)
            .exportBool('Parallax_Optimize', options.Material_Parallax_Optimize)
            .exportBool('Material_SmoothNormals', options.Material_Normals_Smooth)
            .target(0, texAlbedoGB_translucent).blendOff(0)//.blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .target(1,  texTintTranslucent).blendOff(1)
            .target(2, texNormalGB_translucent).blendOff(2)
            .target(3, texMatLightGB_translucent).blendOff(3);

        //if (options.Post_TAA_Enabled) shader.target(4, texVelocity).blendOff(1);
        return shader;
    }

    translucentObjectShader("terrain-translucent", Usage.TERRAIN_TRANSLUCENT)
        .exportBool('Water_WaveEnabled', options.Water_WavesEnabled)
        .exportBool('RENDER_TERRAIN', true)
        .compile();

    // translucentObjectShader("entity-solid", Usage.ENTITY_SOLID).compile();
    
    // translucentObjectShader("entity-cutout", Usage.ENTITY_CUTOUT).compile();

    translucentObjectShader("entity-translucent", Usage.ENTITY_TRANSLUCENT)
        .exportBool('RENDER_ENTITY', true)
        .compile();

    translucentObjectShader("blockentity-translucent", Usage.BLOCK_ENTITY_TRANSLUCENT).compile();

    translucentObjectShader("hand-translucent", Usage.TRANSLUCENT_HAND).compile();

    // translucentObjectShader("text", Usage.TEXT).compile();

    translucentObjectShader("particles", Usage.PARTICLES)
        .exportBool('RENDER_PARTICLES', true)
        .compile();

    if (dimension.World_HasSky) {
        pipeline.createObjectShader("weather", Usage.WEATHER)
            .location("objects/weather")
            .target(0, texWeather).blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .compile();
    }
    
    withStage(pipeline, Stage.POST_RENDER, postRenderStage => {
        postRenderStage.createComposite("reprojection-opaque")
            .location("composite/reproject", "reprojectScene")
            .target(0, texReprojection)
            .target(1, texPosition)
            .overrideObject('texDepth', 'solidDepthTex')
            .compile();
        
        postRenderStage.copy(texPosition, texPositionPrev, screenWidth, screenHeight);

        withSubList(postRenderStage, 'opaque-deferred', opaqueStage => {
            if (dimension.World_HasSky) {
                opaqueStage.createComposite("deferred-sky-wetness")
                    .location("deferred/sky-wetness", "skyWetness")
                    .target(0, texWetnessGB)
                    .overrideObject('texDepth', 'solidDepthTex')
                    .overrideObject('texAlbedoGB', texAlbedoGB_opaque.name())
                    .overrideObject('texNormalGB', texNormalGB_opaque.name())
                    .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                    .compile();
            }

            opaqueStage.createComposite("deferred-lighting-block-hand")
                .location("deferred/lighting-block-hand", "lightingBlockHand")
                .target(0, texDiffuse)
                .target(1, texSpecular)
                .overrideObject('texDepth', 'solidDepthTex')
                .overrideObject('texAlbedoGB', texAlbedoGB_opaque.name())
                .overrideObject('texNormalGB', texNormalGB_opaque.name())
                .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                .compile();

            if (dimension.World_HasSky) {
                opaqueStage.createComposite("deferred-sky-shadow")
                    .location("deferred/sky-shadow", "skyShadowSss")
                    .target(0, texShadowGB)
                    .target(1, texSssGB)
                    .overrideObject('texDepth', 'solidDepthTex')
                    .overrideObject('texAlbedoGB', texAlbedoGB_opaque.name())
                    .overrideObject('texNormalGB', texNormalGB_opaque.name())
                    .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                    .exportFloat('Shadow_MaxRadius', options.Shadow_MaxRadius)
                    .exportInt('Shadow_PcssSamples', options.Shadow_PcssSamples)
                    .exportInt('Shadow_PcfSamples', options.Shadow_PcfSamples)
                    .exportFloat('Shadow_SssMaxDist', options.Shadow_SssMaxDist)
                    .exportFloat('Shadow_SssMaxRadius', options.Shadow_SssMaxRadius)
                    .exportInt('Shadow_SssPcfSamples', options.Shadow_SssPcfSamples)
                    .compile();

                opaqueStage.createCompute("deferred-sky-shadow-filter")
                    .location("deferred/sky-shadow-filter", "filterShadowSss")
                    .workGroups(
                        Math.ceil(screenWidth / 16),
                        Math.ceil(screenHeight / 16),
                        1)
                    .overrideObject('texDepth', 'solidDepthTex')
                    .compile();

                opaqueStage.createComposite("deferred-sky-lighting")
                    .location("deferred/sky-lighting", "lightingSky")
                    .target(0, texDiffuse).blendFunc(0, Func.ONE, Func.ONE, Func.ONE, Func.ONE)
                    .target(1, texSpecular).blendFunc(1, Func.ONE, Func.ONE, Func.ONE, Func.ONE)
                    .overrideObject('texDepth', 'solidDepthTex')
                    .overrideObject('texAlbedoGB', texAlbedoGB_opaque.name())
                    .overrideObject('texNormalGB', texNormalGB_opaque.name())
                    .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                    .exportBool('Reflect_Rough', options.Lighting_Reflection_Rough)
                    .exportBool('Lighting_GI', options.Lighting_GI_Enabled)
                    .compile();
            }

            if (options.Lighting_Point_Enabled) {
                opaqueStage.createCompute("deferred-lighting-block-point")
                    .location("deferred/lighting-block-point", "applyPointLights")
                    .workGroups(
                        Math.ceil(screenWidth / 16.0),
                        Math.ceil(screenHeight / 16.0),
                        1)
                    .overrideObject('texDepth', 'solidDepthTex')
                    .overrideObject('texAlbedoGB', texAlbedoGB_opaque.name())
                    .overrideObject('texNormalGB', texNormalGB_opaque.name())
                    .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                    .exportBool('DEBUG_LIGHT_TILES', DEBUG_LIGHT_TILES)
                    // .exportInt('BufferWidth', screenWidth)
                    // .exportInt('BufferHeight', Tracing_height)
                    // .exportInt('BufferScale', Tracing_scale)
                    .compile();
            }

            if (options.Lighting_GI_Enabled) {
                withSubList(opaqueStage, 'opaque-deferred-gi', stage_opaque_gi => {
                    stage_opaque_gi.createComposite("deferred-gi")
                        .location('deferred/gi/gi-trace', "applyGI")
                        .target(0, texGI_trace)
                        .overrideObject('texAlbedoGB', texAlbedoGB_opaque.name())
                        .overrideObject('texNormalGB', texNormalGB_opaque.name())
                        .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                        .exportInt('GI_VoxelStepCount', options.Lighting_GI_VoxelSteps)
                        .exportInt('GI_ScreenStepCount', options.Lighting_GI_ScreenSteps)
                        .exportInt('GI_RefineStepCount', options.Lighting_GI_RefineSteps)
                        .exportBool('GI_ScreenTrace', options.Lighting_GI_ScreenTrace)
                        .exportInt('GI_SampleCount', options.Lighting_GI_Samples)
                        .exportInt('BufferWidth', Tracing_width)
                        .exportInt('BufferHeight', Tracing_height)
                        .exportInt('BufferScale', Tracing_scale)
                        .compile();

                    if (options.Lighting_Resolution != 0) {
                        stage_opaque_gi.createCompute("deferred-gi-upscale")
                            .location('deferred/gi/gi-upscale', "upscaleGI")
                            .workGroups(
                                Math.ceil(screenWidth / 16),
                                Math.ceil(screenHeight / 16),
                                1)
                            .overrideObject('imgDest', texGI_filter1.imageName())
                            .overrideObject('texSource', texGI_trace.name())
                            .overrideObject('texDepth', 'solidDepthTex')
                            .exportInt('BufferWidth', Tracing_width)
                            .exportInt('BufferHeight', Tracing_height)
                            .exportInt('BufferScale', Tracing_scale)
                            .compile();
                    }

                    for (let i = 0; i < options.Lighting_GI_FilterPasses; i++) {
                        let filter_src: string;
                        if (i == 0) {
                            if (options.Lighting_Resolution != 0) {
                                filter_src = texGI_filter1.name();
                            }
                            else {
                                filter_src = texGI_trace.name();
                            }
                        }
                        else {
                            texGI_flipper.flip();
                            filter_src = texGI_flipper.getReadTexture().name();
                        }

                        stage_opaque_gi.createComposite(`deferred-gi-atrous-${i+1}`)
                            .location('deferred/gi/gi-atrous', "atrousFilter")
                            .target(0, texGI_flipper.getWriteTexture())
                            .overrideObject('texSource', filter_src)
                            .overrideObject('texNormalGB', texNormalGB_opaque.name())
                            .exportInt('AtrousLevel', i)
                            .compile();
                    }

                    let final_src: string = texGI_trace.name();
                    if (options.Lighting_GI_FilterPasses > 0 || options.Lighting_Resolution != 0) {
                        texGI_flipper.flip();
                        final_src = texGI_flipper.getReadTexture().name();
                    }

                    stage_opaque_gi.createComposite("deferred-gi-accumulate")
                        .location('deferred/gi/gi-accumulate', "accumulateGI")
                        .target(0, texGI_final)
                        .overrideObject('texSource', final_src)
                        .overrideObject('texDepth', 'solidDepthTex')
                        .overrideObject('texNormalGB', texNormalGB_opaque.name())
                        .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                        .exportInt('GI_MaxFrames', options.Lighting_GI_MaxFrames)
                        .compile();

                    stage_opaque_gi.copy(texGI_final, texGI_prev, screenWidth, screenHeight);
                });
            }

            finalFlipper.flip();
            
            opaqueStage.createComposite("deferred-lighting-final")
                .location("deferred/lighting-final", "lightingFinal")
                .target(0, finalFlipper.getWriteTexture())
                .overrideObject('texDepth', 'solidDepthTex')
                .overrideObject('texAlbedoGB', texAlbedoGB_opaque.name())
                .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                .exportBool('Lighting_GI', options.Lighting_GI_Enabled)
                .compile();

            if (options.Lighting_Reflection_Mode == ReflectMode.WorldSpace || options.Lighting_Reflection_Mode == ReflectMode.ScreenSpace) {
                finalFlipper.flip();

                const location = options.Lighting_Reflection_Mode == ReflectMode.WorldSpace
                    ? 'deferred/reflect_voxel' : 'deferred/reflect_screen';

                opaqueStage.createComposite("opaque-reflections")
                    .location(location, "applyReflections")
                    .target(0, texReflect)
                    .overrideObject('texSource', finalFlipper.getReadTexture().name())
                    .overrideObject('texAlbedoGB', texAlbedoGB_opaque.name())
                    .overrideObject('texNormalGB', texNormalGB_opaque.name())
                    .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                    .exportBool('Reflect_Rough', options.Lighting_Reflection_Rough)
                    .exportBool('Reflect_SS_Fallback', options.Lighting_Reflection_ScreenSpaceFallback)
                    .exportInt('Reflect_VoxelSteps', options.Lighting_Reflection_VoxelSteps)
                    .exportInt('Reflect_ScreenSteps', options.Lighting_Reflection_ScreenSteps)
                    .exportInt('Reflect_RefineSteps', options.Lighting_Reflection_RefineSteps)
                    .exportInt('BufferWidth', Tracing_width)
                    .exportInt('BufferHeight', Tracing_height)
                    .exportInt('BufferScale', Tracing_scale)
                    .compile();
                
                // TODO: accumulate and upscale
                opaqueStage.createComposite('opaque-reflection-overlay')
                    .location('deferred/reflect_overlay', 'overlayReflections')
                    .target(0, finalFlipper.getWriteTexture())
                    .overrideObject('texSource', finalFlipper.getReadTexture().name())
                    .exportInt('BufferWidth', Tracing_width)
                    .exportInt('BufferHeight', Tracing_height)
                    .exportInt('BufferScale', Tracing_scale)
                    .compile();
            }
        });

        withSubList(postRenderStage, 'translucent-deferred', translucentStage => {
            translucentStage.createComposite("deferred-lighting-block-hand")
                .location("deferred/lighting-block-hand", "lightingBlockHand")
                .target(0, texDiffuse)
                .target(1, texSpecular)
                .overrideObject('texDepth', 'mainDepthTex')
                .overrideObject('texAlbedoGB', texAlbedoGB_translucent.name())
                .overrideObject('texNormalGB', texNormalGB_translucent.name())
                .overrideObject('texMatLightGB', texMatLightGB_translucent.name())
                .compile();

            if (dimension.World_HasSky) {
                translucentStage.createComposite("deferred-sky-shadow")
                    .location("deferred/sky-shadow", "skyShadowSss")
                    .target(0, texShadowGB)
                    .target(1, texSssGB)
                    .overrideObject('texDepth', 'mainDepthTex')
                    .overrideObject('texAlbedoGB', texAlbedoGB_translucent.name())
                    .overrideObject('texNormalGB', texNormalGB_translucent.name())
                    .overrideObject('texMatLightGB', texMatLightGB_translucent.name())
                    .exportFloat('Shadow_MaxRadius', options.Shadow_MaxRadius)
                    .exportInt('Shadow_PcssSamples', options.Shadow_PcssSamples)
                    .exportInt('Shadow_PcfSamples', options.Shadow_PcfSamples)
                    .exportFloat('Shadow_SssMaxDist', options.Shadow_SssMaxDist)
                    .exportFloat('Shadow_SssMaxRadius', options.Shadow_SssMaxRadius)
                    .exportInt('Shadow_SssPcfSamples', options.Shadow_SssPcfSamples)
                    .compile();

                translucentStage.createCompute("deferred-sky-shadow-filter")
                    .location("deferred/sky-shadow-filter", "filterShadowSss")
                    .workGroups(
                        Math.ceil(screenWidth / 16),
                        Math.ceil(screenHeight / 16),
                        1)
                    .overrideObject('texDepth', 'mainDepthTex')
                    .compile();

                translucentStage.createComposite("deferred-sky-lighting")
                    .location("deferred/sky-lighting", "lightingSky")
                    .target(0, texDiffuse).blendFunc(0, Func.ONE, Func.ONE, Func.ONE, Func.ONE)
                    .target(1, texSpecular).blendFunc(1, Func.ONE, Func.ONE, Func.ONE, Func.ONE)
                    .overrideObject('texDepth', 'mainDepthTex')
                    .overrideObject('texAlbedoGB', texAlbedoGB_translucent.name())
                    .overrideObject('texNormalGB', texNormalGB_translucent.name())
                    .overrideObject('texMatLightGB', texMatLightGB_translucent.name())
                    .exportBool('Reflect_Rough', options.Lighting_Reflection_Rough)
                    .exportBool('Lighting_GI', options.Lighting_GI_Enabled)
                    .exportBool('RENDER_TRANSLUCENT', true)
                    .compile();
            }

            if (options.Lighting_Point_Enabled) {
                translucentStage.createCompute("deferred-lighting-block-point")
                    .location("deferred/lighting-block-point", "applyPointLights")
                    .workGroups(
                        Math.ceil(screenWidth / 16.0),
                        Math.ceil(screenHeight / 16.0),
                        1)
                    .overrideObject('texDepth', 'mainDepthTex')
                    .overrideObject('texAlbedoGB', texAlbedoGB_translucent.name())
                    .overrideObject('texNormalGB', texNormalGB_translucent.name())
                    .overrideObject('texMatLightGB', texMatLightGB_translucent.name())
                    .exportBool('DEBUG_LIGHT_TILES', DEBUG_LIGHT_TILES)
                    .compile();
            }
            
            translucentStage.createComposite("deferred-lighting-final")
                .location("deferred/lighting-final", "lightingFinal")
                .target(0, texFinal_translucent)
                .overrideObject('texDepth', 'mainDepthTex')
                .overrideObject('texAlbedoGB', texAlbedoGB_translucent.name())
                .overrideObject('texMatLightGB', texMatLightGB_translucent.name())
                .exportBool('RENDER_TRANSLUCENT', true)
                .compile();
        });

        withSubList(postRenderStage, 'translucent-composite', compositeStage => {
            finalFlipper.flip();

            let location = options.Lighting_Refraction_Mode == RefractMode.WorldSpace
                ? "composite/overlay_voxel" : "composite/overlay_screen";
            
            compositeStage.createComposite("composite-overlays")
                .location(location, "applyOverlays")
                .target(0, finalFlipper.getWriteTexture())
                .overrideObject('texFinal_opaque', finalFlipper.getReadTexture().name())
                .exportBool('Refract_SS_Fallback', options.Lighting_Refraction_ScreenSpaceFallback)
                .exportBool('Refract_Rough', options.Lighting_Refraction_Rough)
                .exportInt('Refract_VoxelSteps', options.Lighting_Refraction_VoxelSteps)
                .exportInt('Refract_ScreenSteps', options.Lighting_Refraction_ScreenSteps)
                .exportInt('Refract_RefineSteps', options.Lighting_Refraction_RefineSteps)
                .compile();

            if (options.Lighting_Reflection_Mode == ReflectMode.WorldSpace || options.Lighting_Reflection_Mode == ReflectMode.ScreenSpace) {
                finalFlipper.flip();

                let location = options.Lighting_Reflection_Mode == ReflectMode.WorldSpace
                    ? "composite/reflect_voxel" : "composite/reflect_screen";

                compositeStage.createComposite("translucent-reflections")
                    .location(location, "applyReflections")
                    .target(0, texReflect)
                    .overrideObject('texSource', finalFlipper.getReadTexture().name())
                    .exportBool('Reflect_SS_Fallback', options.Lighting_Reflection_ScreenSpaceFallback)
                    .exportBool('Reflect_Rough', options.Lighting_Reflection_Rough)
                    .exportInt('Reflect_VoxelSteps', options.Lighting_Reflection_VoxelSteps)
                    .exportInt('Reflect_ScreenSteps', options.Lighting_Reflection_ScreenSteps)
                    .exportInt('Reflect_RefineSteps', options.Lighting_Reflection_RefineSteps)
                    .exportInt('BufferWidth', Tracing_width)
                    .exportInt('BufferHeight', Tracing_height)
                    .exportInt('BufferScale', Tracing_scale)
                    .compile();
                
                // TODO: accumulate and upscale
                compositeStage.createComposite('translucent-reflection-overlay')
                    .location('composite/reflect_overlay', 'overlayReflections')
                    .target(0, finalFlipper.getWriteTexture())
                    .overrideObject('texSource', finalFlipper.getReadTexture().name())
                    .exportInt('BufferWidth', Tracing_width)
                    .exportInt('BufferHeight', Tracing_height)
                    .exportInt('BufferScale', Tracing_scale)
                    .compile();
            }
        });

        withSubList(postRenderStage, 'final', finalStage => {
            finalFlipper.flip();
                
            if (options.Debug_Histogram) {
                finalStage.createCompute('histogram-clear')
                    .location('setup/histogram-clear', "clearHistogram")
                    .workGroups(1, 1, 1)
                    .compile();
            }

            finalStage.createCompute('histogram')
                .location('post/histogram-exposure', "buildHistogram")
                .workGroups(
                    Math.ceil(screenWidth / 16.0),
                    Math.ceil(screenHeight / 16.0),
                    1)
                .overrideObject('texSource', finalFlipper.getReadTexture().name())
                .compile();

            finalStage.createCompute('exposure-compute')
                .location('post/histogram-exposure', "computeExposure")
                .workGroups(1, 1, 1)
                .overrideObject('scene_writer', 'scene')
                .exportBool("DEBUG_HISTOGRAM", options.Debug_Histogram)
                .compile();

            finalStage.createComposite("exposure-apply")
                .location("post/expose", "applyExposure")
                .target(0, finalFlipper.getWriteTexture())
                .overrideObject("texSource", finalFlipper.getReadTexture().name())
                .compile();

            if (options.Post_Bloom_Enabled) {
                finalFlipper.flip();

                const screenWidth_half = Math.ceil(screenWidth / 2.0);
                const screenHeight_half = Math.ceil(screenHeight / 2.0);
            
                let maxLod = Math.log2(Math.min(screenWidth, screenHeight));
                maxLod = Math.floor(maxLod - 1);
                maxLod = Math.max(Math.min(maxLod, 12), 0);
            
                const texBloom = pipeline.createTexture('texBloom')
                    .format(Format.RGB16F)
                    .width(screenWidth_half)
                    .height(screenHeight_half)
                    .mipmap(true)
                    .clear(false)
                    .build();
            
                withSubList(finalStage, 'Bloom', bloomStage => {
                    for (let i = 0; i < maxLod; i++) {
                        bloomStage.createComposite(`bloom-down-${i}`)
                            .location("post/bloom", "applyBloomDown")
                            .target(0, texBloom, i)
                            .overrideObject("texSource", i == 0 ? finalFlipper.getReadTexture().name() : 'texBloom')
                            .exportInt("MIP_INDEX", Math.max(i-1, 0))
                            .compile();
                    }
                
                    for (let i = maxLod-1; i >= 0; i--) {
                        const bloomUpShader = bloomStage.createComposite(`bloom-up-${i}`)
                            .location('post/bloom', "applyBloomUp")
                            .overrideObject("texSource", finalFlipper.getReadTexture().name())
                            .exportInt("BLOOM_INDEX", i)
                            .exportInt("MIP_INDEX", Math.max(i, 0));
                            
                        if (i == 0) {
                            bloomUpShader.target(0, finalFlipper.getWriteTexture())
                                .blendFunc(0, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO);
                        }
                        else {
                            bloomUpShader.target(0, texBloom, i-1)
                                .blendFunc(0, Func.ONE, Func.ONE, Func.ONE, Func.ONE);
                        }

                        bloomUpShader.compile();
                    }
                });
            }

            if (options.Post_TAA_Enabled) {
                texFinalPrevRef = pipeline.createTextureReference("texFinalPrev", null, screenWidth, screenHeight, 1, Format.RGBA16F);
                imgFinalPrevRef = pipeline.createTextureReference(null, "imgFinalPrev", screenWidth, screenHeight, 1, Format.RGBA16F);

                finalFlipper.flip();

                finalStage.createCompute("taa")
                    .location("post/taa", "applyTaa")
                    .workGroups(
                        Math.ceil(screenWidth / 16),
                        Math.ceil(screenHeight / 16),
                        1)
                    .overrideObject("texSource", finalFlipper.getReadTexture().name())
                    .overrideObject("imgFinal", finalFlipper.getWriteTexture().imageName())
                    .overrideObject('texDepth', 'solidDepthTex')
                    .exportBool('TAA_SharpenHistory', options.Post_TAA_CubicHistory)
                    .compile();
            }

            finalFlipper.flip();

            finalStage.createComposite("tonemap")
                .location("post/tonemap", "applyTonemap")
                .target(0, finalFlipper.getWriteTexture())
                .overrideObject("texSource", finalFlipper.getReadTexture().name())
                .compile();

            if (options.Post_TAA_Enabled) {
                finalFlipper.flip();

                finalStage.createCompute("sharpen")
                    .location("post/sharpen", "sharpen")
                    .workGroups(
                        Math.ceil(screenWidth / 16),
                        Math.ceil(screenHeight / 16),
                        1)
                    .overrideObject("texSource", finalFlipper.getReadTexture().name())
                    .overrideObject("imgFinal", finalFlipper.getWriteTexture().imageName())
                    .compile();
            }

            if (options.Debug_Material > 0 || options.Debug_Histogram || DEBUG_LIGHT_TILES) {
                finalStage.createComposite("debug")
                    .location("post/debug", "renderDebugOverlay")
                    .target(0, finalFlipper.getWriteTexture())
                    .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
                    .overrideObject('texAlbedoGB', texAlbedoGB_opaque.name())
                    .overrideObject('texNormalGB', texNormalGB_opaque.name())
                    .overrideObject('texMatLightGB', texMatLightGB_opaque.name())
                    .exportInt('DEBUG_MATERIAL', options.Debug_Material)
                    .exportBool('DEBUG_HISTOGRAM', options.Debug_Histogram)
                    .compile();
            }
        });
    });

    finalFlipper.flip();

    pipeline.createCombinationPass("post/final")
        .overrideObject("texFinal", finalFlipper.getReadTexture().name())
        .compile();

    // HACK: this isn't always called on reload!
    onSettingsChanged(pipeline);
}

export function beginFrame(state : WorldState) : void {
    const options = new Options();
    const alt = state.currentFrame() % 2 == 1;
    
    if (texFinalPrevRef && options.Post_TAA_Enabled) {
        texFinalPrevRef.pointTo(alt ? texFinalPrevA : texFinalPrevB);
        imgFinalPrevRef.pointTo(alt ? texFinalPrevB : texFinalPrevA);
    }

    if (floodfill && options.Lighting_FloodFill_Enabled) {
        floodfill.update(alt);
    }

    settings.uploadData();
}

export function onSettingsChanged(pipeline: PipelineConfig) {
    const options = new Options();

    _renderConfig.sunPathRotation = options.Shadow_Angle;

    new StreamingBufferBuilder(settings)
        .appendFloat(options.Sky_SeaLevel)
        .appendInt(options.Water_WaveDetail)
        .appendFloat(options.Water_WaveSize * 0.01)
        .appendFloat(options.Material_Parallax_Depth * 0.01)
        .appendFloat(options.Post_Bloom_Strength * 0.01)
        .appendFloat(options.Post_ToneMap_Contrast * 0.01)
        .appendFloat(options.Post_Exposure_Min)
        .appendFloat(options.Post_Exposure_Max)
        .appendFloat(options.Post_Exposure_Range)
        .appendFloat(options.Post_TAA_CasStrength * 0.01);
}

export function getBlockId(block: BlockState) : number {
    const name = block.getName();
    const meta = BlockMappings.get(name);
    if (meta) return meta.index;

    return 0;
}

type CommandListAction = (list: CommandList) => void;

// declare global {
//     interface PipelineConfig {
//         withStage(stage: ProgramStage, action: CommandListAction): void;
//     }

//     interface CommandList {
//         withSubList(name: string, action: CommandListAction): void;
//     }
// }

// PipelineConfig.prototype.withStage = function(this: PipelineConfig, stage: ProgramStage, action: CommandListAction): void {
//     const list = this.forStage(stage);
//     action(list);
//     list.end();
// };

// CommandList.prototype.withSubList = function(this: CommandList, name: string, action: CommandListAction): void {
//     const list = this.subList(name);
//     action(list);
//     list.end();
// };

function withStage(context: PipelineConfig, stage: ProgramStage, action: CommandListAction): void {
    const list = context.forStage(stage);
    action(list);
    list.end();
}

function withSubList(context: CommandList, name: string, action: CommandListAction): void {
    const list = context.subList(name);
    action(list);
    list.end();
}

function cubed(x) {return x*x*x;}
