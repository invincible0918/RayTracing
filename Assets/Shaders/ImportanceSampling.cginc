

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

float3 UniformSampleHemisphere(float3 normal)
{
    float2 u = hash2();
    u = float2(rand(), rand());

    float r = sqrt(1 - u.x * u.x);
    float phi = 2.0 * PI * u.y;

    float3  B = normalize(cross(normal, float3(0.0, 0.0, 1.0)));
    float3  T = cross(B, normal);

    return normalize(r * sin(phi) * B + u.x * normal + r * cos(phi) * T);
}

float3 CosineSampleHemisphere(float3 normal)
{
    float2 u = hash2();
    u = float2(rand(), rand());

    float r = sqrt(u.x);
    float theta = 2.0 * PI * u.y;

    float3  B = normalize(cross(normal, float3(0.0, 0.0, 1.0)));
    float3  T = cross(B, normal);

    return normalize(r * sin(theta) * B + sqrt(1.0 - u.x) * normal + r * cos(theta) * T);
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

float3 Tangent2World(float theta, float phi, float3 direction)
{
    float3 localSpaceDir = float3(cos(theta) * sin(phi), sin(theta) * sin(phi), cos(phi));
    // Transform direction to world space
    return mul(localSpaceDir, GetTangentSpace(direction));
}

////////////////////////////
// Importance sampling Light
////////////////////////////
int lightCount;
StructuredBuffer<float4> lightBuffer;
float3 ImportanceSamplingLight(float4 light, float3 position)
{
    float3 lightPosition = light.xyz;
    float lightRadius = light.w;
    float maxCos = sqrt(1 - pow(lightRadius / length(lightPosition - position), 2));

    float theta = acos(1 - rand() + rand() * maxCos);
    //theta = 2 * PI * u.x;
    float phi = 2.0 * PI * rand();

    float3 direction = normalize(lightPosition - position);
    // Transform direction to world space
    return Tangent2World(theta, phi, direction);
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

float3 ImportanceSamplingBRDF(float4 light, float3 direction, RayHit hit)
{
    // 和Unity一样，采样GGX法线分布
    float smoothness = hit.smoothness;
    float perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    float alpha = roughness;

    // 使用场景内灯光方向计算效果更好，参考ppt
    //float3 lightDir = normalize(ray.direction);
    float3 lightPosition = light.xyz;
    float3 lightDir = normalize(lightPosition - hit.position);
    float3 camPos = mul(camera2World, float4(0, 0, 0, 1)).xyz;
    float3 viewDir = normalize(-direction);// normalize(camPos - hit.position);
    float3 halfDir = normalize(lightDir + viewDir);

    float nh = saturate(dot(hit.normal, halfDir));
    float alpha2 = alpha * alpha;
    float a = alpha2 - 1;
    
    float e = alpha2 / (nh * nh * a * a + a) - 1 / a;

    float theta = acos(sqrt((1 - rand()) / (rand() * a + 1))); //acos(sqrt((1 - e) / (e * a + 1)));
    float phi = 2.0 * PI * rand();

    //float3 halfVec = Tangent2World(theta, phi, hit.normal);
    //return 2.0 * dot(viewDir, halfVec) * halfVec - viewDir;

    float Phi = 2 * PI * rand();
    float CosTheta = sqrt((1 - rand()) / (1 + (roughness * roughness - 1) * rand()));
    float SinTheta = sqrt(1 - CosTheta * CosTheta);

    float3 H;
    H.x = SinTheta * cos(Phi);
    H.y = SinTheta * sin(Phi);
    H.z = CosTheta;


    float3  B = normalize(cross(hit.normal, float3(0.0, 0.0, 1.0)));
    float3  T = cross(B, hit.normal);

    float r = sqrt(rand());

    float3 halfVec = normalize(r * SinTheta * B + sqrt(1.0 - rand()) * H + r * CosTheta * T);
    return 2.0 * dot(viewDir, halfVec) * halfVec - viewDir;
}

void ImportanceSampling(RayHit hit, inout Ray ray)
{
    ray.origin = hit.position + hit.normal * 0.001f;
    float4 importanceLight = lightBuffer[rand() * lightCount];
    //float3 dir = ImportanceSamplingLight(importanceLight, ray.origin);
    //ray.direction = dir;

    //if (dot(dir, hit.normal) > 0)
    //    ray.direction = dir;
    //else
    //    ray.direction = CosineSampleHemisphere(hit.normal);
    ray.direction = ImportanceSamplingBRDF(importanceLight, ray.direction, hit);
    //ray.direction = CosineSampleHemisphere(hit.normal);
}
