//// Sphere
//Sphere CreateSphere(float3 center, float radius)
//{
//    Sphere sphere;
//    sphere.center = center;
//    sphere.radius = radius;
//    return sphere;
//}

// sphere
struct Sphere
{
    float3 center;
    float radius;
    float3 albedo;
    float metallic;
    float smoothness;
    float3 emissionColor;
};

// plane
struct Plane
{
    float3 normal;
    float3 position;
    float3 size;
    float3 albedo;
    float metallic;
    float smoothness;
};

// chapter 3.1
struct CMesh
{
    float4x4 localToWorldMatrix;
    int indicesOffset;
    int indicesCount;
    float3 albedo;
    float metallic;
    float smoothness;
};

StructuredBuffer<Sphere> sphereBuffer;
StructuredBuffer<Plane> planeBuffer;

// chapter 3.1
StructuredBuffer<CMesh> meshBuffer;
StructuredBuffer<float3> vertexBuffer;
StructuredBuffer<int> indexBuffer;

const uniform int planeCount;
const uniform int sphereCount;
const uniform int meshCount;

// Ground Plane
void IntersectGroundPlane(Ray ray, inout RayHit hit)
{
    // p = p0 + t * d;
    // plane.y = 0
    // (x, y, z) = (x_origin, y_origin, z_origin) + t * (x_direction, y_direction, z_direction)
    // y = 0
    // 0 = y_origin + t * y_direction
    float t = -ray.origin.y / ray.direction.y;
    if (t > 0 && t < hit.distance)
    {
        hit.distance = t;
        hit.position = ray.origin + t * ray.direction;
        hit.normal = float3(0, 1, 0);
    }
}

// https://blog.csdn.net/LIQIANGEASTSUN/article/details/119462082
void IntersectPlane(Ray ray, Plane plane, inout RayHit hit) 
{   
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
            hit.albedo = plane.albedo;
            hit.metallic = plane.metallic;
            hit.smoothness = plane.smoothness;
        }
    }
}

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
    hit.albedo = sphere.albedo;
    hit.metallic = sphere.metallic;
    hit.smoothness = sphere.smoothness;
    hit.emissionColor = sphere.emissionColor;
}

void IntersectMesh(Ray ray, CMesh mesh, inout RayHit hit)
{
    uint offset = mesh.indicesOffset;
    uint count = offset + mesh.indicesCount;
    for (uint i = offset; i < count; i += 3)
    {
        float3 v0 = (mul(mesh.localToWorldMatrix, float4(vertexBuffer[indexBuffer[i]], 1))).xyz;
        float3 v1 = (mul(mesh.localToWorldMatrix, float4(vertexBuffer[indexBuffer[i + 1]], 1))).xyz;
        float3 v2 = (mul(mesh.localToWorldMatrix, float4(vertexBuffer[indexBuffer[i + 2]], 1))).xyz;

        float t, u, v;
        if (IntersectTriangle_MT97(ray, v0, v1, v2, t, u, v))
        {
            if (t > 0 && t < hit.distance)
            {
                hit.distance = t;
                hit.position = ray.origin + t * ray.direction;
                hit.normal = normalize(cross(v1 - v0, v2 - v0));
                hit.albedo = mesh.albedo;
                hit.metallic = mesh.metallic;
                hit.smoothness = mesh.smoothness;
            }
        }
    }
}

RayHit BruteForceTrace(Ray ray)   
{
    RayHit hit = CreateRayHit();
    //IntersectGroundPlane(ray, hit);

    //Sphere sphere0 = CreateSphere(float3(-2, 1, 0), 1);
    //IntersectSphere(ray, sphere0, hit);

    //Sphere sphere1 = CreateSphere(float3(0, 1, 0), 1);
    //IntersectSphere(ray, sphere1, hit);

    //Sphere sphere2 = CreateSphere(float3(2, 1, 0), 1);
    //IntersectSphere(ray, sphere2, hit);

    // Trace Plane
    for (uint i = 0; i < planeCount; ++i)
    {
        Plane plane = planeBuffer[i];
        IntersectPlane(ray, plane, hit);
    }

    // Trace Sphere
    for (uint i = 0; i < sphereCount; ++i)
    {
        Sphere sphere = sphereBuffer[i];
        IntersectSphere(ray, sphere, hit);
    }

    // chapter 3.1
    // Trace mesh
    for (uint i = 0; i < meshCount; ++i)
    {
        CMesh cmesh = meshBuffer[i];
        IntersectMesh(ray, cmesh, hit);
    }

    return hit;
}