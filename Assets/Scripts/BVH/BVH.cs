using System.Linq;
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

    struct MeshVertex
    {
        public Vector3 position;
        public Vector3 normal;
        public Vector3 tangent;
        public Vector2 uv;
    }
    MeshBufferContainer container;

    [StructLayout(LayoutKind.Sequential)]
    struct MaterialData
    {
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public float transparent;
        public Vector3 emissionColor;
        // 使用标记位来区分不同材质, 0：default opacity, 1: transparent, 2: emission, 3: clear coat, 4: matte mask
        public uint materialType;
        ////////////// chapter6_5 //////////////
        public float ior;
        public Vector3 clearCoatColor;

        public MaterialData(Material mat)
        {
            albedo = new Vector3(mat.color.linear.r, mat.color.linear.g, mat.color.linear.b);
            metallic = Mathf.Max(0.01f, mat.GetFloat("_Metallic"));
            smoothness = Mathf.Max(0.01f, mat.GetFloat("_Glossiness"));
            transparent = -1;
            emissionColor = Vector3.zero;
            clearCoatColor = Vector3.zero;

            ////////////// chapter6_5 //////////////
            if (mat.HasProperty("_MaterialType"))
                materialType = (uint)(mat.GetFloat("_MaterialType"));
            else
                materialType = 0;

            if (mat.HasProperty("_IOR"))
                ior = mat.GetFloat("_IOR");
            else
                ior = 1f;

            if (mat.HasProperty("_ClearCoatColor") && materialType == 3)
            {
                Color col = mat.GetColor("_ClearCoatColor");
                clearCoatColor = new Vector3(col.r, col.g, col.b);
            }

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
        }
    }
    ComputeBuffer materialDataBuffer;

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

    ////////////// chapter4_5 //////////////
    public ComputeShader localRadixSortShader;
    public ComputeShader globalRadixSortShader;
    public ComputeShader scanShader;
    ComputeBufferSorter<uint, uint> sorter;

    ////////////// chapter4_6 //////////////
    public ComputeShader bvhShader;
    public int debugDepth = 1;
    BVHConstructor bvhConstructor;

    ////////////// chapter6_5 //////////////
    ComputeShader rayTracingShader;
    int kernelHandle;

    ////////////// chapter4_3 //////////////
    public void Init(ComputeShader shader, int handle, int kernelHandleShadowMap = -1)
    {
        ////////////// chapter4_7 //////////////
        /// 测试BVH的开销
        //System.DateTime beforeDT = System.DateTime.Now;

        ////////////// chapter6_5 //////////////
        rayTracingShader = shader;
        kernelHandle = handle;

        // 1. 初始化 mesh 数据
        InitMesh(out mesh, out List<uint> materialIndices, out List<Material> materials, out List<Vector2Int> shadowIndices);

        // 2. 初始化 材质 数据
        InitMaterialData(materials);

        // 3. 使用 mesh buffer container来存贮mesh相关数据
        container = new MeshBufferContainer(mesh, materialIndices, shadowIndices);

        ////////////// chapter4_4 //////////////
        MeshData.Calculate(meshDataShader, 
            container.trianglesLength,
            container.bounds,
            container.vertexBuffer,
            container.indexBuffer,
            container.materialIndexBuffer,  
            container.shadowIndexBuffer,
    /*out */container.triangleAABBBuffer,
    /*out */container.triangleDataBuffer,
    /*out */container.triangleIndexBuffer,
    /*out */container.mortonCodeBuffer);

        // Debug data
        //Debug.Log("Before Radix Sort:\n");
        //container.PrintData();

        ////////////// chapter4_5 //////////////
        // 使用GPU版本的基数排序
        sorter = new ComputeBufferSorter<uint, uint>(container.trianglesLength,
            container.mortonCodeBuffer,
            container.triangleIndexBuffer,
            localRadixSortShader,
            globalRadixSortShader,
            scanShader);
        sorter.Sort();
        sorter.Dispose();
        container.DistributeMortonCode();
        //Debug.Log("After Radix Sort:\n");
        //container.PrintData();

        ////////////// chapter4_6 //////////////
        bvhConstructor = new BVHConstructor(container.trianglesLength,
            bvhShader,
            container.mortonCodeBuffer,
            container.triangleIndexBuffer,
            container.triangleAABBBuffer,
            /*out*/container.bvhInternalNodeBuffer,
            /*out*/container.bvhLeafNodeBuffer,
            /*out*/container.bvhDataBuffer);

        bvhConstructor.ConstructTree();
        bvhConstructor.ConstructBVH();
        bvhConstructor.Dispose();

        ////////////// chapter4_7 //////////////
        ///// 测试BVH的开销
        //System.DateTime afterDT = System.DateTime.Now;
        //System.TimeSpan ts = afterDT.Subtract(beforeDT);
        //Debug.Log("BVH spent: " + ts.TotalMilliseconds);

        ////////////// chapter4_7 //////////////
        rayTracingShader.SetBuffer(kernelHandle, "sortedTriangleIndexBuffer", container.triangleIndexBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "triangleAABBBuffer", container.triangleAABBBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "bvhInternalNodeBuffer", container.bvhInternalNodeBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "bvhLeafNodeBuffer", container.bvhLeafNodeBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "bvhDataBuffer", container.bvhDataBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "triangleDataBuffer", container.triangleDataBuffer);
        rayTracingShader.SetBuffer(kernelHandle, "materialDataBuffer", materialDataBuffer);

        ////////////// chapter7_2 //////////////
        if (kernelHandleShadowMap > 0)
        {
            rayTracingShader.SetBuffer(kernelHandleShadowMap, "sortedTriangleIndexBuffer", container.triangleIndexBuffer);
            rayTracingShader.SetBuffer(kernelHandleShadowMap, "triangleAABBBuffer", container.triangleAABBBuffer);
            rayTracingShader.SetBuffer(kernelHandleShadowMap, "bvhInternalNodeBuffer", container.bvhInternalNodeBuffer);
            rayTracingShader.SetBuffer(kernelHandleShadowMap, "bvhLeafNodeBuffer", container.bvhLeafNodeBuffer);
            rayTracingShader.SetBuffer(kernelHandleShadowMap, "bvhDataBuffer", container.bvhDataBuffer);
            rayTracingShader.SetBuffer(kernelHandleShadowMap, "triangleDataBuffer", container.triangleDataBuffer);
            rayTracingShader.SetBuffer(kernelHandleShadowMap, "materialDataBuffer", materialDataBuffer);

        }
    }

    void InitMesh(out Mesh mesh,
        out List<uint> materialIndices,
        out List<Material> materials,
        out List<Vector2Int> shadowIndices)
    {
        MeshRenderer[] mrs = (from mr in meshParent.GetComponentsInChildren<MeshRenderer>(false)
                              where mr.enabled && mr.gameObject.activeInHierarchy
                              select mr).ToArray();

        // mesh 顶点相关数据存储在这些数组中
        List<int> indices = new List<int>();
        List<Vector3> vertices = new List<Vector3>();
        List<Vector3> normals = new List<Vector3>();
        List<Vector3> tangents = new List<Vector3>();
        List<Vector2> uvs = new List<Vector2>();

        // 材质，这里存储的是每一个三角面的材质id
        materialIndices = new List<uint>();
        materials = new List<Material>();

        // 阴影，这里存储的是每一个三角面的cast/receive shadow
        shadowIndices = new List<Vector2Int>();

        // 开始合并模型
        int indexOffset = 0;
        uint materialIndex = 0;
        Bounds encompassingAABB = mrs[0].bounds;

        foreach (MeshRenderer mr in mrs)
        {
            // 1. 处理模型，得到每一个模型的顶点数据
            Mesh m = mr.GetComponent<MeshFilter>().sharedMesh;
            var _indices = m.triangles.Select(i => i + indexOffset);
            // 将顶点，法线，切线从局部坐标变换到世界坐标系
            var _vertices = m.vertices.Select(v => mr.transform.TransformPoint(v));
            var _normals = m.normals.Select(n => mr.transform.TransformVector(n));
            var _tangents = m.tangents.Select(t => mr.transform.TransformVector(t));
            var _uvs = m.uv;

            indices.AddRange(_indices);
            vertices.AddRange(_vertices);
            normals.AddRange(_normals);
            tangents.AddRange(_tangents);
            uvs.AddRange(_uvs);

            // 2. 处理材质，这里是处理当前模型的三角面，而不是顶点
            int[] polygons = m.triangles.Where((value, index) => index % 3 == 0).ToArray();
            Material mat = mr.sharedMaterial;
            // 如果当前模型的材质已经在 materials 里，就用已有的材质 id 赋值
            if (materials.Contains(mat))
            {
                uint index = (uint)materials.IndexOf(mat);
                materialIndices.AddRange(polygons.Select(i => index));
            }
            else // 如果当前模型的材质不在 materials 里，则将这个material添加进来
            {
                materialIndices.AddRange(polygons.Select(i => materialIndex));
                materials.Add(mat);
                materialIndex += 1;
            }

            // 3. 处理阴影，使用2个int来存储阴影数据：第一个int: cast shadow, 第二个int: receive shadow
            shadowIndices.AddRange(polygons.Select(i => new Vector2Int(mr.shadowCastingMode == ShadowCastingMode.On ? 1 : 0, mr.receiveShadows ? 1 : 0)));

            // 迭代好一个mesh之后，index需要做偏移
            indexOffset += m.vertices.Length;

            // 同时也更新一下aabb
            encompassingAABB.min = Vector3.Min(encompassingAABB.min, m.bounds.min);
            encompassingAABB.max = Vector3.Max(encompassingAABB.max, m.bounds.max);
        }

        // 开始合并mesh
        int vertexCount = vertices.Count;
        int indexCount = indices.Count;

        // 1. 创建一个新的mesh
        mesh = new Mesh();

        // 2. 声明mesh的顶点数据结构
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

        // 定义顶点数据结构
        mesh.SetVertexBufferParams(vertexCount, pDesc, nDesc, tDesc, uvDesc);
        // 定义索引数据
        // IndexFormat.UInt16: 2 byte, 范围 0-65535
        // IndexFormat.UInt32: 4 byte, 范围 0-4294967295 
        mesh.SetIndexBufferParams(indexCount, IndexFormat.UInt32);
        // 保证传参是 MeshUpdateFlags.DontRecalculateBounds
        mesh.SetSubMesh(0, new SubMeshDescriptor(0, indexCount), MeshUpdateFlags.DontRecalculateBounds);

        // 传值顶点数据结构
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

        // 传值索引数据
        mesh.SetIndexBufferData(indices, 0, 0, indexCount);
    }

    void InitMaterialData(List<Material> materials)
    {
        MaterialData[] datas = (from m in materials select new MaterialData(m)).ToArray();
        materialDataBuffer = new ComputeBuffer(materials.Count, Marshal.SizeOf(typeof(MaterialData)));
        materialDataBuffer.SetData(datas);
    }

    ////////////// chapter4_4 //////////////
    void DrawAABB(AABB aabb, float scale = 1.0f)
    {
        Gizmos.DrawWireCube((aabb.min + aabb.max) / 2, (aabb.max - aabb.min) * scale);
    }

    ////////////// chapter6_5 //////////////
    public void UpdateMaterialData()
    {
        List<Material> materials = new List<Material>();
        foreach (MeshRenderer mr in meshParent.GetComponentsInChildren<MeshRenderer>(false))
        {
            if (mr.enabled && mr.gameObject.activeInHierarchy)
            {
                Material mat = mr.sharedMaterial;
                // 如果当前模型的材质已经在materials里，就用已有的材质
                if (!materials.Contains(mat))
                    materials.Add(mat);
            }
        }
        MaterialData[] datas = (from m in materials select new MaterialData(m)).ToArray();
        materialDataBuffer.SetData(datas);
        rayTracingShader.SetBuffer(kernelHandle, "materialDataBuffer", materialDataBuffer);

        RayTracing.SetDirty();
    }

    private void OnDrawGizmos()
    {
        switch(debugDataType)
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

                        // 给当前morton code升序排序
                        Dictionary<int, uint> di = new Dictionary<int, uint>();
                        for (int i = 0; i < mortonCodes.Length; ++i)
                            di.Add(i, mortonCodes[i]);

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
                }
                break;
            default:
                break;
        }
    }

    private void OnDestroy()
    {
        ////////////// chapter4_3 //////////////
        materialDataBuffer?.Dispose();
        container?.Dispose();
    }
}
