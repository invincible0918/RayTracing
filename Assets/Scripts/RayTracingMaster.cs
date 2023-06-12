using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class RayTracingMaster : MonoBehaviour
{
    public ComputeShader cs;
    public Cubemap skyboxCube;
    public RenderTexture rt;

    public Light light;
    public float lightIntensityScale = 2;

    public Transform sphereParent;
    public Transform planeParent;
    // chapter 3.1
    public Transform meshParent;

    public bool aliasing;

    // Add a new rt to Anti-Aliasing
    public RenderTexture convergedRT;
    Material addMaterial;
    uint currentSample = 0;

    int kernelHandle;
    Camera cam;

    float[] debugSeeds;
    int debugFrameIndex;
    int debugSampleCount;

    struct Sphere
    {
        public Vector3 center;
        public float radius;
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
    };

    Sphere[] spheres;
    ComputeBuffer sphereCB;

    struct Plane
    {
        public Vector3 normal;
        public Vector3 position;
        public Vector3 size;
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
    };

    Plane[] planes;
    ComputeBuffer planeCB;

    // chapter 3.1
    struct CMesh
    {
        public Matrix4x4 localToWorldMatrix;
        public int indicesOffset;
        public int indicesCount;
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
    }

    CMesh[] cmeshes;
    List<Vector3> vertices = new List<Vector3>();
    List<int> indices = new List<int>();

    ComputeBuffer meshCB;
    ComputeBuffer vertexCB;
    ComputeBuffer indexCB;

    // Start is called before the first frame update
    void Start()
    {
        InitCamera();
        InitPlanes();
        InitSpheres();
        // chapter 3.1
        InitMeshes();

        InitShader();
    }

    private void OnDisable()
    {
        if (rt != null)
            rt.Release();

        if (convergedRT != null)
            convergedRT.Release();
    }

    // Update is called once per frame
    void Update()
    {
        if (transform.hasChanged)
        {
            currentSample = 0;
            transform.hasChanged = false;
        }
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        CustomRender(destination);
    }

    void InitShader()
    {
        if (cs)
        {
            kernelHandle = cs.FindKernel("CSMain");

            cs.SetTexture(kernelHandle, "SkyboxCube", skyboxCube);
        }

        currentSample = 0;

        debugSampleCount = 10;
        debugSeeds = new float[debugSampleCount];
        for (int i = 0; i < debugSampleCount; ++i)
            debugSeeds[i] = Random.value;

        cs.SetBuffer(kernelHandle, "_SphereBuffer", sphereCB);
        cs.SetBuffer(kernelHandle, "_PlaneBuffer", planeCB);
        // chapter 3.1
        cs.SetBuffer(kernelHandle, "_MeshBuffer", meshCB);
        cs.SetBuffer(kernelHandle, "_VertexBuffer", vertexCB);
        cs.SetBuffer(kernelHandle, "_IndexBuffer", indexCB);
#if UNITY_EDITOR_OSX
        cs.SetInt("_PlaneBufferSize", planes.Length);
        cs.SetInt("_SphereBufferSize", spheres.Length);
        // chapter 3.1
        cs.SetInt("_MeshBufferSize", cmeshes.Length);

        cs.SetInt("DestinationWidth", Screen.width);
        cs.SetInt("DestinationHeight", Screen.height);
#endif
    }

    void InitCamera()
    {
        cam = GetComponent<Camera>();
    }

    void InitRT()
    {
        if (rt != null)
            rt.Release();

        if (convergedRT != null)
            convergedRT.Release();

        rt = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear)
        {
            enableRandomWrite = true
        };
        rt.Create();

        convergedRT = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear)
        {
            enableRandomWrite = true
        };
        convergedRT.Create();

        // Reset sampling
        currentSample = 0;
    }

    public bool isCosineSample;
    void CustomRender(RenderTexture destination)
    {
        if (!cs)
            return;

        if (rt == null || convergedRT == null || rt.width != Screen.width || rt.height != Screen.height)
            InitRT();

        // Update geometry in real time
        //InitPlanes();
        //InitSpheres();
        UpdateParameters();

        cs.GetKernelThreadGroupSizes(kernelHandle, out uint x, out uint y, out _);
        int groupX = Mathf.CeilToInt((float)Screen.width / x);
        int groupY = Mathf.CeilToInt((float)Screen.height / y);

        // 1st step, no add shader
        //for (int i = 0; i < debugSampleCount; ++i)
        //{
        //    cs.SetBool("isCosineSample", isCosineSample);
        //    // Make noise stable
        //    cs.SetFloat("_Seed", debugSeeds[debugFrameIndex % debugSampleCount]);
        //    cs.Dispatch(kernelHandle, groupX, groupY, 1);
        //    debugFrameIndex += 1;
        //}

        // 2nd step, utilze add shader
        cs.SetBool("isCosineSample", isCosineSample);
        cs.SetFloat("_Seed", Random.value);
        cs.Dispatch(kernelHandle, groupX, groupY, 1);

        if (!aliasing)
            Graphics.Blit(rt, destination);
        else
        {
            // Anti-Aliasing
            // Blit the result texture to the screen
            if (addMaterial == null)
                addMaterial = new Material(Shader.Find("MyCustom/AddShader"));
            addMaterial.SetFloat("_Sample", currentSample);
            Graphics.Blit(rt, convergedRT, addMaterial);
            Graphics.Blit(convergedRT, destination);
            currentSample++;
        }
    }

    void UpdateParameters()
    {
        cs.SetTexture(kernelHandle, "Destination", rt);

        cs.SetMatrix("_Camera2World", cam.cameraToWorldMatrix);
        cs.SetMatrix("_CameraInverseProjection", cam.projectionMatrix.inverse);
        cs.SetVector("_PixelOffset", new Vector4(Random.value, Random.value, 0, 0));

        if (light)
        {
            Vector3 dir = light.transform.forward;
            cs.SetVector("_DirectionalLight", new Vector4(dir.x, dir.y, dir.z, light.intensity * lightIntensityScale));
            cs.SetVector("_DirectionalLightColor", light.color);
        }
    }

    void InitSpheres()
    {
        if (sphereParent != null)
        {
            Dictionary<Renderer, float> di = new Dictionary<Renderer, float>();
            // Sort by distance first
            foreach(Renderer r in sphereParent.GetComponentsInChildren<Renderer>(false))
            {
                if (!r.gameObject.activeInHierarchy)
                    continue;
                float distance = Vector3.Distance(r.transform.position, cam.transform.position);
                di.Add(r, distance);
            }
            di = di.OrderByDescending(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

            spheres = new Sphere[di.Keys.Count];
            Renderer[] rs = di.Keys.ToArray();

            for (int i = 0; i < rs.Length; ++i)
            {
                Sphere sphere = new Sphere();
                sphere.center = rs[i].transform.position;
                sphere.radius = rs[i].transform.localScale.x / 2;
                Material mat = rs[i].sharedMaterial;
                sphere.albedo = new Vector3(mat.color.r, mat.color.g, mat.color.b);
                sphere.metallic = Mathf.Max(0.01f, mat.GetFloat("_Metallic"));
                sphere.smoothness = Mathf.Max(0.01f, mat.GetFloat("_Glossiness"));
                spheres[i] = sphere;
            }

            if (spheres.Length == 0)
                spheres = new Sphere[1];

            if (sphereCB == null)
                sphereCB = new ComputeBuffer(spheres.Length, sizeof(float) * 9);
            sphereCB.SetData(spheres);
        }
    }

    void InitPlanes()
    {
        if (planeParent != null)
        {
            Dictionary<Renderer, float> di = new Dictionary<Renderer, float>();
            // Sort by distance first
            foreach (Renderer r in planeParent.GetComponentsInChildren<Renderer>(false))
            {
                if (!r.gameObject.activeInHierarchy)
                    continue;
                float distance = Vector3.Distance(r.transform.position, cam.transform.position);
                di.Add(r, distance);
            }
            di = di.OrderByDescending(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

            planes = new Plane[di.Keys.Count];
            Renderer[] rs = di.Keys.ToArray();

            for (int i = 0; i < rs.Length; ++i)
            {
                Plane plane = new Plane();
                plane.normal = rs[i].transform.up;
                //plane.axis = new Vector3(rs[i].transform.position.x * Mathf.Abs(rs[i].transform.up.x),
                //                         rs[i].transform.position.y * Mathf.Abs(rs[i].transform.up.y),
                //                         rs[i].transform.position.z * Mathf.Abs(rs[i].transform.up.z));
                plane.position = rs[i].transform.position;
                plane.size = rs[i].transform.parent.GetComponent<BoxCollider>().size;
                Material mat = rs[i].sharedMaterial;
                plane.albedo = new Vector3(mat.color.r, mat.color.g, mat.color.b);
                plane.metallic = Mathf.Max(0.01f, mat.GetFloat("_Metallic"));
                plane.smoothness = Mathf.Max(0.01f, mat.GetFloat("_Glossiness"));
                planes[i] = plane;
            }

            if (planes.Length == 0)
                planes = new Plane[1];

            if (planeCB == null)
                planeCB = new ComputeBuffer(planes.Length, sizeof(float) * 14);
            planeCB.SetData(planes);
        }
    }

    // chapter 3.1
    void InitMeshes()
    {
        if (meshParent != null)
        {
            Dictionary<MeshRenderer, float> di = new Dictionary<MeshRenderer, float>();
            // Sort by distance first
            foreach (MeshRenderer r in meshParent.GetComponentsInChildren<MeshRenderer>(false))
            {
                if (!r.gameObject.activeInHierarchy)
                    continue;
                float distance = Vector3.Distance(r.transform.position, cam.transform.position);
                di.Add(r, distance);
            }
            di = di.OrderByDescending(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

            MeshRenderer[] rs = di.Keys.ToArray();

            cmeshes = new CMesh[di.Keys.Count];
            indices.Clear();
            vertices.Clear();

            for (int i = 0; i < rs.Length; ++i)
            {
                Mesh mesh = rs[i].GetComponent<MeshFilter>().sharedMesh;

                // Add vertex data
                int firstVertex = vertices.Count;
                vertices.AddRange(mesh.vertices);

                // Add index data - if the vertex buffer wasn't empty before, the
                // indices need to be offset
                int firstIndex = indices.Count;
                int[] currentMeshIndices = mesh.GetIndices(0);
                indices.AddRange(currentMeshIndices.Select(index => index + firstVertex));

                CMesh cmesh = new CMesh();
                cmesh.localToWorldMatrix = rs[i].transform.localToWorldMatrix;
                cmesh.indicesOffset = firstIndex;
                cmesh.indicesCount = currentMeshIndices.Length;

                Material mat = rs[i].sharedMaterial;
                cmesh.albedo = new Vector3(mat.color.r, mat.color.g, mat.color.b);
                cmesh.metallic = Mathf.Max(0.01f, mat.GetFloat("_Metallic"));
                cmesh.smoothness = Mathf.Max(0.01f, mat.GetFloat("_Glossiness"));
                cmeshes[i] = cmesh;
            }

            if (cmeshes.Length == 0)
            {
                cmeshes = new CMesh[1];
                vertices.Add(Vector3.zero);
                indices.Add(0);
            }

            if (meshCB == null)
                meshCB = new ComputeBuffer(cmeshes.Length, sizeof(float) * 21 + sizeof(int) * 2);
            meshCB.SetData(cmeshes);

            if (vertexCB == null)
                vertexCB = new ComputeBuffer(vertices.Count, sizeof(float) * 3);
            vertexCB.SetData(vertices);

            if (indexCB == null)
                indexCB = new ComputeBuffer(indices.Count, sizeof(int));
            indexCB.SetData(indices);

            // BVH
            BVHTree tree = new BVHTree(mr);
        }
    }

    private void OnDestroy()
    {
        sphereCB?.Release();
        planeCB?.Release();

        // chapter 3.1
        meshCB?.Release();
        vertexCB?.Release();
        indexCB?.Release();
    }
}
