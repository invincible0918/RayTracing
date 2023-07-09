using System;
using System.Runtime.InteropServices;
using UnityEngine;

public class MeshBufferContainer : IDisposable
{
    // TODO reduce scene data for finding AABB scene in runtime

    private static readonly float size = 125f;

    private static readonly AABB Whole = new AABB()
    {
        min = Vector3.one * -1 * size,
        max = Vector3.one * size
    };

    public ComputeBuffer Keys => _keysBuffer.DeviceBuffer;
    public ComputeBuffer TriangleIndex => _triangleIndexBuffer.DeviceBuffer;
    public ComputeBuffer TriangleData => _triangleDataBuffer.DeviceBuffer;
    public ComputeBuffer TriangleAABB => _triangleAABBBuffer.DeviceBuffer;
    public ComputeBuffer BvhData => _bvhDataBuffer.DeviceBuffer;
    public ComputeBuffer BvhLeafNode => _bvhLeafNodesBuffer.DeviceBuffer;
    public ComputeBuffer BvhInternalNode => _bvhInternalNodesBuffer.DeviceBuffer;
    public uint[] KeysData => _keysBuffer.LocalBuffer;
    public uint[] ValuesData => _triangleIndexBuffer.LocalBuffer;

    public AABB[] TriangleAABBLocalData => _triangleAABBBuffer.LocalBuffer;
    public AABB[] BVHLocalData => _bvhDataBuffer.LocalBuffer;
    public LeafNode[] BvhLeafNodeLocalData => _bvhLeafNodesBuffer.LocalBuffer;
    public InternalNode[] BvhInternalNodeLocalData => _bvhInternalNodesBuffer.LocalBuffer;
    public uint TrianglesLength => _trianglesLength;

    public GraphicsBuffer IndexBuffer => _indexBuffer;
    public GraphicsBuffer VertexBuffer => _vertexBuffer;
    public Bounds Bounds => _bounds;

    private static uint ExpandBits(uint v)
    {
        v = (v * 0x00010001u) & 0xFF0000FFu;
        v = (v * 0x00000101u) & 0x0F00F00Fu;
        v = (v * 0x00000011u) & 0xC30C30C3u;
        v = (v * 0x00000005u) & 0x49249249u;
        return v;
    }

    private static uint Morton3D(float x, float y, float z)
    {
        x = Math.Min(Math.Max(x * 1024.0f, 0.0f), 1023.0f);
        y = Math.Min(Math.Max(y * 1024.0f, 0.0f), 1023.0f);
        z = Math.Min(Math.Max(z * 1024.0f, 0.0f), 1023.0f);
        uint xx = ExpandBits((uint)x);
        uint yy = ExpandBits((uint)y);
        uint zz = ExpandBits((uint)z);
        return xx * 4 + yy * 2 + zz;
    }

    private static void GetCentroidAndAABB(Vector3 a, Vector3 b, Vector3 c, out Vector3 centroid, out AABB aabb)
    {
        Vector3 min = new Vector3(
            Math.Min(Math.Min(a.x, b.x), c.x) - 0.001f,
            Math.Min(Math.Min(a.y, b.y), c.y) - 0.001f,
            Math.Min(Math.Min(a.z, b.z), c.z) - 0.001f
        );
        Vector3 max = new Vector3(
            Math.Max(Math.Max(a.x, b.x), c.x) + 0.001f,
            Math.Max(Math.Max(a.y, b.y), c.y) + 0.001f,
            Math.Max(Math.Max(a.z, b.z), c.z) + 0.001f
        );

        centroid = (min + max) * 0.5f;
        aabb = new AABB
        {
            min = min,
            max = max
        };
    }

    private static Vector3 NormalizeCentroid(Vector3 centroid)
    {
        Vector3 ret = centroid;
        ret.x -= Whole.min.x;
        ret.y -= Whole.min.y;
        ret.z -= Whole.min.z;
        ret.x /= (Whole.max.x - Whole.min.x);
        ret.y /= (Whole.max.y - Whole.min.y);
        ret.z /= (Whole.max.z - Whole.min.z);
        return ret;
    }

    private readonly uint _trianglesLength;

    private readonly DataBuffer<uint> _keysBuffer;
    private readonly DataBuffer<uint> _triangleIndexBuffer;
    private readonly DataBuffer<Triangle> _triangleDataBuffer;
    private readonly DataBuffer<AABB> _triangleAABBBuffer;

    private readonly DataBuffer<AABB> _bvhDataBuffer;
    private readonly DataBuffer<LeafNode> _bvhLeafNodesBuffer;
    private readonly DataBuffer<InternalNode> _bvhInternalNodesBuffer;

    private readonly GraphicsBuffer _indexBuffer;
    private readonly GraphicsBuffer _vertexBuffer;

    private readonly Bounds _bounds;

    public MeshBufferContainer(Mesh mesh) // TODO multiple meshes
    {
        if (Marshal.SizeOf(typeof(Triangle)) != 144)
        {
            Debug.LogError("Triangle struct size = " + Marshal.SizeOf(typeof(Triangle)) + ", not 144");
        }

        if (Marshal.SizeOf(typeof(AABB)) != 32)
        {
            Debug.LogError("AABB struct size = " + Marshal.SizeOf(typeof(AABB)) + ", not 32");
        }

        _keysBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        _triangleIndexBuffer = new DataBuffer<uint>(Constants.DATA_ARRAY_COUNT, uint.MaxValue);
        _triangleDataBuffer = new DataBuffer<Triangle>(Constants.DATA_ARRAY_COUNT);
        _triangleAABBBuffer = new DataBuffer<AABB>(Constants.DATA_ARRAY_COUNT);

        _bvhDataBuffer = new DataBuffer<AABB>(Constants.DATA_ARRAY_COUNT);
        _bvhLeafNodesBuffer = new DataBuffer<LeafNode>(Constants.DATA_ARRAY_COUNT, LeafNode.NullLeaf);
        _bvhInternalNodesBuffer = new DataBuffer<InternalNode>(Constants.DATA_ARRAY_COUNT, InternalNode.NullLeaf);

        _bounds = new Bounds
        {
            min = Whole.min,
            max = Whole.max
        };// 不要使用真实的mesh bounds，因为数值太小了，mesh.bounds;
        _trianglesLength = (uint)mesh.triangles.Length / 3;

        _indexBuffer = mesh.GetIndexBuffer();
        _vertexBuffer = mesh.GetVertexBuffer(0);
    }

    public void DistributeKeys()
    {
        _keysBuffer.GetData();
        
        uint newCurrentValue = 0;
        uint oldCurrentValue = _keysBuffer.LocalBuffer[0];
        _keysBuffer.LocalBuffer[0] = newCurrentValue;
        for (uint i = 1; i < _trianglesLength; i++)
        {
            newCurrentValue += Math.Max(_keysBuffer.LocalBuffer[i] - oldCurrentValue, 1);
            oldCurrentValue = _keysBuffer.LocalBuffer[i];
            _keysBuffer.LocalBuffer[i] = newCurrentValue;
        }
        
        _keysBuffer.Sync();
    }

    public void GetAllGpuData()
    {
        _keysBuffer.GetData();
        _triangleIndexBuffer.GetData();
        _triangleDataBuffer.GetData();
        _triangleAABBBuffer.GetData();
        _bvhDataBuffer.GetData();
        _bvhLeafNodesBuffer.GetData();
        _bvhInternalNodesBuffer.GetData();

        // debug
        //for (uint i = 0; i < _trianglesLength; i++)
        //{
        //    if (_bvhLeafNodesBuffer[i].index == 0xFFFFFFFF && _bvhLeafNodesBuffer[i].parent == 0xFFFFFFFF)
        //    {
        //        Debug.LogErrorFormat("LEAF CORRUPTED {0}", i);
        //    }
        //}

        //for (uint i = 0; i < _trianglesLength - 1; i++)
        //{
        //    if (_bvhInternalNodesBuffer[i].index == 0xFFFFFFFF && _bvhInternalNodesBuffer[i].parent == 0xFFFFFFFF)
        //    {
        //        Debug.LogErrorFormat("INTERNAL CORRUPTED {0}", i);
        //    }
        //}
    }

    public void PrintData()
    {
        Debug.Log(_triangleIndexBuffer);
        Debug.Log(_keysBuffer);
        Debug.Log(_bvhInternalNodesBuffer);
        Debug.Log(_bvhLeafNodesBuffer);
        Debug.Log(_bvhDataBuffer);
    }


    public void Dispose()
    {
        _keysBuffer.Dispose();
        _triangleIndexBuffer.Dispose();
        _triangleDataBuffer.Dispose();
        _triangleAABBBuffer.Dispose();
        _bvhDataBuffer.Dispose();
        _bvhLeafNodesBuffer.Dispose();
        _bvhInternalNodesBuffer.Dispose();
    }
}