using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

public class MeshBufferContainer
{
    // �����������������AABB��
    static readonly float size = 125f;
    static readonly AABB Whole = new AABB()
    {
        min = Vector3.one * -1 * size,
        max = Vector3.one * size
    };

    // mesh��bounds��ʹ��bounds������AABB
    public Bounds bounds => _bounds;
    // �����������
    public uint trianglesLength => _trianglesLength;
    // ÿ���������Ī����
    public ComputeBuffer mortonCodeBuffer => _mortonCodeBuffer.computeBuffer;
    // ����������
    public ComputeBuffer triangleIndexBuffer => _triangleIndexBuffer.computeBuffer;
    public ComputeBuffer triangleDataBuffer => _triangleDataBuffer.computeBuffer;
    public ComputeBuffer triangleAABBBuffer => _triangleAABBBuffer.computeBuffer;
    // BVH����
    public ComputeBuffer bvhDataBuffer => _bvhDataBuffer.computeBuffer;
    public ComputeBuffer bvhLeafNodeBuffer => _bvhLeafNodeBuffer.computeBuffer;
    public ComputeBuffer bvhInternalNodeBuffer => _bvhInternalNodeBuffer.computeBuffer;
    // ʹ��Unity��Advanced Mesh API��ͨ���ڴ����mesh
    public GraphicsBuffer indexBuffer => _indexBuffer;
    public GraphicsBuffer vertexBuffer => _vertexBuffer;
    // ���ʵ�����
    public ComputeBuffer materialIndexBuffer => _materialIndexBuffer.computeBuffer;
    // ÿ���������Ƿ����/������Ӱ
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
        }; // ��Ҫʹ����ʵ�ĳ�����mesh bounds����Ϊ����mesh.bounds����ֵ̫С
        _trianglesLength = (uint)mesh.triangles.Length / 3;

        _indexBuffer = mesh.GetIndexBuffer();
        _vertexBuffer = mesh.GetVertexBuffer(0);

        // ����洢����ÿһ��������Ĳ���id
        _materialIndexBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        _materialIndexBuffer.SetData(materialIndices.ToArray());

        // ����洢����ÿһ�����������Ӱ����
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
