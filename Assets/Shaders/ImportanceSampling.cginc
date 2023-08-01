﻿#ifndef IMPORTANCE_SAMPLING_INCLUDE
#define IMPORTANCE_SAMPLING_INCLUDE

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

float3 UniformSampling(RayHit hit, inout Ray ray)
{
    // https://sites.google.com/site/ivorsgraphicsblog/ray-tracing-engine/cosine-distributed-sampling
    // 这里处理的是 fr(x, ωi, ωo) * (ωo⋅n) / pdf 部分

    // For a perfectly diffuse surface
    // fr(x, ωi, ωo) = c / PI, c is the diffuse material color
    // pdf = 1 / 2⋅PI
    // fr(x, ωi, ωo) * (ωo⋅n) / pdf 化简为 2c * (ωo⋅n)
    float theta = 0.5 * PI * rand();
    float phi = 2.0 * PI * rand();
    ray.direction = Tangent2World(theta, phi, hit.normal);

    float pdf = 1.0 / (2.0 * PI);
    float3 fr = hit.albedo / PI;

    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));

    return result;
}

float3 CosineSampling(RayHit hit, inout Ray ray)
{
    // https://sites.google.com/site/ivorsgraphicsblog/ray-tracing-engine/cosine-distributed-sampling
    //float theta = acos(sqrt(1 - rand()));
    float theta = sqrt(rand());
    float phi = 2.0 * PI * rand();
    ray.direction = Tangent2World(theta, phi, hit.normal);

    //pdf = cos / PI;
    //float3 fr = hit.albedo / PI;
    //float3 result = fr / pdf * cos; 可以化简
    float3 result = hit.albedo;

    return result;
}

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
#ifdef SPHERE_LIGHT
struct SphereLight
{
    float3 position;
    float radius;
};
int sphereLightCount;
StructuredBuffer<SphereLight> sphereLightBuffer;

float3 ImportanceSamplingSphereLight(RayHit hit, inout Ray ray, SphereLight light)
{
    // https://zhuanlan.zhihu.com/p/508136071
    float maxCos = sqrt(1 - pow(light.radius / length(light.position - position), 2));

    float theta = acos(1 - rand() + rand() * maxCos);
    //theta = 2 * PI * u.x;
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(light.position - position);
    ray.direction = Tangent2World(theta, phi, direction);

    float pdf = 1.0 / (2.0 * PI * (1 - maxCos));

    float3 fr = hit.albedo / PI;

    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));

    return result;
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

float3 ImportanceSamplingAreaLight(RayHit hit, inout Ray ray, AreaLight light)
{
    // https://blog.csdn.net/qq_35312463/article/details/117190054

    float x = (rand() * 2 - 1) * light.size.x / 2;
    float z = (rand() * 2 - 1) * light.size.y / 2;

    float3 pointOnArea = float3(x, 0, z);

    float3 binormal = normalize(cross(light.normal, light.up));
    float3x3 m = float3x3(binormal, light.normal, light.up);
    float3 pointWS = mul(pointOnArea, m) + light.position;

    // Calculate pdf
    ray.direction = pointWS - hit.position;
    float distanceSquard = dot(ray.direction, ray.direction);
    float area = light.size.x * light.size.y;
    float lightCosine = dot(normalize(-ray.direction), light.normal);
    ray.direction = normalize(ray.direction);

    float pdf = distanceSquard / (lightCosine * area);

    float3 fr = hit.albedo / PI;

    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));

    return result;
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

float3 ImportanceSamplingDiscLight(RayHit hit, inout Ray ray, DiscLight light)
{
    float theta = sqrt(rand() * light.radius);
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(light.position - hit.position);
    // Transform direction to world space
    ray.direction = Tangent2World(theta, phi, direction);

    float pdf = 1 / (PI * light.radius * light.radius);

    float3 fr = hit.albedo / PI;

    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));

    return result;
}
#endif


float3 ImportanceSamplingLight(RayHit hit, inout Ray ray)
{
    // https://blog.csdn.net/qq_35312463/article/details/117190054
#if (defined (SPHERE_LIGHT)) && (defined (AREA_LIGHT))
    float roulette = rand();
    if (roulette > 0.5)
        return ImportanceSamplingSphereLight(hit, ray, sphereLightBuffer[rand() * sphereLightCount]);
    else
        return ImportanceSamplingAreaLight(hit, ray, areaLightBuffer[rand() * areaLightCount]);
#else
    #ifdef SPHERE_LIGHT
        return ImportanceSamplingSphereLight(hit, ray, sphereLightBuffer[rand() * sphereLightCount]);
    #endif

    #if defined(AREA_LIGHT)
        return ImportanceSamplingAreaLight(hit, ray, areaLightBuffer[rand() * areaLightCount]);
    #endif
#endif

    return 0;
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

//float3 ImportanceSamplingBRDF(RayHit hit, float3 direction, out float pdf)
//{
//    // http://three-eyed-games.com/2018/05/12/gpu-path-tracing-in-unity-part-2/
//    // 和Unity一样，采样GGX法线分布
//    float alpha = SmoothnessToPhongAlpha(hit.smoothness);

//    float theta = acos(pow(sqrt(rand()), 1 / (alpha+1)));
//    float phi = 2.0 * PI * rand();

//    float3 normal = reflect(direction, hit.normal);

//    pdf = 1;

//    return Tangent2World(theta, phi, normal);
//}

float3 SpecularBRDF()
{
    return 1;
}

float3 ImportanceSamplingBRDF(RayHit hit, inout Ray ray)
{
    // https://toposcat.top/cn/2020/10/13/Importance%20Sampling/
    // https://agraphicsguynotes.com/posts/sample_microfacet_brdf/

    float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    float roughness2 = roughness * roughness;

    float e = rand();
    float theta = acos(sqrt((1 - e) / (e * (roughness2 - 1) + 1)));
    float phi = 2.0 * PI * rand();

    ray.direction = Tangent2World(theta, phi, hit.normal);

    //+0.00001f to avoid dividing by 0
    float denom = (roughness2 - 1.0f) * cos(theta) * cos(theta) + 1.0f + 0.00001;
    float pdf = (2 * roughness2 * cos(theta) * sin(theta))/* / (denom * denom)*/;

    float3 fr = SpecularBRDF();
    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));

    return hit.smoothness;
}

float3 ImportanceSampling(RayHit hit, inout Ray ray)
{
    // 这里处理的是 fr(x, ωi, ωo) * (ωo⋅n) / pdf 部分
    float3 output = 0;

    ray.origin = hit.position + hit.normal * 0.001f;

    //float3 lightOutput = ImportanceSamplingLight(hit, ray);

    //if (0.5 > rand() && dot(ray.direction, hit.normal) > 0)
    //{
    //    output = lightOutput;
    //}
    //else
    //{
    //    //if (hit.smoothness > rand())
    //    //    ray.direction = ImportanceSamplingBRDF(hit, samplingLightDir, ray.direction, pdf);
    //    //else
    ////output = UniformSampling(hit, ray);
    //    output = CosineSampling(hit, ray);
    //}


    output = ImportanceSamplingBRDF(hit, ray);

    return output;
}
#endif