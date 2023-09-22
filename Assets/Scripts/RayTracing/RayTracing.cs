using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class RayTracing : MonoBehaviour
{
    ////////////// chapter2_1 //////////////
    public ComputeShader cs;
    public RenderTexture rt;

    int kernelHandle;
    Camera cam;
    bool isInitialized;

    ////////////// chapter2_2 //////////////
    public MeshCollector meshCollector;

    ////////////// chapter3_1 //////////////
    public Material skyboxMat;

    ////////////// chapter3_4 //////////////
    public Light mainLight;
    public Color shadowColor;
    public float shadowIntensity = 1f;

    ////////////// chapter3_5 //////////////
    public bool aliasing;
    public uint samplePrePixel = 0;
    Material addMaterial;
    public RenderTexture convergedRT;

    ////////////// chapter4_3 //////////////
    public BVH bvh;
    public bool useBVH;

    ////////////// chapter6_2 //////////////
    public enum SamplingType
    {
        Uniform,
        Cosine,
        LightImportance,
        BSDFImportance,
        MultipleImportance
    }
    public SamplingType samplingType = SamplingType.Uniform;

    public LightImportanceSampling lightImportanceSampling;

    ////////////// chapter6_5 //////////////
    static RayTracing instance;

    ////////////// chapter7_1 //////////////
    public GameObject matteMaskGO;
    public RenderTexture ao;
    bool isRenderMatteMask;
    int kernelHandleAO;

    // Start is called before the first frame update
    void Start()
    {
        ////////////// chapter2_1 //////////////
        InitCamera();
        InitRT();
        ////////////// chapter2_2 //////////////
        InitShader();
        ////////////// chapter3_4 //////////////
        InitLight();
        ////////////// chapter6_2 //////////////
        InitSampling();
        ////////////// chapter6_5 //////////////
        instance = this;

        // 初始化结束
        ////////////// chapter4_3 //////////////
        if (useBVH)
        {
            bvh.Init(cs, kernelHandle, kernelHandleAO);
            cs.EnableKeyword("BVH");
        }
        else
        {
            meshCollector.Init(cs, kernelHandle);
            cs.DisableKeyword("BVH");
        }

        // 所有的初始化结束之后，标记位为true
        isInitialized = true;
    }

    // Update is called once per frame
    void Update()
    {
        ////////////// chapter2_1 //////////////
        /// 当相机位移之后，需要重新计算
        if (transform.hasChanged)
        {
            // Todo
            SetDirty();
            transform.hasChanged = false;
        }
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        CustomRender(destination);
    }

    ////////////// chapter2_1 //////////////
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
        cs.Dispatch(kernelHandle, groupX, groupY, 1);

        ////////////// chapter7_1 //////////////
        if (isRenderMatteMask)
            cs.Dispatch(kernelHandleAO, groupX, groupY, 1);

        // 使用光线追踪方法绘制 destination RT
        if (!aliasing)
            Graphics.Blit(rt, destination);
        else
        {
            addMaterial.SetFloat("_SamplePrePixel", samplePrePixel);
            addMaterial.SetTexture("_AO", ao);
            Graphics.Blit(rt, convergedRT, addMaterial);
            Graphics.Blit(convergedRT, destination);

            samplePrePixel++;
        }
    }

    void InitCamera()
    {
        cam = GetComponent<Camera>();
        cam.allowHDR = true;
    }

    void InitRT()
    {
        CreateRT(ref rt);
        ////////////// chapter3_5 //////////////
        CreateRT(ref convergedRT);
        ////////////// chapter7_1 //////////////
        if (matteMaskGO != null)
        {
            isRenderMatteMask = true;
            CreateRT(ref ao);
        }

        samplePrePixel = 0;
    }

    ////////////// chapter2_2 //////////////
    void InitShader()
    {
        kernelHandle = cs.FindKernel("CSMain");

        cs.SetInt("width", Screen.width);
        cs.SetInt("height", Screen.height);

        ////////////// chapter3_1 //////////////
        if (skyboxMat != null)
        {
            cs.SetTexture(kernelHandle, "skyboxCube", skyboxMat.GetTexture("_Tex"));

            //////////////// chapter5_3 //////////////
            cs.SetFloat("skyboxRotation", skyboxMat.GetFloat("_Rotation"));
            cs.SetFloat("skyboxExposure", skyboxMat.GetFloat("_Exposure"));
        }

        ////////////// chapter3_5 //////////////
        if (addMaterial == null)
            addMaterial = new Material(Shader.Find("MyCustom/AddShader"));

        ////////////// chapter7_1 //////////////
        kernelHandleAO = cs.FindKernel("AmbientOcclusion");
    }

    void UpdateParameters()
    {
        cs.SetTexture(kernelHandle, "destination", rt);

        cs.SetMatrix("camera2World", cam.cameraToWorldMatrix);
        cs.SetMatrix("cameraInverseProjection", cam.projectionMatrix.inverse);

        //////////////// chapter3_5 //////////////
        cs.SetVector("pixelOffset", new Vector4(Random.value, Random.value, 0, 0));

        //////////////// chapter5_2 //////////////
        cs.SetFloat("seed", Random.value);

        //////////////// chapter7_1 //////////////
        if (isRenderMatteMask)
            cs.SetTexture(kernelHandleAO, "ao", ao);
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

    ////////////// chapter3_4 //////////////
    void InitLight()
    {
        Vector3 dir = mainLight.transform.forward;
        cs.SetVector("lightParameter", new Vector4(dir.x, dir.y, dir.z, mainLight.intensity));
        cs.SetVector("lightColor", mainLight.color);
        cs.SetVector("shadowParameter", new Vector4(shadowColor.r, shadowColor.g, shadowColor.b, shadowIntensity));

        ////////////// chapter5_4 //////////////
        cs.DisableKeyword("NO_SHADOW");
        cs.DisableKeyword("HARD_SHADOW");
        cs.DisableKeyword("SOFT_SHADOW");

        switch(mainLight.shadows)
        {
            case LightShadows.None:
                cs.EnableKeyword("NO_SHADOW");
                break;
            case LightShadows.Hard:
                cs.EnableKeyword("HARD_SHADOW");
                break;
            case LightShadows.Soft:
                cs.EnableKeyword("SOFT_SHADOW");
                break;
        }

        ////////////// chapter6_2 //////////////
        lightImportanceSampling.Init(cs, kernelHandle);
    }

    ////////////// chapter6_2 //////////////
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

    ////////////// chapter6_5 //////////////
    public static void SetDirty()
    {
        instance.samplePrePixel = 0;
    }

    private void OnDisable()
    {
        if (rt != null)
            rt.Release();

        if (convergedRT != null)
            convergedRT.Release();

        ////////////// chapter7_1 //////////////
        if (ao != null)
            ao.Release();
    }
}
