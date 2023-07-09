using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class BVH : MonoBehaviour
{
    // 0. 大致框架
    public Transform meshParent;

    public ComputeShader meshShader;
    public ComputeShader localRadixSortShader;
    public ComputeShader globalRadixSortShader;
    public ComputeShader scanShader;
    public ComputeShader bvhShader;

    ComputeShader rayTracingShader;
    int kernelHandle;
    public enum DebugDataType
    {
        None,
        AABB,
        BeforeSort,
        AfterSort,
        BVH
    }
    public DebugDataType debugDataType = DebugDataType.None;
    public int debugDepth = 1;

    public Mesh mesh;

    MeshBufferContainer _container;
    ComputeBufferSorter<uint, uint> _sorter;
    BVHConstructor _bvhConstructor;

    struct MeshVertex
    {
        public Vector3 position;
        public Vector3 normal;
        public Vector3 tangent;
        public Vector2 uv;
    }

    public void Init(ComputeShader shader, int handle)
    {
        rayTracingShader = shader;
        kernelHandle = handle;

        MeshRenderer[] mrs = meshParent.GetComponentsInChildren<MeshRenderer>(false);
        
        // 构造BVH的基本流程：1. 构造ZOrder Curve & Morton Code 2. 排序 3 构造子节点 4 构造内部节点 5 更新AABB
        // http://ma-yidong.com/2018/11/10/construct-bvh-with-unity-job-system/

        System.DateTime beforeDT = System.DateTime.Now;

        // 1. 构造 AABB
        InitMesh(mrs, out mesh, out List<int> materialIndices, out List<Material> materials);
        _container = new MeshBufferContainer(mesh);

        // 2. 构造 AABB, Morton Code
        MeshData.Calculate(_container.TrianglesLength,
            _container.VertexBuffer,
            _container.IndexBuffer,
            _container.Keys,
            _container.TriangleIndex,
            _container.TriangleAABB,
            _container.TriangleData,
            _container.Bounds,
            materialIndices,
            meshShader);

        Debug.Log("Before BVH");
        //_container.GetAllGpuData();
        //_container.PrintData();

        // 3. 基数排序Radix Sort，适合并行计算的排序算法
        _sorter = new ComputeBufferSorter<uint, uint>(_container.TrianglesLength, 
            _container.Keys, 
            _container.TriangleIndex,
            localRadixSortShader,
            globalRadixSortShader,
            scanShader);
        _sorter.Sort();

        _container.DistributeKeys();

        // 4. 构造BVH
        _bvhConstructor = new BVHConstructor(_container.TrianglesLength,
            _container.Keys,
            _container.TriangleIndex,
            _container.TriangleAABB,
            _container.BvhInternalNode,
            _container.BvhLeafNode,
            _container.BvhData,
            bvhShader);

        _bvhConstructor.ConstructTree();
        _bvhConstructor.ConstructBVH();

        Debug.Log("After BVH");
        _container.GetAllGpuData();
        //_container.PrintData();

        System.DateTime afterDT = System.DateTime.Now;
        System.TimeSpan ts = afterDT.Subtract(beforeDT);
        Debug.Log("BVH spent: " + ts.TotalMilliseconds);

        // 5. 开始渲染
        rayTracingShader.SetBuffer(kernelHandle, "sortedTriangleIndices", _container.TriangleIndex);
        rayTracingShader.SetBuffer(kernelHandle, "triangleAABB", _container.TriangleAABB);
        rayTracingShader.SetBuffer(kernelHandle, "internalNodes", _container.BvhInternalNode);
        rayTracingShader.SetBuffer(kernelHandle, "leafNodes", _container.BvhLeafNode);
        rayTracingShader.SetBuffer(kernelHandle, "bvhData", _container.BvhData);
        rayTracingShader.SetBuffer(kernelHandle, "triangleData", _container.TriangleData);
    }

    // 1. 构造 AABB
    void InitMesh(MeshRenderer[] mrs, out Mesh mesh, out List<int> materialIndices, out List<Material> materials)
    {
        List<int> indices = new List<int>();
        List<Vector3> vertices = new List<Vector3>();
        List<Vector3> normals = new List<Vector3>();
        List<Vector3> tangents = new List<Vector3>();
        List<Vector2> uvs = new List<Vector2>();

        // 处理材质
        materialIndices = new List<int>();    // 这里存贮的是每一个顶点的材质id
        materials = new List<Material>();

        int indexOffset = 0;
        int materialIndex = 0;
        Bounds encompassingAABB = mrs[0].bounds;

        // 1.0 create triangle structure
        foreach (MeshRenderer mr in mrs)
        {
            Mesh m = mr.GetComponent<MeshFilter>().sharedMesh;
            var _indices = m.triangles.Select(i => i + indexOffset);
            // world space tri verts
            var _vertices = m.vertices.Select(v => mr.transform.TransformPoint(v));
            // world space tri nromals
            var _normals = m.normals.Select(n => mr.transform.TransformVector(n));
            // world space tri tangents
            var _tangents = m.tangents.Select(t => mr.transform.TransformVector(t));
            var _uvs = m.uv;

            indices.AddRange(_indices);
            vertices.AddRange(_vertices);
            normals.AddRange(_normals);
            tangents.AddRange(_tangents);
            uvs.AddRange(_uvs);

            // 处理材质
            Material mat = mr.material;
            if (materials.Contains(mat))
            {
                int index = materials.IndexOf(mat);
                materialIndices.AddRange(m.triangles.Select(i => index));
            }
            else
            {
                materialIndices.AddRange(m.triangles.Select(i => materialIndex));

                materials.Add(mat);
                materialIndex += 1;
            }

            // index offsets
            indexOffset += m.vertices.Length;

            encompassingAABB.min = Vector3.Min(encompassingAABB.min, m.bounds.min);
            encompassingAABB.max = Vector3.Max(encompassingAABB.max, m.bounds.max);
        }

        int vertexCount = vertices.Count;
        int indexCount = indices.Count;

        // 创建一个新的mesh
        mesh = new Mesh();

        // Byte Address Buffer, 读写的时候，把buffer里的内容（byte）做偏移，可用于寻址
        // 对应的是HLSL的ByteAddressBuffer，RWByteAddressBuffer
        mesh.indexBufferTarget |= GraphicsBuffer.Target.Raw;
        mesh.vertexBufferTarget |= GraphicsBuffer.Target.Raw;

        // Vertex position: float32 x 3
        VertexAttributeDescriptor pDesc = new VertexAttributeDescriptor(VertexAttribute.Position, VertexAttributeFormat.Float32, 3);
        // Vertex normal: float32 x 3
        VertexAttributeDescriptor nDesc = new VertexAttributeDescriptor(VertexAttribute.Normal, VertexAttributeFormat.Float32, 3);
        // Vertex tangent: float32 x 3
        VertexAttributeDescriptor tDesc = new VertexAttributeDescriptor(VertexAttribute.Tangent, VertexAttributeFormat.Float32, 3);
        // Vertex uv: float32 x 2
        VertexAttributeDescriptor uvDesc = new VertexAttributeDescriptor(VertexAttribute.TexCoord0, VertexAttributeFormat.Float32, 2);

        mesh.SetVertexBufferParams(vertexCount, pDesc, nDesc, tDesc, uvDesc);
        // IndexFormat.UInt16: 2 byte, 范围 0～65535 
        // IndexFormat.UInt32: 4 byte, 范围 0～4294967295 
        mesh.SetIndexBufferParams(indexCount, IndexFormat.UInt32);
        // 保证传参是 MeshUpdateFlags.DontRecalculateBounds
        mesh.SetSubMesh(0, new SubMeshDescriptor(0, indexCount), MeshUpdateFlags.DontRecalculateBounds);

        // 开始传递顶点索引
        mesh.SetIndexBufferData(indices, 0, 0, indexCount);

        // 开始传递顶点缓存
        MeshVertex[] vertexArray = new MeshVertex[vertexCount];
        for (var i = 0; i < vertexCount; ++i)
        {
            vertexArray[i].position = vertices[i];
            vertexArray[i].normal = normals[i];
            vertexArray[i].tangent = tangents[i];
            vertexArray[i].uv = uvs[i];
        }
        mesh.SetVertexBufferData(vertexArray, 0, 0, vertexCount);

        mesh.bounds = encompassingAABB;
    }

    private void OnDestroy()
    {
        _sorter?.Dispose();
        _container?.Dispose();
        _bvhConstructor?.Dispose();
    }

    #region Debug
    private void DrawAABB(AABB aabb, float scale = 1.0f)
    {
        Gizmos.DrawWireCube((aabb.min + aabb.max) / 2, (aabb.max - aabb.min) * scale);
    }

    private void OnDrawGizmos()
    {
        switch (debugDataType)
        {
            case DebugDataType.AABB:
                {
                    Gizmos.color = Color.green;

                    for (int i = 0; i < _container.TrianglesLength; i++)
                    {
                        AABB aabb = _container.TriangleAABBLocalData[i];
                        DrawAABB(aabb);
                    }
                }
                break;
            case DebugDataType.BeforeSort:
            case DebugDataType.AfterSort:
                {
                    Vector3[] vertices = new Vector3[_container.VertexBuffer.count];
                    _container.VertexBuffer.GetData(vertices);
                    int[] triangles = new int[_container.IndexBuffer.count];
                    _container.IndexBuffer.GetData(triangles);

                    List<int[]> values = new List<int[]>();
                    for (int i = 0; i < triangles.Length; i += 3)
                        values.Add(new int[3] { triangles[i], triangles[i + 1], triangles[i + 2] });

                    Vector3 start = Vector3.zero;
                    if (debugDataType == DebugDataType.BeforeSort)
                    {
                        for (int i = 0; i < values.Count; ++i)
                        {
                            int i0 = values[i][0];
                            int i1 = values[i][1];
                            int i2 = values[i][2];

                            Vector3 v0 = vertices[i0];
                            Vector3 v1 = vertices[i1];
                            Vector3 v2 = vertices[i2];
                            Vector3 center = (v0 + v1 + v2) / 3;

                            Gizmos.DrawLine(center, start);
                            start = center;

                            //if (i >= debugTriangleIndexRange.x && i <= debugTriangleIndexRange.y)
                            //{
                            //    UnityEditor.Handles.Label(center, i.ToString());
                            //}
                        }
                    }
                    else
                    {
                        uint[] sortedValues = _container.ValuesData;

                        for (int i = 0; i < sortedValues.Length; ++i)
                        {
                            int i0 = values[(int)sortedValues[i]][0];
                            int i1 = values[(int)sortedValues[i]][1];
                            int i2 = values[(int)sortedValues[i]][2];

                            Vector3 v0 = vertices[i0];
                            Vector3 v1 = vertices[i1];
                            Vector3 v2 = vertices[i2];
                            Vector3 center = (v0 + v1 + v2) / 3;

                            Gizmos.DrawLine(center, start);
                            start = center;
                            //if (i >= debugTriangleIndexRange.x && i <= debugTriangleIndexRange.y)
                            //{
                            //    UnityEditor.Handles.Label(center, i.ToString());
                            //}
                        }
                        //after = string.Empty;
                        //foreach (uint code in sortedValues)
                        //    after += code.ToString() + ", ";
                        //Debug.Log("after value: " + after);
                    }
                }
                break;
            case DebugDataType.BVH:
                {
                    uint[] stack = new uint[64];
                    uint currentStackIndex = 0;
                    stack[currentStackIndex] = 0;
                    currentStackIndex = 1;

                    int depthLeft = 0;
                    int depthRight = 0;
                    int depthMax = 10;

                    while (currentStackIndex != 0)
                    {
                        currentStackIndex--;
                        uint index = stack[currentStackIndex];
                        InternalNode internalNode = _container.BvhInternalNodeLocalData[index];

                        uint leftIndex = internalNode.leftNode;
                        uint leftType = internalNode.leftNodeType;

                        if (leftType == 0) // INTERNAL_NODE
                        {
                            stack[currentStackIndex] = leftIndex;
                            currentStackIndex++;

                            AABB leftAABB = _container.BVHLocalData[leftIndex];
                            Gizmos.color = Color.Lerp(Color.red * 0.25f, Color.red, (float)depthLeft / depthMax);
                            
                            if (depthLeft < debugDepth)
                                DrawAABB(leftAABB);

                            depthLeft += 1;

                        }

                        uint rightIndex = internalNode.rightNode;
                        uint rightType = internalNode.rightNodeType;

                        if (rightType == 0)// INTERNAL_NODE
                        {
                            stack[currentStackIndex] = rightIndex;
                            currentStackIndex++;


                            AABB rightAABB = _container.BVHLocalData[rightIndex];
                            Gizmos.color = Color.Lerp(Color.green * 0.25f, Color.green, (float)depthRight / depthMax);
                            
                            if (depthRight < debugDepth)
                                DrawAABB(rightAABB);

                            depthRight += 1;
                        }
                    }
                    //{
                    //    List<int[]> values = new List<int[]>();
                    //    for (int i = 0; i < _container.Triangles.Length; i += 3)
                    //        values.Add(new int[3] { _container.Triangles[i], _container.Triangles[i + 1], _container.Triangles[i + 2] });

                    //    Vector3 start = Vector3.zero;

                    //    uint[] sortedValues = _container.ValuesData;

                    //    for (int i = 0; i < sortedValues.Length; ++i)
                    //    {
                    //        int i0 = values[(int)sortedValues[i]][0];
                    //        int i1 = values[(int)sortedValues[i]][1];
                    //        int i2 = values[(int)sortedValues[i]][2];

                    //        Vector3 v0 = _container.Vertices[i0];
                    //        Vector3 v1 = _container.Vertices[i1];
                    //        Vector3 v2 = _container.Vertices[i2];
                    //        Vector3 center = (v0 + v1 + v2) / 3;

                    //        Gizmos.color = Color.white;
                    //        Gizmos.DrawLine(center, start);
                    //        start = center;
                    //    }
                    //}
                }
                break;
        }
    }
    #endregion
}
