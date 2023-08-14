using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

public class MeshCollector : MonoBehaviour
{
    ////////////// chapter2_2 //////////////
    public Transform planeParent;

    Camera cam;

    //////////////// chapter3_3 //////////////
    /// 将 Plane从 Primitive处继承
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

        public Plane(Renderer r)
        {
            normal = r.transform.up;
            position = r.transform.position;
            size = r.transform.localScale;
            //////////////// chapter3_3 //////////////
            Primitive.InitMaterial(r, out albedo, out metallic, out smoothness, out transparent, out emissionColor);
        }
    };
    ComputeBuffer planeBuffer;

    ////////////// chapter2_3 //////////////
    interface Primitive
    {
        public void Init(Renderer r)
        {
        }

        //////////////// chapter3_3 //////////////
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
    };

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
    };
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
    };
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

            // Add vertex data
            int firstVertex = vertices.Count;
            vertices.AddRange(mesh.vertices);

            // normal 可以先不讲解
            normals.AddRange(mesh.normals);

            // Add index data - if the vertex buffer wasn't empty before, the
            // indices need to be offset
            int firstIndex = indices.Count;
            int[] currentMeshIndices = mesh.GetIndices(0);
            indices.AddRange(currentMeshIndices.Select(index => index + firstVertex));

            localToWorldMatrix = r.transform.localToWorldMatrix;
            indicesOffset = firstIndex;
            indicesCount = currentMeshIndices.Length;

            //////////////// chapter3_3 //////////////
            Primitive.InitMaterial(r, out albedo, out metallic, out smoothness, out transparent, out emissionColor);
        }
    }
    public Transform customMeshParent;
    ComputeBuffer customMeshBuffer;
    ComputeBuffer vertexBuffer;
    ComputeBuffer normalBuffer;
    ComputeBuffer indexBuffer;
    static List<Vector3> vertices = new List<Vector3>();
    static List<Vector3> normals = new List<Vector3>(); // normal 可以先不讲解， 需要结合旋转来讲解
    static List<int> indices = new List<int>();

    ////////////// chapter2_2 //////////////
    public void Init(ComputeShader cs, int kernelHandle)
    {
        cam = Camera.main;

        InitPlane(cs, kernelHandle);
        ////////////// chapter2_3 //////////////
        InitPrimitive<Sphere>(cs, kernelHandle, ref sphereBuffer, sphereParent, "sphereBuffer", "sphereCount");
        InitPrimitive<Cube>(cs, kernelHandle, ref cubeBuffer, cubeParent, "cubeBuffer", "cubeCount");
        ////////////// chapter4_1 //////////////
        vertices.Clear();
        normals.Clear();// normal 可以先不讲解
        indices.Clear();

        InitPrimitive<CustomMesh>(cs, kernelHandle, ref customMeshBuffer, customMeshParent, "customMeshBuffer", "customMeshCount");

        vertexBuffer = new ComputeBuffer(vertices.Count, sizeof(float) * 3);
        vertexBuffer.SetData(vertices);
        cs.SetBuffer(kernelHandle, "vertexBuffer", vertexBuffer);

        // normal 可以先不讲解
        normalBuffer = new ComputeBuffer(normals.Count, sizeof(float) * 3);
        normalBuffer.SetData(normals);
        cs.SetBuffer(kernelHandle, "normalBuffer", normalBuffer);

        indexBuffer = new ComputeBuffer(indices.Count, sizeof(int));
        indexBuffer.SetData(indices);
        cs.SetBuffer(kernelHandle, "indexBuffer", indexBuffer);
    }

    void InitPlane(ComputeShader cs, int kernelHandle)
    {
        Plane[] planes = (from r in planeParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Plane(r)).ToArray();

        //planeBuffer = new ComputeBuffer(planes.Length, sizeof(float) * 9);
        //////////////// chapter3_3 //////////////
        planeBuffer = new ComputeBuffer(planes.Length, Marshal.SizeOf(typeof(Plane)));
        planeBuffer.SetData(planes);

        cs.SetBuffer(kernelHandle, "planeBuffer", planeBuffer);
        cs.SetInt("planeCount", planes.Length);
    }

    void InitPrimitive<T>(ComputeShader cs, int kernelHandle, ref ComputeBuffer buffer, Transform parent, string bufferName, string bufferCountName) where T : Primitive, new ()
    {
        T[] primitives = null;
        if (parent == null)
            primitives = new T[1] { new T() };
        else
        {
            Dictionary<Renderer, float> di = new Dictionary<Renderer, float>();
            // Sort by distance first
            foreach (Renderer r in parent.GetComponentsInChildren<Renderer>(false))
            {
                if (!r.gameObject.activeInHierarchy)
                    continue;
                float distance = Vector3.Distance(r.transform.position, cam.transform.position);
                di.Add(r, distance);
            }
            // 先示范不排序的结果
            di = di.OrderByDescending(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

            primitives = new T[di.Keys.Count];
            Renderer[] rs = di.Keys.ToArray();

            for (int i = 0; i < rs.Length; ++i)
            {
                primitives[i] = new T();
                primitives[i].Init(rs[i]);
            }
        }

        if (primitives == null || primitives.Length == 0)
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
