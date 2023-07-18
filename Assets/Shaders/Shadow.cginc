static const int NUM_SHADOW_RAYS = 16;  // blue noise will use 64 samples max. white noise will use however many you specify here.
static const float LIGHT_RADIUS = 0.1f; // radius of light disk at 1 unit away
static const float GOLDEN_RATIO_CONJUGATE = 0.61803398875f; // also just fract(goldenRatio)

// This "blue noise in disk" array is blue noise in a circle and is used for sampling the
// sun disk for the blue noise.
// these were generated using a modified mitchell's best candidate algorithm.
// 1) It was not calculated on a torus (no wrap around distance for points)
// 2) Candidates were forced to be in the unit circle (through rejection sampling)
static const float2 BLUE_NOISE_IN_DISK[64] = {
    float2(0.478712,0.875764),
    float2(-0.337956,-0.793959),
    float2(-0.955259,-0.028164),
    float2(0.864527,0.325689),
    float2(0.209342,-0.395657),
    float2(-0.106779,0.672585),
    float2(0.156213,0.235113),
    float2(-0.413644,-0.082856),
    float2(-0.415667,0.323909),
    float2(0.141896,-0.939980),
    float2(0.954932,-0.182516),
    float2(-0.766184,0.410799),
    float2(-0.434912,-0.458845),
    float2(0.415242,-0.078724),
    float2(0.728335,-0.491777),
    float2(-0.058086,-0.066401),
    float2(0.202990,0.686837),
    float2(-0.808362,-0.556402),
    float2(0.507386,-0.640839),
    float2(-0.723494,-0.229240),
    float2(0.489740,0.317826),
    float2(-0.622663,0.765301),
    float2(-0.010640,0.929347),
    float2(0.663146,0.647618),
    float2(-0.096674,-0.413835),
    float2(0.525945,-0.321063),
    float2(-0.122533,0.366019),
    float2(0.195235,-0.687983),
    float2(-0.563203,0.098748),
    float2(0.418563,0.561335),
    float2(-0.378595,0.800367),
    float2(0.826922,0.001024),
    float2(-0.085372,-0.766651),
    float2(-0.921920,0.183673),
    float2(-0.590008,-0.721799),
    float2(0.167751,-0.164393),
    float2(0.032961,-0.562530),
    float2(0.632900,-0.107059),
    float2(-0.464080,0.569669),
    float2(-0.173676,-0.958758),
    float2(-0.242648,-0.234303),
    float2(-0.275362,0.157163),
    float2(0.382295,-0.795131),
    float2(0.562955,0.115562),
    float2(0.190586,0.470121),
    float2(0.770764,-0.297576),
    float2(0.237281,0.931050),
    float2(-0.666642,-0.455871),
    float2(-0.905649,-0.298379),
    float2(0.339520,0.157829),
    float2(0.701438,-0.704100),
    float2(-0.062758,0.160346),
    float2(-0.220674,0.957141),
    float2(0.642692,0.432706),
    float2(-0.773390,-0.015272),
    float2(-0.671467,0.246880),
    float2(0.158051,0.062859),
    float2(0.806009,0.527232),
    float2(-0.057620,-0.247071),
    float2(0.333436,-0.516710),
    float2(-0.550658,-0.315773),
    float2(-0.652078,0.589846),
    float2(0.008818,0.530556),
    float2(-0.210004,0.519896) 
};


const float4 shadowParameter;


void HardShadow(inout Ray ray, float3 lightDir)
{
	// 正式添加软阴影的实现
    Ray shadowRay = CreateRay(ray.origin, lightDir);
    RayHit shadowHit = BVHTrace(shadowRay);
    if (shadowHit.castShadow > 0 && shadowHit.distance != 1.#INF)
    {
        // 可以用enery来控制阴影的黑色
        ray.energy *= lerp(1, shadowParameter.rgb, shadowParameter.a);
    }
}

float3 SoftShadow(float3 origin, float3 lightDir)
{
    // use the screen space blue noise texture and golden ratio * frame number to
    // get a "random number" to convert to an angle for how much to rotate
    // the blue noise sample positions for this pixel
    float blueNoise = rand();//texture(iChannel1, pixelPos / 1024.0f).r;
    //blueNoise = frac(blueNoise + GOLDEN_RATIO_CONJUGATE * float(frame));
    float theta = blueNoise * 2.0 * PI;
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);

    // shoot some shadow rays
    float shadowTerm = 0.0f;
    float3 lightTangent = normalize(cross(lightDir, float3(0.0f, 1.0f, 0.0f)));
    float3 lightBitangent = normalize(cross(lightTangent, lightDir));
    for (int shadowRayIndex = 0; shadowRayIndex < NUM_SHADOW_RAYS; ++shadowRayIndex)
    {
        // calculate a ray direction to a random point on a disk in the direction of the light.
        // AKA PIck a random point on the sun and shoot a ray at it.
        float3 shadowRayDir;
        {
            float2 diskPoint;
                
            // get a blue noise sample position
            float2 samplePos = BLUE_NOISE_IN_DISK[shadowRayIndex];

            // rotate it
            diskPoint.x = samplePos.x * cosTheta - samplePos.y * sinTheta;
            diskPoint.y = samplePos.x * sinTheta + samplePos.y * cosTheta;

            // scale it by the disk size
            diskPoint *= LIGHT_RADIUS;

            // calculate the normalized vector to the random point on the disk
            shadowRayDir = normalize(lightDir + diskPoint.x * lightTangent + diskPoint.y * lightBitangent);
        }

        // trace shadow ray
        Ray shadowRay = CreateRay(origin, shadowRayDir);
        RayHit shadowHit = BVHTrace(shadowRay);
        if (shadowHit.castShadow > 0)
            shadowTerm = lerp(shadowTerm, ((shadowHit.distance == 1.#INF) ? 0.0f : 1.0f), 1.0f / float(shadowRayIndex + 1));
    }

    return lerp(1, shadowParameter.rgb, shadowParameter.a * shadowTerm);

}

float3 Shadow(Ray ray, RayHit hit)
{
    float3 softShadow = SoftShadow(hit.position + hit.normal * 0.01f, -directionalLight.xyz);
    return softShadow;
}