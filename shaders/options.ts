export function setupOptions() {
    return new Page('main')
        .add(new Page('SKY')
            .add(asIntRange('SKY.SEA_LEVEL', 60, -20, 90, 2, false))
            .add(asIntRange('SKY.FOG_DENSITY', 100, 0, 300, 5, false))
            .add(asBool('SKY.FOG_NOISE', false, true))
            .add(EMPTY)
            .add(asBool('SKY.WIND_ENABLED', true, true))
            .add(EMPTY)
            .add(asIntRange('SKY.WEATHER_OPACITY', 80, 0, 100, 2, false))
            .build())
        .add(new Page('WATER')
            .add(asBool('WATER.WAVES_ENABLED', true, true))
            .add(asIntRange('WATER.WAVE_SIZE', 12, 2, 100, 2, false))
            .build())
        .add(new Page('MATERIAL')
            .add(asInt('MATERIAL.FORMAT', 0, 1, 2).needsReload(true).build(0))
            .add(EMPTY)
            .add(new Page('MATERIAL.NORMALS')
                // .add(asBool('MATERIAL_NORMALS_ROUGH', false, true))
                .add(asBool('MATERIAL.NORMALS.SMOOTH', false, true))
                .build())
            .add(new Page("MATERIAL.PARALLAX")
                .add(asBool('MATERIAL.PARALLAX.ENABLED', false, true))
                .add(EMPTY)
                .add(asInt('MATERIAL.PARALLAX.TYPE', 0, 1, 2).needsReload(true).build(1))
                .add(asIntRange('MATERIAL.PARALLAX.DEPTH', 25, 5, 100, 5, false))
                .add(asIntRange('MATERIAL.PARALLAX.SAMPLES', 32, 8, 128, 8, true))
                .add(asBool('MATERIAL.PARALLAX.OPTIMIZE', true, true))
                .build())
            .build())
        .add(new Page('LIGHTING')
            .add(asInt('LIGHTING.RESOLUTION', 0, 1, 2).needsReload(true).build(1))
            .add(EMPTY)
            .add(new Page('LIGHTING.REFRACTION')
                .add(asInt('LIGHTING.REFRACT.MODE', 0, 1, 2).needsReload(true).build(0))
                .add(asBool('LIGHTING.REFRACT.SS_FALLBACK', true, true))
                .add(asBool('LIGHTING.REFRACT.ROUGH', false, true))
                .add(EMPTY)
                .add(asIntRange('LIGHTING.REFRACT.VOXEL_STEPS', 16, 2, 64, 2, true))
                .add(asIntRange('LIGHTING.REFRACT.SCREEN_STEPS', 16, 2, 32, 2, true))
                .add(asIntRange('LIGHTING.REFRACT.REFINE_STEPS', 4, 2, 8, 1, true))
                .build())
            .add(new Page('LIGHTING.REFLECTIONS')
                .add(asInt('LIGHTING.REFLECT.MODE', 0, 1, 2, 3).needsReload(true).build(2))
                .add(asBool('LIGHTING.REFLECT.SS_FALLBACK', true, true))
                .add(asBool('LIGHTING.REFLECT.ROUGH', false, true))
                .add(EMPTY)
                .add(asIntRange('LIGHTING.REFLECT.VOXEL_STEPS', 16, 2, 64, 2, true))
                .add(asIntRange('LIGHTING.REFLECT.SCREEN_STEPS', 16, 2, 32, 2, true))
                .add(asIntRange('LIGHTING.REFLECT.REFINE_STEPS', 4, 2, 8, 1, true))
                .build())
            .add(new Page('LIGHTING.GI')
                .add(asBool('LIGHTING.GI.ENABLED', false, true))
                .add(asBool('LIGHTING.GI.SS_TRACE', true, true))
                // .add(asIntRange('LIGHTING.GI.RESOLUTION', 1, 0, 2, 1, true))
                .add(asIntRange('LIGHTING.GI.MAXFRAMES', 30, 2, 60, 2, true))
                .add(asIntRange('LIGHTING.GI.FILTERING', 2, 0, 5, 1, true))
                .add(EMPTY)
                .add(asIntRange('LIGHTING.GI.SAMPLES', 1, 1, 6, 1, true))
                .add(asIntRange('LIGHTING.GI.VOXEL_STEPS', 16, 2, 64, 2, true))
                .add(asIntRange('LIGHTING.GI.SCREEN_STEPS', 16, 2, 32, 2, true))
                .add(asIntRange('LIGHTING.GI.REFINE_STEPS', 4, 2, 8, 1, true))
                .build())
            .add(new Page('LIGHTING_POINT')
                .add(asBool('LIGHTING_POINT_ENABLED', false, true))
                .add(asIntRange('LIGHTING_POINT_MAXCOUNT', 128, 4, 256, 4, true))
                .add(asInt('LIGHTING_POINT_RESOLUTION', 32, 64, 128, 256, 512).needsReload(true).build(128))
                .add(EMPTY)
                .add(asIntRange('LIGHTING_POINT_REALTIME', 4, 0, 16, 1, false))
                .add(asBool('LIGHTING_POINT_EMISSION_MASK', false, true))
                .build())
            .add(new Page('LIGHTING_FLOODFILL')
                .add(asBool('LIGHTING_FLOODFILL_ENABLED', true, true))
                .add(asInt('LIGHTING_FLOODFILL_SIZE', 64, 128, 256).needsReload(true).build(128))
                .build())
            .add(EMPTY)
            .add(asInt('LIGHTING.VOXEL_RESOLUTION', 64, 128, 256).needsReload(true).build(128))
            .add(asBool('LIGHTING.COLOR_CANDLES', true, true))
            .build())
        .add(new Page('SHADOWS')
            .add(asBool('SHADOW.CSM_ENABLED', true, true))
            .add(asInt('SHADOW.RESOLUTION', 512, 1024, 2048, 4096, 8192).needsReload(true).build(1024))
            .add(asInt('SHADOW.DISTANCE', 50, 100, 150, 200, 250, 300, 400, 500, 600, 800, 1000, 2000, 4000, 8000).needsReload(true).build(200))
            .add(asIntRange('SHADOW.ANGLE', 24, -90, 90, 2, false))
            //.add(asBool('SHADOW_COLORED', true, true))
            .add(EMPTY)
            .add(new Page('SHADOWS.ADVANCED')
                .add(asFloatRange('SHADOW.MAX_RADIUS', 0.4, 0.0, 2.0, 0.1, true))
                .add(asIntRange('SHADOW.PCSS_SAMPLES', 3, 1, 12, 1, true))
                .add(asIntRange('SHADOW.PCF_SAMPLES',  4, 1, 16, 1, true))
                .add(EMPTY)
                .add(asFloatRange('SHADOW.SSS_MAX_RADIUS', 1.4, 0.1, 2.0, 0.1, true))
                .add(asFloatRange('SHADOW.SSS_MAX_DIST', 6.0, 0.2, 9.0, 0.2, true))
                .add(asIntRange('SHADOW.SSS_PCF_SAMPLES', 2, 1, 16, 1, true))
                .build())
            .build())
        .add(new Page('POST')
            .add(new Page('POST.TONEMAP')
                .add(asIntRange('POST.TONEMAP.CONTRAST', 80, 10, 190, 2, false))
                .build())
            .add(new Page('POST.EXPOSURE')
                .add(asFloatRange('POST.EXPOSURE.MIN',   -2.0, -6.0,  0.0, 0.2, false))
                .add(asFloatRange('POST.EXPOSURE.MAX',   16.6,  0.0, 20.0, 0.2, false))
                .add(asFloatRange('POST.EXPOSURE.RANGE', 12.8,  3.0, 19.0, 0.2, false))
                .build())
            .add(new Page('POST.BLOOM')
                .add(asBool('POST.BLOOM.ENABLED', true, true))
                .add(asFloatRange('POST.BLOOM.STRENGTH', 2.0, 0.2, 20.0, 0.1, false))
                .build())
            .add(new Page('POST.TAA')
                .add(asBool('POST.TAA.ENABLED', true, true))
                .add(EMPTY)
                .add(asBool('POST.TAA.CUBIC_HISTORY', false, true))
                .add(asIntRange('POST.TAA.CAS_STRENGTH', 60, 0, 100, 2, false))
                .build())
            .build())
        .add(EMPTY)
        .add(new Page('DEBUG')
            .add(asIntRange('DEBUG_MATERIAL', 0, 0, 5, 1, true))
            .add(asBool('DEBUG_WHITEWORLD', false, true))
            .add(asBool('DEBUG_HISTOGRAM', false, true))
            .build())
        .build();
}

function asIntRange(keyName: string, defaultValue: number, valueMin: number, valueMax: number, interval: number, reload: boolean = true) {
    const values = getValueRange(valueMin, valueMax, interval);
    return asInt(keyName, ...values).needsReload(reload).build(defaultValue);
}

function asFloatRange(keyName: string, defaultValue: number, valueMin: number, valueMax: number, interval: number, reload: boolean = true) {
    const values = getValueRange(valueMin, valueMax, interval);
    return asFloat(keyName, ...values).needsReload(reload).build(defaultValue);
}

function asStringRange(keyName: string, defaultValue: number, valueMin: number, valueMax: number, reload: boolean = true) {
    const values = getValueRange(valueMin, valueMax, 1);
    return asString(keyName, ...values.map(v => v.toString())).needsReload(reload).build(defaultValue.toString());
}

function getValueRange(valueMin: number, valueMax: number, interval: number) {
    const values = [];

    let value = valueMin;
    while (value <= valueMax) {
        values.push(value);
        value += interval;
    }

    return values;
}
