
float3x3 GetTangentSpace(float3 normal)
{
    // Choose a helper vector for the cross product
    float3 helper = float3(1, 0, 0);
    if (abs(normal.x) > 0.99f)
        helper = float3(0, 0, 1);
    // Generate vectors
    float3 tangent = normalize(cross(normal, helper));
    float3 binormal = normalize(cross(normal, tangent));
    return float3x3(tangent, binormal, normal);
}

float3 Tangent2World(float theta, float phi, float3 direction)
{
    float3 localSpaceDir = float3(cos(phi) * sin(theta), sin(phi) * sin(theta), cos(theta));
    // Transform direction to world space
    return mul(localSpaceDir, GetTangentSpace(direction));
}

float3 UniformSampling(float3 normal)
{
    float theta = 0.5 * PI * rand();
    float phi = 2.0 * PI * rand();

    return Tangent2World(theta, phi, normal);
}

float3 CosineSampling(float3 normal)
{
    //float theta = acos(sqrt(1 - rand()));
    float theta = sqrt(rand());
    float phi = 2.0 * PI * rand();

    return Tangent2World(theta, phi, normal);}

// Add Monte Carlo integration
 //Samples uniformly from the hemisphere
 //alpha = 0 for uniform
 //alpha = 1 for cosine
 //alpha > 1 for higher Phong exponents
float3 SampleHemisphere(float3 normal, float alpha)
{
    // Sample the hemisphere, where alpha determines the kind of the sampling
    float cosTheta = pow(rand(), 1.0f / (alpha + 1.0f));
    float sinTheta = sqrt(1.0f - cosTheta * cosTheta);
    float phi = 2 * PI * rand();
    float3 tangentSpaceDir = float3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
    // Transform direction to world space
    return mul(tangentSpaceDir, GetTangentSpace(normal));
}


////////////////////////////
// Importance sampling Light
////////////////////////////
#pragma multi_compile __ SPHERE_LIGHT
#pragma multi_compile __ AREA_LIGHT
#pragma multi_compile __ DISC_LIGHT

#ifdef SPHERE_LIGHT
struct SphereLight
{
    float3 position;
    float radius;
};
int sphereLightCount;
StructuredBuffer<SphereLight> sphereLightBuffer;

float3 ImportanceSamplingSphereLight(SphereLight light, float3 position)
{
    float maxCos = sqrt(1 - pow(light.radius / length(light.position - position), 2));

    float theta = acos(1 - rand() + rand() * maxCos);
    //theta = 2 * PI * u.x;
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(light.position - position);
    // Transform direction to world space
    return Tangent2World(theta, phi, direction);
}
#endif

#ifdef AREA_LIGHT
struct AreaLight
{
    float3 position;
    float3 normal;
    float3 up;
    float2 size;
};
int areaLightCount;
StructuredBuffer<AreaLight> areaLightBuffer;

float3 ImportanceSamplingAreaLight(AreaLight light, float3 position)
{
    float area = light.size.x * light.size.y;

    float x = (rand() * 2 - 1) * light.size.x;
    float z = (rand() * 2 - 1) * light.size.y;

    float3 pointOnArea = float3(x, 0, z);

    float3 binormal = normalize(cross(light.normal, light.up));
    float3x3 m = float3x3(light.up, binormal, light.normal);
    float3 pointWS = mul(pointOnArea, m) + light.position;
    float3 direction = normalize(pointWS - position);
    return pointWS/20;
}
#endif

#ifdef DISC_LIGHT
struct DiscLight
{
    float3 position;
    float3 normal;
    float radius;
};
int discLightCount;
StructuredBuffer<DiscLight> discLightBuffer;

float3 ImportanceSamplingDiscLight(DiscLight light, float3 position)
{
    float theta = sqrt(rand() * light.radius);
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(light.position - position);
    // Transform direction to world space
    return Tangent2World(theta, phi, direction);
}
#endif


float3 ImportanceSamplingLight(float3 position)
{
#if (defined (SPHERE_LIGHT)) && (defined (AREA_LIGHT))
    float roulette = rand();
    if (roulette > 0.5)
        return ImportanceSamplingSphereLight(sphereLightBuffer[rand() * sphereLightCount], position);
    else
        return ImportanceSamplingAreaLight(areaLightBuffer[rand() * areaLightCount], position);
#else
    #ifdef SPHERE_LIGHT
        return ImportanceSamplingSphereLight(sphereLightBuffer[rand() * sphereLightCount], position);
    #else
        return ImportanceSamplingAreaLight(areaLightBuffer[rand() * areaLightCount], position);
    #endif
#endif
}

////////////////////////////
// Importance sampling BRDF
////////////////////////////
float SmoothnessToPerceptualRoughness(float smoothness)
{
    return (1 - smoothness);
}

float PerceptualRoughnessToRoughness(float perceptualRoughness)
{
    return perceptualRoughness * perceptualRoughness;
}

float SmoothnessToPhongAlpha(float s)
{
  return pow(10000.0f, s);
}


float3 ImportanceSamplingBRDF(float3 direction, RayHit hit)
{
    // 和Unity一样，采样GGX法线分布
    float alpha = SmoothnessToPhongAlpha(hit.smoothness);

    float theta = acos(pow(sqrt(rand()), 1 / (alpha+1)));
    float phi = 2.0 * PI * rand();

    float3 normal = reflect(direction, hit.normal);;

    return Tangent2World(theta, phi, normal);
}

void ImportanceSampling(RayHit hit, inout Ray ray)
{
    ray.origin = hit.position + hit.normal * 0.001f;
    //ray.direction = UniformSampling(hit.normal);
    //ray.direction = CosineSampling(hit.normal);

    float3 samplingLightDir = ImportanceSamplingLight(ray.origin);

    //if (0.5 > rand() && dot(samplingLightDir, hit.normal) > 0)
    //{
        ray.direction = samplingLightDir;
    //}
    //else
    //{
    //    if (hit.smoothness > rand())
    //        ray.direction = ImportanceSamplingBRDF(ray.direction, hit);
    //    else
    //        ray.direction = CosineSampling(hit.normal);
    //}
}