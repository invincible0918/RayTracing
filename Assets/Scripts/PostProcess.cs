using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PostProcess : MonoBehaviour
{
    // Bloom start: https://zhuanlan.zhihu.com/p/525500877

    public enum BloomDebugFlag
    {
        None = 0,
        DownSample = 1,
        UpSample = 2
    }

    [Space(20)]

    public int downSampleStep = 7;

    [Range(3, 15)] public int downSampleBlurSize = 5;
    [Range(0.01f, 10.0f)] public float downSampleBlurSigma = 1.0f;

    [Range(3, 15)] public int upSampleBlurSize = 5;
    [Range(0.01f, 10.0f)] public float upSampleBlurSigma = 1.0f;

    [Space(20)]

    public bool useKarisAverage = false;
    [Range(0.001f, 10.0f)] public float luminanceThreshole = 1.0f;
    [Range(0.001f, 10.0f)] public float bloomIntensity = 1.0f;

    [Space(20)]

    public BloomDebugFlag debugFlag;
    [Range(0, 6)] public int mipDebugIndex = 0;

    Material thresholdMat;
    Material downSampleMat;
    Material upSampleMat;
    Material postMat;
    Material postDebugMat;
    // Bloom end

    public void Render(RenderTexture source, RenderTexture destination)
    {
        Shader.SetGlobalInt("_downSampleBlurSize", downSampleBlurSize);
        Shader.SetGlobalFloat("_downSampleBlurSigma", downSampleBlurSigma);
        Shader.SetGlobalInt("_upSampleBlurSize", upSampleBlurSize);
        Shader.SetGlobalFloat("_upSampleBlurSigma", upSampleBlurSigma);

        Shader.SetGlobalFloat("_luminanceThreshole", luminanceThreshole);
        Shader.SetGlobalFloat("_bloomIntensity", bloomIntensity);

        // 高亮像素筛选
        RenderTexture RT_threshold = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        RT_threshold.filterMode = FilterMode.Bilinear;
        Graphics.Blit(source, RT_threshold, thresholdMat);


        int N = downSampleStep;  // 下采样次数
        int downSize = 2;
        RenderTexture[] RT_BloomDown = new RenderTexture[N];

        // 创建纹理
        for (int i = 0; i < N; i++)
        {
            int w = Screen.width / downSize;
            int h = Screen.height / downSize;
            RT_BloomDown[i] = RenderTexture.GetTemporary(w, h, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            RT_BloomDown[i].filterMode = FilterMode.Bilinear;   // 启用双线性滤波
            downSize *= 2;
        }

        // down sample
        Graphics.Blit(RT_threshold, RT_BloomDown[0], downSampleMat);
        for (int i = 1; i < N; i++)
        {
            Graphics.Blit(RT_BloomDown[i - 1], RT_BloomDown[i], downSampleMat);
        }


        // 创建上采样纹理
        RenderTexture[] RT_BloomUp = new RenderTexture[N];
        for (int i = 0; i < N - 1; i++)
        {
            int w = RT_BloomDown[N - 2 - i].width;
            int h = RT_BloomDown[N - 2 - i].height;
            RT_BloomUp[i] = RenderTexture.GetTemporary(w, h, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            RT_BloomUp[i].filterMode = FilterMode.Bilinear;   // 启用双线性滤波
        }

        // up sample : RT_BloomUp[i] = Blur(RT_BloomDown[N-2-i]) + RT_BloomUp[i-1]
        // RT_BloomDown[N-2-i] 是原始的前一级 mip,尺寸为 (w, h)
        // RT_BloomUp[i-1] 是混合后的前一级 mip, 尺寸为 (w/2, h/2)
        // RT_BloomUp[i] 是当前待处理的 mip, 尺寸为 (w, h)
        Shader.SetGlobalTexture("_PrevMip", RT_BloomDown[N - 1]);
        Graphics.Blit(RT_BloomDown[N - 2], RT_BloomUp[0], upSampleMat);
        for (int i = 1; i < N - 1; i++)
        {
            RenderTexture prev_mip = RT_BloomUp[i - 1];
            RenderTexture curr_mip = RT_BloomDown[N - 2 - i];
            Shader.SetGlobalTexture("_PrevMip", prev_mip);
            Graphics.Blit(curr_mip, RT_BloomUp[i], upSampleMat);
        }


        // pass to shader
        Shader.SetGlobalTexture("_BloomTex", RT_BloomUp[N - 2]);

        // output
        if (debugFlag == BloomDebugFlag.None)
        {
            Graphics.Blit(source, destination, postMat);
        }
        else if (debugFlag == BloomDebugFlag.DownSample)
        {
            Graphics.Blit(RT_BloomDown[mipDebugIndex], destination, postDebugMat);
        }
        else if (debugFlag == BloomDebugFlag.UpSample)
        {
            Graphics.Blit(RT_BloomUp[mipDebugIndex], destination, postDebugMat);
        }


        for (int i = 0; i < N; i++)
        {
            RenderTexture.ReleaseTemporary(RT_BloomDown[i]);
            RenderTexture.ReleaseTemporary(RT_BloomUp[i]);
        }
        RenderTexture.ReleaseTemporary(RT_threshold);
    }

    void Start()
    {
        thresholdMat = new Material(Shader.Find("MyCustom/Threshold"));
        downSampleMat = new Material(Shader.Find("MyCustom/DownSample"));
        upSampleMat = new Material(Shader.Find("MyCustom/UpSample"));
        postMat = new Material(Shader.Find("MyCustom/Post"));
        postDebugMat = new Material(Shader.Find("MyCustom/PostDebug"));

        Camera.main.allowHDR = true;
    }
}
