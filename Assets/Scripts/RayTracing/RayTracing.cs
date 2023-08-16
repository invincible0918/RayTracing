using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// 需要相机的 OnRenderImage
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

    //////////////// chapter3_4 //////////////
    public Light mainLight;
    public Color shadowColor;
    public float shadowIntensity = 1f;

    //////////////// chapter3_5 //////////////
    public RenderTexture convergedRT;
    public bool aliasing;
    public uint currentSample = 0;
    Material addMaterial;

    ////////////// chapter4_3 //////////////
    public BVH bvh;
    public bool useBVH;

    // Start is called before the first frame update
    void Start()
    {
        ////////////// chapter2_1 //////////////
        InitCamera();
        InitRT();
        //////////////// chapter3_4 //////////////
        InitLight();
        InitShader();

        ////////////// chapter2_2 //////////////
        //meshCollector.Init(cs, kernelHandle);
        ////////////// chapter4_3 //////////////
        // 开始 bvh 部分
        if (useBVH)
        {
            bvh.Init(cs, kernelHandle);
            cs.EnableKeyword("BVH");
        }
        else
        {
            meshCollector.Init(cs, kernelHandle);
            cs.DisableKeyword("BVH");
        }

        isInitialized = true;
    }



    // Update is called once per frame
    void Update()
    {
        // 当相机移动了之后，需要重新计算
        if (transform.hasChanged)
        {
            transform.hasChanged = false;
        }
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        CustomRender(destination);
    }

    void CustomRender(RenderTexture destination)
    {
        if (!cs || !isActiveAndEnabled || !isInitialized)
            return;

        //if (rt == null || rt.width != Screen.width || rt.height != Screen.height)
        //////////////// chapter3_5 //////////////
        if (rt == null || convergedRT == null || rt.width != Screen.width || rt.height != Screen.height)
            InitRT();

        UpdateParameters();

        cs.GetKernelThreadGroupSizes(kernelHandle, out uint x, out uint y, out _);
        int groupX = Mathf.CeilToInt((float)Screen.width / x);
        int groupY = Mathf.CeilToInt((float)Screen.height / y);

        cs.Dispatch(kernelHandle, groupX, groupY, 1);
        //////////////// chapter3_5 //////////////
        //Graphics.Blit(rt, destination);
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

    #region chapter2_1
    void InitCamera()
    {
        cam = GetComponent<Camera>();
        cam.allowHDR = true;
    }

    void InitRT()
    {
        CreateRT(ref rt);
        //////////////// chapter3_5 //////////////
        CreateRT(ref convergedRT);
        // Reset sampling
        currentSample = 0;
    }

    void InitShader()
    {
        kernelHandle = cs.FindKernel("CSMain");

        cs.SetInt("width", Screen.width);
        cs.SetInt("height", Screen.height);

        ////////////// chapter3_1 //////////////
        cs.SetTexture(kernelHandle, "skyboxCube", skyboxMat.GetTexture("_Tex"));
    }

    void UpdateParameters()
    {
        cs.SetTexture(kernelHandle, "destination", rt);

        // chapter2_2
        cs.SetMatrix("camera2World", cam.cameraToWorldMatrix);
        cs.SetMatrix("cameraInverseProjection", cam.projectionMatrix.inverse);
        //////////////// chapter3_5 //////////////
        cs.SetVector("pixelOffset", new Vector4(Random.value, Random.value, 0, 0));
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

    private void OnDisable()
    {
        if (rt != null)
            rt.Release();

        if (convergedRT != null)
            convergedRT.Release();
    }
    #endregion

    //////////////// chapter3_4 //////////////
    void InitLight()
    {
        Vector3 dir = mainLight.transform.forward;
        cs.SetVector("lightParameter", new Vector4(dir.x, dir.y, dir.z, mainLight.intensity));
        cs.SetVector("lightColor", mainLight.color);
        cs.SetVector("shadowParameter", new Vector4(shadowColor.r, shadowColor.g, shadowColor.b, shadowIntensity));
    }
}
