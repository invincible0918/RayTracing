#include "BVH/Constants.cginc"

struct MaterialData
{
    float3 albedo;
    float metallic;
    float smoothness;
    float transparent;
    float3 emissionColor;
};

StructuredBuffer<uint> sortedTriangleIndices; // size = THREADS_PER_BLOCK * BLOCK_SIZE
StructuredBuffer<AABB> triangleAABB; // size = THREADS_PER_BLOCK * BLOCK_SIZE
StructuredBuffer<InternalNode> internalNodes; // size = THREADS_PER_BLOCK * BLOCK_SIZE - 1
StructuredBuffer<LeafNode> leafNodes; // size = THREADS_PER_BLOCK * BLOCK_SIZE
StructuredBuffer<AABB> bvhData; // size = THREADS_PER_BLOCK * BLOCK_SIZE - 1
StructuredBuffer<Triangle> triangleData; // size = THREADS_PER_BLOCK * BLOCK_SIZE
StructuredBuffer<MaterialData> materialDataBuffer;

bool RayBoxIntersection(AABB b, Ray r)
{
    const float3 t1 = (b.min - r.origin) / r.direction;
    const float3 t2 = (b.max - r.origin) / r.direction;

    const float3 tmin1 = min(t1, t2);
    const float3 tmax1 = max(t1, t2);

    const float tmin = max(tmin1.x, max(tmin1.y, tmin1.z));
    const float tmax = min(tmax1.x, min(tmax1.y, tmax1.z));

    return tmax > tmin && tmax > 0;
}

void CheckTriangle(uint triangleIndex, Ray ray, inout RayHit hit)
{
    if (RayBoxIntersection(triangleAABB[triangleIndex], ray))
    {
        const Triangle tri = triangleData[triangleIndex];
        float t, u, v;
        if (IntersectTriangle_MT97(ray, tri.point0, tri.point1, tri.point2, t, u, v))
        {
            if (t > 0 && t < hit.distance)
            {
                hit.distance = t;
                hit.position = ray.origin + t * ray.direction;

                //const float2 uv = (1 - u - v) * tri.uv0 + u * tri.uv1 + v * tri.uv2;
                const float3 normal = (1 - u - v) * tri.normal0 + u * tri.normal1 + v * tri.normal2;
                hit.normal = normalize(normal);

                MaterialData materialData = materialDataBuffer[tri.materialIndex];

                hit.albedo = materialData.albedo;
                hit.metallic = materialData.metallic;
                hit.smoothness = materialData.smoothness;
                hit.transparent = materialData.transparent;
                hit.emissionColor = materialData.emissionColor;
                hit.castShadow = tri.castShadow;
                hit.receiveShadow = tri.receiveShadow;
            }
        }
    }
}

void IntersectTriangle(Ray ray, inout RayHit hit)
{
    uint stack[64];
    uint currentStackIndex = 0;
    stack[currentStackIndex] = 0;
    currentStackIndex = 1;

    while (currentStackIndex != 0)
    {
        currentStackIndex --;
        const uint index = stack[currentStackIndex];

        if (!RayBoxIntersection(bvhData[index], ray))
        {
            continue;
        }

        const uint leftIndex = internalNodes[index].leftNode;
        const uint leftType = internalNodes[index].leftNodeType;

        if (leftType == INTERNAL_NODE)
        {
            stack[currentStackIndex] = leftIndex;
            currentStackIndex++;
        }
        else
        {
            const uint triangleIndex = sortedTriangleIndices[leafNodes[leftIndex].index];
            CheckTriangle(triangleIndex, ray, hit);
        }

        const uint rightIndex = internalNodes[index].rightNode;
        const uint rightType = internalNodes[index].rightNodeType;


        if (rightType == INTERNAL_NODE)
        {
            stack[currentStackIndex] = rightIndex;
            currentStackIndex ++;
        }
        else
        {
            const uint triangleIndex = sortedTriangleIndices[leafNodes[rightIndex].index];
            CheckTriangle(triangleIndex, ray, hit);
        }
    }

    //const Triangle t = triangleData[result.triangleIndex];
    //const float2 uv = (1 - result.uv.x - result.uv.y) * t.a_uv + result.uv.x * t.b_uv + result.uv.y * t.c_uv;
    //const float3 normal = (1 - result.uv.x - result.uv.y) * t.a_normal + result.uv.x * t.b_normal + result.uv.y * t.c_normal;
}

RayHit BVHTrace(Ray ray)   
{
    RayHit hit = CreateRayHit();
    IntersectTriangle(ray, hit);
    
    return hit;
}
