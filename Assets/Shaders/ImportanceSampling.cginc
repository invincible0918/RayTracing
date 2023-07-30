#ifndef IMPORTANCE_SAMPLING_INCLUDE
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

float3 UniformSampling(float3 normal, out float pdf)
{
    float theta = 0.5 * PI * rand();
    float phi = 2.0 * PI * rand();

    pdf = 1.0 / (2.0 * PI);

    return Tangent2World(theta, phi, normal);
}

float3 CosineSampling(float3 normal, Ray ray, out float pdf)
{
    //float theta = acos(sqrt(1 - rand()));
    float theta = sqrt(rand());
    float phi = 2.0 * PI * rand();

    float3 direction = Tangent2World(theta, phi, normal);
    pdf = dot(normal, direction) / PI;

    return direction;
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

float3 ImportanceSamplingSphereLight(SphereLight light, float3 position, out float pdf)
{
    // https://zhuanlan.zhihu.com/p/508136071
    float maxCos = sqrt(1 - pow(light.radius / length(light.position - position), 2));

    float theta = acos(1 - rand() + rand() * maxCos);
    //theta = 2 * PI * u.x;
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(light.position - position);

    pdf = 1.0 / (2.0 * PI * (1 - maxCos));
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

float3 ImportanceSamplingAreaLight(AreaLight light, float3 position, out float pdf)
{
    // https://blog.csdn.net/qq_35312463/article/details/117190054

    float x = (rand() * 2 - 1) * light.size.x / 2;
    float z = (rand() * 2 - 1) * light.size.y / 2;

    float3 pointOnArea = float3(x, 0, z);

    float3 binormal = normalize(cross(light.normal, light.up));
    float3x3 m = float3x3(binormal, light.normal, light.up);
    float3 pointWS = mul(pointOnArea, m) + light.position;

    // Calculate pdf
    float3 direction = pointWS - position;
    float distanceSquard = dot(direction, direction);
    float area = light.size.x * light.size.y;
    float lightCosine = dot(normalize(-direction), light.normal);

    pdf = distanceSquard / (lightCosine * area);

    return pointWS;
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


float3 ImportanceSamplingLight(float3 position, out float pdf)
{
#if (defined (SPHERE_LIGHT)) && (defined (AREA_LIGHT))
    float roulette = rand();
    if (roulette > 0.5)
        return ImportanceSamplingSphereLight(sphereLightBuffer[rand() * sphereLightCount], position, pdf);
    else
        return ImportanceSamplingAreaLight(areaLightBuffer[rand() * areaLightCount], position, pdf);
#else
    #ifdef SPHERE_LIGHT
        return ImportanceSamplingSphereLight(sphereLightBuffer[rand() * sphereLightCount], position, pdf);
    #endif

    #if defined(AREA_LIGHT)
        return ImportanceSamplingAreaLight(areaLightBuffer[rand() * areaLightCount], position, pdf);
    #endif
#endif

    pdf = -1;
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

float3 ImportanceSamplingBRDF(RayHit hit, float lightDir, float3 direction, out float pdf)
{
    // https://toposcat.top/cn/2020/10/13/Importance%20Sampling/

    // 使用场景内灯光方向计算效果更好，参考ppt, float3 lightDir = normalize(ray.direction);
	//float3 lightDir = normalize(direction);
    float3 camPos = mul(camera2World, float4(0, 0, 0, 1)).xyz;
    float3 viewDir = normalize(camPos - hit.position);

    float3 halfDir = normalize (lightDir + viewDir);
    float nh = saturate(dot(hit.normal, halfDir));

    float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    float roughness2 = roughness * roughness;

    float f = (roughness2 - 1) * nh * nh + 1;
    pdf = 1;//roughness2 * nh / (PI * f * f);

    float e = roughness2 / (nh * nh * (pow(roughness2 - 1, 2) + roughness2 - 1)) - 1 / (roughness2 - 1);
    //float theta = acos(sqrt((1 - e) / (e * (roughness2 - 1) + 1)));
    //float phi = 2.0 * PI * rand();

    float alpha = SmoothnessToPhongAlpha(hit.smoothness);

    float theta = acos(pow(sqrt(rand()), 1 / (alpha+1)));
    float phi = 2.0 * PI * rand();

    float3 normal = reflect(direction, hit.normal);
    return Tangent2World(theta, phi, normal);
}

void ImportanceSampling(RayHit hit, inout Ray ray, out float pdf)
{
    ray.origin = hit.position + hit.normal * 0.001f;
    //ray.direction = UniformSampling(hit.normal);
    //ray.direction = CosineSampling(hit.normal);

    float3 samplingLightDir = ImportanceSamplingLight(ray.origin, pdf);

    //if (0.5 > rand()/* && dot(samplingLightDir, hit.normal) > 0*/)
    //{
    //    ray.direction = samplingLightDir;
    //}
    //else
    //{
        //if (hit.smoothness > rand())
            ray.direction = ImportanceSamplingBRDF(hit, samplingLightDir, ray.direction, pdf);
        //else
            //ray.direction = CosineSampling(hit.normal, ray, pdf);
            //ray.direction = UniformSampling(hit.normal, pdf);
    //}
}
#endif