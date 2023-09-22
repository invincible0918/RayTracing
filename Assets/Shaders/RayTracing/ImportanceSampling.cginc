#ifndef _IMPORTANCE_SAMPLING_
#define _IMPORTANCE_SAMPLING_

//////////////// chapter6_3 //////////////
#include "BRDF.cginc"

//////////////// chapter6_2 //////////////
#ifdef SPHERE_LIGHT
struct SphereLight
{
    float3 position;
    float radius;
};
int sphereLightCount;
StructuredBuffer<SphereLight> sphereLightBuffer;
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
#endif

//////////////// chapter5_2 //////////////
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

// 在 direction方向所在的半球上均值采样方向
float3 Tangent2World(float theta, float phi, float3 direction)
{
    float3 localSpaceDir = float3(cos(phi) * sin(theta), sin(phi) * sin(theta), cos(theta));
    // Transform direction to world space
    return normalize(mul(localSpaceDir, GetTangentSpace(direction)));
}

float3 UniformSampling(RayHit hit, inout Ray ray)
{
	//将渲染方程
	// L(p, ωo) = Le(p, ωo)+∫Ωfr(p, ωi, ωo)(ωi⋅n)L(p, ωi)dωi
	// 写成蒙特卡洛积分形式
	// L(p, ωo) = Le(p, ωo) + 1/N * ∑fr(p,  ωi,  ωo) / pdf ⋅ (ωi⋅n)L(p, ωi)

	// pdf = 1 / 2⋅ pi
	// fr = c / pi      // https://sites.google.com/site/ivorsgraphicsblog/ray-tracing-engine/cosine-distributed-sampling

    float theta = acos(1 - Rand());
    float phi = 2.0 * PI * Rand();

	ray.origin = hit.position + hit.normal * 0.01f;
	ray.direction = Tangent2World(theta, phi, hit.normal);

    float pdf = 1.0 / (2.0 * PI);
    float3 fr = hit.albedo / PI;        // Diffuse BRDF, https://google.github.io/filament/Filament.html#materialsystem/diffusebrdf

    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));
    return result;
}

//////////////// chapter6_1 //////////////
float3 CosineWeightedSampling(RayHit hit, inout Ray ray)
{
    float theta = acos(sqrt(1 - Rand()));
    float phi = 2.0 * PI * Rand();

	ray.origin = hit.position + hit.normal * 0.01f;
	ray.direction = Tangent2World(theta, phi, hit.normal);

    //float pdf = cos / PI;
    //float3 fr = hit.albedo / PI;        // Diffuse BRDF, https://google.github.io/filament/Filament.html#materialsystem/diffusebrdf
    //float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));
    float3 result = hit.albedo;
    return result;
}

//////////////// chapter6_2 //////////////
#ifdef SPHERE_LIGHT
void SphereLightImportanceSampling(RayHit hit, inout Ray ray, SphereLight light, out float3 func, out float pdf)
{
    // https://www.pbr-book.org/3ed-2018/Light_Transport_I_Surface_Reflection/Sampling_Light_Sources
    float3 dir = light.position - hit.position;
    float maxCos = sqrt(1 - pow(light.radius / length(dir), 2));

    float theta = acos(Rand() * (maxCos - 1) + 1);
    float phi = 2.0 * PI * Rand();

    float3 direction = normalize(dir);
	ray.origin = hit.position + hit.normal * 0.01f;
	ray.direction = Tangent2World(theta, phi, direction);

    pdf = 1.0 / (2.0 * PI * (1 - maxCos));
    func = hit.albedo / PI * saturate(dot(hit.normal, ray.direction));        // Diffuse BRDF, https://google.github.io/filament/Filament.html#materialsystem/diffusebrdf
}
#endif

#ifdef AREA_LIGHT
void AreaLightImportanceSampling(RayHit hit, inout Ray ray, AreaLight light, out float3 func, out float pdf)
{
    float x = (Rand() * 2 - 1) * light.size.x / 2;
    float z = (Rand() * 2 - 1) * light.size.y / 2;

    float3 pointOnArea = float3(x, 0, z);

    float3 binormal = normalize(cross(light.normal, light.up));
    float3x3 m = float3x3(binormal, light.normal, light.up);
    float3 pointWS = mul(pointOnArea, m) + light.position;

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = pointWS - hit.position;

    float distanceSquard = dot(ray.direction, ray.direction);
    float area = light.size.x * light.size.y;
    float lightCosine = dot(normalize(-ray.direction), light.normal);
    ray.direction = normalize(ray.direction);

    pdf = distanceSquard / (lightCosine * area);
    func = hit.albedo / PI * saturate(dot(hit.normal, ray.direction));
}
#endif

#ifdef DISC_LIGHT
void DiscLightImportanceSampling(RayHit hit, inout Ray ray, DiscLight light, out float3 func, out float pdf)
{
    float theta = sqrt(Rand() * light.radius);
    float phi = 2.0 * PI * Rand();

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

#if (defined (SPHERE_LIGHT)) && (defined (AREA_LIGHT))
    float roulette = Rand();
    if (roulette > 0.5)
        SphereLightImportanceSampling(hit, /*inout*/ray, sphereLightBuffer[Rand() * sphereLightCount], /*out*/func, /*out*/pdf);
    else
        AreaLightImportanceSampling(hit, /*inout*/ray, areaLightBuffer[Rand() * areaLightCount], /*out*/func, /*out*/pdf);
#else
    #ifdef SPHERE_LIGHT
        SphereLightImportanceSampling(hit, /*inout*/ray, sphereLightBuffer[Rand() * sphereLightCount], /*out*/func, /*out*/pdf);
    #endif

    #if defined(AREA_LIGHT)
        AreaLightImportanceSampling(hit, ray, areaLightBuffer[Rand() * areaLightCount], func, pdf);
    #endif
#endif
    
    // 如果光线传递的方向在normal后侧，则直接判断为不被照明到
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

    _LightImportanceSampling(hit, /*inout*/ray, /*out*/func, /*out*/pdf);

    if (pdf > 0)
        return func / pdf;
    else
        return 0;
}

//////////////// chapter6_3 //////////////
void _BSDFImportanceSampling(RayHit hit, inout Ray ray, out float3 func, out float pdf)
{
    // BRDF，产生反射的材质
    // https://toposcat.top/cn/2020/10/13/Importance%20Sampling/
    // https://agraphicsguynotes.com/posts/sample_microfacet_brdf/

    // 漫反射产生的反射射线
    float3 diffuseReflectionDir;
    // 镜面反射产生的反射射线
    float3 specularReflectionDir;

    float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    roughness = max(roughness, 0.002);

    // 当前材质漫反射占比比较高
    {
        // 使用 cosine weighted的重要性采样
        float theta = acos(sqrt(1 - Rand()));
        float phi = 2.0 * PI * Rand();

        diffuseReflectionDir = Tangent2World(theta, phi, hit.normal);
    }

    // 当前材质镜面反射占比比较高
    {
        float e = Rand();

        float roughness2 = roughness * roughness;
        float theta = acos(sqrt((1 - e) / (e * (roughness2 - 1) + 1)));
        float phi = 2.0 * PI * Rand();

        // 计算微表面法线
        float3 microfacetNormal = Tangent2World(theta, phi, hit.normal);
        specularReflectionDir = normalize(reflect(ray.direction, microfacetNormal));
    }

    float3 reflectionDir;
    float diffuseRatio = 0.5 * (1.0 - hit.metallic);
    float specularRoatio = 1 - diffuseRatio;

    if (Rand() < diffuseRatio)
        reflectionDir = diffuseReflectionDir;
    else
        reflectionDir = specularReflectionDir;

    // BTDF, 产生折射的材质
    if (hit.materialType == 1 || hit.materialType == 3)
    {
        bool fromOutside = dot(ray.direction, hit.normal) < 0;

        // refraction
        float etai = 1;
        float etat = hit.ior;

        float eta = fromOutside ? etai / etat : etat / etai;
        if (hit.materialType == 3)
        {
            float specularChance = FresnelReflectAmount(
                 !fromOutside ? etat : etai,
                 fromOutside ? etat : etai,
                 ray.direction,
                 hit.normal,
                 COLOR_SPACE_DIELECTRIC_SPEC.r,
                 1.0f);
            
            specularChance = pow(specularChance, eta * eta * eta * eta);
            reflectionDir = lerp(diffuseReflectionDir, specularReflectionDir, Rand() < specularChance);
        }
        else if (hit.materialType == 1 && Rand() > hit.transparent)
        {
            float3 N = fromOutside ? hit.normal : -hit.normal;

            float3 bias = N * 0.001f;
            ray.origin = hit.position - bias;

            float3 refractionDir = normalize(refract(ray.direction, N, eta));
            refractionDir = normalize(lerp(refractionDir, -N + specularReflectionDir, roughness * roughness));
 
            ray.direction = refractionDir;

            func = 1;
            pdf = 1;

            // 继续下一轮迭代
            return;
        }
    }

    // 开始 BRDF 的计算
    float3 viewDir = normalize(-ray.direction);
    float3 halfDir = normalize(viewDir + reflectionDir);
    float3 lightDir = reflectionDir;

    BRDF(hit.materialType, viewDir, halfDir, lightDir, hit.albedo, hit.normal, hit.metallic, perceptualRoughness, roughness, diffuseRatio, specularRoatio, /*out */func, /*out */pdf);

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = reflectionDir;

    //if (hit.materialType == 4)
    //{
    //    ray.direction = -viewDir;
    //}
}

void _BSDFImportanceSampling(float3 inputDir, float3 outputDir, RayHit hit, inout Ray ray, out float3 func, out float pdf)
{
    float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    roughness = max(roughness, 0.002);

    float diffuseRatio = 0.5 * (1.0 - hit.metallic);
    float specularRoatio = 1 - diffuseRatio;

    float3 viewDir = normalize(-inputDir);
    float3 halfDir = normalize(viewDir + outputDir);
    float3 lightDir = outputDir;

    BRDF(hit.materialType, viewDir, halfDir, lightDir, hit.albedo, hit.normal, hit.metallic, perceptualRoughness, roughness, diffuseRatio, specularRoatio, /*out */func, /*out */pdf);

    ray.origin = hit.position + hit.normal * 0.001f;
    ray.direction = outputDir;
}

float3 BSDFImportanceSampling(RayHit hit, inout Ray ray)
{
    float3 func;
    float pdf;

    _BSDFImportanceSampling(hit, /*inout*/ray, /*out*/func, /*out*/pdf);

    if (pdf > 0)
        return func / pdf;
    else
        return 1;
}

//////////////// chapter6_4 //////////////
float3 MultipleImportanceSampling(RayHit hit, inout Ray ray)
{
    float3 lightFunc;
    float lightPdf;
    float3 inputDir = ray.direction;

    _LightImportanceSampling(hit, /*inout*/ray, /*out*/lightFunc, /*out*/lightPdf);
    float3 outputDir = ray.direction;

    if (Rand() > 0.5 && dot(hit.normal, outputDir) > 0.01)
    {
        // 使用针对灯光的重要性采样得到的反弹光线的方向，进行BSDF的重要性采样
        float lightWeight;

        if (lightPdf > 0)
            lightWeight = 0.5;
        else
            lightWeight = 0.5;
        float3 brdfFunc;
        float brdfPdf;
        float brdfWeight;

        _BSDFImportanceSampling(inputDir, outputDir, hit, /*inout*/ray, /*out*/brdfFunc, /*out*/brdfPdf);
    
        if (brdfPdf > 0)
            brdfWeight = 0.5;
        else
            brdfWeight = 0.5;

        float3 func = lightFunc + brdfFunc;
        float pdf = lightPdf * lightWeight + brdfPdf * brdfWeight;

        if (pdf > 0)
            return func / pdf;
        else
            return 0;
    }
    else
    {
        // 直接对BSDF进行重要性采样
        // 需要先把ray的方向赋回初值
        ray.direction = inputDir;

        float3 func;
        float pdf;

        _BSDFImportanceSampling(hit, /*inout*/ray, /*out*/func, /*out*/pdf);

        if (pdf > 0 )
            return func / pdf;
        else
            return 1;
    }
}
#endif