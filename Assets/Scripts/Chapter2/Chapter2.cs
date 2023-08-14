using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// 需要相机的 OnRenderImage
[RequireComponent(typeof(Camera))]
public class Chapter2 : MonoBehaviour
{
    ////////////// chapter2_1 //////////////
    public ComputeShader cs;
    public RenderTexture rt;

    int kernelHandle;
    Camera cam;
    bool isInitialized;

    ////////////// chapter2_2 //////////////
    public MeshCollector meshCollector;

    // Start is called before the first frame update
    void Start()
    {
        ////////////// chapter2_1 //////////////
        InitCamera();
        InitRT();
        InitShader();
        ////////////// chapter2_2 //////////////
        meshCollector.Init(cs, kernelHandle);

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

        if (rt == null || rt.width != Screen.width || rt.height != Screen.height)
            InitRT();

        UpdateParameters();

        cs.GetKernelThreadGroupSizes(kernelHandle, out uint x, out uint y, out _);
        int groupX = Mathf.CeilToInt((float)Screen.width / x);
        int groupY = Mathf.CeilToInt((float)Screen.height / y);

        cs.Dispatch(kernelHandle, groupX, groupY, 1);
        Graphics.Blit(rt, destination);
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
    }

    void InitShader()
    {
        kernelHandle = cs.FindKernel("CSMain");

        cs.SetInt("width", Screen.width);
        cs.SetInt("height", Screen.height);
    }

    void UpdateParameters()
    {
        cs.SetTexture(kernelHandle, "destination", rt);

        // chapter2_2
        cs.SetMatrix("camera2World", cam.cameraToWorldMatrix);
        cs.SetMatrix("cameraInverseProjection", cam.projectionMatrix.inverse);

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
    #endregion
}
