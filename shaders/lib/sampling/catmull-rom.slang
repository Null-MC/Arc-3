public module catmull_rom;

half4 sample_CatmullRom_RGBA(const in Sampler2D<half4> texSampler, const in float2 uv, const in float2 bufferSize) {
    float2 samplePos = uv * bufferSize;
    float2 texPos1 = floor(samplePos - 0.5) + 0.5;
    float2 f = samplePos - texPos1;

    // Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
    // These equations are pre-expanded based on our knowledge of where the texels will be located,
    // which lets us avoid having to evaluate a piece-wise function.
    float2 w0 = f * ( -0.5 + f * (1.0 - 0.5*f));
    float2 w1 = 1.0 + f * f * (-2.5 + 1.5*f);
    float2 w2 = f * ( 0.5 + f * (2.0 - 1.5*f) );
    float2 w3 = f * f * (-0.5 + 0.5 * f);

    // Work out weighting factors and sampling offsets that will let us use bilinear filtering to
    // simultaneously evaluate the middle 2 samples from the 4x4 grid.
    float2 w12 = w1 + w2;
    float2 offset12 = w2 / max(w12, 0.001);

    float2 _w0  = saturate( w0);
    float2 _w12 = saturate(w12);
    float2 _w3  = saturate( w3);

    // Compute the final UV coordinates we'll use for sampling the texture
    float2 pixelSize = rcp(bufferSize);

    float2 texPos0  = (texPos1 - 1.0) * pixelSize;
    float2 texPos3  = (texPos1 + 2.0) * pixelSize;
    float2 texPos12 = (texPos1 + offset12) * pixelSize;

    float4 result = 0.0;

    result += texSampler.SampleLevel(float2(texPos0.x,  texPos0.y), 0) * (_w0.x * _w0.y);
    result += texSampler.SampleLevel(float2(texPos12.x, texPos0.y), 0) * (_w12.x * _w0.y);
    result += texSampler.SampleLevel(float2(texPos3.x,  texPos0.y), 0) * (_w3.x * _w0.y);

    result += texSampler.SampleLevel(float2(texPos0.x,  texPos12.y), 0) * (_w0.x * _w12.y);
    result += texSampler.SampleLevel(float2(texPos12.x, texPos12.y), 0) * (_w12.x * _w12.y);
    result += texSampler.SampleLevel(float2(texPos3.x,  texPos12.y), 0) * (_w3.x * _w12.y);

    result += texSampler.SampleLevel(float2(texPos0.x,  texPos3.y), 0) * (_w0.x * _w3.y);
    result += texSampler.SampleLevel(float2(texPos12.x, texPos3.y), 0) * (_w12.x * _w3.y);
    result += texSampler.SampleLevel(float2(texPos3.x,  texPos3.y), 0) * (_w3.x * _w3.y);

    return max(half4(result), half4(0.0));
}

// float sample_CatmullRom(const in sampler2D texSampler, const in vec2 uv, const in vec2 bufferSize) {
//     vec2 samplePos = uv * bufferSize;
//     vec2 texPos1 = floor(samplePos - 0.5) + 0.5;
//     vec2 f = samplePos - texPos1;

//     // Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
//     // These equations are pre-expanded based on our knowledge of where the texels will be located,
//     // which lets us avoid having to evaluate a piece-wise function.
//     vec2 w0 = f * ( -0.5 + f * (1.0 - 0.5*f));
//     vec2 w1 = 1.0 + f * f * (-2.5 + 1.5*f);
//     vec2 w2 = f * ( 0.5 + f * (2.0 - 1.5*f) );
//     vec2 w3 = f * f * (-0.5 + 0.5 * f);

//     // Work out weighting factors and sampling offsets that will let us use bilinear filtering to
//     // simultaneously evaluate the middle 2 samples from the 4x4 grid.
//     vec2 w12 = w1 + w2;
//     vec2 offset12 = w2 / max(w12, 0.001);

//     w0 = saturate(w0);
//     w12 = saturate(w12);
//     w3 = saturate(w3);

//     // Compute the final UV coordinates we'll use for sampling the texture
//     vec2 pixelSize = 1.0 / bufferSize;

//     vec2 texPos0  = (texPos1 - 1.0) * pixelSize;
//     vec2 texPos3  = (texPos1 + 2.0) * pixelSize;
//     vec2 texPos12 = (texPos1 + offset12) * pixelSize;

//     float result = 0.0;

//     result += textureLod(texSampler, vec2(texPos0.x,  texPos0.y), 0).r * w0.x * w0.y;
//     result += textureLod(texSampler, vec2(texPos12.x, texPos0.y), 0).r * w12.x * w0.y;
//     result += textureLod(texSampler, vec2(texPos3.x,  texPos0.y), 0).r * w3.x * w0.y;

//     result += textureLod(texSampler, vec2(texPos0.x,  texPos12.y), 0).r * w0.x * w12.y;
//     result += textureLod(texSampler, vec2(texPos12.x, texPos12.y), 0).r * w12.x * w12.y;
//     result += textureLod(texSampler, vec2(texPos3.x,  texPos12.y), 0).r * w3.x * w12.y;

//     result += textureLod(texSampler, vec2(texPos0.x,  texPos3.y), 0).r * w0.x * w3.y;
//     result += textureLod(texSampler, vec2(texPos12.x, texPos3.y), 0).r * w12.x * w3.y;
//     result += textureLod(texSampler, vec2(texPos3.x,  texPos3.y), 0).r * w3.x * w3.y;

//     return max(result, 0.0);
// }
