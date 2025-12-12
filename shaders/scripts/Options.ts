export class Options {
    get Sky_SeaLevel(): number {return getIntSetting('SKY.SEA_LEVEL');}
    get Sky_WindEnabled(): boolean {return getBoolSetting('SKY.WIND_ENABLED');}
    get Sky_WeatherOpacity(): number {return getIntSetting('SKY.WEATHER_OPACITY');}
    get Sky_PuddleThreshold(): number {return getIntSetting('SKY.PUDDLE_THRESHOLD');}

    get Sky_FogEnabled(): boolean {return getBoolSetting('SKY.FOG_ENABLED');}
    get Sky_FogDensity(): number {return getIntSetting('SKY.FOG_DENSITY');}
    get Sky_FogNoise(): boolean {return getBoolSetting('SKY.FOG_NOISE');}

    get Sky_DustDensity(): number {return getIntSetting('SKY.DUST_DENSITY');}

    get Water_WavesEnabled(): boolean {return getBoolSetting('WATER.WAVES_ENABLED');}
    get Water_WaveSize(): number {return getIntSetting('WATER.WAVE_SIZE');}
    get Water_WaveDetail(): number {return 16;}
    get Water_DirtLevel(): number {return getIntSetting('WATER.DIRT_LEVEL');}

    get Material_Format(): number {return getIntSetting('MATERIAL.FORMAT');}
    get Material_MipBias(): number {return getIntSetting('MATERIAL.MIP_BIAS');}

    // get Material_Normals_Rough(): boolean {return getBoolSetting('MATERIAL.NORMALS_ROUGH');}
    get Material_Normals_Smooth(): boolean {return getBoolSetting('MATERIAL.NORMALS.SMOOTH');}

    get Material_Parallax_Enabled(): boolean {return getBoolSetting('MATERIAL.PARALLAX.ENABLED');}
    get Material_Parallax_Type(): number {return getIntSetting('MATERIAL.PARALLAX.TYPE');}
    get Material_Parallax_Depth(): number {return getIntSetting('MATERIAL.PARALLAX.DEPTH');}
    get Material_Parallax_SampleCount(): number {return getIntSetting('MATERIAL.PARALLAX.SAMPLES');}
    get Material_Parallax_Optimize(): boolean {return getBoolSetting('MATERIAL.PARALLAX.OPTIMIZE');}

    get Material_Porosity_Format(): number {return this.getFormatFallback('MATERIAL.POROSITY.FORMAT');}
    
    get Material_Emission_Format(): number {return this.getFormatFallback('MATERIAL.EMISSION.FORMAT');}
    get Material_Emission_Scale(): number {return getIntSetting('MATERIAL.EMISSION.SCALE');}
    get Material_Emission_Curve(): number {return getIntSetting('MATERIAL.EMISSION.CURVE');}
    
    // get Lighting_Resolution(): number {return getIntSetting('LIGHTING.RESOLUTION');}
    get Lighting_VoxelResolution(): number {return getIntSetting('LIGHTING.VOXEL_RESOLUTION');}
    get Lighting_ColorCandles(): boolean {return getBoolSetting('LIGHTING.COLOR_CANDLES');}

    get Lighting_Refraction_Mode(): number {return getIntSetting('LIGHTING.REFRACT.MODE');}
    get Lighting_Refraction_ScreenSpaceFallback(): boolean {return getBoolSetting('LIGHTING.REFRACT.SS_FALLBACK');}
    get Lighting_Refraction_Rough(): boolean {return getBoolSetting('LIGHTING.REFRACT.ROUGH');}
    get Lighting_Refraction_VoxelSteps(): number {return getIntSetting('LIGHTING.REFRACT.VOXEL_STEPS');}
    get Lighting_Refraction_ScreenSteps(): number {return getIntSetting('LIGHTING.REFRACT.SCREEN_STEPS');}
    get Lighting_Refraction_RefineSteps(): number {return getIntSetting('LIGHTING.REFRACT.REFINE_STEPS');}

    get Lighting_Reflection_Resolution(): number {return getIntSetting('LIGHTING.REFLECT.RESOLUTION');}
    get Lighting_Reflection_Mode(): number {return getIntSetting('LIGHTING.REFLECT.MODE');}
    get Lighting_Reflection_ScreenSpaceFallback(): boolean {return getBoolSetting('LIGHTING.REFLECT.SS_FALLBACK');}
    get Lighting_Reflection_Rough(): boolean {return getBoolSetting('LIGHTING.REFLECT.ROUGH');}
    get Lighting_Reflection_VoxelSteps(): number {return getIntSetting('LIGHTING.REFLECT.VOXEL_STEPS');}
    get Lighting_Reflection_ScreenSteps(): number {return getIntSetting('LIGHTING.REFLECT.SCREEN_STEPS');}
    get Lighting_Reflection_RefineSteps(): number {return getIntSetting('LIGHTING.REFLECT.REFINE_STEPS');}

    get Lighting_GI_Enabled(): boolean {return getBoolSetting('LIGHTING.GI.ENABLED');}
    get Lighting_GI_ScreenTrace(): boolean {return getBoolSetting('LIGHTING.GI.SS_TRACE');}
    get Lighting_GI_Resolution(): number {return getIntSetting('LIGHTING.GI.RESOLUTION');}
    get Lighting_GI_MaxFrames(): number {return getIntSetting('LIGHTING.GI.MAXFRAMES');}
    get Lighting_GI_FilterPasses(): number {return getIntSetting('LIGHTING.GI.FILTERING');}
    get Lighting_GI_Samples(): number {return getIntSetting('LIGHTING.GI.SAMPLES');}
    get Lighting_GI_VoxelSteps(): number {return getIntSetting('LIGHTING.GI.VOXEL_STEPS');}
    get Lighting_GI_ScreenSteps(): number {return getIntSetting('LIGHTING.GI.SCREEN_STEPS');}
    get Lighting_GI_RefineSteps(): number {return getIntSetting('LIGHTING.GI.REFINE_STEPS');}

    get Lighting_Point_Enabled(): boolean {return getBoolSetting('LIGHTING_POINT_ENABLED');}
    get Lighting_Point_EmissionMask(): boolean {return getBoolSetting('LIGHTING_POINT_EMISSION_MASK');}
    get Lighting_Point_MaxCount(): number {return getIntSetting('LIGHTING_POINT_MAXCOUNT');}
    get Lighting_Point_Resolution(): number {return getIntSetting('LIGHTING_POINT_RESOLUTION');}
    get Lighting_Point_RealTime(): number {return getIntSetting('LIGHTING_POINT_REALTIME');}

    get Lighting_FloodFill_Enabled(): boolean {return getBoolSetting('LIGHTING_FLOODFILL_ENABLED');}
    get Lighting_FloodFill_Size(): number {return getIntSetting('LIGHTING_FLOODFILL_SIZE');}

    get Shadow_CSM_Enabled(): boolean {return getBoolSetting('SHADOW.CSM_ENABLED');}
    get Shadow_Resolution(): number {return getIntSetting('SHADOW.RESOLUTION');}
    get Shadow_Distance(): number {return getIntSetting('SHADOW.DISTANCE');}
    get Shadow_Angle(): number {return getIntSetting('SHADOW.ANGLE');}
    get Shadow_MaxRadius(): number {return getFloatSetting('SHADOW.MAX_RADIUS');}
    get Shadow_PcssSamples(): number {return getIntSetting('SHADOW.PCSS_SAMPLES');}
    get Shadow_PcfSamples(): number {return getIntSetting('SHADOW.PCF_SAMPLES');}
    get Shadow_SssMaxRadius(): number {return getFloatSetting('SHADOW.SSS_MAX_RADIUS');}
    get Shadow_SssMaxDist(): number {return getFloatSetting('SHADOW.SSS_MAX_DIST');}
    get Shadow_SssPcfSamples(): number {return getIntSetting('SHADOW.SSS_PCF_SAMPLES');}

    get Post_ToneMap_Saturation(): number {return getIntSetting('POST.TONEMAP.SATURATION');}
    // get Post_ToneMap_Contrast(): number {return getIntSetting('POST.TONEMAP.CONTRAST');}
    get Post_ToneMap_RedOffset(): number {return getIntSetting('POST.TONEMAP.RED_OFFSET');}
    get Post_ToneMap_RedScale(): number {return getIntSetting('POST.TONEMAP.RED_SCALE');}
    get Post_ToneMap_RedPower(): number {return getIntSetting('POST.TONEMAP.RED_POWER');}
    get Post_ToneMap_GreenOffset(): number {return getIntSetting('POST.TONEMAP.GREEN_OFFSET');}
    get Post_ToneMap_GreenScale(): number {return getIntSetting('POST.TONEMAP.GREEN_SCALE');}
    get Post_ToneMap_GreenPower(): number {return getIntSetting('POST.TONEMAP.GREEN_POWER');}
    get Post_ToneMap_BlueOffset(): number {return getIntSetting('POST.TONEMAP.BLUE_OFFSET');}
    get Post_ToneMap_BlueScale(): number {return getIntSetting('POST.TONEMAP.BLUE_SCALE');}
    get Post_ToneMap_BluePower(): number {return getIntSetting('POST.TONEMAP.BLUE_POWER');}

    get Post_Exposure_Min(): number {return getFloatSetting('POST.EXPOSURE.MIN');}
    get Post_Exposure_Max(): number {return getFloatSetting('POST.EXPOSURE.MAX');}
    get Post_Exposure_Range(): number {return getFloatSetting('POST.EXPOSURE.RANGE');}

    get Post_Vignette_Enabled(): boolean {return getBoolSetting('POST.VIGNETTE.ENABLED');}
    get Post_Vignette_Scale(): number {return getIntSetting('POST.VIGNETTE.SCALE');}

    get Post_Bloom_Enabled(): boolean {return getBoolSetting('POST.BLOOM.ENABLED');}
    get Post_Bloom_Strength(): number {return getFloatSetting('POST.BLOOM.STRENGTH');}

    get Post_TAA_Enabled(): boolean {return getBoolSetting('POST.TAA.ENABLED');}
    get Post_TAA_CubicHistory(): boolean {return getBoolSetting('POST.TAA.CUBIC_HISTORY');}
    get Post_TAA_CasStrength(): number {return getIntSetting('POST.TAA.CAS_STRENGTH');}

    get Debug_Material(): number {return getIntSetting('DEBUG_MATERIAL');}
    get Debug_WhiteWorld(): boolean {return getBoolSetting('DEBUG_WHITEWORLD');}
    get Debug_Histogram(): boolean {return getBoolSetting('DEBUG_HISTOGRAM');}


    // get Material_PorosityFormatFinal(): number {return this.FormatFallback(this.Material_Porosity_Format);}

    get VoxelEnabled(): boolean {
        if (this.Lighting_Refraction_Mode == RefractMode.WorldSpace) return true;
        if (this.Lighting_Reflection_Mode == ReflectMode.WorldSpace) return true;
        if (this.Lighting_GI_Enabled) return true;
        return false;
    }

    private getFormatFallback(settingKey: string): number {
        const format = getIntSetting(settingKey);
        return format == 0 ? this.Material_Format : format;
    }

    appendExports(exports: ExportList): void {
        exports
            .addBool('Sky_FogEnabled', this.Sky_FogEnabled)
            .addBool('Sky_FogNoise', this.Sky_FogNoise)
            .addBool('Sky_WindEnabled', this.Sky_WindEnabled)
            .addInt('Material_Format', this.Material_Format)
            .addInt('Material_PorosityFormat', this.Material_Porosity_Format)
            .addInt('Material_EmissionFormat', this.Material_Emission_Format)
            .addInt('Shadow_Resolution', this.Shadow_Resolution)
            .addInt('ReflectMode', this.Lighting_Reflection_Mode)
            .addInt('RefractMode', this.Lighting_Refraction_Mode)
            .addBool('FloodFill_Enabled', this.Lighting_FloodFill_Enabled)
            .addInt('FloodFill_BufferSize', this.Lighting_FloodFill_Size)
            // .addBool('FloodFill_Sky_Enabled', this.Sky_FogEnabled && dimension.World_HasSky)
            // .addInt('FloodFill_Sky_BufferSizeXZ', FloodFill_Sky.BufferSizeXZ)
            // .addInt('FloodFill_Sky_BufferSizeY', FloodFill_Sky.BufferSizeY)
            .addBool('PointLight_Enabled', this.Lighting_Point_Enabled)
            .addInt('PointLight_MaxCount', this.Lighting_Point_MaxCount)
            .addInt('Voxel_Resolution', this.Lighting_VoxelResolution)
            .addBool('Vignette_Enabled', this.Post_Vignette_Enabled)
            .addBool('TAA_Enabled', this.Post_TAA_Enabled)
            .addBool('Debug_WhiteWorld', this.Debug_WhiteWorld);
    }
}

export const ReflectMode = {
    WorldSpace: 3,
    ScreenSpace: 2,
    SkyOnly: 1,
    None: 0,
}

export const RefractMode = {
    WorldSpace: 2,
    ScreenSpace: 1,
    None: 0,
}
