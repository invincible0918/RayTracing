using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

public class MeshCollector : MonoBehaviour
{
    //////////////// chapter3_3 //////////////
    interface Primitive
    {
        public void Init(Renderer r)
        {
        }

        public static void InitMaterial(Renderer r,
            out Vector3 albedo,
            out float metallic,
            out float smoothness,
            out float transparent,
            out Vector3 emissionColor)
        {
            Material mat = r.sharedMaterial;

            albedo = new Vector3(mat.color.linear.r, mat.color.linear.g, mat.color.linear.b);
            metallic = Mathf.Max(0.01f, mat.GetFloat("_Metallic"));
            smoothness = Mathf.Max(0.01f, mat.GetFloat("_Glossiness"));

            transparent = -1;
            emissionColor = Vector3.zero;

            if ((int)(mat.GetFloat("_Mode")) == 3)
                transparent = mat.color.linear.a;

            if (mat.IsKeywordEnabled("_EMISSION"))
            {
                Color color = mat.GetColor("_EmissionColor");
                emissionColor = new Vector3(color.r, color.g, color.b);
            }
        }
    }

    ////////////// chapter2_2 //////////////
    Camera cam;

    [StructLayout(LayoutKind.Sequential)]
    struct Plane : Primitive
    {
        public Vector3 normal;
        public Vector3 position;
        public Vector3 size;
        //////////////// chapter3_3 //////////////
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public float transparent;
        public Vector3 emissionColor;

        public void Init(Renderer r)
        {
            normal = r.transform.up;
            position = r.transform.position;
            size = r.transform.localScale;

            Primitive.InitMaterial(r, out albedo, out metallic, out smoothness, out transparent, out emissionColor);
        }
    }
    public Transform planeParent;
    ComputeBuffer planeBuffer;

    ////////////// chapter2_3 //////////////
    [StructLayout(LayoutKind.Sequential)]
    struct Sphere : Primitive
    {
        public Vector3 center;
        public float radius;
        //////////////// chapter3_3 //////////////
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public float transparent;
        public Vector3 emissionColor;

        public void Init(Renderer r)
        {
            center = r.transform.position;
            radius = r.transform.localScale.x / 2;
            //////////////// chapter3_3 //////////////
            Primitive.InitMaterial(r, out albedo, out metallic, out smoothness, out transparent, out emissionColor);
        }
    }
    public Transform sphereParent;
    ComputeBuffer sphereBuffer;

    [StructLayout(LayoutKind.Sequential)]
    struct Cube : Primitive
    {
        public Vector3 min;
        public Vector3 max;
        //////////////// chapter3_3 //////////////
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public float transparent;
        public Vector3 emissionColor;

        public void Init(Renderer r)
        {
            Vector3 pos = r.transform.position;
            Vector3 halfSize = r.transform.localScale / 2;
            min = pos - halfSize;
            max = pos + halfSize;
            //////////////// chapter3_3 //////////////
            Primitive.InitMaterial(r, out albedo, out metallic, out smoothness, out transparent, out emissionColor);
        }
    }
    public Transform cubeParent;
    ComputeBuffer cubeBuffer;

    ////////////// chapter4_1 //////////////
    [StructLayout(LayoutKind.Sequential)]
    struct CustomMesh : Primitive
    {
        public Matrix4x4 localToWorldMatrix;
        public int indicesOffset;
        public int indicesCount;
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public float transparent;
        public Vector3 emissionColor;

        public void Init(Renderer r)
        {
            Mesh mesh = r.GetComponent<MeshFilter>().sharedMesh;

            // 添加顶点位置
            int firstVertex = vertices.Count;
            vertices.AddRange(mesh.vertices);

            // 添加顶点法线
            normals.AddRange(mesh.normals);

            // 添加顶点索引
            int firstIndex = indices.Count;
            int[] currentMeshIndices = mesh.GetIndices(0);
            // 合并mesh之后，顶点索引需要在上一个mesh的顶点索引基础之上累加
            indices.AddRange(currentMeshIndices.Select(index => index + firstVertex));

            localToWorldMatrix = r.transform.localToWorldMatrix;
            indicesOffset = firstIndex;
            indicesCount = currentMeshIndices.Length;

            Primitive.InitMaterial(r, out albedo, out metallic, out smoothness, out transparent, out emissionColor);
        }
    }
    public Transform customMeshParent;
    ComputeBuffer customMeshBuffer;
    ComputeBuffer vertexBuffer;
    ComputeBuffer normalBuffer;
    ComputeBuffer indexBuffer;
    // 记录场景中需要绘制的所有custom mesh的顶点位置
    static List<Vector3> vertices = new List<Vector3>();
    // 记录场景中需要绘制的所有custom mesh的法线方向
    static List<Vector3> normals = new List<Vector3>();
    // 记录场景中需要绘制的所有custom mesh的顶点索引
    static List<int> indices = new List<int>();

    ////////////// chapter2_2 //////////////
    public void Init(ComputeShader cs, int kernelHandle)
    {
        cam = Camera.main;

        //InitPlane(cs, kernelHandle);
        //////////////// chapter2_3 //////////////
        //InitSphere(cs, kernelHandle);
        //InitCube(cs, kernelHandle);
        ////////////// chapter3_3 //////////////
        InitPrimitive<Plane>(cs, kernelHandle, planeParent, "planeBuffer", "planeCount", ref planeBuffer);
        InitPrimitive<Sphere>(cs, kernelHandle, sphereParent, "sphereBuffer", "sphereCount", ref sphereBuffer);
        InitPrimitive<Cube>(cs, kernelHandle, cubeParent, "cubeBuffer", "cubeCount", ref cubeBuffer);
        ////////////// chapter4_1 //////////////
        vertices.Clear();
        normals.Clear();
        indices.Clear();

        InitPrimitive<CustomMesh>(cs, kernelHandle, customMeshParent, "customMeshBuffer", "customMeshCount", ref customMeshBuffer);

        vertexBuffer = new ComputeBuffer(vertices.Count, sizeof(float) * 3);
        vertexBuffer.SetData(vertices);
        cs.SetBuffer(kernelHandle, "vertexBuffer", vertexBuffer);

        normalBuffer = new ComputeBuffer(normals.Count, sizeof(float) * 3);
        normalBuffer.SetData(normals);
        cs.SetBuffer(kernelHandle, "normalBuffer", normalBuffer);

        indexBuffer = new ComputeBuffer(indices.Count, sizeof(int));
        indexBuffer.SetData(indices);
        cs.SetBuffer(kernelHandle, "indexBuffer", indexBuffer);
    }

    //void InitPlane(ComputeShader cs, int kernelHandle)
    //{
    //    Plane[] planes = (from r in planeParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Plane(r)).ToArray();
    //    planeBuffer = new ComputeBuffer(planes.Length, Marshal.SizeOf(typeof(Plane)));
    //    planeBuffer.SetData(planes);

    //    cs.SetBuffer(kernelHandle, "planeBuffer", planeBuffer);
    //    cs.SetInt("planeCount", planes.Length);
    //}

    ////////////// chapter2_3 //////////////
    //void InitSphere(ComputeShader cs, int kernelHandle)
    //{
    //    // 需要考虑Z排序
    //    //Sphere[] spheres = (from r in sphereParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Sphere(r)).ToArray();
    //    Dictionary<Renderer, float> di = new Dictionary<Renderer, float>();
    //    foreach (Renderer r in sphereParent.GetComponentsInChildren<Renderer>(false))
    //    {
    //        if (!r.gameObject.activeInHierarchy)
    //            continue;

    //        float distance = Vector3.Distance(r.transform.position, cam.transform.position);
    //        di.Add(r, distance);
    //    }
    //    // 根据距离的远近，由远及近进行排序，在compute shader中，远处物体先画
    //    // 近处物体后画，则完成了Z值排序，绘制到正确结果
    //    di = di.OrderByDescending(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

    //    Renderer[] rs = di.Keys.ToArray();
    //    Sphere[] spheres = new Sphere[di.Keys.Count];
    //    for (int i = 0; i < rs.Length; ++i)
    //        spheres[i] = new Sphere(rs[i]);

    //    sphereBuffer = new ComputeBuffer(spheres.Length, sizeof(float) * 4);
    //    sphereBuffer.SetData(spheres);

    //    cs.SetBuffer(kernelHandle, "sphereBuffer", sphereBuffer);
    //    cs.SetInt("sphereCount", spheres.Length);
    //}

    //void InitCube(ComputeShader cs, int kernelHandle)
    //{
    //    //Cube[] cubes = (from r in cubeParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Cube(r)).ToArray();
    //    Dictionary<Renderer, float> di = new Dictionary<Renderer, float>();
    //    foreach (Renderer r in cubeParent.GetComponentsInChildren<Renderer>(false))
    //    {
    //        if (!r.gameObject.activeInHierarchy)
    //            continue;

    //        float distance = Vector3.Distance(r.transform.position, cam.transform.position);
    //        di.Add(r, distance);
    //    }
    //    // 根据距离的远近，由远及近进行排序，在compute shader中，远处物体先画
    //    // 近处物体后画，则完成了Z值排序，绘制到正确结果
    //    di = di.OrderByDescending(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

    //    Renderer[] rs = di.Keys.ToArray();
    //    Cube[] cubes = new Cube[di.Keys.Count];
    //    for (int i = 0; i < rs.Length; ++i)
    //        cubes[i] = new Cube(rs[i]);

    //    cubeBuffer = new ComputeBuffer(cubes.Length, sizeof(float) * 6);
    //    cubeBuffer.SetData(cubes);

    //    cs.SetBuffer(kernelHandle, "cubeBuffer", cubeBuffer);
    //    cs.SetInt("cubeCount", cubes.Length);
    //}

    //////////////// chapter3_3 //////////////
    void InitPrimitive<T>(ComputeShader cs, 
        int kernelHandle, 
        Transform parent,
        string bufferName,
        string bufferCountName,
        ref ComputeBuffer buffer
        ) where T : Primitive, new()
    {
        Dictionary<Renderer, float> di = new Dictionary<Renderer, float>();
        foreach (Renderer r in parent.GetComponentsInChildren<Renderer>(false))
        {
            if (!r.gameObject.activeInHierarchy)
                continue;

            float distance = Vector3.Distance(r.transform.position, cam.transform.position);
            di.Add(r, distance);
        }
        // 根据距离的远近，由远及近进行排序，在compute shader中，远处物体先画
        // 近处物体后画，则完成了Z值排序，绘制到正确结果
        di = di.OrderByDescending(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

        Renderer[] rs = di.Keys.ToArray();
        T[] primitives = new T[di.Keys.Count];
        for (int i = 0; i < rs.Length; ++i)
        {
            primitives[i] = new T();
            primitives[i].Init(rs[i]);
        }
        if (parent == null || primitives.Length == 0)
            primitives = new T[1] { new T() };

        buffer = new ComputeBuffer(primitives.Length, Marshal.SizeOf(typeof(T)));
        buffer.SetData(primitives);

        cs.SetBuffer(kernelHandle, bufferName, buffer);
        cs.SetInt(bufferCountName, primitives.Length);
    }

    private void OnDestroy()
    {
        planeBuffer?.Release();
        sphereBuffer?.Release();
        cubeBuffer?.Release();
        customMeshBuffer?.Release();
        vertexBuffer?.Release();
        normalBuffer?.Release();
        indexBuffer?.Release();
    }
}
