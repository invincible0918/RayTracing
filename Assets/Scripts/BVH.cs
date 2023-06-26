using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


public class BVH : MonoBehaviour
{
    // 0. 大致框架
    public ComputeShader cs;
    public ComputeShader localRadixSortShader;
    public ComputeShader globalRadixSortShader;
    public ComputeShader scanShader;
    //public bool realtimeUpdate;
    //bool updateOneTime;
    //bool initializationIsDone;

    // 1. 构造 AABB
    int kernelCalculateAABB;

    GraphicsBuffer indexBuffer;
    GraphicsBuffer vertexBuffer;
    ComputeBuffer aabbBuffer;
    ComputeBuffer triangleIndexBuffer;

    List<int> indices = new List<int>();
    List<Vector3> vertices = new List<Vector3>();

    int triangleCount;
    Bounds encompassingAABB;        // 包含所有aabb

    // 2. 构造 Morton Code
    int kernelCalculateMortonCode;
    ComputeBuffer mortonCodeBuffer;

    // 3. Radix Sort


    //void Start()
    //{
    //    if (!realtimeUpdate)
    //        updateOneTime = true;


    //}

    //void Update()
    //{
    //    if (!initializationIsDone)
    //        return;

    //    if (!realtimeUpdate)
    //    {
    //        if (updateOneTime)
    //            CustomUpdate();

    //        updateOneTime = false;
    //        return;
    //    }

    //    CustomUpdate();
    //}

    //void CustomUpdate()
    //{
    //}


    public void Calculate(MeshRenderer[] mrs)
    {
        // 构造BVH的基本流程：1. 构造ZOrder Curve & Morton Code 2. 排序 3 构造子节点 4 构造内部节点 5 更新AABB
        // http://ma-yidong.com/2018/11/10/construct-bvh-with-unity-job-system/

        //System.DateTime beforDT = System.DateTime.Now;
        //System.DateTime afterDT = System.DateTime.Now;
        //System.TimeSpan ts = afterDT.Subtract(beforDT);
        //Debug.Log("DateTime总共花费" + ts.TotalMilliseconds);

        // 1. 构造 AABB
        InitMesh(mrs);
        CalculateAABB();

        // 2. 构造 Morton Code
        CalculateMortonCode();

        // 3. 基数排序Radix Sort，适合并行计算的排序算法
        CalculateRadixSort();

        //initializationIsDone = true;
    }

    // 1. 构造 AABB
    void InitMesh(MeshRenderer[] mrs)
    {
        indices.Clear();
        vertices.Clear();

        int indexOffset = 0;
        encompassingAABB = mrs[0].bounds;

        // 1.0 create triangle structure
        foreach (MeshRenderer mr in mrs)
        {
            Mesh m = mr.GetComponent<MeshFilter>().sharedMesh;
            var _indices = m.triangles.Select(i => i + indexOffset);
            // world space tri verts
            var _vertices = m.vertices.Select(v => mr.transform.TransformPoint(v));

            indices.AddRange(_indices);
            vertices.AddRange(_vertices);

            // index offsets
            indexOffset += m.vertices.Length;
            encompassingAABB.min = Vector3.Min(encompassingAABB.min, m.bounds.min);
            encompassingAABB.max = Vector3.Max(encompassingAABB.max, m.bounds.max);
        }

        int vertexCount = vertices.Count;
        int indexCount = indices.Count;
        triangleCount = indexCount / 3;
    }

    void CalculateAABB()
    {
        kernelCalculateAABB = cs.FindKernel("CalculateAABB");

        // Byte Address Buffer, 读写的时候，把buffer里的内容（byte）做偏移，可用于寻址
        // 对应的是HLSL的ByteAddressBuffer，RWByteAddressBuffer
        // 4 (32-bit indices)
        // IndexFormat.UInt16: 2 byte, 范围 0～65535 
        // IndexFormat.UInt32: 4 byte, 范围 0～4294967295 
        indexBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Index | GraphicsBuffer.Target.Raw, indices.Count, sizeof(int));
        indexBuffer.SetData(indices);

        vertexBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Vertex | GraphicsBuffer.Target.Raw, vertices.Count, 3 * sizeof(float));
        vertexBuffer.SetData(vertices);

        aabbBuffer = new ComputeBuffer(triangleCount, 6 * sizeof(float));
        triangleIndexBuffer = new ComputeBuffer(triangleCount, sizeof(uint));

        // 传递buffer
        cs.SetBuffer(kernelCalculateAABB, "indexBuffer", indexBuffer);
        cs.SetBuffer(kernelCalculateAABB, "vertexBuffer", vertexBuffer);
        cs.SetBuffer(kernelCalculateAABB, "aabbBuffer", aabbBuffer);
        cs.SetBuffer(kernelCalculateAABB, "triangleIndexBuffer", triangleIndexBuffer);

        DispatchThreads(kernelCalculateAABB, triangleCount);
    }

    // 2. 计算 MortonCode
    void CalculateMortonCode()
    {
        kernelCalculateMortonCode = cs.FindKernel("CalculateMortonCode");

        mortonCodeBuffer = new ComputeBuffer(triangleCount, sizeof(uint));

        cs.SetVector("encompassingAABBMin", new Vector3( encompassingAABB.min.x, encompassingAABB.min.y, encompassingAABB.min.z));
        cs.SetVector("encompassingAABBMax", new Vector3( encompassingAABB.max.x, encompassingAABB.max.y, encompassingAABB.max.z));
        cs.SetBuffer(kernelCalculateMortonCode, "aabbBuffer", aabbBuffer);
        cs.SetBuffer(kernelCalculateMortonCode, "mortonCodeBuffer", mortonCodeBuffer);

        DispatchThreads(kernelCalculateMortonCode, triangleCount);

        //uint[] tests = new uint[triangleCount];
        //mortonCodeBuffer.GetData(tests);

    }

    // 3. 排序
    void CalculateRadixSort()
    {
        ComputeBufferSorter sorter = new ComputeBufferSorter(
            triangleCount,
            mortonCodeBuffer,
            triangleIndexBuffer,
            localRadixSortShader,
            globalRadixSortShader,
            scanShader);

        sorter.Sort();
        sorter.GetSortedDataBack(out uint[] sortedMortonCodes, out uint[] sortedTriangleIndices);

        sorter.Dispose();
    }

    void DispatchThreads(int kernel, int count)
    {
        //cs.GetKernelThreadGroupSizes(kernel, out uint threadGroupSize, out _, out _);
        //int groups = Mathf.CeilToInt(count / (float)threadGroupSize);
        int groups = Mathf.CeilToInt(count / 256f);
        cs.Dispatch(kernel, groups, 1, 1);
    }

    #region Debug Start
    //struct AABB
    //{
    //    public Vector3 min;
    //    public Vector3 max;
    //};

    //private void OnDrawGizmos()
    //{
    //    if (aabbBuffer == null)
    //        return;

    //    AABB[] aabbs = new AABB[triangleCount];
    //    aabbBuffer.GetData(aabbs);

    //    Gizmos.color = Color.green;
    //    foreach (AABB aabb in aabbs)
    //    {
    //        Vector3 center = (aabb.min + aabb.max) / 2;
    //        Vector3 size = aabb.max - aabb.min;
    //        Gizmos.DrawWireCube(center, size);
    //    }
    //}
    #endregion
}
