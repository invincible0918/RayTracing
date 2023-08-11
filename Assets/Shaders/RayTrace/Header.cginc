﻿#ifndef _HEADER_
#define _HEADER_

////////////// chapter2_1 //////////////
#define MAX_BOUNCE 6

////////////// chapter2_2 //////////////
float4x4 camera2World;
float4x4 cameraInverseProjection;

////////////// chapter2_1 //////////////
struct Ray
{
    float3 origin;
    float3 direction;
    float3 energy;
};

Ray CreateRay(float3 origin, float3 direction)
{
    Ray ray;
    ray.origin = origin;
    ray.direction = direction;
    ray.energy = float3(1.0f, 1.0f, 1.0f);

    return ray;
}

Ray CreateCameraRay(float2 uv)
{
    ////////////// chapter2_2 //////////////
    float3 origin = mul(camera2World, float4(0, 0, 0, 1)).xyz;

    // Invert the perspective projection of the view-space position
    float3 direction = mul(cameraInverseProjection, float4(uv, 0.0f, 1.0f)).xyz;
    // Transform the direction from camera to world space and normalize
    direction = mul(camera2World, float4(direction, 0.0f)).xyz;
    direction = normalize(direction);

    return CreateRay(origin, direction);
}

struct RayHit
{
    float3 position;
    float distance;
    float3 normal;
};

RayHit CreateRayHit()
{
    RayHit hit;
    hit.position = float3(0.0f, 0.0f, 0.0f);
    hit.distance = 1.#INF;
    hit.normal = float3(0.0f, 0.0f, 0.0f);
    return hit;
}

#endif