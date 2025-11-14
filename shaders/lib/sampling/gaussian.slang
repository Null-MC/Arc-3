public module gaussian;

//float Gaussian(const in float sigma, const in float x) {
//    return 0.39894 * exp(-0.5 * (x*x) / (sigma*sigma)) / sigma;
//}

float Gaussian(const in float sigma, const in float x) {
    return exp(-(x*x) / (2.0 * (sigma*sigma)));
}

float3 Gaussian(const in float sigma, const in float3 x) {
    return exp(-(x*x) / (2.0 * (sigma*sigma)));
}