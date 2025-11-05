import {Options} from "./scripts/Options";
import {BlockMap} from "./scripts/BlockMap";
import {Dimensions} from "./scripts/Dimensions";
import {FloodFill} from "./scripts/FloodFill";
import {BufferFlipper} from "./scripts/BufferFlipper";
import {StreamingBufferBuilder} from "./scripts/StreamingBufferBuilder";
import {ApplyLightColors} from "./scripts/Lights";


const DEBUG_LIGHT_TILES = false;

let dimension: Dimensions;
let BlockMappings: BlockMap;
let floodfill: FloodFill | undefined;

let texFinalPrevA: BuiltTexture | undefined;
let texFinalPrevB: BuiltTexture | undefined;
let texFinalPrevRef: ActiveTextureReference | undefined;
let imgFinalPrevRef: ActiveTextureReference | undefined;
let settings: BuiltStreamingBuffer | undefined;

let _renderConfig: RendererConfig;

const Refract_WorldSpace = 2;
const Refract_ScreenSpace = 1;
const Refract_None = 0;


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

    BlockMappings = new BlockMap();
    BlockMappings.map('water', 'BLOCK_WATER');
    BlockMappings.map('lava', 'BLOCK_LAVA');

    const globalExports = pipeline.createExportList()
        .addInt('DIMENSION', dimension.Index)
        .addBool('World_HasSky', dimension.World_HasSky)
        .addFloat('BLOCK_LUX', 200)
        .addInt('MATERIAL_FORMAT', options.Material_Format)
        .addInt('Shadow_Resolution', options.Shadow_Resolution)
        .addInt('SHADOW_CASCADE_COUNT', 4)
        .addInt('ReflectMode', options.Lighting_Reflection_Mode)
        .addInt('RefractMode', options.Lighting_Refraction_Mode)
        .addBool('FloodFill_Enabled', options.Lighting_FloodFill_Enabled)
        .addInt('FloodFill_BufferSize', options.Lighting_FloodFill_Size)
        .addBool('PointLight_Enabled', options.Lighting_Point_Enabled)
        .addInt('PointLight_MaxCount', renderConfig.pointLight.maxCount)
        .addBool('TAA_Enabled', options.Post_TAA_Enabled)
        .addBool('Debug_WhiteWorld', options.Debug_WhiteWorld);

    for (let blockName in BlockMappings.mappings) {
        const meta = BlockMappings.get(blockName);
        globalExports.addInt(meta.define, meta.index);
    }
        
    pipeline.setGlobalExport(globalExports.build());

    ApplyLightColors(options.Lighting_ColorCandles);

    pipeline.createBuffer("scene", 1024, false);
    settings = pipeline.createStreamingBuffer("settings", 128);

    const texFinalA = pipeline.createImageTexture("texFinalA", "imgFinalA")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .build();

    const texFinalB = pipeline.createImageTexture("texFinalB", "imgFinalB")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .build();

    const finalFlipper = new BufferFlipper(texFinalA, texFinalB);

    const texFinalTranslucent = pipeline.createTexture("texFinalTranslucent")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .clearColor(0, 0, 0, 0)
        .build();

    const texTintTranslucent = pipeline.createTexture("texTintTranslucent")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGB8)
        .clearColor(1, 1, 1, 1)
        .build();

    const texDataTranslucent = pipeline.createTexture("texDataTranslucent")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.R32UI)
        .clearColor(0, 0, 0, 0)
        .build();

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

    // const texPositionGB = pipeline.createTexture('texPositionGB')
    //     .width(screenWidth)
    //     .height(screenHeight)
    //     .format(Format.RGB16F)
    //     .clearColor(0, 0, 0, 0)
    //     .build();

    const texAlbedoGB = pipeline.createTexture('texAlbedoGB')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA8)
        .clearColor(0, 0, 0, 0)
        .build();

    const texNormalGB = pipeline.createTexture('texNormalGB')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RG32UI)
        .clearColor(0, 0, 0, 0)
        .build();

    const texMatLightGB = pipeline.createTexture('texMatLightGB')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RG32UI)
        .clearColor(0, 0, 0, 0)
        .build();

    // pipeline.createImageTexture('texWaterVolume', 'imgWaterVolume')
    //     .width(screenWidth)
    //     .height(screenHeight)
    //     .format(Format.RG32UI)
    //     // .clearColor(0, 0, 0, 0)
    //     .build();

    let texShadowColor: BuiltTexture | undefined;
    let texSkyTransmit: BuiltTexture | undefined;
    let texSkyMultiScatter: BuiltTexture | undefined;
    let texSkyView: BuiltTexture | undefined;
    let texSkyIrradiance: BuiltTexture | undefined;
    let texShadowGB: BuiltTexture | undefined;
    let texSssGB: BuiltTexture | undefined;
    let texWeather: BuiltTexture | undefined;
    if (dimension.World_HasSky) {
        texShadowGB = pipeline.createTexture('texShadowGB')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGB8)
            .build();

        pipeline.createImageTexture('texShadowFinal', 'imgShadowFinal')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA8)
            .build();

        texSssGB = pipeline.createTexture('texSssGB')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGB8)
            .build();

        pipeline.createImageTexture('texSssFinal', 'imgSssFinal')
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA8)
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

    pipeline.createImageTexture('texHistogram', 'imgHistogram')
        .format(Format.R32UI)
        .width(256)
        .clear(false)
        .build();

    if (DEBUG_LIGHT_TILES) {
        pipeline.createImageTexture('texDebug', 'imgDebug')
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
                .compile();

            beginStage.createComposite('sky-irradiance')
                .location('pre/sky-irradiance', 'bakeSkyIrradiance')
                .target(0, texSkyIrradiance)
                .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
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
    }

    type ShadowPass = [string, ProgramUsage];
    [
        ['shadow-sky-terrain-cutout', Usage.SHADOW_TERRAIN_CUTOUT],
        ['shadow-sky-terrain-translucent', Usage.SHADOW_TERRAIN_TRANSLUCENT],
        ['shadow-sky-entity-cutout', Usage.SHADOW_ENTITY_CUTOUT],
        ['shadow-sky-entity-translucent', Usage.SHADOW_ENTITY_TRANSLUCENT],
        ['shadow-sky-blockentity-translucent', Usage.SHADOW_BLOCK_ENTITY_TRANSLUCENT],
    ].forEach((pass: ShadowPass) => {
        shadowSkyShader(pass[0], pass[1])
            .exportBool('ALPHATEST_ENABLED', true)
            .target(0, texShadowColor).blendOff(0)
            .compile();
    });

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
            // .exportFloat('Parallax_Depth', options.Material_Parallax_Depth * 0.01)
            .exportInt('Parallax_SampleCount', options.Material_Parallax_SampleCount)
            .exportBool('Parallax_Optimize', options.Material_Parallax_Optimize)
            .target(0, texAlbedoGB).blendOff(0)//.blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            // .target(1, texPositionGB).blendOff(1)
            .target(1, texNormalGB).blendOff(1)
            .target(2, texMatLightGB).blendOff(2);

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

    opaqueObjectShader("entity-solid", Usage.ENTITY_SOLID).compile();
    
    opaqueObjectShader("entity-cutout", Usage.ENTITY_CUTOUT).compile();

    opaqueObjectShader("blockentity-cutout", Usage.BLOCK_ENTITY).compile();

    opaqueObjectShader("hand", Usage.HAND).compile();

    // opaqueObjectShader("basic-opaque", Usage.PARTICLES_TRANSLUCENT)
    //     .exportBool('RENDER_PARTICLES', true)
    //     .compile();

    function translucentObjectShader(name: string, usage: ProgramUsage) {
        const shader = pipeline.createObjectShader(name, usage)
            .location("objects/translucent")
            .target(0, texFinalTranslucent).blendFunc(0, Func.ONE, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .target(1,  texTintTranslucent).blendFunc(1, Func.DST_COLOR, Func.ZERO, Func.ZERO, Func.ZERO)
            .target(2,  texDataTranslucent).blendOff(2);

        //if (options.Post_TAA_Enabled) shader.target(1, texVelocity).blendOff(1);
        return shader;
    }

    translucentObjectShader("terrain-translucent", Usage.TERRAIN_TRANSLUCENT)
        .exportBool('Water_WaveEnabled', options.Water_WavesEnabled)
        .exportBool('RENDER_TERRAIN', true)
        .compile();

    translucentObjectShader("entity-translucent", Usage.ENTITY_TRANSLUCENT).compile();

    translucentObjectShader("blockentity-translucent", Usage.BLOCK_ENTITY_TRANSLUCENT).compile();

    translucentObjectShader("hand-translucent", Usage.TRANSLUCENT_HAND).compile();

    translucentObjectShader("text", Usage.TEXT).compile();

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
        finalFlipper.flip();

        if (options.Lighting_Refraction_Mode == Refract_WorldSpace) {
            // TODO: rewrite opaque gbuffer data with WS refraction?
        }

        withSubList(postRenderStage, 'opaque-deferred', opaqueStage => {
            if (dimension.World_HasSky) {
                opaqueStage.createComposite("deferred-shadow-sky")
                    .location("deferred/shadow-sky", "skyShadowSss")
                    .target(0, texShadowGB)
                    .target(1, texSssGB)
                    .exportFloat('Shadow_MaxRadius', options.Shadow_MaxRadius)
                    .exportInt('Shadow_PcssSamples', options.Shadow_PcssSamples)
                    .exportInt('Shadow_PcfSamples', options.Shadow_PcfSamples)
                    .exportFloat('Shadow_SssMaxDist', options.Shadow_SssMaxDist)
                    .exportFloat('Shadow_SssMaxRadius', options.Shadow_SssMaxRadius)
                    .exportInt('Shadow_SssPcfSamples', options.Shadow_SssPcfSamples)
                    .compile();

                opaqueStage.createCompute("deferred-shadow-sky-filter")
                    .location("deferred/shadow-sky-filter", "filterShadowSss")
                    .workGroups(
                        Math.ceil(screenWidth / 16),
                        Math.ceil(screenHeight / 16),
                        1)
                    .compile();

                opaqueStage.createComposite("deferred-lighting-sky")
                    .location("deferred/lighting-sky", "lightingSky")
                    .target(0, texDiffuse)
                    .target(1, texSpecular)
                    .compile();
            }

            opaqueStage.createComposite("deferred-lighting-block-hand")
                .location("deferred/lighting-block-hand", "lightingBlockHand")
                .target(0, texDiffuse).blendFunc(0, Func.ONE, Func.ONE, Func.ONE, Func.ONE)
                .target(1, texSpecular).blendFunc(1, Func.ONE, Func.ONE, Func.ONE, Func.ONE)
                .compile();

            if (options.Lighting_Point_Enabled) {
                opaqueStage.createCompute("deferred-lighting-block-point")
                    .location("deferred/lighting-block-point", "applyPointLights")
                    .workGroups(
                        Math.ceil(screenWidth / 16.0),
                        Math.ceil(screenHeight / 16.0),
                        1)
                    .exportBool('DEBUG_LIGHT_TILES', DEBUG_LIGHT_TILES)
                    .compile();
            }

            opaqueStage.createComposite("deferred-lighting-final")
                .location("deferred/lighting-final", "lightingFinal")
                .target(0, finalFlipper.getWriteTexture())
                .compile();
        });

        withSubList(postRenderStage, 'translucent-composite', translucentStage => {
            finalFlipper.flip();

            translucentStage.createComposite("composite-overlays")
                .location("composite/overlays", "applyOverlays")
                .target(0, finalFlipper.getWriteTexture())
                .overrideObject('texSource', finalFlipper.getReadTexture().name())
                .exportInt('RefractMode', options.Lighting_Refraction_Mode)
                .compile();
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
                maxLod = Math.floor(maxLod);
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
    
    if (options.Post_TAA_Enabled) {
        texFinalPrevRef.pointTo(alt ? texFinalPrevA : texFinalPrevB);
        imgFinalPrevRef.pointTo(alt ? texFinalPrevB : texFinalPrevA);
    }

    if (options.Lighting_FloodFill_Enabled) {
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
