#ifndef _BRDF_
#define _BRDF_

static const float4 COLOR_SPACE_DIELECTRIC_SPEC  = half4(0.04, 0.04, 0.04, 1.0 - 0.04); // standard dielectric reflectivity coef at incident angle (= 4%)

inline half Pow5(half x)
{
    return x * x * x * x * x;
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

float SmoothnessToPerceptualRoughness(float smoothness)
{
    return (1 - smoothness);
}

float PerceptualRoughnessToRoughness(float perceptualRoughness)
{
    return perceptualRoughness * perceptualRoughness;
}

inline half3 DiffuseAndSpecularFromMetallic (half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
{
    specColor = lerp (COLOR_SPACE_DIELECTRIC_SPEC.rgb, albedo, metallic);
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    return albedo * oneMinusReflectivity;
}

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
    float NdotV = saturate(dot(N, V));
    float NdotL = saturate(dot(N, L));
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
    F = FresnelTerm(specColor, hv);

    //使用unity的版本会产生大量噪点，这里使用的是unreal的G，float G = SmithJointGGXVisibilityTerm (nl, nv, roughness);
    float G = GeometrySmith(normal, viewDir, lightDir, roughness);

    float3 nominator = D * G * F;
    float denominator = 4.0 * nv * nl + 0.001;
    float3 brdf = nominator / denominator;

    pdf = D * nh / (4.0 * hv);
    return brdf;
}

void BRDF(uint materialType, 
    float3 viewDir, 
    float3 halfDir, 
    float3 lightDir, 
    float3 albedo, 
    float3 normal, 
    float metallic, 
    float perceptualRoughness, 
    float roughness, 
    float diffuseRatio, 
    float specularRoatio, 
    out float3 func, 
    out float pdf)
{
    // 针对于BRDF的重要性采样，采用的Cook torrence微表面模型
    // fr = DFG / (4 * (n, i) * (n, o))

    // 以下计算参考unity的standard pbr shader
    float oneMinusReflectivity;
    float3 specColor;

    // 漫反射
    float3 diffuse = DiffuseAndSpecularFromMetallic(albedo, metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);
    float diffusePdf;
    float3 diffuseBRDF = DiffuseBRDF(diffuse, normal, viewDir, halfDir, lightDir, perceptualRoughness, /*out*/ diffusePdf);

    // 镜面反射
    float3 F;
    float specularPdf;
    float3 specularBRDF = SpecularBRDF(specColor, normal, viewDir, halfDir, lightDir, roughness, /*out*/ F, /*out*/ specularPdf);

    float3 kS = F;
    float3 kD = 1.0 - kS;
    kD *= 1.0 - metallic;

    float3 totalBRDF = (diffuseBRDF * kD + specularBRDF) * saturate(dot(normal, lightDir));
    float totalPdf = diffusePdf * diffuseRatio + specularPdf * specularRoatio;
    
    func = totalBRDF;
    pdf = totalPdf;
}

////////////// chapter6_6 //////////////
float FresnelReflectAmount(float n1, float n2, float3 normal, float3 incident, float f0, float f90)
{
    // Schlick aproximation
    float r0 = (n1 - n2) / (n1 + n2);
    r0 *= r0;
    float cosX = -dot(normal, incident);
    if (n1 > n2)
    {
        float n = n1 / n2;
        float sinT2 = n * n * (1.0 - cosX * cosX);
        // Total internal reflection
        if (sinT2 > 1.0)
            return f90;
        cosX = sqrt(1.0 - sinT2);
    }
    float x = 1.0 - cosX;
    float ret = r0 + (1.0 - r0) * x * x * x * x * x;

    // adjust reflect multiplier for object reflectivity
    return lerp(f0, f90, ret);
}

#endif