using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PostProcessStack : MonoBehaviour
{
    public Denoise denoise;
    public Bloom bloom;

    public delegate void PostProcessRender(RenderTexture source, RenderTexture destination);
    PostProcessRender renderers;

    public void Render(RenderTexture source, RenderTexture destination)
    {
        if (renderers != null)
            renderers(source, destination);
        else
            Graphics.Blit(source, destination);
    }

    void Start()
    {
        if (denoise != null)
            renderers += new PostProcessRender(denoise.RenderImage);
        
        if (bloom != null)
            renderers += new PostProcessRender(bloom.RenderImage);
    }
}
