using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Bloom : PostProcessBase
{
    [Range(0.001f, 20.0f)]
    public float luminanceThreshold = 1f;
    Material thresholdMat;

    [Space(20)]
    public int downSampleStep = 7;
    [Range(3, 15)] 
    public int downSampleBlurSize = 5;
    [Range(0.01f, 10.0f)] 
    public float downSampleBlurSigma = 1.0f;
    Material downSampleMat;

    [Space(20)]
    [Range(3, 15)]
    public int upSampleBlurSize = 5;
    [Range(0.01f, 10.0f)]
    public float upSampleBlurSigma = 1.0f;
    Material upSampleMat;

    [Space(20)]
    [Range(0.001f, 10.0f)] 
    public float bloomIntensity = 1.0f;
    Material bloomMat;

    protected override void Start()
    {
        base.Start();

        thresholdMat = new Material(Shader.Find("MyCustom/Threshold"));
        downSampleMat = new Material(Shader.Find("MyCustom/DownSample"));
        upSampleMat = new Material(Shader.Find("MyCustom/UpSample"));
        bloomMat = new Material(Shader.Find("MyCustom/Bloom"));
    }

    public override void RenderImage(RenderTexture source, RenderTexture destination)
    {
        // Step 1. 筛选出高亮的像素
        thresholdMat.SetFloat("_LuminanceThreshold", luminanceThreshold);

        RenderTexture thresholdRT = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        thresholdRT.filterMode = FilterMode.Bilinear;

        Graphics.Blit(source, thresholdRT, thresholdMat);
        //Graphics.Blit(thresholdRT, destination, thresholdMat);

        // Step 2. Down sample
        downSampleMat.SetInt("_DownSampleBlurSize", downSampleBlurSize);
        downSampleMat.SetFloat("_DownSampleBlurSigma", downSampleBlurSigma);

        int n = downSampleStep;
        int downSize = 2;
        RenderTexture[] bloomDowns = new RenderTexture[n];
        for (int i = 0; i < n; ++i)
        {
            int w = Screen.width / downSize;
            int h = Screen.height / downSize;

            bloomDowns[i] = RenderTexture.GetTemporary(w, h, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            bloomDowns[i].filterMode = FilterMode.Bilinear;
            downSize *= 2;
        }
        Graphics.Blit(thresholdRT, bloomDowns[0], downSampleMat);
        for (int i = 1; i < n; ++i)
        {
            Graphics.Blit(bloomDowns[i - 1], bloomDowns[i], downSampleMat);
        }
        //Graphics.Blit(bloomDowns[n-1], destination);

        // Step 3. Up sample
        upSampleMat.SetInt("_UpSampleBlurSize", upSampleBlurSize);
        upSampleMat.SetFloat("_UpSampleBlurSigma", upSampleBlurSigma);
        upSampleMat.SetTexture("_PrevMip", bloomDowns[n - 1]);

        RenderTexture[] bloomUps = new RenderTexture[n];
        for (int i = 0; i < n - 1; ++i)
        {
            int w = bloomDowns[n - 2 - i].width;
            int h = bloomDowns[n - 2 - i].height;
            bloomUps[i] = RenderTexture.GetTemporary(w, h, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            bloomUps[i].filterMode = FilterMode.Bilinear;
        }

        // up sample: bloomUps[i] = blur(bloomDowns[n - 2 - i]) + bloomUps[i-1]
        // bloomDowns[n - 2 - i]： 是原始的前一级 mip，尺寸是 (w, h)
        // bloomUps[i-1]: 是混合后的前一级 mip，尺寸是(w/2, h/2)
        // bloomUps[i]: 是当前待处理的mip, 尺寸是(w, h)
        Graphics.Blit(bloomDowns[n - 2], bloomUps[0], upSampleMat);
        for (int i = 1; i < n - 1; ++i)
        {
            RenderTexture prevMip = bloomUps[i - 1];
            RenderTexture curMip = bloomDowns[n - 2 - i];
            upSampleMat.SetTexture("_PrevMip", prevMip);
            Graphics.Blit(curMip, bloomUps[i], upSampleMat);
        }
        //Graphics.Blit(bloomUps[4], destination);

        // Step 4.传递 bloom 到原图
        bloomMat.SetFloat("_BloomIntensity", bloomIntensity);
        bloomMat.SetTexture("_BloomTex", bloomUps[n - 2]);

        Graphics.Blit(source, destination, bloomMat);

        for (int i = 0; i < n; ++i)
        {
            RenderTexture.ReleaseTemporary(bloomDowns[i]);
            RenderTexture.ReleaseTemporary(bloomUps[i]);
        }
        RenderTexture.ReleaseTemporary(thresholdRT);
    }
}
