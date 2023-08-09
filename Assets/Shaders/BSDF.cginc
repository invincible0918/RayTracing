#ifndef BSDF_INCLUDE
#define BSDF_INCLUDE

static const float4 COLOR_SPACE_DIELECTRIC_SPEC  = half4(0.04, 0.04, 0.04, 1.0 - 0.04); // standard dielectric reflectivity coef at incident angle (= 4%)

/////////////////////////////////////////////////////////////////////////////
//////////////////////// Importance sampling BRDF ///////////////////////////
/////////////////////////////////////////////////////////////////////////////
inline half Pow5(half x)
{
    return x * x * x * x * x;
}

float3 LitDiffuseBRDF(float3 albedo)
{
    return albedo / PI;
}

inline half OneMinusReflectivityFromMetallic(half metallic)
{
    // We'll need oneMinusReflectivity, so
    //   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
    // store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
    //   1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) =
    //                  = alpha - metallic * alpha
    half oneMinusDielectricSpec = COLOR_SPACE_DIELECTRIC_SPEC.a;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}

inline half3 DiffuseAndSpecularFromMetallic (half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
{
    specColor = lerp (COLOR_SPACE_DIELECTRIC_SPEC.rgb, albedo, metallic);
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    return albedo * oneMinusReflectivity;
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

float3 DiffuseBRDF(float3 albedo, float3 normal, float3 viewDir, float3 halfDir, float3 lightDir, float perceptualRoughness, out float pdf)
{
    half nv = saturate(dot(normal, viewDir));    // This abs allow to limit artifact
    half nl = saturate(dot(normal, lightDir));
    half lh = saturate(dot(lightDir, halfDir));

    half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;

    // 通过计算漫反射模型 albedo / PI 和 albedo * diffuseTerm / PI 差别不是很大
    //float3 brdf = albedo / PI;
    float3 brdf =  albedo * diffuseTerm / PI;
    pdf = nl / PI;
    return brdf;
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

float GeometryKelemen(float LoH)
{
    return 0.25 / (LoH * LoH);
}

float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
{
    float NdotV = abs(dot(N, V));
    float NdotL = abs(dot(N, L));
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

float3 SpecularBRDF(float3 specColor, float3 normal, float3 viewDir, float3 halfDir, float3 lightDir, float roughness, out float3 F, out float pdf)
{
    half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact, 这条非常重要，使用sat会在边缘产生奇怪的高光
    half nl = saturate(dot(normal, lightDir));
    float nh = saturate(dot(normal, halfDir));

    half lv = saturate(dot(lightDir, viewDir));
    half lh = saturate(dot(lightDir, halfDir));

    half hv = saturate(dot(halfDir, viewDir));

    float D = GGXTerm(nh, roughness);
    //float3 F0 = lerp (COLOR_SPACE_DIELECTRIC_SPEC.rgb * specColor, albedo, metallic);
    //F = FresnelTerm(F0, hv);
    F = FresnelTerm(specColor, hv);
    //使用unity的版本会产生大量噪点，这里使用的是unreal的G，float G = SmithJointGGXVisibilityTerm (nl, nv, roughness);
    float G = GeometrySmith(normal, viewDir, lightDir, roughness);

    float3 nominator = D * G * F;
    float denominator = 4.0 * nv * nl + 0.001;
    float3 brdf = nominator / denominator;

    pdf = D * nh / (4.0 * hv);
    return brdf;

    //if (pdf > 0)
    //    return brdf / pdf * nl;
    //else
    //    return 1;
}

float3 ClearCoatBRDF(float3 specColor, float3 normal, float3 viewDir, float3 halfDir, float3 lightDir, float roughness, out float3 F, out float pdf)
{
    // 主要参考：https://google.github.io/filament/Filament.md.html#materialsystem/clearcoatmodel
    // https://google.github.io/filament//Materials.md.html#materialmodels/litmodel/clearcoat
    half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact, 这条非常重要，使用sat会在边缘产生奇怪的高光
    half nl = saturate(dot(normal, lightDir));
    float nh = saturate(dot(normal, halfDir));

    half lv = saturate(dot(lightDir, viewDir));
    half lh = saturate(dot(lightDir, halfDir));

    half hv = saturate(dot(halfDir, viewDir));


    // remapping and linearization of clear coat roughness
    float clearCoatRoughness = clamp(roughness, 0.089, 1.0);

    // clear coat BRDF
    float D = GGXTerm(nh, clearCoatRoughness);
    float G = GeometryKelemen(lh);
    F = FresnelTerm(0.04, lh);

    float3 nominator = D * G * F;
    float denominator = 1;// 4.0 * nv * nl + 0.001;
    float3 brdf = nominator / denominator;

    pdf = D * nh / (4.0 * hv);
    return brdf;

    //if (pdf > 0)
    //    return brdf / pdf * nl;
    //else
    //    return 1;
}

#endif