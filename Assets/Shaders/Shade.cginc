#include "Header.cginc"

TextureCube<float4> skyboxCube;
SamplerState sampler_LinearClamp;

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

// Samples uniformly from the hemisphere
// alpha = 0 for uniform
// alpha = 1 for cosine
// alpha > 1 for higher Phong exponents
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

// Converts direction from carthesian coords to spherical coords
float2 CarthesianToSpherical(float3 direction)
{
    float phi = atan2(direction.x, -direction.z) / -PI * 0.5f;
    float theta = acos(direction.y) / -PI;
    return float2(phi, theta);
}

// The energy function is a little helper that averages the color channels:
float Energy(float3 color)
{
    return dot(color, 1.0f / 3.0f);
}

// 用在step 6
float SmoothnessToPhongAlpha(float s)
{
    return pow(1000, s * s);
}

// Lighting Model 相关开始reflectedDir, outputDir, hit
float3 ClassicLightingModel(float3 reflectedDir, float3 outputDir, RayHit hit)
{
    float3 finalColor;

    float3 albedo = hit.albedo;
    float3 normal = hit.normal;
    float smoothness = hit.smoothness;
    float metallic = hit.metallic;
    float3 lightDir = outputDir;

    float3 reflected = reflect(lightDir, normal);
    float alpha = SmoothnessToPhongAlpha(smoothness);

    float3 specularColor = lerp(albedo, albedo * 0.1f, metallic);
    float3 diffuse = albedo;//2 * min(1.0f - specularColor, albedo);

    // 公式参考 http://three-eyed-games.com/2018/05/12/gpu-path-tracing-in-unity-part-2/
    float3 specular = specularColor * (alpha + 2) * pow(saturate(dot(reflectedDir, lightDir)), alpha);
    finalColor = (diffuse + specular) * saturate(dot(normal, lightDir));


    return hit.albedo;
}

float3 PbrLightingModel(float3 lightDir, RayHit hit)
{
    //float NdotL = abs(dot(N, L));
    //float NdotV = abs(dot(N, V));

    //float NdotH = abs(dot(N, H));
    //float VdotH = abs(dot(V, H));
    //float LdotH = abs(dot(L, H));


    //float NDF = DistributionGGX(N, H, hit.roughness);
    //float G = GeometrySmith(N, V, L, hit.roughness);



    //float3 specularBrdf = SpecularBRDF(NDF, G, F, V, L, N);


    return 0;
}
// Lighting Model 相关结束

float debugSmoothness;
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
        //RayHit shadowHit = Trace(shadowRay);
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
        ray.origin = hit.position + hit.normal * 0.01f;
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

        float3 reflectedDir = reflect(ray.direction, hit.normal);

        float alpha = SmoothnessToPhongAlpha(hit.smoothness);
        ray.direction = SampleHemisphere(hit.normal, alpha);
        //ray.direction = lerp(reflectedDir, CosineSampleHemisphere(hit.normal), hit.smoothness);

        float3 finalColor = 0;
        finalColor = ClassicLightingModel(reflectedDir, ray.direction, hit);

        ray.energy *= finalColor;
        
        // 这里其实是渲染方程 L(x,ωo) ≈ Le(x,ωo) + 1/N * ∑2πfr(x, ωi, ωo)(ωi⋅n)L(x, ωi) 的发光项，但是目前我们先不考虑自发光物体 Le(x,ωo)
        return 0;
    }
    else
    {
        ray.energy = 0.0f;
        return skyboxCube.SampleLevel(sampler_LinearClamp, ray.direction, 0).xyz;
    }
}