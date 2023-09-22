#ifndef _CONSTANTS_
#define _CONSTANTS_

#define THREADS_PER_BLOCK 1024
#define BLOCK_SIZE 512
#define RADIX 8
#define BUCKET_SIZE 256 // 2 ^ RADIX
#define WARP_SIZE 32

////////////// chapter4_4 //////////////
struct AABB
{
    float3 min;
    float _dummy0;
    float3 max;
    float _dummy1;
};

////////////// chapter4_5 //////////////
struct Triangle
{
    // It's a pack: 4 float variables
    float3 point0;
    float _dummy0;

    float3 point1;
    float _dummy1;

    float3 point2;
    float _dummy2;

    float2 uv0;
    float2 uv1;
    float2 uv2;
    float2 _dummy3;

    float3 normal0;
    float _dummy4;

    float3 normal1;
    float _dummy5;

    float3 normal2;
    float _dummy6;

    float3 tangent0;
    float _dummy7;

    float3 tangent1;
    float _dummy8;

    float3 tangent2;
    float _dummy9;

    int materialIndex;
    int castShadow;
    int receiveShadow;
    float _dummy10;
};

////////////// chapter4_6 //////////////
#define INTERNAL_NODE 0
#define LEAF_NODE 1

struct InternalNode
{
    uint leftNode;
    uint leftNodeType; // TODO combine node types in one 4 byte word 
    uint rightNode;
    uint rightNodeType;
    uint parent;
    uint index;
};

struct LeafNode
{
    uint parent;
    uint index;
};

#endif