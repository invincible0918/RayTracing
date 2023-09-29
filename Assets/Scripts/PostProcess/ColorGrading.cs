using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ColorGrading : PostProcessBase
{
    public Texture2D lutTex;
    Material mat;

    protected override void Start()
    {
        base.Start();

        mat = new Material(Shader.Find("MyCustom/ColorGrading"));
        mat.SetTexture("_LutTex", lutTex);
    }

    public override void RenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, mat);
    }
}
