#define RADIX 8
#define BUCKET_SIZE 256 // 2 ^ RADIX
#define BLOCK_SIZE 512
#define THREADS_PER_BLOCK 1024
#define WARP_SIZE 32

#define MAX_FLOAT 0x7F7FFFFF

struct AABB
{
    float3 min;
    float _dummy0;
    float3 max;
    float _dummy1;
};

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

struct Triangle
{
    float3 point0;
    float3 point1;
    float3 point2;
    float3 normal0;
    float3 normal1;
    float3 normal2;
    float3 tangent0;
    float3 tangent1;
    float3 tangent2;
    float2 uv0;
    float2 uv1;
    float2 uv2;
    uint materialIndex;
};  
