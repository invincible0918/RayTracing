using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Denoise : PostProcessBase
{
    public RenderTexture buffer0;
    public RenderTexture buffer1;

    Material mat;
    // Bloom end

    public void RenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, buffer0);
        Graphics.Blit(buffer0, buffer1, mat);
        Graphics.Blit(buffer1, destination);
    }

    void Start()
    {
        mat = new Material(Shader.Find("MyCustom/Denoise"));

        buffer0 = CreateTexture(RenderTextureFormat.ARGB32);
        buffer1 = CreateTexture(RenderTextureFormat.ARGB32);
    }

    RenderTexture CreateTexture(RenderTextureFormat format = RenderTextureFormat.ARGBHalf)
    {
        var rt = new RenderTexture(1538, 961, 0, format);
        rt.enableRandomWrite = true;
        rt.Create();
        return rt;
    }
}
