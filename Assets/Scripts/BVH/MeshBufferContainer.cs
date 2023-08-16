using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

public class MeshBufferContainer/* : IDisposable*/
{
    // TODO reduce scene data for finding AABB scene in runtime

    static readonly float size = 125f;

    static readonly AABB Whole = new AABB()
    {
        min = Vector3.one * -1 * size,
        max = Vector3.one * size
    };

    public ComputeBuffer Keys => keysBuffer.DeviceBuffer;
    public ComputeBuffer TriangleIndex => triangleIndexBuffer.DeviceBuffer;
    public ComputeBuffer TriangleData => triangleDataBuffer.DeviceBuffer;
    public ComputeBuffer TriangleAABB => triangleAABBBuffer.DeviceBuffer;
    public ComputeBuffer BvhData => bvhDataBuffer.DeviceBuffer;
    public ComputeBuffer BvhLeafNode => bvhLeafNodesBuffer.DeviceBuffer;
    public ComputeBuffer BvhInternalNode => bvhInternalNodesBuffer.DeviceBuffer;
    public uint[] KeysData => keysBuffer.LocalBuffer;
    public uint[] ValuesData => triangleIndexBuffer.LocalBuffer;
    public AABB[] TriangleAABBLocalData => triangleAABBBuffer.LocalBuffer;
    public AABB[] BVHLocalData => bvhDataBuffer.LocalBuffer;
    public LeafNode[] BvhLeafNodeLocalData => bvhLeafNodesBuffer.LocalBuffer;
    public InternalNode[] BvhInternalNodeLocalData => bvhInternalNodesBuffer.LocalBuffer;
    public uint TrianglesLength => trianglesLength;

    public GraphicsBuffer IndexBuffer => indexBuffer;
    public GraphicsBuffer VertexBuffer => vertexBuffer;
    public ComputeBuffer MaterialIndexBuffer => materialIndexBuffer.DeviceBuffer;
    public ComputeBuffer ShadowIndexBuffer => shadowIndexBuffer.DeviceBuffer;

    public Bounds Bounds => _bounds;

    readonly uint trianglesLength;

    readonly DataBuffer<uint> keysBuffer;
    readonly DataBuffer<uint> triangleIndexBuffer;
    readonly DataBuffer<Triangle> triangleDataBuffer;
    readonly DataBuffer<AABB> triangleAABBBuffer;

    readonly DataBuffer<AABB> bvhDataBuffer;
    readonly DataBuffer<LeafNode> bvhLeafNodesBuffer;
    readonly DataBuffer<InternalNode> bvhInternalNodesBuffer;

    readonly GraphicsBuffer indexBuffer;
    readonly GraphicsBuffer vertexBuffer;
    readonly DataBuffer<uint> materialIndexBuffer;
    readonly DataBuffer<Vector2Int> shadowIndexBuffer;

    private readonly Bounds _bounds;

    public MeshBufferContainer(Mesh mesh, List<uint> materialIndices, List<Vector2Int> shadowIndices) // TODO multiple meshes
    {
        if (Marshal.SizeOf(typeof(Triangle)) != 192)
        {
            Debug.LogError("Triangle struct size = " + Marshal.SizeOf(typeof(Triangle)) + ", not 192");
        }

        if (Marshal.SizeOf(typeof(AABB)) != 32)
        {
            Debug.LogError("AABB struct size = " + Marshal.SizeOf(typeof(AABB)) + ", not 32");
        }

        keysBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        triangleIndexBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        triangleDataBuffer = new DataBuffer<Triangle>(Constants.DATA_ARRAY_COUNT, Triangle.NullTriangle);
        triangleAABBBuffer = new DataBuffer<AABB>(Constants.DATA_ARRAY_COUNT, AABB.NullAABB);

        bvhDataBuffer = new DataBuffer<AABB>(Constants.DATA_ARRAY_COUNT);
        bvhLeafNodesBuffer = new DataBuffer<LeafNode>(Constants.DATA_ARRAY_COUNT, LeafNode.NullLeaf);
        bvhInternalNodesBuffer = new DataBuffer<InternalNode>(Constants.DATA_ARRAY_COUNT, InternalNode.NullLeaf);

        _bounds = new Bounds
        {
            min = Whole.min,
            max = Whole.max
        };// 不要使用真实的mesh bounds，因为数值太小了，mesh.bounds;
        trianglesLength = (uint)mesh.triangles.Length / 3;

        indexBuffer = mesh.GetIndexBuffer();
        vertexBuffer = mesh.GetVertexBuffer(0);

        // 这里存贮的是每一个三角面的材质id
        materialIndexBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        for (uint i = 0; i < materialIndices.Count; ++i)
            materialIndexBuffer[i] = materialIndices[(int)i];
        materialIndexBuffer.Sync();

        // 这里存贮的是每一个三角面的阴影属性
        shadowIndexBuffer = new DataBuffer<Vector2Int>(Constants.DATA_ARRAY_COUNT, Vector2Int.one);
        for (uint i = 0; i < shadowIndices.Count; ++i)
            shadowIndexBuffer[i] = shadowIndices[(int)i];
        shadowIndexBuffer.Sync();
    }

    public void DistributeKeys()
    {
        keysBuffer.GetData();
        
        uint newCurrentValue = 0;
        uint oldCurrentValue = keysBuffer.LocalBuffer[0];
        keysBuffer.LocalBuffer[0] = newCurrentValue;
        for (uint i = 1; i < trianglesLength; i++)
        {
            newCurrentValue += Math.Max(keysBuffer.LocalBuffer[i] - oldCurrentValue, 1);
            oldCurrentValue = keysBuffer.LocalBuffer[i];
            keysBuffer.LocalBuffer[i] = newCurrentValue;
        }
        
        keysBuffer.Sync();
    }

    public void GetAllGpuData()
    {
        keysBuffer.GetData();
        triangleIndexBuffer.GetData();
        triangleDataBuffer.GetData();
        triangleAABBBuffer.GetData();
        bvhDataBuffer.GetData();
        bvhLeafNodesBuffer.GetData();
        bvhInternalNodesBuffer.GetData();
        materialIndexBuffer.GetData();
        shadowIndexBuffer.GetData();

        // debug
        //for (uint i = 0; i < trianglesLength; i++)
        //{
        //    if (bvhLeafNodesBuffer[i].index == 0xFFFFFFFF && bvhLeafNodesBuffer[i].parent == 0xFFFFFFFF)
        //    {
        //        Debug.LogErrorFormat("LEAF CORRUPTED {0}", i);
        //    }
        //}

        //for (uint i = 0; i < trianglesLength - 1; i++)
        //{
        //    if (bvhInternalNodesBuffer[i].index == 0xFFFFFFFF && bvhInternalNodesBuffer[i].parent == 0xFFFFFFFF)
        //    {
        //        Debug.LogErrorFormat("INTERNAL CORRUPTED {0}", i);
        //    }
        //}
    }

    public void PrintData()
    {
        //Debug.Log("triangleIndexBuffer: " + triangleIndexBuffer);
        //Debug.Log("triangleAABBBuffer: " + triangleAABBBuffer);
        //Debug.Log("bvhInternalNodesBuffer: " + bvhInternalNodesBuffer);
        //Debug.Log("bvhLeafNodesBuffer: " + bvhLeafNodesBuffer);
        //Debug.Log("bvhDataBuffer: " + bvhDataBuffer);
        //Debug.Log("triangleDataBuffer: " + triangleDataBuffer);
        //Debug.Log("keysBuffer: " + keysBuffer);
        //Debug.Log("materialIndexBuffer: " + materialIndexBuffer);
        //Debug.Log("shadowIndexBuffer: " + shadowIndexBuffer);
    }


    public void Dispose()
    {
        keysBuffer.Dispose();
        triangleIndexBuffer.Dispose();
        triangleDataBuffer.Dispose();
        triangleAABBBuffer.Dispose();
        bvhDataBuffer.Dispose();
        bvhLeafNodesBuffer.Dispose();
        bvhInternalNodesBuffer.Dispose();

        indexBuffer.Dispose();
        vertexBuffer.Dispose();
        materialIndexBuffer.Dispose();
        shadowIndexBuffer.Dispose();
    }
}