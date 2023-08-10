﻿#ifndef _HEADER_
#define _HEADER_

static const float PI = 3.14159265f;
static const float INV_PI = 0.31830988618f;
static const float EPSILON = 1e-8;

float4x4 camera2World;
float4x4 cameraInverseProjection;

// Camera
struct Ray
{
    float3 origin;
    float3 direction;

    // Reflection
    float3 energy;
};

// Tracing
struct RayHit
{
    float3 position;
    float distance;
    float3 normal;
    float3 albedo;
    float metallic;
    float smoothness;
    float transparent;
    float3 emissionColor;
    uint materialType;           // 0: default opacity, 1: transparent, 2: emission, 3: clear coat  
    int castShadow;
    int receiveShadow;
};

Ray CreateRay(float3 origin, float3 direction)
{
    Ray ray;
    ray.origin = origin;
    ray.direction = direction;
    ray.energy = float3(1.0f, 1.0f, 1.0f);
    
    return ray;
}

RayHit CreateRayHit()
{
    RayHit hit;
    hit.position = float3(0.0f, 0.0f, 0.0f);
    hit.distance = 1.#INF;
    hit.normal = float3(0.0f, 0.0f, 0.0f);
    hit.albedo = 0.75;
    hit.metallic = 0;
    hit.smoothness = 0;
    hit.transparent = -1;
    hit.emissionColor = 0;
    hit.castShadow = 1;
    hit.receiveShadow = 1;
    return hit;
}

// Sky Light
float4 light;
// Sphere Light and Aera Light
float4 lightPosition;

float4 lightColor;

float2 _pixel;
float seed;

// range: 0~1
float rand()
{
    float result = frac(sin(seed / 100.0f * dot(_pixel, float2(12.9898f, 78.233f))) * 43758.5453f);
    seed += 1.0f;
    return result;
}

float rand(float seed)
{
    float result = frac(sin(seed / 100.0f * dot(_pixel, float2(12.9898f, 78.233f))) * 43758.5453f);
    return result;
}

float2 hash2()
{
    return frac(sin(_pixel) * float2(43758.5453123, 22578.1459123));
}

// chapter 3.1
bool IntersectTriangle_MT97(Ray ray, float3 vert0, float3 vert1, float3 vert2,
    inout float t, inout float u, inout float v)
{
    // find vectors for two edges sharing vert0
    float3 edge1 = vert1 - vert0;
    float3 edge2 = vert2 - vert0;

    // begin calculating determinant - also used to calculate U parameter
    float3 pvec = cross(ray.direction, edge2);

    // if determinant is near zero, ray lies in plane of triangle
    float det = dot(edge1, pvec);

    // use backface culling
    if (det < EPSILON)
        return false;
    float inv_det = 1.0f / det;

    // calculate distance from vert0 to ray origin
    float3 tvec = ray.origin - vert0;

    // calculate U parameter and test bounds
    u = dot(tvec, pvec) * inv_det;
    if (u < 0.0 || u > 1.0f)
        return false;

    // prepare to test V parameter
    float3 qvec = cross(tvec, edge1);

    // calculate V parameter and test bounds
    v = dot(ray.direction, qvec) * inv_det;
    if (v < 0.0 || u + v > 1.0f)
        return false;

    // calculate t, ray intersects triangle
    t = dot(edge2, qvec) * inv_det;

    return true;
}


#endif