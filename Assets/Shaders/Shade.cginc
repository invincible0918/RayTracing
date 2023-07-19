static const float4 COLOR_SPACE_DIELECTRIC_SPEC  = half4(0.04, 0.04, 0.04, 1.0 - 0.04); // standard dielectric reflectivity coef at incident angle (= 4%)
static const float SPECCUBE_LOD_STEPS = 6;
TextureCube<float4> skyboxCube;
SamplerState sampler_LinearClamp;
float skyboxRotation;

// Add Monte Carlo integration
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

// https://zhuanlan.zhihu.com/p/437461225
float3 SampleHemisphere(float3 normal)
{
    ////// Uniformly sample hemisphere direction
    //float theta = 2 * PI * rand();
    //float phi = 0.5 * PI * rand(); // semi-sphere

    //float3 localSpaceDir = float3(cos(theta) * sin(phi), sin(theta) * sin(phi), cos(phi));
    //// Transform direction to world space
    //return mul(localSpaceDir, GetTangentSpace(normal));

    // Uniformly sample hemisphere direction
    float cosTheta = rand();
    float sinTheta = sqrt(max(0.0f, 1.0f - cosTheta * cosTheta));
    float phi = 2 * PI * rand();
    float3 tangentSpaceDir = float3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
    // Transform direction to world space
    return mul(tangentSpaceDir, GetTangentSpace(normal));
}

float3 UniformSampleHemisphere(float3 normal)
{
    float2 u = float2(rand(), rand());

    float r = sqrt(1 - u.x * u.x);
    float phi = 2.0 * PI * u.y;

    float3  B = normalize(cross(normal, float3(0.0, 0.0, 1.0)));
    float3  T = cross(B, normal);

    return normalize(r * sin(phi) * B + u.x * normal + r * cos(phi) * T);
}

float3 CosineSampleHemisphere(float3 normal)
{
    float2 u = float2(rand(), rand());

    float r = sqrt(u.x);
    float theta = 2.0 * PI * u.y;

    float3  B = normalize(cross(normal, float3(0.0, 0.0, 1.0)));
    float3  T = cross(B, normal);

    return normalize(r * sin(theta) * B + sqrt(1.0 - u.x) * normal + r * cos(theta) * T);
}

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

// 用在step 6
float SmoothnessToPhongAlpha(float s)
{
    return pow(10000, s * s);
}

// Lighting Model 相关开始reflectedDir, outputDir, hit
float3 ClassicLightingModel(inout Ray ray, RayHit hit)
{
    float3 finalColor;

    float3 albedo = hit.albedo;
    float3 normal = hit.normal;
    float smoothness = hit.smoothness;
    float metallic = hit.metallic;

    float3 specularColor = lerp(albedo, albedo * 0.1f, metallic);
    
    // 公式参考 http://three-eyed-games.com/2018/05/12/gpu-path-tracing-in-unity-part-2/
    
    
    float alpha = SmoothnessToPhongAlpha(hit.smoothness);
    
    ray.direction = SampleHemisphere(reflect(ray.direction, hit.normal), alpha);
    float f = (alpha + 2) / (alpha + 1);
    float specChance = dot(specularColor, 1.0f / 3.0f);
    finalColor = (1.0f / specChance) * specularColor * saturate(dot(hit.normal, ray.direction) * f);

    return finalColor;
}

float SmoothnessToPerceptualRoughness(float smoothness)
{
    return (1 - smoothness);
}

inline half Pow5 (half x)
{
    return x*x * x*x * x;
}


half DisneyDiffuse(half NdotV, half NdotL, half LdotH, half perceptualRoughness)
{
    half fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
    // Two schlick fresnel term
    half lightScatter   = (1 + (fd90 - 1) * Pow5(1 - NdotL));
    half viewScatter    = (1 + (fd90 - 1) * Pow5(1 - NdotV));

    return lightScatter * viewScatter;
}
float PerceptualRoughnessToRoughness(float perceptualRoughness)
{
    return perceptualRoughness * perceptualRoughness;
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

inline float GGXTerm (float NdotH, float roughness)
{
    float a2 = roughness * roughness;
    float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; // 2 mad
    return INV_PI * a2 / (d * d + 1e-7f); // This function is not intended to be running on Mobile,
                                            // therefore epsilon is smaller than what can be represented by half
}

inline half3 FresnelTerm (half3 F0, half cosA)
{
    half t = Pow5 (1 - cosA);   // ala Schlick interpoliation
    return F0 + (1-F0) * t;
}

inline half OneMinusReflectivityFromMetallic(half metallic)
{
    half oneMinusDielectricSpec = COLOR_SPACE_DIELECTRIC_SPEC.a;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}

inline half3 FresnelLerp (half3 F0, half3 F90, half cosA)
{
    half t = Pow5 (1 - cosA);   // ala Schlick interpoliation
    return lerp (F0, F90, t);
}

float3 Brdf(inout Ray ray, RayHit hit)
{
    float3 finalColor = 1;

    ray.origin = hit.position + hit.normal * 0.001f;

    float alpha = SmoothnessToPhongAlpha(hit.smoothness);
    ray.direction = SampleHemisphere(reflect(ray.direction, hit.normal), alpha);
    //ray.direction = ImportanceSampleGGX(float2(rand(), rand()), hit.normal, 0, 1 - hit.smoothness);
    float3 camPos = mul(camera2World, float4(0, 0, 0, 1)).xyz;
	float3 normal = hit.normal;
	float3 posWorld = hit.position;
    float smoothness = hit.smoothness;
    float metallic = hit.metallic;

	// 使用场景内灯光方向计算效果更好，参考ppt, float3 lightDir = normalize(ray.direction);
	float3 lightDir = normalize(-directionalLight.xyz);
	float3 viewDir = normalize(camPos - posWorld);
	float3 lightColor = directionalLightColor.rgb;
    float3 specColor = lerp (COLOR_SPACE_DIELECTRIC_SPEC.rgb, hit.albedo, metallic);
    float oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    float perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
    float3 diffColor = hit.albedo * oneMinusReflectivity;

    float3 halfDir = normalize (lightDir + viewDir);


    half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
    half nl = saturate(dot(normal, lightDir));
    float nh = saturate(dot(normal, halfDir));

    half lv = saturate(dot(lightDir, viewDir));
    half lh = saturate(dot(lightDir, halfDir));

    // Diffuse term
    half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;

    // Specular term
    // HACK: theoretically we should divide diffuseTerm by Pi and not multiply specularTerm!
    // BUT 1) that will make shader look significantly darker than Legacy ones
    // and 2) on engine side "Non-important" lights have to be divided by Pi too in cases when they are injected into ambient SH
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    // GGX with roughtness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughtness remapping.
    roughness = max(roughness, 0.002);
    half V = SmithJointGGXVisibilityTerm (nl, nv, roughness);
    float D = GGXTerm (nh, roughness);

    half specularTerm = V * D * PI; // Torrance-Sparrow model, Fresnel is applied later

    // specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    specularTerm = max(0, specularTerm * nl);

    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
    half surfaceReduction;

    surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

    half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
    finalColor =  diffColor * (/*gi.diffuse + */lightColor * diffuseTerm)
                    + specularTerm * lightColor * FresnelTerm (specColor, lh)
                    + surfaceReduction * /*gi.specular * */FresnelLerp (specColor, grazingTerm, nv);

    return finalColor;
}


float3 Btdf(inout Ray ray, RayHit hit)
{
    float3 finalColor = 1;

    // 需要同时考虑反射和折射,https://zhuanlan.zhihu.com/p/58692781
    float roulette = rand();

    if (roulette <= hit.transparent)
        finalColor = Brdf(ray, hit);
    else
    {
        bool fromOutside = dot(ray.direction, hit.normal) < 0;
        float3 N = fromOutside ? hit.normal : -hit.normal;
        float3 bias = N * 0.001f;
        ray.origin = hit.position - bias;

        // refraction
        //float etai = 1;
        //float etat = 1.55;

        //float eta = fromOutside ? etai / etat : etat / etai;

        ////float3 V = normalize(-ray.direction);
        ////float3 H = ImportanceSampleGGX(float2(rand(), rand()), N, V, 1 - hit.smoothness);
        ////finalColor = dot(ray.direction, -H);
        //ray.direction = normalize(refract(ray.direction, N, eta));

        // penetration
        // in this part the direction won't change
    }

    return finalColor;
}

float3 PbrLightingModel(inout Ray ray, RayHit hit)
{
    float3 finalColor = 1;

    if (any(hit.emissionColor)) 
        return 0;

    float transparent = hit.transparent;

    // BSDF = BRDF + BTDF
    if (transparent < 0)
    {
        // BRDF
        finalColor = Brdf(ray, hit);
    }
    else
    {
        // BTDF
        finalColor = Btdf(ray, hit);
    }

    return finalColor;
}

float3 RotateAroundYInDegrees(float3 dir, float degrees)
{
    float alpha = degrees * PI / 180.0;
    float sina, cosa;
    sincos(alpha, sina, cosa);
    float2x2 m = float2x2(cosa, -sina, sina, cosa);
    return float3(mul(m, dir.xz), dir.y).xzy;
}

half PerceptualRoughnessToMipmapLevel(half perceptualRoughness)
{
    return perceptualRoughness * SPECCUBE_LOD_STEPS;
}

// Lighting Model 相关结束
float3 Shade(inout Ray ray, RayHit hit)
{
    if (hit.distance < 1.#INF)
    {   
        //// Whitted ray trace start
        //// https://blog.csdn.net/qq_39300235/article/details/105520960
        //// step 1. 完全镜面反射，不考虑能量衰减
        //ray.origin = hit.position + hit.normal * 0.01f;
        //ray.direction = reflect(ray.direction, hit.normal);
        //return 0;// hit.normal * 0.5f + 0.5f;

        //// step 2. 添加一个测试阴影
        //Ray shadowRay = CreateRay(hit.position + hit.normal * 0.01f, -directionalLight.xyz);
        //RayHit shadowHit = BVHTrace(shadowRay);
        //if (shadowHit.distance != 1.#INF)
        //{
        //    // 可以用enery来控制阴影的黑色
        //    ray.energy *= 0.2f;
        //    return 0;
        //}

        //// step 3. 添加材质，更准确地说，是添加颜色
        //// Add lambert lighting model
        //// 测试带diffuse的能量衰减
        //ray.energy *= hit.albedo;
        ////ray.energy *= 2 * hit.albedo * saturate(dot(hit.normal, ray.direction));
        //// Whitted ray trace end

        // Monte Carlo ray tracing start
        // step 4. 以上都是Whitted ray trace，没有考虑真正的渲染方程，即漫反射, 间接光
        // 不能很好的模拟 Glossy（金属，类似磨砂的感觉） 材质的物体, 能产生高光，但是又有点糊，没有那么光滑, The Utah Teapot（经典模型）
        // 引入渲染方程    
        // L(x,ωo)=Le(x,ωo)+∫Ωfr(x,ωi,ωo)(ωi⋅n)L(x,ωi)dωi
        // 并使用 Monte Carlo积分运算：https://blog.csdn.net/weixin_44176696/article/details/113418991
        // 渲染方程简化为  
        // L(x,ωo)=Le(x,ωo) + 1/N * ∑2πfr(x, ωi, ωo)(ωi⋅n)L(x, ωi)
        // 其中:
        // Le(x,ωo) 是自发光
        // 1/N是各个方向的多次采样，已经实现在AddShader中了
        // fr(x, ωi, ωo) 是 PBR 渲染的 Cook-Torrance BRDF： fr = kd * flambert + ks * fcook-torrance
        // (ωi⋅n)就是cosθ
        // L(x, ωi)是每次迭代的数值，反应在代码里就是每次的ray.energy

        // step 5. 只考虑lambert模型的漫反射的BRDF，注意此时的lambert是遵循PBR的，并不是 n dot l这样的经验光照模型
        // fr(x,ωi,ωo)=kd/π, 推导见：https://zhuanlan.zhihu.com/p/29837458
        // L(x,ωo)=1/N * ∑2*kd* (ωi⋅n)L(x, ωi)
        //ray.origin = hit.position + hit.normal * 0.001f;
        //ray.direction = SampleHemisphere(hit.normal);
        //ray.energy *= 2 * hit.albedo * saturate(dot(hit.normal, ray.direction));

        
        // step 6. 同时考虑漫反射和高光的BRDF,https://zhuanlan.zhihu.com/p/500811555, https://www.cs.princeton.edu/courses/archive/fall08/cos526/assign3/lawrence.pdf
        // fr(x,ωi,ωo)=kd/π + ks(α+2)/2π*pow((ωr⋅ωo), α)
        // (ωr⋅ωo) 是光线出射方向与入射光线理想镜面反射方向之间的夹角；
        // kd 漫反射率（diffuse reflectivity），即投射到物体表面的能量中发生漫反射的比例；
        // ks 镜面反射率（specular reflectivity），即垂直投射到物体表面的能量中被镜面反射的比例；
        // α  镜面指数（specular exponent），更高的值会产生更清晰的镜面反射；
        // 则推导公式为：
        // L(x,ωo)=1/N * ∑[2π*(kd/π + ks(α+2)/2π*pow((ωr⋅ωo), α)]*(ωi⋅n)L(x, ωi)
        // L(x,ωo)=1/N * ∑[2*kd + ks(α+2)*pow((ωr⋅ωo), α)]*(ωi⋅n)L(x, ωi)
        //float3 specularColor = lerp(hit.albedo, hit.albedo * 0.1f, hit.metallic);
        //float3 reflected = reflect(ray.direction, hit.normal);
        //float alpha = smoothness2PhongAlpha(hit.smoothness);
        //float3 diffuse = 2 * min(1.0f - specularColor, hit.albedo);
        //ray.direction = SampleHemisphere(reflect(ray.direction, hit.normal));

        //float3 specular = specularColor * (alpha + 2) * pow(saturate(dot(reflected, ray.direction)), alpha);
        //ray.energy *= (diffuse + specular) * saturate(dot(hit.normal, ray.direction));

        // step 7. 此时可以关闭 aliasing，现在我们的渲染仍然存在一个问题：噪声太多，尤其是黑色噪点，这是因为我们使用的是 uniform sampling 的Monte Carlo积分
        // 理论上在Monte Carlo积分中，∑fr(x)/pdf(x) 中的 f(x) 和 pdf(x) 应该尽可能的相似应该尽可能的相似, 即FN≈1/N ∑1
        // 但是 fr(x)是未知的, 因为Monte Carlo积分的目的是求∫ f(x), 如果已知 f(x) 的形状那么可以直接获得解析解

        // 因为 ∫ pdf(x) = 1, 所以
        // pdf(x) = (ωi⋅n)/π = cosθsinθ/π, https://puluo.top/%E8%92%99%E7%89%B9%E5%8D%A1%E6%B4%9B%E7%A7%AF%E5%88%86%E4%B8%8E%E9%87%8D%E8%A6%81%E6%80%A7%E9%87%87%E6%A0%B7/
        // 这个就是最简单的 Importance Sampling： Cosine Sampling
        // L(x,ωo)=1/N * ∑kdL(x, ωi) 
//        float3 inputDir = ray.direction;
//        float3 outputDir;
//#ifdef COSINE_SAMPLE
//        outputDir = CosineSampleHemisphere(hit.normal);
//#else
//        outputDir = UniformSampleHemisphere(hit.normal);
//#endif
//        ray.direction = outputDir;


        //ray.direction = lerp(reflectedDir, CosineSampleHemisphere(hit.normal), hit.smoothness);

        float3 finalColor = 0;

        //finalColor = ClassicLightingModel(ray, hit);
        finalColor = PbrLightingModel(ray, hit);
        ray.energy *= finalColor;
        
        // 这里其实是渲染方程 L(x,ωo) ≈ Le(x,ωo) + 1/N * ∑2πfr(x, ωi, ωo)(ωi⋅n)L(x, ωi) 的发光项，但是目前我们先不考虑自发光物体 Le(x,ωo)
        // 渲染方程的泰勒展开 https://zhuanlan.zhihu.com/p/463166884
        return hit.emissionColor;
    }
    else
    {
        ray.energy = 0.0f;
        float3 dir = RotateAroundYInDegrees(ray.direction, -skyboxRotation);

        float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
        half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
        return skyboxCube.SampleLevel(sampler_LinearClamp, dir, mip).xyz;
    }
}
