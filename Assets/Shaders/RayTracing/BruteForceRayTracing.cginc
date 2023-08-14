#ifndef _BRUTE_FORCE_RAY_TRACING_
#define _BRUTE_FORCE_RAY_TRACING_

////////////// chapter2_2 //////////////
struct Plane
{
    float3 normal;
    float3 position;
    float3 size;
    //////////////// chapter3_3 //////////////
    float3 albedo;
    float metallic;
    float smoothness;
    float transparent;
    float3 emissionColor;
};
StructuredBuffer<Plane> planeBuffer;
const int planeCount;

////////////// chapter2_3 //////////////
struct Sphere
{
    float3 center;
    float radius;
    //////////////// chapter3_3 //////////////
    float3 albedo;
    float metallic;
    float smoothness;
    float transparent;
    float3 emissionColor;
};
StructuredBuffer<Sphere> sphereBuffer;
const int sphereCount;

struct Cube
{
    float3 min;
    float3 max;
    //////////////// chapter3_3 //////////////
    float3 albedo;
    float metallic;
    float smoothness;
    float transparent;
    float3 emissionColor;
};
StructuredBuffer<Cube> cubeBuffer;
const int cubeCount;

////////////// chapter4_1 //////////////
struct CustomMesh
{
    float4x4 localToWorldMatrix;
    int indicesOffset;
    int indicesCount;
    float3 albedo;
    float metallic;
    float smoothness;
    float transparent;
    float3 emissionColor;
};
StructuredBuffer<CustomMesh> customMeshBuffer;
StructuredBuffer<float3> vertexBuffer;
StructuredBuffer<float3> normalBuffer;
StructuredBuffer<int> indexBuffer;
const int customMeshCount;

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
            //////////////// chapter3_3 //////////////
            hit.albedo = plane.albedo;
            hit.metallic = plane.metallic;
            hit.smoothness = plane.smoothness;
            hit.transparent = plane.transparent;
            hit.emissionColor = plane.emissionColor;
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
    //////////////// chapter3_3 //////////////
    hit.albedo = sphere.albedo;
    hit.metallic = sphere.metallic;
    hit.smoothness = sphere.smoothness;
    hit.transparent = sphere.transparent;
    hit.emissionColor = sphere.emissionColor;
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
    //////////////// chapter3_3 //////////////
    hit.albedo = cube.albedo;
    hit.metallic = cube.metallic;
    hit.smoothness = cube.smoothness;
    hit.transparent = cube.transparent;
    hit.emissionColor = cube.emissionColor;
}

//////////////// chapter4_1 //////////////
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

void IntersectMesh(Ray ray, CustomMesh mesh, inout RayHit hit)
{
    uint offset = mesh.indicesOffset;
    uint count = offset + mesh.indicesCount;
    for (uint i = offset; i < count; i += 3)
    {
        float3 v0 = (mul(mesh.localToWorldMatrix, float4(vertexBuffer[indexBuffer[i]], 1))).xyz;
        float3 v1 = (mul(mesh.localToWorldMatrix, float4(vertexBuffer[indexBuffer[i + 1]], 1))).xyz;
        float3 v2 = (mul(mesh.localToWorldMatrix, float4(vertexBuffer[indexBuffer[i + 2]], 1))).xyz;

        // normal 可以先不讲解
        float3 n0 = (mul(mesh.localToWorldMatrix, float4(normalBuffer[indexBuffer[i]], 0))).xyz;
        float3 n1 = (mul(mesh.localToWorldMatrix, float4(normalBuffer[indexBuffer[i + 1]], 0))).xyz;
        float3 n2 = (mul(mesh.localToWorldMatrix, float4(normalBuffer[indexBuffer[i + 2]], 0))).xyz;

        float t, u, v;
        if (IntersectTriangle_MT97(ray, v0, v1, v2, t, u, v))
        {
            if (t > 0 && t < hit.distance)
            {
                hit.distance = t;
                hit.position = ray.origin + t * ray.direction;
                //hit.normal = normalize(cross(v1 - v0, v2 - v0));
                hit.normal = normalize((1 - u - v) * n0 + u * n1 + v * n2);
                hit.albedo = mesh.albedo;
                hit.metallic = mesh.metallic;
                hit.smoothness = mesh.smoothness;
                hit.transparent = mesh.transparent;
                hit.emissionColor = mesh.emissionColor;
            }
        }
    }
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

    ////////////// chapter4_1 //////////////
    for (i = 0; i < customMeshCount; ++i)
    {
        CustomMesh mesh = customMeshBuffer[i];
        IntersectMesh(ray, mesh, hit);
    }

    return hit;
}
#endif