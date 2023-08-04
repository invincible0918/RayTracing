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

void SphereLightImportanceSampling(RayHit hit, inout Ray ray, SphereLight light, out float3 func, out float pdf)
{
    // https://zhuanlan.zhihu.com/p/508136071
    // https://www.pbr-book.org/3ed-2018/Light_Transport_I_Surface_Reflection/Sampling_Light_Sources
    float3 dir = light.position - hit.position;
    float maxCos = sqrt(1 - pow(light.radius / length(dir), 2));

    float theta = acos(1 - rand() + rand() * maxCos);
    //theta = 2 * PI * u.x;
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(dir);
    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = Tangent2World(theta, phi, direction);

    func = hit.albedo / PI * saturate(dot(hit.normal, ray.direction));
    pdf = 1.0 / (2.0 * PI * (1 - maxCos));
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

void AreaLightImportanceSampling(RayHit hit, inout Ray ray, AreaLight light, out float3 func, out float pdf)
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

    func = hit.albedo / PI * saturate(dot(hit.normal, ray.direction));
    pdf = distanceSquard / (lightCosine * area);
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

void DiscLightImportanceSampling(RayHit hit, inout Ray ray, DiscLight light, out float3 func, out float pdf)
{
    float theta = sqrt(rand() * light.radius);
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(light.position - hit.position);
    // Transform direction to world space

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = Tangent2World(theta, phi, direction);

    func = hit.albedo / PI * saturate(dot(hit.normal, ray.direction));
    pdf = 1 / (PI * light.radius * light.radius);
}
#endif

void _LightImportanceSampling(RayHit hit, inout Ray ray, out float3 func, out float pdf)
{
    // https://blog.csdn.net/qq_35312463/article/details/117190054
#if (defined (SPHERE_LIGHT)) && (defined (AREA_LIGHT))
    float roulette = rand();
    if (roulette > 0.5)
        SphereLightImportanceSampling(hit, ray, sphereLightBuffer[rand() * sphereLightCount], func, pdf);
    else
        AreaLightImportanceSampling(hit, ray, areaLightBuffer[rand() * areaLightCount], func, pdf);
#else
    #ifdef SPHERE_LIGHT
        SphereLightImportanceSampling(hit, ray, sphereLightBuffer[rand() * sphereLightCount], func, pdf);
    #endif

    #if defined(AREA_LIGHT)
        AreaLightImportanceSampling(hit, ray, areaLightBuffer[rand() * areaLightCount], func, pdf);
    #endif
#endif
    
    // 如果光线传递方向在normal后侧，则直接判断为不被照明到
    if (dot(ray.direction, hit.normal) < 0.01)
    {
        func = 0;
        pdf = -1;
    }
}

float3 LightImportanceSampling(RayHit hit, inout Ray ray)
{
    float3 func;
    float pdf;

    _LightImportanceSampling(hit, ray, func, pdf);

    if (pdf > 0)
        return func / pdf;
    else
        return 0;
}

/////////////////////////////////////////////////////////////////////////////
//////////////////////// Importance sampling BRDF ///////////////////////////
/////////////////////////////////////////////////////////////////////////////
void BRDF(float3 viewDir, float3 halfDir, float3 lightDir, float3 albedo, float3 normal, float metallic, float perceptualRoughness, float roughness, float diffuseRatio, float specularRoatio, out float3 func, out float pdf)
{
    // 准备计算用参数
    float oneMinusReflectivity;
    float3 specColor;
    float3 diffuse = DiffuseAndSpecularFromMetallic (albedo, metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);
    //// shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    //// this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
    //half outputAlpha;
    //s.Albedo = PreMultiplyAlpha (s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

    float diffusePdf;
    float3 diffuseBRDF = DiffuseBRDF(diffuse, normal, viewDir, halfDir, lightDir, perceptualRoughness, diffusePdf);

    float specularPdf;
    float3 F;
    float3 specularBRDF = SpecularBRDF(diffuse, specColor, metallic, normal, viewDir, halfDir, lightDir, roughness, F, specularPdf);

    float3 kS = F;
    float3 kD = 1.0 - kS;
    kD *= 1.0 - metallic;

    float3 totalBrdf = (diffuseBRDF * kD + specularBRDF) * saturate(dot(normal, lightDir));
    float totalPdf = diffusePdf * diffuseRatio + specularPdf * specularRoatio;
    
    //if (diffusePdf > 0)
    //    return diffuseBRDF/diffusePdf * saturate(dot(hit.normal, lightDir));
    //else
    //    return 1;

    func = totalBrdf;
    pdf = totalPdf;
}

void _BRDFImportanceSampling(float3 inputDir, float3 outputDir, RayHit hit, inout Ray ray, out float3 func, out float pdf)
{
    // https://zhuanlan.zhihu.com/p/505284731
    // https://toposcat.top/cn/2020/10/13/Importance%20Sampling/
    // https://agraphicsguynotes.com/posts/sample_microfacet_brdf/

    float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

    float diffuseRatio = 0.5 * (1.0 - hit.metallic);
    float specularRoatio = 1 - diffuseRatio;

    float3 viewDir = normalize(-inputDir);
    float3 halfDir = normalize(viewDir + outputDir);
    float3 lightDir = outputDir;

    BRDF(viewDir, halfDir, lightDir, hit.albedo, hit.normal, hit.metallic, perceptualRoughness, roughness, diffuseRatio, specularRoatio, func, pdf);

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = outputDir;
}

void _BRDFImportanceSampling(RayHit hit, inout Ray ray, out float3 func, out float pdf)
{
    // https://zhuanlan.zhihu.com/p/505284731
    // https://toposcat.top/cn/2020/10/13/Importance%20Sampling/
    // https://agraphicsguynotes.com/posts/sample_microfacet_brdf/

    float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

    float diffuseRatio = 0.5 * (1.0 - hit.metallic);
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

    BRDF(viewDir, halfDir, lightDir, hit.albedo, hit.normal, hit.metallic, perceptualRoughness, roughness, diffuseRatio, specularRoatio, func, pdf);

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = reflectionDir;
}

float3 BRDFImportanceSampling(RayHit hit, inout Ray ray)
{
    float3 func;
    float pdf;

    _BRDFImportanceSampling(hit, ray, func, pdf);
    
    if (pdf > 0)
        return func / pdf;
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
    float3 lightFunc;
    float lightPdf;
    float3 inputDir = ray.direction;
    _LightImportanceSampling(hit, ray, lightFunc, lightPdf);
    float3 outputDir = ray.direction;

    // 0.01 不宜过小，否则会产生锯齿阴影
    if (rand() > 0.5 && dot(hit.normal, outputDir) > 0.01)
    {
        float lightWeight;

        if (lightPdf > 0)
            lightWeight = 0.5;

        float3 brdfFunc;
        float brdfPdf;
        float brdfWeight;

        _BRDFImportanceSampling(inputDir, outputDir, hit, ray, brdfFunc, brdfPdf);

        if (brdfPdf > 0)
            brdfWeight = 0.5;

        float3 func = /*lightFunc + */brdfFunc;
        float pdf = lightPdf * 0.5 + brdfFunc * 0.5;

        if (pdf > 0)
            return func / pdf;
        else
            return 0; // 如果光线传递方向在normal后侧，则直接判断为不被照明到
    }
    else
    {
        ray.direction = inputDir;

        float3 func;
        float pdf;

        _BRDFImportanceSampling(hit, ray, func, pdf);

        if (pdf > 0 )
            return func / pdf;
        else
            return 1;
    }
}
#endif