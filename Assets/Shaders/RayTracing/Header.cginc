#ifndef _HEADER_
#define _HEADER_

////////////// chapter2_1 //////////////
#define MAX_BOUNCE 8

////////////// chapter2_2 //////////////
float4x4 camera2World;
float4x4 cameraInverseProjection;

//////////////// chapter3_4 //////////////
float4 lightParameter;          // rgb: direction, a:intensity
float4 lightColor;
float4 shadowParameter;         // rgb: color, a:intensity

////////////// chapter4_1 //////////////
static const float EPSILON = 1e-8;

////////////// chapter5_2 //////////////
static const float PI = 3.14159265f;

////////////// chapter7_2 //////////////
static const float NORMAL_BIAS = 0.001f;

////////////// chapter7_6 //////////////
#ifdef DEPTH_OF_FIELD
    float _LensRadius;
    float _FocalLength;
#endif

////////////// chapter2_1 //////////////
struct Ray
{
	float3 origin;		// 射线源点
	float3 direction;	// 射线方向
    // chapter3_1
    float3 energy;      // 光能传递遵循能量守恒定律
};

struct RayHit
{
	float3 position;	// 射线和物体的交点，世界坐标系下
    float distance;		// 射线源点和交点的距离
    float3 normal;		// 射线和物体的交点的法线，世界坐标系下
    //////////////// chapter3_3 //////////////
    float3 albedo;
    float metallic;
    float smoothness;
    float transparent;
    float3 emissionColor;
    //////////////// chapter4_7 //////////////
    uint materialType;           // 0: default opacity, 1: transparent, 2: emission, 3: clear coat  
    int castShadow;
    int receiveShadow;
    ////////////// chapter6_5 //////////////
    float ior;
    float3 clearCoatColor;
};

////////////// chapter5_2 //////////////
float2 _pixel;
float seed;

uint rngstate;

uint RandInt() 
{
    rngstate ^= rngstate << 13;
    rngstate ^= rngstate >> 17;
	rngstate ^= rngstate << 5;
    return rngstate;
}

float RandFloat() 
{
    return frac(float(RandInt()) / float(1<<32 - 5));
}

void SetSeed() 
{
    rngstate = _pixel.x * _pixel.y;
    RandInt(); RandInt(); RandInt(); // Shift some bits around
}

// range: 0~1
float Rand()
{
    float result = sin(seed / 100.0f * dot(_pixel, float2(12.9898f, 78.233f))) * 43758.5453f;
    seed += 1.0f;
    rngstate += result;

    return RandFloat();
    //float result = frac(sin(seed / 100.0f * dot(_pixel, float2(12.9898f, 78.233f))) * 43758.5453f);
    //seed += 1.0f;
    //return result;
}

////////////// chapter2_1 //////////////
Ray CreateRay(float3 origin, float3 direction)
{
	Ray ray;
    ray.origin = origin;
    ray.direction = direction;
    // chapter3_1
    ray.energy = float3(1.0f, 1.0f, 1.0f);

	return ray;
}

Ray CreateCameraRay(float2 uv)
{
    ////////////// chapter2_2 //////////////
    float3 origin = mul(camera2World, float4(0, 0, 0, 1)).xyz;

    // 反转观察坐标系的透视投影到摄像机坐标系
    float3 direction = mul(cameraInverseProjection, float4(uv, 0.0f, 1.0f)).xyz;
    // 再从摄像机坐标系转到世界坐标系
    direction = mul(camera2World, float4(direction, 0.0f)).xyz;
    direction = normalize(direction);

	return CreateRay(origin, direction);
}

////////////// chapter7_6 //////////////
#ifdef DEPTH_OF_FIELD
float2 ConcentricSampleDisk(float2 u)
{
    // 随机数 u 从 (0, 1) 转换到 (-1, 1)
    float2 u1 = float2(u.x * 2.0f - 1, u.y * 2.0f - 1);

    if (u1.x == 0 && u1.y == 0)
		return float2(0, 0);

    // 采样出来的随机数符合在圆盘内
    // x = sin(theta) * radius, y = cos(theta) * radius
    // r = x, theta = y/x * PI / 4
    float theta, r;
    if (abs(u1.x) > abs(u1.y))
	{
		r = u1.x;
		theta = u1.y / u1.x * PI / 4;
	}
    else
    {
        r = u1.y;
		theta = PI / 2 - u1.x / u1.y * PI / 4;
    }
    return r * float2(cos(theta), sin(theta));
}

Ray CreateDoFCameraRay(float2 uv)
{
    float3 origin = 0;
    // 反转观察坐标系的透视投影到摄像机坐标系
    float3 direction = mul(cameraInverseProjection, float4(uv, 0.0f, 1.0f)).xyz;
    // offset 是采样一个圆盘上的随机位置
    float2 offset = ConcentricSampleDisk(float2(Rand(), Rand())) * _LensRadius;

    float ft = abs(_FocalLength / direction.z);
    float3 focusPoint = origin + direction * ft;
    origin = float3(offset, 0);
    direction = normalize(focusPoint - origin);

    // 再从摄像机坐标系转到世界坐标系
    origin = mul(camera2World, float4(origin, 1)).xyz;
    direction = mul(camera2World, float4(direction, 0.0f)).xyz;
    direction = normalize(direction);

    return CreateRay(origin, direction);
}
#endif

RayHit CreateRayHit()
{
    RayHit hit;
    hit.position = float3(0.0f, 0.0f, 0.0f);
    hit.distance = 1.#INF;
    hit.normal = float3(0.0f, 0.0f, 0.0f);
    return hit;
}

////////////// chapter6_6 //////////////
float3 LessThan(float3 f, float value)
{
    return float3(
        (f.x < value) ? 1.0f : 0.0f,
        (f.y < value) ? 1.0f : 0.0f,
        (f.z < value) ? 1.0f : 0.0f);
}

float3 SRGBToLinear(float3 rgb)
{   
    rgb = clamp(rgb, 0.0f, 1.0f);
    
    return lerp(
        pow(((rgb + 0.055f) / 1.055f), 2.4f),
        rgb / 12.92f,
        LessThan(rgb, 0.04045f)
	);
}

float3 LinearToSRGB(float3 rgb)
{
    rgb = clamp(rgb, 0.0f, 1.0f);
    
    return lerp(
        pow(rgb, 1.0f / 2.4f) * 1.055f - 0.055f,
        rgb * 12.92f,
        LessThan(rgb, 0.0031308f)
    );
}

#endif