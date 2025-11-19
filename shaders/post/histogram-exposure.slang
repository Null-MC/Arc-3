import aperture;
import buffers.scene;
import lib.common;

extern static const bool DEBUG_HISTOGRAM = false;
extern static const float Scene_PostExposureSpeed = 0.8;

static const float Exposure_logLumRange = settings.Exposure_Max - settings.Exposure_Min;
static const float Exposure_logLumRangeInv = rcp(Exposure_logLumRange);

RWStructuredBuffer<SceneBuffer> scene_writer;

[[vk::image_format("r32ui")]]
RWTexture1D<uint> imgHistogram;

Sampler2D<float4> texSource;
Sampler2D<float> handDepth;
Sampler2D<float> mainDepthTex;

groupshared Atomic<uint> histogramBins[256];
groupshared uint exposureBins[256];



uint colorToBin(const in float3 hdrColor, const in float minLogLum, const in float inverseLogLumRange) {
	float lum = luminance(hdrColor);
	if (lum < EPSILON) return 0u;

	float logLum = saturate((log2(lum) - minLogLum) * inverseLogLumRange);
	return uint(logLum * 254.0 + 1.0);
}


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(16, 16, 1)]
void buildHistogram(ComputeInput input) {
	histogramBins[input.groupIndex] = 0u;
	GroupMemoryBarrierWithGroupSync();

	int2 uv = int2(input.globalPos.xy);
	if (all(uv < int2(ap.game.screenSize))) {
		float3 hdrColor = texSource[uv].rgb;

		// ignore if hand pixel
		// TODO: FIX THIS LATER! false-positive in water
//		float depthPreHand = textureLod(handDepth, uv, 0).r;
//		float depthPostHand = textureLod(mainDepthTex, uv, 0).r;
//		if (depthPostHand < depthPreHand) hdrColor = vec3(0.0);

		uint binIndex = colorToBin(hdrColor, settings.Exposure_Min, Exposure_logLumRangeInv);
		histogramBins[binIndex].increment();
	}

	GroupMemoryBarrierWithGroupSync();

	InterlockedAdd(imgHistogram[input.groupIndex], histogramBins[input.groupIndex].load());
}

[[shader("compute")]]
[numthreads(256, 1, 1)]
void computeExposure(uint groupIndex : SV_GroupIndex) {
	uint countForThisBin = imgHistogram[groupIndex];
	exposureBins[groupIndex] = countForThisBin * groupIndex;

	GroupMemoryBarrierWithGroupSync();

	if (!DEBUG_HISTOGRAM) {
		imgHistogram[groupIndex] = 0u;
	}

	// This loop will perform a weighted count of the luminance range
	for (uint cutoff = (256u >> 1u); cutoff > 0u; cutoff >>= 1u) {
		if (uint(groupIndex) < cutoff) {
			exposureBins[groupIndex] += exposureBins[groupIndex + cutoff];
		}

		GroupMemoryBarrierWithGroupSync();
	}

	if (groupIndex == 0) {
		float Exposure_numPixels = ap.game.screenSize.x * ap.game.screenSize.y;
		float nonBlackPixelCount = Exposure_numPixels - countForThisBin;
		float weightedLogAverage = (exposureBins[0] / max(nonBlackPixelCount, 1.0)) - 1.0;

		// Map from our histogram space to actual luminance
		float weightedAvgLum = exp2((weightedLogAverage/254.0 * Exposure_logLumRange) + settings.Exposure_Min);
		float adaptedLum = weightedAvgLum;

		// do not mix if first rendered frame
		if (ap.timing.frameCounter != 0) {
			float timeF = 1.0 - exp(-max(Scene_PostExposureSpeed * ap.timing.lastFrameTime, 1.0e-12));

			float lumLastFrame = clamp(scene_writer[0].exposure, 0.0, 65000.0);
			adaptedLum = lumLastFrame + (weightedAvgLum - lumLastFrame) * timeF;
		}

		scene_writer[0].exposure = adaptedLum;
	}
}
