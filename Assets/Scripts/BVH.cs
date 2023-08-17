using System.Linq;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

public class BVH : MonoBehaviour
{
    ////////////// chapter4_3 //////////////
    public Transform meshParent;
    public ComputeShader meshDataShader;
    public Mesh mesh;

    ComputeShader rayTracingShader;
    int kernelHandle;

    struct MeshVertex
    {
        public Vector3 position;
        public Vector3 normal;
        public Vector3 tangent;
        public Vector2 uv;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MaterialData
    {
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public float transparent;
        public Vector3 emissionColor;
        public uint materialType;           // 0: default opacity, 1: transparent, 2: emission, 3: clear coat  

        public MaterialData(Material mat)
        {
            albedo = new Vector3(mat.color.linear.r, mat.color.linear.g, mat.color.linear.b);
            metallic = Mathf.Max(0.01f, mat.GetFloat("_Metallic"));
            smoothness = Mathf.Max(0.01f, mat.GetFloat("_Glossiness"));
            transparent = -1;
            emissionColor = Vector3.zero;
            materialType = 0;

            if ((int)(mat.GetFloat("_Mode")) == 3)
            {
                transparent = mat.color.linear.a;
                materialType = 1;
            }

            if (mat.IsKeywordEnabled("_EMISSION"))
            {
                Color color = mat.GetColor("_EmissionColor");
                emissionColor = new Vector3(color.r, color.g, color.b);
                materialType = 2;
            }

            //if (mat.name.ToLower().Contains("_paint_"))
            //{
            //    materialType = 3;
            //}
        }
    }

    ComputeBuffer materialDataBuffer;
    MeshBufferContainer container;

    ////////////// chapter4_4 //////////////
    public enum DebugDataType
    {
        None,
        AABB,
        MortonCode,
        BeforeSort,
        AfterSort,
        BVH
    }
    public DebugDataType debugDataType = DebugDataType.None;
    public int debugDepth = 1;

    public ComputeShader localRadixSortShader;
    public ComputeShader globalRadixSortShader;
    public ComputeShader scanShader;
    public ComputeShader bvhShader;

    ComputeBufferSorter<uint, uint> sorter;
    BVHConstructor bvhConstructor;

    ////////////// chapter4_4 //////////////
    uint[] debugBeforeSortTriangleIndice;
    uint[] debugAfterSortTriangleIndice;

    ////////////// chapter4_3 //////////////
    public void Init(ComputeShader shader, int handle)
    {
        rayTracingShader = shader;
        kernelHandle = handle;

        MeshRenderer[] mrs = (from mr in meshParent.GetComponentsInChildren<MeshRenderer>(false) where mr.enabled && mr.gameObject.activeInHierarchy select mr).ToArray();

        // 构造BVH的基本流程：1. 构造ZOrder Curve & Morton Code 2. 排序 3 构造子节点 4 构造内部节点 5 更新AABB
        // http://ma-yidong.com/2018/11/10/construct-bvh-with-unity-job-system/

        //System.DateTime beforeDT = System.DateTime.Now;

        // 构造 Mesh
        InitMesh(mrs, out mesh, out List<uint> materialIndices, out List<Material> materials, out List<Vector2Int> shadowIndices);
        // 收集材质球
        InitMaterialData(materials);

        container = new MeshBufferContainer(mesh, materialIndices, shadowIndices);

        ////////////// chapter4_4 //////////////
        // 构造 AABB, Morton Code
        MeshData.Calculate(container.trianglesLength,
            container.vertexBuffer,
            container.indexBuffer,
            container.mortonCodeBuffer,
            container.triangleIndexBuffer,
            container.triangleAABBBuffer,
            container.triangleDataBuffer,
            container.materialIndexBuffer,
            container.shadowIndexBuffer,
            container.bounds,
            meshDataShader);

        //Debug.Log("Before BVH");
        ////container.GetAllGpuData();
        ////container.PrintData();

        ////////////// chapter4_5 //////////////
        //// 基数排序Radix Sort，适合并行计算的排序算法 https://github.com/drzhn/UnityGpuCollisionDetection
        debugBeforeSortTriangleIndice = new uint[container.triangleIndexBuffer.count];
        container.triangleIndexBuffer.GetData(debugBeforeSortTriangleIndice);
        Debug.Log("Before Radix Sort:\n" + ArrayToString(debugBeforeSortTriangleIndice));

        sorter = new ComputeBufferSorter<uint, uint>(container.trianglesLength,
            container.mortonCodeBuffer,
            container.triangleIndexBuffer,
            localRadixSortShader,
            globalRadixSortShader,
            scanShader);
        sorter.Sort();
        container.DistributeMortonCode();

        debugAfterSortTriangleIndice = new uint[container.triangleIndexBuffer.count];
        container.triangleIndexBuffer.GetData(debugAfterSortTriangleIndice);
        Debug.Log("After Radix Sort:\n" + ArrayToString(debugAfterSortTriangleIndice));

        ////////////// chapter4_6 //////////////
        //// 构造BVH
        bvhConstructor = new BVHConstructor(container.trianglesLength,
            container.mortonCodeBuffer,
            container.triangleIndexBuffer,
            container.triangleAABBBuffer,
            container.bvhInternalNodeBuffer,
            container.bvhLeafNodeBuffer,
            container.bvhDataBuffer,
            bvhShader);

        bvhConstructor.ConstructTree();
        bvhConstructor.ConstructBVH();

        //Debug.Log("After BVH");
        ////container.PrintData();

        ////System.DateTime afterDT = System.DateTime.Now;
        ////System.TimeSpan ts = afterDT.Subtract(beforeDT);
        ////Debug.Log("BVH spent: " + ts.TotalMilliseconds);

        ////Debug.Log("TriangleAABB stride: " + container.TriangleAABB.stride);
        ////Debug.Log("TriangleAABB count: " + container.TriangleAABB.count);
        ////AABB[] aabbs = new AABB[container.TriangleAABB.count];
        ////container.TriangleAABB.GetData(aabbs);
        ////for (int i = 0; i < container.TriangleAABB.count; ++i)
        ////    Debug.Log(aabbs[i].ToString());

        ////////////// chapter4_7 //////////////
        rayTracingShader.SetBuffer(kernelHandle, "sortedTriangleIndexBuffer", container.triangleIndexBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "triangleAABBBuffer", container.triangleAABBBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "bvhInternalNodeBuffer", container.bvhInternalNodeBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "bvhLeafNodeBuffer", container.bvhLeafNodeBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "bvhDataBuffer", container.bvhDataBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "triangleDataBuffer", container.triangleDataBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "materialDataBuffer", materialDataBuffer);
    }

    // 1. 构造 AABB
    void InitMesh(MeshRenderer[] mrs, out Mesh mesh, out List<uint> materialIndices, out List<Material> materials, out List<Vector2Int> shadowIndices)
    {
        List<int> indices = new List<int>();
        List<Vector3> vertices = new List<Vector3>();
        List<Vector3> normals = new List<Vector3>();
        List<Vector3> tangents = new List<Vector3>();
        List<Vector2> uvs = new List<Vector2>();

        // 处理材质
        materialIndices = new List<uint>();    // 这里存贮的是每一个三角面的材质id
        materials = new List<Material>();

        // 处理阴影
        shadowIndices = new List<Vector2Int>();   // 这里存贮的是每一个三角面的cast/receive shadow

        int indexOffset = 0;
        uint materialIndex = 0;
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
            // 得到所有的三角面，而不是所有顶点
            int[] polygons = m.triangles.Where((value, index) => index % 3 == 0).ToArray();
            Material mat = mr.sharedMaterial;
            if (materials.Contains(mat))
            {
                uint index = (uint)materials.IndexOf(mat);
                materialIndices.AddRange(polygons.Select(i => index));
            }
            else
            {
                materialIndices.AddRange(polygons.Select(i => materialIndex));

                materials.Add(mat);
                materialIndex += 1;
            }

            // 处理阴影
            shadowIndices.AddRange(polygons.Select(i => new Vector2Int(mr.shadowCastingMode == ShadowCastingMode.On ? 1 : 0, 
                                                                       mr.receiveShadows ? 1 : 0)));

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

    void InitMaterialData(List<Material> materials)
    {
        MaterialData[] datas = (from m in materials select new MaterialData(m)).ToArray();
        materialDataBuffer = new ComputeBuffer(materials.Count, Marshal.SizeOf(typeof(MaterialData)));
        materialDataBuffer.SetData(datas);
    }

    private void OnDestroy()
    {
        ////////////// chapter4_3 //////////////
        materialDataBuffer?.Dispose();
        container?.Dispose();

        ////////////// chapter4_4 //////////////
        sorter?.Dispose();
        bvhConstructor?.Dispose();
    }

    ////////////// chapter4_5 //////////////
    StringBuilder ArrayToString<T>(T[] array, uint maxElements = 4096)
    {
        StringBuilder builder = new StringBuilder("");
        for (var i = 0; i < array.Length; i++)
        {
            if (i >= maxElements) break;
            builder.Append(array[i] + " ");
        }

        return builder;
    }

    ////////////// chapter4_4 //////////////
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
            case DebugDataType.MortonCode:
                {
                    AABB[] aabbs = new AABB[container.trianglesLength];
                    container.triangleAABBBuffer.GetData(aabbs);

                    if (debugDataType == DebugDataType.MortonCode)
                    {
                        uint[] mortonCodes = new uint[container.trianglesLength];
                        container.mortonCodeBuffer.GetData(mortonCodes);

                        //Dictionary<int, uint> di = mortonCodes.ToDictionary(key => System.Array.IndexOf(mortonCodes, key), key => key);
                        Dictionary<int, uint> di = new Dictionary<int, uint>();
                        for (int i = 0; i < mortonCodes.Length; ++i)
                            di.Add(i, mortonCodes[i]);
                        //di = di.OrderBy(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

                        Vector3 fromPos = Vector3.zero;
                        foreach (KeyValuePair<int, uint> kvp in di)
                        {
                            Gizmos.color = Color.green;
                            DrawAABB(aabbs[kvp.Key]);

                            Vector3 toPos = (aabbs[kvp.Key].min + aabbs[kvp.Key].max) / 2;
                            if (fromPos != Vector3.zero)
                                UnityEditor.Handles.DrawLine(fromPos, toPos);
                            fromPos = toPos;
                            
                            Gizmos.color = Color.white;
                            UnityEditor.Handles.Label(toPos, kvp.Value.ToString());
                        }
                    }
                    else
                    {
                        Gizmos.color = Color.green;

                        for (int i = 0; i < container.trianglesLength; i++)
                            DrawAABB(aabbs[i]);
                    }

                }
                break;
            case DebugDataType.BeforeSort:
            case DebugDataType.AfterSort:
                {
                    MeshVertex[] vertices = new MeshVertex[container.vertexBuffer.count];
                    container.vertexBuffer.GetData(vertices);
                    int[] triangles = new int[container.indexBuffer.count];
                    container.indexBuffer.GetData(triangles);

                    List<int[]> values = new List<int[]>();
                    for (int i = 0; i < triangles.Length; i += 3)
                        values.Add(new int[3] { triangles[i], triangles[i + 1], triangles[i + 2] });

                    Vector3 fromPos = Vector3.zero;
                    if (debugDataType == DebugDataType.BeforeSort)
                    {
                        for (int i = 0; i < values.Count; ++i)
                        {
                            int i0 = values[i][0];
                            int i1 = values[i][1];
                            int i2 = values[i][2];

                            Vector3 v0 = vertices[i0].position;
                            Vector3 v1 = vertices[i1].position;
                            Vector3 v2 = vertices[i2].position;
                            Vector3 toPos = (v0 + v1 + v2) / 3;

                            Gizmos.color = Color.white;
                            Gizmos.DrawLine(fromPos, toPos);
                            Gizmos.color = Color.green;
                            UnityEditor.Handles.Label(toPos + new Vector3(0, 1, 0), i.ToString());
                            fromPos = toPos;

                            //if (i >= debugTriangleIndexRange.x && i <= debugTriangleIndexRange.y)
                            //{
                            //    UnityEditor.Handles.Label(center, i.ToString());
                            //}
                        }
                    }
                    else
                    {
                        uint[] sortedValues = new uint[container.triangleIndexBuffer.count];
                        container.triangleIndexBuffer.GetData(sortedValues);

                        Vector3 min = Vector3.one * float.MaxValue;
                        Vector3 max = Vector3.one * float.MinValue;

                        int clusterIndex = 0;
                        for (int i = 0; i < sortedValues.Length; ++i)
                        {
                            int i0 = values[(int)sortedValues[i]][0];
                            int i1 = values[(int)sortedValues[i]][1];
                            int i2 = values[(int)sortedValues[i]][2];

                            Vector3 v0 = vertices[i0].position;
                            Vector3 v1 = vertices[i1].position;
                            Vector3 v2 = vertices[i2].position;
                            Vector3 toPos = (v0 + v1 + v2) / 3;

                            Gizmos.color = Color.white;
                            Gizmos.DrawLine(fromPos, toPos);
                            Gizmos.color = Color.green;
                            UnityEditor.Handles.Label(toPos + new Vector3(0, 1, 0), sortedValues[i].ToString());
                            fromPos = toPos;

                            if (i % Constants.RADIX != 0)
                            {
                                min = Vector3.Min(min, Vector3.Min(v0, Vector3.Min(v1, v2)));
                                max = Vector3.Max(max, Vector3.Max(v0, Vector3.Max(v1, v2)));
                            }
                            else
                            {
                                Vector3 center = (min + max) / 2;
                                Gizmos.DrawWireCube(center, max - min);
                                UnityEditor.Handles.Label(center, "cluster index: " + clusterIndex.ToString());

                                min = Vector3.one * float.MaxValue;
                                max = Vector3.one * float.MinValue;

                                clusterIndex += 1;
                            }
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

                    InternalNode[] internalNodes = new InternalNode[container.bvhInternalNodeBuffer.count];
                    container.bvhInternalNodeBuffer.GetData(internalNodes);
                    
                    AABB[] aabbs = new AABB[container.bvhDataBuffer.count];
                    container.bvhDataBuffer.GetData(aabbs);
                    while (currentStackIndex != 0)
                    {
                        currentStackIndex--;
                        uint index = stack[currentStackIndex];
                        InternalNode internalNode = internalNodes[index];

                        uint leftIndex = internalNode.leftNode;
                        uint leftType = internalNode.leftNodeType;

                        if (leftType == 0) // INTERNAL_NODE
                        {
                            stack[currentStackIndex] = leftIndex;
                            currentStackIndex++;

                            AABB leftAABB = aabbs[leftIndex];
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

                            AABB rightAABB = aabbs[rightIndex];
                            Gizmos.color = Color.Lerp(Color.green * 0.25f, Color.green, (float)depthRight / depthMax);

                            if (depthRight < debugDepth)
                                DrawAABB(rightAABB);

                            depthRight += 1;
                        }
                    }
                    //{
                    //    List<int[]> values = new List<int[]>();
                    //    for (int i = 0; i < container.Triangles.Length; i += 3)
                    //        values.Add(new int[3] { container.Triangles[i], container.Triangles[i + 1], container.Triangles[i + 2] });

                    //    Vector3 start = Vector3.zero;

                    //    uint[] sortedValues = container.ValuesData;

                    //    for (int i = 0; i < sortedValues.Length; ++i)
                    //    {
                    //        int i0 = values[(int)sortedValues[i]][0];
                    //        int i1 = values[(int)sortedValues[i]][1];
                    //        int i2 = values[(int)sortedValues[i]][2];

                    //        Vector3 v0 = container.Vertices[i0];
                    //        Vector3 v1 = container.Vertices[i1];
                    //        Vector3 v2 = container.Vertices[i2];
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
