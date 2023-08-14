#ifndef _BRUTEFORCERAYTRACE_
#define _BRUTEFORCERAYTRACE_

////////////// chapter2_2 //////////////
struct Plane
{
    float3 normal;
    float3 position;
    float3 size;
};
StructuredBuffer<Plane> planeBuffer;
const int planeCount;

////////////// chapter2_3 //////////////
struct Sphere
{
    float3 center;
    float radius;
};
StructuredBuffer<Sphere> sphereBuffer;
const int sphereCount;

struct Cube
{
    float3 min;
    float3 max;
};
StructuredBuffer<Cube> cubeBuffer;
const int cubeCount;

////////////// chapter2_2 //////////////
void IntersectPlane(Ray ray, Plane plane, inout RayHit hit)
{
    // 射线和平面相交：https://blog.csdn.net/LIQIANGEASTSUN/article/details/119462082
    float t = dot(plane.position - ray.origin, plane.normal) / dot(ray.direction, plane.normal);
    if (t > 0 && t < hit.distance)
    {
        // 再判断交点是否在这个aabb中
        float3 min = plane.position - plane.size / 2;
        float3 max = plane.position + plane.size / 2;

        float3 p = ray.origin + t * ray.direction;
        if (p.x > min.x && p.x < max.x && p.y > min.y && p.y < max.y && p.z > min.z && p.z < max.z)
        {
            hit.distance = t;
            hit.position = p;
            hit.normal = plane.normal;
        }
    }
}

////////////// chapter2_3 //////////////
void IntersectSphere(Ray ray, Sphere sphere, inout RayHit hit)
{
    // ref: https://zhuanlan.zhihu.com/p/136763389
    float3 dir = sphere.center - ray.origin;
    
    float distance = length(sphere.center - ray.origin);
    // Ray origin is inside of sphere, no intersection
    if (distance < sphere.radius)
        return;

    // Ray origin is behind sphere, no intersection
    float l = dot(dir, normalize(ray.direction));
    if (l < 0)
        return;

    float m = sqrt(distance * distance - l * l);

    if (m > sphere.radius)
        return;

    float q = sqrt(sphere.radius * sphere.radius - m * m);
    hit.distance = l - q;
    hit.position = ray.origin + (l - q) * ray.direction;
    hit.normal = normalize(hit.position - sphere.center);
}

void IntersectCube(Ray ray, Cube cube, inout RayHit hit)
{
    float3 invDir = 1.0f / ray.direction;
    float3 tMin = (cube.min - ray.origin) * invDir;
    float3 tMax = (cube.max - ray.origin) * invDir;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);

    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);

    if (tNear > tFar)
        return;

    float3 normal = float3(1, 0, 0);
    if (tNear == t1.y)
        normal = float3(0, 1, 0);
    else if (tNear == t1.z)
        normal = float3(0, 0, 1);

    normal *= sign(ray.origin - (cube.min + cube.max) * 0.5);

    hit.distance = tNear;
    hit.position = ray.origin + tNear * ray.direction;
    hit.normal = normal;
}


////////////// chapter2_1 //////////////
RayHit BruteForceRayTrace(Ray ray)
{
    RayHit hit = CreateRayHit();

    ////////////// chapter2_2 //////////////
    // 之前是没有任何计算碰撞，直接return了hit，现在开始计算和平面的碰撞
    int i = 0;
    for (i = 0; i < planeCount; ++i)
    {
        Plane plane = planeBuffer[i];
        IntersectPlane(ray, plane, hit);
    }

    ////////////// chapter2_3 //////////////
    for (i = 0; i < sphereCount; ++i)
    {
        Sphere sphere = sphereBuffer[i];
        IntersectSphere(ray, sphere, hit);
    }

    for (i = 0; i < cubeCount; ++i)
    {
        Cube cube = cubeBuffer[i];
        IntersectCube(ray, cube, hit);
    }

    return hit;
}
#endif