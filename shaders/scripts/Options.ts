export class Options {
    get Sky_SeaLevel(): number {return 62;}

    get Water_WavesEnabled(): boolean {return getBoolSetting('WATER_WAVES_ENABLED');}
    get Water_WaveSize(): number {return getIntSetting('WATER_WAVE_SIZE');}
    get Water_WaveDetail(): number {return 18;}

    get Material_Format(): number {return getIntSetting('MATERIAL_FORMAT');}

    get Material_Parallax_Enabled(): boolean {return getBoolSetting('MATERIAL_PARALLAX_ENABLED');}
    get Material_Parallax_Type(): number {return getIntSetting('MATERIAL_PARALLAX_TYPE');}
    get Material_Parallax_Depth(): number {return getIntSetting('MATERIAL_PARALLAX_DEPTH');}
    get Material_Parallax_SampleCount(): number {return getIntSetting('MATERIAL_PARALLAX_SAMPLES');}
    get Material_Parallax_Optimize(): boolean {return getBoolSetting('MATERIAL_PARALLAX_OPTIMIZE');}
    
    get Lighting_ColorCandles(): boolean {return getBoolSetting('LIGHTING_COLOR_CANDLES');}

    // get Lighting_Reflection_Enabled(): boolean {return getBoolSetting('LIGHTING_REFLECT_ENABLED');}
    get Lighting_Reflection_Mode(): number {return getIntSetting('LIGHTING_REFLECT_MODE');}

    // get Lighting_Refraction_Enabled(): boolean {return getBoolSetting('LIGHTING_REFRACT_ENABLED');}
    get Lighting_Refraction_Mode(): number {return getIntSetting('LIGHTING_REFRACT_MODE');}

    get Lighting_FloodFill_Enabled(): boolean {return getBoolSetting('LIGHTING_FLOODFILL_ENABLED');}
    get Lighting_FloodFill_Size(): number {return getIntSetting('LIGHTING_FLOODFILL_SIZE');}

    get Lighting_Point_Enabled(): boolean {return getBoolSetting('LIGHTING_POINT_ENABLED');}
    get Lighting_Point_EmissionMask(): boolean {return getBoolSetting('LIGHTING_POINT_EMISSION_MASK');}
    get Lighting_Point_MaxCount(): number {return getIntSetting('LIGHTING_POINT_MAXCOUNT');}
    get Lighting_Point_Resolution(): number {return getIntSetting('LIGHTING_POINT_RESOLUTION');}
    get Lighting_Point_RealTime(): number {return getIntSetting('LIGHTING_POINT_REALTIME');}

    get Shadow_Resolution(): number {return getIntSetting('SHADOW_RESOLUTION');}
    get Shadow_Distance(): number {return getIntSetting('SHADOW_DISTANCE');}
    get Shadow_Angle(): number {return getIntSetting('SHADOW_ANGLE');}

    get Post_Bloom_Enabled(): boolean {return getBoolSetting('POST_BLOOM_ENABLED');}
    get Post_Bloom_Strength(): number {return getFloatSetting('POST_BLOOM_STRENGTH');}

    get Post_TAA_Enabled(): boolean {return getBoolSetting('POST_TAA_ENABLED');}

    get Post_Exposure_Min(): number {return -0.8;}
    get Post_Exposure_Max(): number {return 10.8;}
    get Post_Exposure_Range(): number {return 9.6;}

    get Debug_Material(): number {return getIntSetting('DEBUG_MATERIAL');}
    get Debug_WhiteWorld(): boolean {return getBoolSetting('DEBUG_WHITEWORLD');}
    get Debug_Histogram(): boolean {return getBoolSetting('DEBUG_HISTOGRAM');}
}
