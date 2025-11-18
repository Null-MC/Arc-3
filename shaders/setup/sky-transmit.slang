import aperture;
import lib.common;
import lib.sky.common;
import lib.sky.scattering;

extern static const int BufferWidth;
extern static const int BufferHeight;

static const int sunTransmittanceSteps = 40;


[[shader("fragment")]]
float3 bakeSkyTransmission(float2 pos : SV_Position) : SV_Target0 {
    float2 uv = pos / float2(BufferWidth, BufferHeight);

    float sunCosTheta = 2.0*uv.x - 1.0;
    sunCosTheta = pow3(sunCosTheta);// * sign(sunCosTheta);

    float sunTheta = safeacos(sunCosTheta);
    float height = lerp(groundRadiusMM, atmosphereRadiusMM, uv.y);
    
    float3 pos = float3(0.0, height, 0.0); 
    float3 sunDir = normalize(float3(0.0, sunCosTheta, -sin(sunTheta)));

    float3 transmittance = 0.0;
    if (rayIntersectSphere(pos, sunDir, groundRadiusMM) <= 0.0) {
        float atmoDist = rayIntersectSphere(pos, sunDir, atmosphereRadiusMM);
        float t = 0.0;
        
        transmittance = 1.0;

        for (int i = 0; i < sunTransmittanceSteps; i++) {
            float newT = ((i + 0.3)/sunTransmittanceSteps)*atmoDist;
            float dt = newT - t;
            t = newT;
            
            float3 newPos = pos + t*sunDir;
            
            float3 rayleighScattering, extinction;
            float mieScattering;
            getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);
            
            transmittance *= exp(-dt*extinction);
        }
    }

    return transmittance;
}
