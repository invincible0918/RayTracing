using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Denoise : PostProcessBase
{
    Material mat;
    // Bloom end

    public void RenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, mat);
    }

    void Start()
    {
        mat = new Material(Shader.Find("MyCustom/Denoise"));
    }
}
