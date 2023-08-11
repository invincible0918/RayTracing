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

////////////// chapter2_1 //////////////
RayHit BruteForceRayTrace(Ray ray)
{
    RayHit hit = CreateRayHit();

    ////////////// chapter2_2 //////////////
    // 之前是没有任何计算碰撞，直接return了hit，现在开始计算和平面的碰撞
    for (int i = 0; i < planeCount; ++i)
    {
        Plane plane = planeBuffer[i];
        IntersectPlane(ray, plane, hit);
    }

    return hit;
}
#endif