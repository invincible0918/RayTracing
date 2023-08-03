#ifndef IMPORTANCE_SAMPLING_INCLUDE
#define IMPORTANCE_SAMPLING_INCLUDE

#include "BSDF.cginc"

/////////////////////////////////////////////////////////////////////////////
///////////////////////////// Common function ///////////////////////////////
/////////////////////////////////////////////////////////////////////////////
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

/////////////////////////////////////////////////////////////////////////////
/////////////////////// Uniform Sampling ////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
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

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = Tangent2World(theta, phi, hit.normal);

    float pdf = 1.0 / (2.0 * PI);
    float3 fr = hit.albedo / PI;

    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));

    return result;
}

/////////////////////////////////////////////////////////////////////////////
//////////////////////// Cosine Sampling ////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
float3 CosineSampling(RayHit hit, inout Ray ray)
{
    // https://sites.google.com/site/ivorsgraphicsblog/ray-tracing-engine/cosine-distributed-sampling
    //float theta = acos(sqrt(1 - rand()));
    float theta = sqrt(rand());
    float phi = 2.0 * PI * rand();

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = Tangent2World(theta, phi, hit.normal);

    // 这是使用经典 diffuse brdf
    //float pdf = cos / PI;
    //float3 fr = hit.albedo / PI;
    //float3 result = fr / pdf * cos; 可以化简
    float3 result = hit.albedo;

    return result;
}

/////////////////////////////////////////////////////////////////////////////
//////////////////////// Importance sampling Light //////////////////////////
/////////////////////////////////////////////////////////////////////////////
#ifdef SPHERE_LIGHT
struct SphereLight
{
    float3 position;
    float radius;
};
int sphereLightCount;
StructuredBuffer<SphereLight> sphereLightBuffer;

float3 SphereLightImportanceSampling(RayHit hit, inout Ray ray, SphereLight light)
{
    // https://zhuanlan.zhihu.com/p/508136071
    float maxCos = sqrt(1 - pow(light.radius / length(light.position - ray.origin), 2));

    float theta = acos(1 - rand() + rand() * maxCos);
    //theta = 2 * PI * u.x;
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(light.position - ray.origin);
    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = Tangent2World(theta, phi, direction);

    float pdf = 1.0 / (2.0 * PI * (1 - maxCos));

    float3 fr = hit.albedo / PI;

    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));

    return fr;
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

float3 AreaLightImportanceSampling(RayHit hit, inout Ray ray, AreaLight light)
{
    // https://blog.csdn.net/qq_35312463/article/details/117190054

    float x = (rand() * 2 - 1) * light.size.x / 2;
    float z = (rand() * 2 - 1) * light.size.y / 2;

    float3 pointOnArea = float3(x, 0, z);

    float3 binormal = normalize(cross(light.normal, light.up));
    float3x3 m = float3x3(binormal, light.normal, light.up);
    float3 pointWS = mul(pointOnArea, m) + light.position;

    // Calculate pdf
    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = pointWS - hit.position;

    float distanceSquard = dot(ray.direction, ray.direction);
    float area = light.size.x * light.size.y;
    float lightCosine = dot(normalize(-ray.direction), light.normal);
    ray.direction = normalize(ray.direction);

    float3 fr = hit.albedo / PI;
    float pdf = distanceSquard / (lightCosine * area);


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

float3 DiscLightImportanceSampling(RayHit hit, inout Ray ray, DiscLight light)
{
    float theta = sqrt(rand() * light.radius);
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(light.position - hit.position);
    // Transform direction to world space

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = Tangent2World(theta, phi, direction);

    float pdf = 1 / (PI * light.radius * light.radius);

    float3 fr = hit.albedo / PI;

    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));

    return result;
}
#endif


float3 LightImportanceSampling(RayHit hit, inout Ray ray)
{
    // https://blog.csdn.net/qq_35312463/article/details/117190054
#if (defined (SPHERE_LIGHT)) && (defined (AREA_LIGHT))
    float roulette = rand();
    if (roulette > 0.5)
        return SphereLightImportanceSampling(hit, ray, sphereLightBuffer[rand() * sphereLightCount]);
    else
        return AreaLightImportanceSampling(hit, ray, areaLightBuffer[rand() * areaLightCount]);
#else
    #ifdef SPHERE_LIGHT
    return SphereLightImportanceSampling(hit, ray, sphereLightBuffer[rand() * sphereLightCount]);
    #endif

    #if defined(AREA_LIGHT)
        return AreaLightImportanceSampling(hit, ray, areaLightBuffer[rand() * areaLightCount]);
    #endif
#endif

    return 0;
}

/////////////////////////////////////////////////////////////////////////////
//////////////////////// Importance sampling BRDF ///////////////////////////
/////////////////////////////////////////////////////////////////////////////
float3 BRDFImportanceSampling(RayHit hit, inout Ray ray)
{
    // https://zhuanlan.zhihu.com/p/505284731
    // https://toposcat.top/cn/2020/10/13/Importance%20Sampling/
    // https://agraphicsguynotes.com/posts/sample_microfacet_brdf/

    float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

    float diffuseRatio = 0.5 * (1.0 - hit.smoothness);
    float specularRoatio = 1 - diffuseRatio;
    float roulette = rand();

    float3 reflectionDir;
    if (roulette < diffuseRatio)
    {
        float theta = sqrt(rand());
        float phi = 2.0 * PI * rand();

        reflectionDir = Tangent2World(theta, phi, hit.normal);
    }
    else
    {
        // GGX with roughtness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughtness remapping.
        roughness = max(roughness, 0.002);
        float roughness2 = roughness * roughness;

        float e = rand();
        float theta = acos(sqrt((1 - e) / (e * (roughness2 - 1) + 1)));
        float phi = 2.0 * PI * rand();

        // Microfacet normal, 微表面法线
        float3 microfacetNormal = Tangent2World(theta, phi, hit.normal);
        reflectionDir = normalize(reflect(ray.direction, microfacetNormal));
    }

    float3 viewDir = normalize(-ray.direction);
    float3 halfDir = normalize(viewDir + reflectionDir);
    float3 lightDir = reflectionDir;

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = reflectionDir;

    // 准备计算用参数
    float diffusePdf;
    float3 diffuseBRDF = DiffuseBRDF(hit.albedo, hit.normal, viewDir, halfDir, lightDir, perceptualRoughness, diffusePdf);

    float specularPdf;
    float3 F;
    float3 specularBRDF = SpecularBRDF(hit.albedo, hit.metallic, hit.normal, viewDir, halfDir, lightDir, roughness, F, specularPdf);

    float3 kS = F;
    float3 kD = 1.0 - kS;
    kD *= 1.0 - hit.metallic;


    float3 totalBrdf = (diffuseBRDF + specularBRDF) * saturate(dot(hit.normal, lightDir));
    float totalPdf = diffusePdf  + specularPdf;
    
    if (totalPdf > 0)
        return totalBrdf / totalPdf;
    else
        return 1;
}

/////////////////////////////////////////////////////////////////////////////
////////////////////// multiple Importance sampling /////////////////////////
/////////////////////////////////////////////////////////////////////////////
float3 MultipleImportanceSampling(RayHit hit, inout Ray ray)
{
    // L(x,ωo)=Le(x,ωo)+∫ΩLi(x,ωi) * fr(x,ωi,ωo) * (ωo⋅n) * dωo
    // 论文里是 ωi⋅n, 是因为光线从光源出发，但是具体实现的时候我们是光线从摄像机出发
    // 为什么要乘以一个 cos 值，是因为入射到表面的方向不同，则表面单位面积接受到的光能量大小也是不同的
    // 同样强度的光，对于左边斜着方向发射到矩形的表面的光源和右边垂直发射到表面的光源，表面的单位面积接收到的光能量是不一样的。

    // output的光 = 自发光 + 入射的光 * BRDF * 反射的角度, 入射光即ray.energy
    // 渲染方程的泰勒展开 https://zhuanlan.zhihu.com/p/463166884
    // 转化成 Monte Carlo Integration 蒙特卡洛积分
    // L(x,ωo)=Le(x,ωo) + 1/N * ∑fr(x, ωi, ωo) * (ωo⋅n) / pdf * dωo

    // 这里处理的是 fr(x, ωi, ωo) / pdf * (ωo⋅n)  部分

    float3 output = 0;

    ray.origin = hit.position + hit.normal * 0.001f;

    float3 lightOutput = LightImportanceSampling(hit, ray);
    if (0.5 > rand()/* && dot(ray.direction, hit.normal) > 0*/)
    {
        return lightOutput;
    }
    else
    {
        //if (hit.smoothness > rand())
        //    output = BRDFImportanceSampling(hit, ray);
        //else
    //output = UniformSampling(hit, ray);
        return CosineSampling(hit, ray);
    }
}
#endif