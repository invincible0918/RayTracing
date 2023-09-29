using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ColorCorrection : PostProcessBase
{
    [Range(0, 3)]
    public float brightness = 0.96f;
    [Range(0, 3)]
    public float saturation = 1.33f;
    [Range(0, 3)]
    public float contrast = 1.85f;

    Material mat;

    protected override void Start()
    {
        base.Start();

        mat = new Material(Shader.Find("MyCustom/ColorCorrection"));
    }
    public override void RenderImage(RenderTexture source, RenderTexture destination)
    {
        mat.SetFloat("_Brightness", brightness);
        mat.SetFloat("_Saturation", saturation);
        mat.SetFloat("_Contrast", contrast);

        Graphics.Blit(source, destination, mat);
    }
}
