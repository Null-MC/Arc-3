export function setupOptions() {
    return new Page('main')
        .add(new Page('WATER')
            .add(asBool('WATER_WAVES_ENABLED', true, true))
            .add(asIntRange('WATER_WAVE_SIZE', 60, 2, 100, 2, false))
            .build())
        .add(new Page('MATERIAL')
            .add(asInt('MATERIAL_FORMAT', 0, 1, 2).needsReload(true).build(0))
            .add(EMPTY)
            .add(new Page("MATERIAL_PARALLAX")
                .add(asBool('MATERIAL_PARALLAX_ENABLED', false, true))
                .add(EMPTY)
                .add(asInt('MATERIAL_PARALLAX_TYPE', 0, 1, 2).needsReload(true).build(1))
                .add(asIntRange('MATERIAL_PARALLAX_DEPTH', 25, 5, 100, 5, false))
                .add(asIntRange('MATERIAL_PARALLAX_SAMPLES', 32, 8, 128, 8, true))
                .add(asBool('MATERIAL_PARALLAX_OPTIMIZE', true, true))
                .build())
            .build())
        .add(new Page('LIGHTING')
            .add(new Page('LIGHTING_REFLECTIONS')
                // .add(asBool('LIGHTING_REFLECT_ENABLED', true, true))
                .add(asInt('LIGHTING_REFLECT_MODE', 0, 1, 2, 3).needsReload(true).build(1))
                .build())
            .add(new Page('LIGHTING_REFRACTION')
                // .add(asBool('LIGHTING_REFRACT_ENABLED', true, true))
                .add(asInt('LIGHTING_REFRACT_MODE', 0, 1, 2).needsReload(true).build(1))
                .add(asBool('LIGHTING_REFRACT_SS_FALLBACK', true, true))
                .build())
            .add(new Page('LIGHTING_POINT')
                .add(asBool('LIGHTING_POINT_ENABLED', true, true))
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
            .add(asBool('LIGHTING_COLOR_CANDLES', true, true))
            .build())
        .add(new Page('SHADOWS')
            .add(asInt('SHADOW_RESOLUTION', 512, 1024, 2048, 4096, 8192).needsReload(true).build(1024))
            .add(asInt('SHADOW_DISTANCE', 50, 100, 150, 200, 250, 300, 400, 500, 600, 800, 1000, 2000, 4000, 8000).needsReload(true).build(200))
            .add(asIntRange('SHADOW_ANGLE', 24, -90, 90, 2, false))
            //.add(asBool('SHADOW_COLORED', true, true))
            .add(EMPTY)
            .add(new Page('SHADOW_ADVANCED')
                .add(asFloatRange('SHADOW_MAX_RADIUS', 0.4, 0.0, 2.0, 0.1, true))
                .add(asIntRange('SHADOW_PCSS_SAMPLES', 3, 1, 12, 1, true))
                .add(asIntRange('SHADOW_PCF_SAMPLES',  4, 1, 16, 1, true))
                .add(EMPTY)
                .add(asFloatRange('SHADOW_SSS_MAX_RADIUS', 1.4, 0.1, 2.0, 0.1, true))
                .add(asFloatRange('SHADOW_SSS_MAX_DIST', 6.0, 0.2, 9.0, 0.2, true))
                .add(asIntRange('SHADOW_SSS_PCF_SAMPLES', 2, 1, 16, 1, true))
                .build())
            .build())
        .add(new Page('POST')
            .add(new Page('POST_EXPOSURE')
                .add(asFloatRange('POST_EXPOSURE_MIN', -0.8, -2.0,  0.0, 0.2, false))
                .add(asFloatRange('POST_EXPOSURE_MAX', 11.0,  0.0, 20.0, 0.2, false))
                .add(asFloatRange('POST_EXPOSURE_RANGE', 6.6, 3.0, 16.0, 0.2, false))
                .build())
            .add(new Page('POST_BLOOM')
                .add(asBool('POST_BLOOM_ENABLED', true, true))
                .add(asFloatRange('POST_BLOOM_STRENGTH', 4.0, 0.2, 20.0, 0.2, false))
                .build())
            .add(new Page('POST_TAA')
                .add(asBool('POST_TAA_ENABLED', true, true))
                .add(EMPTY)
                .add(asBool('POST_TAA_CUBIC_HISTORY', true, true))
                .add(asIntRange('POST_TAA_CAS_STRENGTH', 50, 0, 100, 2, false))
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
