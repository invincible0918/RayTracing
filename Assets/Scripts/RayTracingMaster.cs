using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class RayTracingMaster : MonoBehaviour
{
    public ComputeShader cs;
    public Material skyboxMat;
    public RenderTexture rt;

    public GameObject[] sphereLights;
    public GameObject[] areaLights;
    public GameObject[] discLights;
    ComputeBuffer sphereLightBuffer;
    ComputeBuffer areaLightBuffer;
    ComputeBuffer discLightBuffer;
    struct SphereLight
    {
        public Vector3 position;
        public float radius;
        public SphereLight(GameObject go)
        {
            position = go.transform.position;
            radius = go.GetComponent<SphereCollider>().radius * go.transform.localScale.x;
        }
    }

    struct AreaLight
    {
        public Vector3 position;
        public Vector3 normal;
        public Vector3 up;
        public Vector2 size;
        public AreaLight(GameObject go)
        {
            position = go.transform.position;
            normal = -go.transform.forward;
            up = go.transform.up;
            size = go.GetComponent<BoxCollider>().size;
            size.x *= go.transform.localScale.x;
            size.y *= go.transform.localScale.y;
        }
    }

    struct DiscLight
    {
        public Vector3 position;
        public Vector3 normal;
        public float radius;
        public DiscLight(GameObject go)
        {
            position = go.transform.position;
            normal = -go.transform.forward;
            radius = go.GetComponent<SphereCollider>().radius * go.transform.localScale.x;
        }
    }

    public Light skyLight;
    public float lightIntensityScale = 2;

    public Transform sphereParent;
    public Transform planeParent;
    // chapter 3.1
    public Transform meshParent;

    public bool aliasing;

    // Add a new rt to Anti-Aliasing
    public RenderTexture convergedRT;
    public uint currentSample = 0;

    Material addMaterial;

    public bool isBruteForce;

    int kernelHandle;
    Camera cam;

    float[] debugSeeds;
    int debugFrameIndex;
    int debugSampleCount;

    public Color shadowColor;
    public float shadowIntensity = 1f;

    // Importance sampling
    public enum SamplingType
    {
        Uniform,
        Cosine,
        LightImportance,
        BSDFImportance,
        MultipleImportance
    }
    public SamplingType samplingType = SamplingType.Uniform;

    // Post process
    public PostProcess postProcess;
    public bool enablePostProcess;
    public RenderTexture postProcessRT;

    bool isInitialized;

    struct Sphere
    {
        public Vector3 center;
        public float radius;
        public Vector3 albedo;
        public float metallic;
        public float smoothness;
        public Vector3 emissionColor;
    };

    Sphere[] spheres;
    ComputeBuffer sphereBuffer;

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
    ComputeBuffer planeBuffer;

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

    ComputeBuffer meshBuffer;
    ComputeBuffer vertexBuffer;
    ComputeBuffer indexBuffer;

    // BVH
    public BVH bvh;

    // Start is called before the first frame update
    void Start()
    {
        InitCamera();
        InitRT();
        InitShader();
        InitLight();
        InitSampling();

        // chapter 3.1
        if (isBruteForce)
        {
            InitPlanes();
            InitSpheres();
            InitMeshes();
        }
        else
            bvh.Init(cs, kernelHandle);

        isInitialized = true;
    }

    ComputeBuffer testBuffer;

    private void OnDisable()
    {
        if (rt != null)
            rt.Release();

        if (convergedRT != null)
            convergedRT.Release();

        if (postProcessRT != null)
            postProcessRT.Release();
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
            kernelHandle = cs.FindKernel("CSMain");

        currentSample = 0;

        debugSampleCount = 10;
        debugSeeds = new float[debugSampleCount];
        for (int i = 0; i < debugSampleCount; ++i)
            debugSeeds[i] = Random.value;

        cs.SetInt("width", Screen.width);
        cs.SetInt("height", Screen.height);
        cs.SetFloat("skyboxRotation", skyboxMat.GetFloat("_Rotation"));
        cs.SetFloat("skyboxExposure", skyboxMat.GetFloat("_Exposure"));
        cs.SetTexture(kernelHandle, "skyboxCube", skyboxMat.GetTexture("_Tex"));

        cs.SetInt("destinationWidth", Screen.width);
        cs.SetInt("destinationHeight", Screen.height);
    }

    void InitCamera()
    {
        cam = GetComponent<Camera>();
        cam.allowHDR = true;
    }

    void InitRT()
    {
        CreateRT(ref rt);
        CreateRT(ref convergedRT);
        CreateRT(ref postProcessRT);

        // Reset sampling
        currentSample = 0;
    }

    void InitLight()
    {
        List<SphereLight> sphereLightList = new List<SphereLight>(from light in sphereLights where light.activeInHierarchy select new SphereLight(light));    // position, radius,
        List<AreaLight> areaLightList = new List<AreaLight>(from light in areaLights where light.activeInHierarchy select new AreaLight(light));      // position, forward, width, height, 8 float
        List<DiscLight> discLightList = new List<DiscLight>(from light in discLights where light.gameObject.activeInHierarchy select new DiscLight(light));      // position, forward, radius, 7 float

        Vector3 dir = skyLight.transform.forward;
        cs.SetVector("light", new Vector4(dir.x, dir.y, dir.z, skyLight.intensity * lightIntensityScale));
        cs.SetVector("lightColor", skyLight.color);
        cs.SetVector("shadowParameter", new Vector4(shadowColor.r, shadowColor.g, shadowColor.b, shadowIntensity));

        if (sphereLightList.Count > 0)
        {
            cs.EnableKeyword("SPHERE_LIGHT");

            sphereLightBuffer = new ComputeBuffer(sphereLightList.Count, sizeof(float) * 4);
            sphereLightBuffer.SetData(sphereLightList);
            cs.SetBuffer(kernelHandle, "sphereLightBuffer", sphereLightBuffer);
            cs.SetInt("sphereLightCount", sphereLightList.Count);
        }
        else
            cs.DisableKeyword("SPHERE_LIGHT");

        if (areaLightList.Count > 0)
        {
            cs.EnableKeyword("AREA_LIGHT");

            areaLightBuffer = new ComputeBuffer(areaLightList.Count, sizeof(float) * 11);
            areaLightBuffer.SetData(areaLightList);
            cs.SetBuffer(kernelHandle, "areaLightBuffer", areaLightBuffer);
            cs.SetInt("areaLightCount", areaLightList.Count);
        }
        else
            cs.DisableKeyword("AREA_LIGHT");

        if (discLightList.Count > 0)
        {
            cs.EnableKeyword("DISC_LIGHT");

            discLightBuffer = new ComputeBuffer(discLightList.Count, sizeof(float) * 7);
            discLightBuffer.SetData(discLightList);
            cs.SetBuffer(kernelHandle, "discLightBuffer", discLightBuffer);
            cs.SetInt("discLightCount", discLightList.Count);
        }
        else
            cs.DisableKeyword("DISC_LIGHT");
    }

    void InitSampling()
    {
        cs.DisableKeyword("UNIFORM_SAMPLING");
        cs.DisableKeyword("COSINE_SAMPLING");
        cs.DisableKeyword("LIGHT_IMPORTANCE_SAMPLING");
        cs.DisableKeyword("BSDF_IMPORTANCE_SAMPLING");
        cs.DisableKeyword("MULTIPLE_IMPORTANCE_SAMPLING");

        switch (samplingType)
        {
            case SamplingType.Uniform:
                cs.EnableKeyword("UNIFORM_SAMPLING");
                break;
            case SamplingType.Cosine:
                cs.EnableKeyword("COSINE_SAMPLING");
                break;
            case SamplingType.LightImportance:
                cs.EnableKeyword("LIGHT_IMPORTANCE_SAMPLING");
                break;
            case SamplingType.BSDFImportance:
                cs.EnableKeyword("BSDF_IMPORTANCE_SAMPLING");
                break;
            case SamplingType.MultipleImportance:
                cs.EnableKeyword("MULTIPLE_IMPORTANCE_SAMPLING");
                break;
        }
    }

    void CreateRT(ref RenderTexture rt)
    {
        if (rt != null)
            rt.Release();

        rt = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear)
        {
            enableRandomWrite = true
        };
        rt.Create();
    }

    void CustomRender(RenderTexture destination)
    {
        if (!cs || !isActiveAndEnabled || !isInitialized)
            return;

        if (rt == null || convergedRT == null || rt.width != Screen.width || rt.height != Screen.height)
            InitRT();

        UpdateParameters();

        cs.GetKernelThreadGroupSizes(kernelHandle, out uint x, out uint y, out _);
        int groupX = Mathf.CeilToInt((float)Screen.width / x);
        int groupY = Mathf.CeilToInt((float)Screen.height / y);

        // 1st step, no add shader
        //for (int i = 0; i < debugSampleCount; ++i)
        //{
        //    cs.SetBool("isCosineSample", isCosineSample);
        //    // Make noise stable
        //    cs.SetFloat("seed", debugSeeds[debugFrameIndex % debugSampleCount]);
        //    cs.Dispatch(kernelHandle, groupX, groupY, 1);
        //    debugFrameIndex += 1;
        //}

        // 2nd step, utilze add shader
        if (isBruteForce)
            cs.EnableKeyword("BRUTE_FORCE");
        else
            cs.DisableKeyword("BRUTE_FORCE");

        cs.SetFloat("seed", Random.value);

        cs.Dispatch(kernelHandle, groupX, groupY, 1);
        //bvh.Update();
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

            if (enablePostProcess)
            {
                postProcess.Render(convergedRT, postProcessRT);
                Graphics.Blit(postProcessRT, destination);
            }
            else
                Graphics.Blit(convergedRT, destination);

            currentSample++;
        }
    }

    void OnValidate()
    {
        if (!cs || !isActiveAndEnabled || !isInitialized)
            return;

        // 只有面板上的数值发生变化的时候，或者start的时候，才会调用
    }

    void UpdateParameters()
    {
        cs.SetTexture(kernelHandle, "destination", rt);

        cs.SetMatrix("camera2World", cam.cameraToWorldMatrix);
        cs.SetMatrix("cameraInverseProjection", cam.projectionMatrix.inverse);
        cs.SetVector("pixelOffset", new Vector4(Random.value, Random.value, 0, 0));
    }

    void InitSpheres()
    {
        if (sphereParent == null)
            return;

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
            sphere.emissionColor = mat.IsKeywordEnabled("_EMISSION") ? new Vector3(mat.GetColor("_EmissionColor").r, mat.GetColor("_EmissionColor").g, mat.GetColor("_EmissionColor").b) : Vector3.zero;
            
            spheres[i] = sphere;
        }

        if (spheres.Length == 0)
            spheres = new Sphere[1];

        if (sphereBuffer == null)
            sphereBuffer = new ComputeBuffer(spheres.Length, sizeof(float) * 12);
        sphereBuffer.SetData(spheres);

        cs.SetBuffer(kernelHandle, "sphereBuffer", sphereBuffer);
        cs.SetInt("sphereCount", spheres.Length);
    }

    void InitPlanes()
    {
        if (planeParent == null)
            return;

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

        if (planeBuffer == null)
            planeBuffer = new ComputeBuffer(planes.Length, sizeof(float) * 14);
        planeBuffer.SetData(planes);

        cs.SetBuffer(kernelHandle, "planeBuffer", planeBuffer);
        cs.SetInt("planeCount", planes.Length);
    }

    // chapter 3.1
    void InitMeshes()
    {
        if (meshParent == null)
            return;

        Dictionary<MeshRenderer, float> di = new Dictionary<MeshRenderer, float>();
        // Sort by distance first
        foreach (MeshRenderer r in meshParent.GetComponentsInChildren<MeshRenderer>(false))
        {
            if (!r.enabled || !r.gameObject.activeInHierarchy)
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

        if (meshBuffer == null)
            meshBuffer = new ComputeBuffer(cmeshes.Length, sizeof(float) * 21 + sizeof(int) * 2);
        meshBuffer.SetData(cmeshes);

        if (vertexBuffer == null)
            vertexBuffer = new ComputeBuffer(vertices.Count, sizeof(float) * 3);
        vertexBuffer.SetData(vertices);

        if (indexBuffer == null)
            indexBuffer = new ComputeBuffer(indices.Count, sizeof(int));
        indexBuffer.SetData(indices);

        // chapter 3.1
        cs.SetBuffer(kernelHandle, "meshBuffer", meshBuffer);
        cs.SetBuffer(kernelHandle, "vertexBuffer", vertexBuffer);
        cs.SetBuffer(kernelHandle, "indexBuffer", indexBuffer);
        cs.SetInt("meshCount", cmeshes.Length);
    }

    private void OnDestroy()
    {
        sphereBuffer?.Release();
        planeBuffer?.Release();

        // chapter 3.1
        meshBuffer?.Release();
        vertexBuffer?.Release();
        indexBuffer?.Release();

        sphereLightBuffer?.Release();
        areaLightBuffer?.Release();
        discLightBuffer?.Release();
        testBuffer?.Release();
    }
}
