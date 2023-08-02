#ifndef BSDF_INCLUDE
#define BSDF_INCLUDE

static const float4 COLOR_SPACE_DIELECTRIC_SPEC  = half4(0.04, 0.04, 0.04, 1.0 - 0.04); // standard dielectric reflectivity coef at incident angle (= 4%)

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
/////////////////////// Uniform Sampling/////////////////////////////////////
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
    ray.direction = Tangent2World(theta, phi, hit.normal);

    float pdf = 1.0 / (2.0 * PI);
    float3 fr = hit.albedo / PI;

    float3 result = fr / pdf * saturate(dot(hit.normal, ray.direction));

    return result;
}

/////////////////////////////////////////////////////////////////////////////
//////////////////////// Cosine Sampling/////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
float3 CosineSampling(RayHit hit, inout Ray ray)
{
    // https://sites.google.com/site/ivorsgraphicsblog/ray-tracing-engine/cosine-distributed-sampling
    //float theta = acos(sqrt(1 - rand()));
    float theta = sqrt(rand());
    float phi = 2.0 * PI * rand();
    ray.direction = Tangent2World(theta, phi, hit.normal);

    // 这是使用经典 diffuse brdf
    //float pdf = cos / PI;
    //float3 fr = hit.albedo / PI;
    //float3 result = fr / pdf * cos; 可以化简
    float3 result = hit.albedo;

    return result;
}

/////////////////////////////////////////////////////////////////////////////
//////////////////////// Importance sampling Light///////////////////////////
/////////////////////////////////////////////////////////////////////////////
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

/////////////////////////////////////////////////////////////////////////////
//////////////////////// Importance sampling BRDF ///////////////////////////
/////////////////////////////////////////////////////////////////////////////
inline half Pow5(half x)
{
    return x * x * x * x * x;
}

// Diffuse BRDF
// Note: Disney diffuse must be multiply by diffuseAlbedo / PI. This is done outside of this function.
half DisneyDiffuse(half NdotV, half NdotL, half LdotH, half perceptualRoughness)
{
    half fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
    // Two schlick fresnel term
    half lightScatter = (1 + (fd90 - 1) * Pow5(1 - NdotL));
    half viewScatter = (1 + (fd90 - 1) * Pow5(1 - NdotV));

    return lightScatter * viewScatter;
}

float3 DiffuseBRDF(float3 albedo, float3 normal, float3 viewDir, float3 halfDir, float3 lightDir, float perceptualRoughness)
{
    half nv = saturate(dot(normal, viewDir));    // This abs allow to limit artifact
    half nl = saturate(dot(normal, lightDir));
    half lh = saturate(dot(lightDir, halfDir));

    half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;

    // float pdf = nl / PI, albedo * diffuseTerm / pdf * nl, 可以化简为：
    return albedo * diffuseTerm * PI * nl;
}

// Specular BRDF
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

// 和unity方法同名
inline float GGXTerm(float NdotH, float roughness)
{
    float a2 = roughness * roughness;
    float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; // 2 mad
    return a2 / (PI * (d * d + 1e-7f)); // This function is not intended to be running on Mobile,
                                            // therefore epsilon is smaller than what can be represented by half
}

inline half3 FresnelTerm(half3 F0, half cosA)
{
    half t = Pow5(1 - cosA);   // ala Schlick interpoliation
    return F0 + (1 - F0) * t;
}

// Ref: http://jcgt.org/published/0003/02/03/paper.pdf
inline half SmithJointGGXVisibilityTerm(half NdotL, half NdotV, half roughness)
{
    // Approximation of the above formulation (simplify the sqrt, not mathematically correct but close enough)
    half a = roughness;
    half lambdaV = NdotL * (NdotV * (1 - a) + a);
    half lambdaL = NdotV * (NdotL * (1 - a) + a);

    return 0.5f / (lambdaV + lambdaL + 1e-5f);
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}
float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
{
    float NdotV = abs(dot(N, V));
    float NdotL = abs(dot(N, L));
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

float3 SpecularBRDF(float3 albedo, float metallic, float3 normal, float3 viewDir, float3 halfDir, float3 lightDir, float roughness)
{
    half nv = saturate(dot(normal, viewDir));    // This abs allow to limit artifact
    half nl = saturate(dot(normal, lightDir));
    float nh = saturate(dot(normal, halfDir));

    half lv = saturate(dot(lightDir, viewDir));
    half lh = saturate(dot(lightDir, halfDir));

    half hv = saturate(dot(halfDir, viewDir));

    float D = GGXTerm(nh, roughness);
    float3 F0 = lerp (COLOR_SPACE_DIELECTRIC_SPEC.rgb, albedo, metallic);
    float3 F = FresnelTerm(F0, hv);
    //使用unity的版本会产生大量噪点，这里使用的是unreal的G，float G = SmithJointGGXVisibilityTerm (nl, nv, roughness);
    float G = GeometrySmith(normal, viewDir, lightDir, roughness);

    float3 nominator = D * G * F;
    float denominator = 4.0 * nv * nl + 0.001;
    float3 brdf = nominator / denominator;
    float pdf = D * nh / (4.0 * hv);

    if (pdf > 0)
        return brdf / pdf * nl;
    else
        return 1;
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
    float3 microfacetNormal = Tangent2World(theta, phi, hit.normal);

    float3 halfDir = normalize(viewDir + ray.direction);
    float3 lightDir = normalize(reflect(ray.direction, microfacetNormal));

    ray.direction = lightDir;

    // float3 result = f / pdf * saturate(dot(hit.normal, ray.direction));
    float3 diffuseBRDF = DiffuseBRDF(hit.albedo, hit.normal, viewDir, halfDir, lightDir, perceptualRoughness);

    float3 specularBRDF = SpecularBRDF(hit.albedo, hit.metallic, hit.normal, viewDir, halfDir, lightDir, roughness);


    return specularBRDF;
}

float3 ImportanceSampling(RayHit hit, inout Ray ray)
{
    // 这里处理的是 fr(x, ωi, ωo) * (ωo⋅n) / pdf 部分
    float3 output = 0;

    ray.origin = hit.position + hit.normal * 0.001f;

    float3 lightOutput = ImportanceSamplingLight(hit, ray);

    //if (0.5 > rand()/* && dot(ray.direction, hit.normal) > 0*/)
    //{
        output = lightOutput;
    //}
    //else
    //{
    //    if (hit.smoothness > rand())
    //        output = ImportanceSamplingBRDF(hit, ray);
    //    else
    ////output = UniformSampling(hit, ray);
        //output = CosineSampling(hit, ray);
    //}


    //output = ImportanceSamplingBRDF(hit, ray);

    return output;
}
#endif