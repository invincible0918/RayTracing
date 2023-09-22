using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

public class MeshBufferContainer
{
    // 定义包含整个场景的AABB，
    static readonly float size = 125f;
    static readonly AABB Whole = new AABB()
    {
        min = Vector3.one * -1 * size,
        max = Vector3.one * size
    };

    // mesh的bounds，使用bounds来计算AABB
    public Bounds bounds => _bounds;
    // 三角面的总数
    public uint trianglesLength => _trianglesLength;
    // 每个三角面的莫顿码
    public ComputeBuffer mortonCodeBuffer => _mortonCodeBuffer.computeBuffer;
    // 三角面数据
    public ComputeBuffer triangleIndexBuffer => _triangleIndexBuffer.computeBuffer;
    public ComputeBuffer triangleDataBuffer => _triangleDataBuffer.computeBuffer;
    public ComputeBuffer triangleAABBBuffer => _triangleAABBBuffer.computeBuffer;
    // BVH数据
    public ComputeBuffer bvhDataBuffer => _bvhDataBuffer.computeBuffer;
    public ComputeBuffer bvhLeafNodeBuffer => _bvhLeafNodeBuffer.computeBuffer;
    public ComputeBuffer bvhInternalNodeBuffer => _bvhInternalNodeBuffer.computeBuffer;
    // 使用Unity的Advanced Mesh API，通过内存访问mesh
    public GraphicsBuffer indexBuffer => _indexBuffer;
    public GraphicsBuffer vertexBuffer => _vertexBuffer;
    // 材质的索引
    public ComputeBuffer materialIndexBuffer => _materialIndexBuffer.computeBuffer;
    // 每个三角面是否接受/产生阴影
    public ComputeBuffer shadowIndexBuffer => _shadowIndexBuffer.computeBuffer;

    private Bounds _bounds;
    private uint _trianglesLength;
    private DataBuffer<uint> _mortonCodeBuffer;
    private DataBuffer<uint> _triangleIndexBuffer;
    private DataBuffer<Triangle> _triangleDataBuffer;
    private DataBuffer<AABB> _triangleAABBBuffer;
    private DataBuffer<AABB> _bvhDataBuffer;
    private DataBuffer<LeafNode> _bvhLeafNodeBuffer;
    private DataBuffer<InternalNode> _bvhInternalNodeBuffer;
    private GraphicsBuffer _indexBuffer;
    private GraphicsBuffer _vertexBuffer;
    private DataBuffer<uint> _materialIndexBuffer;
    private DataBuffer<Vector2Int> _shadowIndexBuffer;

    public MeshBufferContainer(Mesh mesh, List<uint> materialIndices, List<Vector2Int> shadowIndices)
    {
        if (Marshal.SizeOf(typeof(Triangle)) != 192)
        {
            Debug.LogError("Triangle struct size = " + Marshal.SizeOf(typeof(Triangle)) + ", not 192");
        }

        if (Marshal.SizeOf(typeof(AABB)) != 32)
        {
            Debug.LogError("AABB struct size = " + Marshal.SizeOf(typeof(AABB)) + ", not 32");
        }

        _mortonCodeBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        _triangleIndexBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        _triangleDataBuffer = new DataBuffer<Triangle>(Constants.DATA_ARRAY_COUNT, Triangle.NullTriangle);
        _triangleAABBBuffer = new DataBuffer<AABB>(Constants.DATA_ARRAY_COUNT, AABB.NullAABB);

        _bvhDataBuffer = new DataBuffer<AABB>(Constants.DATA_ARRAY_COUNT);
        _bvhLeafNodeBuffer = new DataBuffer<LeafNode>(Constants.DATA_ARRAY_COUNT, LeafNode.NullLeaf);
        _bvhInternalNodeBuffer = new DataBuffer<InternalNode>(Constants.DATA_ARRAY_COUNT, InternalNode.NullLeaf);

        _bounds = new Bounds
        {
            min = Whole.min,
            max = Whole.max
        }; // 不要使用真实的场景的mesh bounds，因为可能mesh.bounds的数值太小
        _trianglesLength = (uint)mesh.triangles.Length / 3;

        _indexBuffer = mesh.GetIndexBuffer();
        _vertexBuffer = mesh.GetVertexBuffer(0);

        // 这里存储的是每一个三角面的材质id
        _materialIndexBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        _materialIndexBuffer.SetData(materialIndices.ToArray());

        // 这里存储的是每一个三角面的阴影属性
        _shadowIndexBuffer = new DataBuffer<Vector2Int>(Constants.DATA_ARRAY_COUNT, Vector2Int.one);
        _shadowIndexBuffer.SetData(shadowIndices.ToArray());
    }

    public void DistributeMortonCode()
    {
        _mortonCodeBuffer.GetData(out uint[] values);

        uint newCurrentValue = 0;
        uint oldCurrentValue = values[0];
        values[0] = newCurrentValue;
        for (uint i = 1; i < _trianglesLength; i++)
        {
            newCurrentValue += Math.Max(values[i] - oldCurrentValue, 1);
            oldCurrentValue = values[i];
            values[i] = newCurrentValue;
        }

        _mortonCodeBuffer.SetData(values);
    }

    public void PrintData()
    {
        Debug.Log("_mortonCodeBuffer: " + _mortonCodeBuffer);
        Debug.Log("_triangleIndexBuffer: " + _triangleIndexBuffer);
    }

    public void Dispose()
    {
        _mortonCodeBuffer.Dispose();
        _triangleIndexBuffer.Dispose();
        _triangleDataBuffer.Dispose();
        _triangleAABBBuffer.Dispose();
        _bvhDataBuffer.Dispose();
        _bvhLeafNodeBuffer.Dispose();
        _bvhInternalNodeBuffer.Dispose();

        _indexBuffer.Dispose();
        _vertexBuffer.Dispose();
        _materialIndexBuffer.Dispose();
        _shadowIndexBuffer.Dispose();
    }
}
