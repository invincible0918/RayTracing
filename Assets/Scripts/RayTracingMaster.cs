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

    // Start is called before the first frame update
    void Start()
    {
        InitShader();
        InitCamera();
        InitPlanes();
        InitSpheres();
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

        //// 1st step, no add shader
        //for (int i = 0; i < debugSampleCount; ++i)
        //{
        //    cs.SetBool("isCosineSample", isCosineSample);
        //    // Make noise stable
        //    cs.SetFloat("_Seed", debugSeeds[debugFrameIndex % debugSampleCount]);
        //    //cs.SetFloat("_Seed", Random.value);
        //    cs.Dispatch(kernelHandle, groupX, groupY, 1);
        //    debugFrameIndex += 1;
        //}

        // 2nd step, utilze add shader
        cs.SetBool("isCosineSample", isCosineSample);
        // Make noise stable
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
        //cs.SetFloat("_Seed", Random.value);
        //cs.SetFloat("_rnd0", Random.value);
        //cs.SetFloat("_rnd1", Random.value);

        if (light)
        {
            Vector3 dir = light.transform.forward;
            cs.SetVector("_DirectionalLight", new Vector4(dir.x, dir.y, dir.z, light.intensity * lightIntensityScale));
            cs.SetVector("_DirectionalLightColor", light.color);
        }

        // Pass sphere and planes datas
        sphereCB.SetData(spheres);
        planeCB.SetData(planes);
        cs.SetBuffer(kernelHandle, "_SphereBuffer", sphereCB);
        cs.SetBuffer(kernelHandle, "_PlaneBuffer", planeCB);
#if UNITY_EDITOR_OSX
        cs.SetInt("_PlaneBufferSize", planes.Length);
        cs.SetInt("_SphereBufferSize", spheres.Length);
        cs.SetInt("DestinationWidth", Screen.width);
        cs.SetInt("DestinationHeight", Screen.height);
#endif
    }

    void InitSpheres()
    {
        if (sphereParent != null)
        {
            Dictionary<float, Renderer> di = new Dictionary<float, Renderer>();
            // Sort by distance first
            foreach(Renderer r in sphereParent.GetComponentsInChildren<Renderer>())
            {
                float distance = Vector3.Distance(r.transform.position, cam.transform.position);
                di.Add(distance, r);
            }
            di = di.OrderByDescending(o => o.Key).ToDictionary(o => o.Key, p => p.Value);

            spheres = new Sphere[di.Values.Count];
            Renderer[] rs = di.Values.ToArray();

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

            if (sphereCB == null)
                sphereCB = new ComputeBuffer(spheres.Length, sizeof(float) * 9);
            sphereCB.SetData(spheres);
        }
    }

    void InitPlanes()
    {
        if (planeParent != null)
        {
            Dictionary<float, Renderer> di = new Dictionary<float, Renderer>();
            // Sort by distance first
            foreach (Renderer r in planeParent.GetComponentsInChildren<Renderer>())
            {
                float distance = Vector3.Distance(r.transform.position, cam.transform.position);
                di.Add(distance, r);
            }
            di = di.OrderByDescending(o => o.Key).ToDictionary(o => o.Key, p => p.Value);

            planes = new Plane[di.Values.Count];
            Renderer[] rs = di.Values.ToArray();

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

            if (planeCB == null)
                planeCB = new ComputeBuffer(planes.Length, sizeof(float) * 14);
            planeCB.SetData(planes);
        }
    }
    private void OnDestroy()
    {
        sphereCB?.Release();
        planeCB?.Release();
    }
}
