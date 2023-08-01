﻿#ifndef IMPORTANCE_SAMPLING_INCLUDE
#define IMPORTANCE_SAMPLING_INCLUDE

static const float4 COLOR_SPACE_DIELECTRIC_SPEC  = half4(0.08, 0.08, 0.08, 1.0 - 0.04); // standard dielectric reflectivity coef at incident angle (= 4%)

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
    float maxCos = sqrt(1 - pow(light.radius / length(light.position - ray.origin), 2));

    float theta = acos(1 - rand() + rand() * maxCos);
    //theta = 2 * PI * u.x;
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(light.position - ray.origin);
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

// Sampling Blinn, 这个是最简单的Microfacet Model
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

// 和unity方法同名
inline float GGXTerm (float NdotH, float roughness)
{
    float a2 = roughness * roughness;
    float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; // 2 mad
    return a2 / (PI * (d * d + 1e-7f)); // This function is not intended to be running on Mobile,
                                            // therefore epsilon is smaller than what can be represented by half
}

inline half Pow5 (half x)
{
    return x*x * x*x * x;
}

inline half3 FresnelTerm (half3 F0, half cosA)
{
    half t = Pow5 (1 - cosA);   // ala Schlick interpoliation
    return F0 + (1-F0) * t;
}

// Ref: http://jcgt.org/published/0003/02/03/paper.pdf
inline half SmithJointGGXVisibilityTerm (half NdotL, half NdotV, half roughness)
{
    // Approximation of the above formulation (simplify the sqrt, not mathematically correct but close enough)
    half a = roughness;
    half lambdaV = NdotL * (NdotV * (1 - a) + a);
    half lambdaL = NdotV * (NdotL * (1 - a) + a);

    return 0.5f / (lambdaV + lambdaL + 1e-5f);
}

float3 SpecularBRDF(float3 albedo, float metallic, float3 normal, float3 viewDir, float3 halfDir, float3 lightDir, float roughness)
{
    half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
    half nl = saturate(dot(normal, lightDir));
    float nh = saturate(dot(normal, halfDir));

    half lv = saturate(dot(lightDir, viewDir));
    half lh = saturate(dot(lightDir, halfDir));

    half hv = saturate(dot(halfDir, viewDir));

    float D = GGXTerm(nh, roughness);
    float3 F0 = lerp (COLOR_SPACE_DIELECTRIC_SPEC.rgb, albedo, metallic);
    float3 F = FresnelTerm(F0, hv);
    float G = SmithJointGGXVisibilityTerm (nl, nv, roughness);

    half specularTerm = D * G * PI;
    specularTerm = max(0, specularTerm * nl);

    float3 nominator = D * G * F;
    float denominator = 4.0 * nv * nl + 0.001;
    float3 brdf = nominator / denominator;
    float pdf = D * nh / (4.0 * hv);

    return metallic;
    // 可以化简 brdf / pdf
    if (pdf > 0)
        return brdf / pdf * nl;
    else
        return 0;
    return F * G * hv / (nv * nl * nh);
}

float3 ImportanceSamplingBRDF(RayHit hit, inout Ray ray)
{
    // https://zhuanlan.zhihu.com/p/505284731
    // https://toposcat.top/cn/2020/10/13/Importance%20Sampling/
    // https://agraphicsguynotes.com/posts/sample_microfacet_brdf/

    float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    // GGX with roughtness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughtness remapping.
    roughness = max(roughness, 0.002);
    float roughness2 = roughness * roughness;

    float e = rand();
    float theta = acos(sqrt((1 - e) / (e * (roughness2 - 1) + 1)));
    float phi = 2.0 * PI * rand();

    // Microfacet normal, 微表面法线
    float3 viewDir = normalize(-ray.direction);
    float3 halfDir = Tangent2World(theta, phi, hit.normal);
    ray.direction = normalize(reflect(ray.direction, halfDir)); 

    // float3 result = f / pdf * saturate(dot(hit.normal, ray.direction));
    float3 specularBRDF = SpecularBRDF(hit.albedo, hit.metallic, hit.normal, viewDir, normalize(viewDir + ray.direction), ray.direction, roughness);

    return specularBRDF;
}

float3 ImportanceSampling(RayHit hit, inout Ray ray)
{
    // 这里处理的是 fr(x, ωi, ωo) * (ωo⋅n) / pdf 部分
    float3 output = 0;

    ray.origin = hit.position + hit.normal * 0.001f;

    //float3 lightOutput = ImportanceSamplingLight(hit, ray);

    //if (0.5 > rand()/* && dot(ray.direction, hit.normal) > 0*/)
    //{
    //    output = lightOutput;
    //}
    //else
    //{
    //    if (hit.smoothness > rand())
    //        output = ImportanceSamplingBRDF(hit, ray);
    //    else
    ////output = UniformSampling(hit, ray);
    //    output = CosineSampling(hit, ray);
    //}


    output = ImportanceSamplingBRDF(hit, ray);

    return output;
}
#endif