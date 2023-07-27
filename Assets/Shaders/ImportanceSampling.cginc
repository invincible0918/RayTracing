
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
int lightCount;
StructuredBuffer<float4> lightBuffer;
float3 ImportanceSamplingLight(float4 light, float3 position)
{
    float3 lightPosition = light.xyz;
    float lightRadius = light.w;
    float maxCos = sqrt(1 - pow(lightRadius / length(lightPosition - position), 2));

    float theta = acos(1 - rand() + rand() * maxCos);
    //theta = 2 * PI * u.x;
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(lightPosition - position);
    // Transform direction to world space
    return Tangent2World(theta, phi, direction);
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
    float4 importanceLight = lightBuffer[rand() * lightCount];

    ray.origin = hit.position + hit.normal * 0.001f;
    //ray.direction = UniformSampling(hit.normal);
    //ray.direction = CosineSampling(hit.normal);

    float3 samplingLightDir = ImportanceSamplingLight(importanceLight, ray.origin);

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
