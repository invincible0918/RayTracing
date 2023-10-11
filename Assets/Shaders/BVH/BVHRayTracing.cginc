#ifndef _BVH_RAY_TRACING_
#define _BVH_RAY_TRACING_

#include "Constants.cginc"

struct MaterialData
{
    float3 albedo;
    float metallic;
    float smoothness;
    float transparent;
    float3 emissionColor;
    uint materialType;           // 0: default opacity, 1: transparent, 2: emission, 3: clear coat, 4: matte mask
    ////////////// chapter6_5 //////////////
    float ior;
    float3 clearCoatColor;
};

StructuredBuffer<uint> sortedTriangleIndexBuffer; // size = THREADS_PER_BLOCK * BLOCK_SIZE
StructuredBuffer<AABB> triangleAABBBuffer; // size = THREADS_PER_BLOCK * BLOCK_SIZE
StructuredBuffer<InternalNode> bvhInternalNodeBuffer; // size = THREADS_PER_BLOCK * BLOCK_SIZE - 1
StructuredBuffer<LeafNode> bvhLeafNodeBuffer; // size = THREADS_PER_BLOCK * BLOCK_SIZE
StructuredBuffer<AABB> bvhDataBuffer; // size = THREADS_PER_BLOCK * BLOCK_SIZE - 1
StructuredBuffer<Triangle> triangleDataBuffer; // size = THREADS_PER_BLOCK * BLOCK_SIZE
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
    if (RayBoxIntersection(triangleAABBBuffer[triangleIndex], ray))
    {
        const Triangle tri = triangleDataBuffer[triangleIndex];

        // t: 射线源点和三角面的交点的距离
        // u: 交点在三角面u方向的百分比, 从0到1
        // v: 交点在三角面v方向的百分比, 从0到1
        float t, u, v;
        if (IntersectTriangle_MT97(ray, tri.point0, tri.point1, tri.point2, /*inout */t, /*inout */u, /*inout */v))
        {
            // 有交点并且在三角面的正面朝向的话
            if (t > 0 && t < hit.distance)
            {
                hit.distance = t;
                hit.position = ray.origin + t * ray.direction;
                hit.normal = normalize((1 - u - v) * tri.normal0 + u * tri.normal1 + v * tri.normal2);
            
                // 传递材质
                MaterialData materialData = materialDataBuffer[tri.materialIndex];
                hit.albedo = materialData.albedo;
                hit.metallic = materialData.metallic;
                hit.smoothness = materialData.smoothness;
                hit.transparent = materialData.transparent;
                hit.emissionColor = materialData.emissionColor;
                hit.materialType = materialData.materialType;
                ////////////// chapter6_5 //////////////
                hit.ior = materialData.ior;
                hit.clearCoatColor = materialData.clearCoatColor;
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

		// 如果当前ray和 当前bvh data不相交，则进行下一轮迭代
		if (!RayBoxIntersection(bvhDataBuffer[index], ray))
        {
            continue;
        }

		// 开始判断是否和左/右节点相交
		const uint leftIndex = bvhInternalNodeBuffer[index].leftNode;
        const uint leftType = bvhInternalNodeBuffer[index].leftNodeType;
		if (leftType == INTERNAL_NODE)
        {
            stack[currentStackIndex] = leftIndex;
            currentStackIndex++;
        }
		else
        {
            const uint triangleIndex = sortedTriangleIndexBuffer[bvhLeafNodeBuffer[leftIndex].index];
            CheckTriangle(triangleIndex, ray, /*inout*/hit);
        }

		const uint rightIndex = bvhInternalNodeBuffer[index].rightNode;
        const uint rightType = bvhInternalNodeBuffer[index].rightNodeType;
        if (rightType == INTERNAL_NODE)
        {
            stack[currentStackIndex] = rightIndex;
            currentStackIndex ++;
        }
        else
        {
            const uint triangleIndex = sortedTriangleIndexBuffer[bvhLeafNodeBuffer[rightIndex].index];
            CheckTriangle(triangleIndex, ray, /*inout*/hit);
        }
	}
}

RayHit BVHRayTrace(Ray ray)  
{
	RayHit hit = CreateRayHit();

	// 处理射线和场景的交互
	IntersectTriangle(ray, /*inout */hit);

	return hit;
}

#endif