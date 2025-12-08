public module common;

import lib.common;

static const float Water_ScatterColor = 0.012;
static const float3 WaterAbsorbClear = InputTransform(1.0 - float3(0.525, 0.820, 0.820));
static const float3 WaterAbsorbMurky = InputTransform(1.0 - float3(0.231, 0.220, 0.165));
