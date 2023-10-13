using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PostProcessStack : MonoBehaviour
{
    public ColorCorrection colorCorrection;
    public ColorGrading colorGrading;
    public Bloom bloom;
    public DepthOfField dof;

    public delegate void PostProcessRender(RenderTexture source, RenderTexture destination);
    PostProcessRender renderers;

    public delegate void PostProcessUpdate();
    PostProcessUpdate updates;

    public delegate void PostProcessInit(ComputeShader cs, int kernelHandle);
    PostProcessInit inits;

    public void Init(ComputeShader cs, int kernelHandle)
    {
        Bind();

        if (inits != null)
            inits(cs, kernelHandle);
    }

    public void Render(RenderTexture source, RenderTexture destination)
    {
        if (renderers != null)
            renderers(source, destination);
        else
            Graphics.Blit(source, destination);
    }

    public void UpdateParameter()
    {
        if (updates != null)
            updates();
    }

    void Bind()
    {
        if (colorCorrection != null && colorCorrection.enabled)
        {
            inits += new PostProcessInit(colorCorrection.Init);
            renderers += new PostProcessRender(colorCorrection.RenderImage);
            updates += new PostProcessUpdate(colorCorrection.UpdateParameter);
        }

        if (colorGrading != null && colorGrading.enabled)
        {
            inits += new PostProcessInit(colorGrading.Init);
            renderers += new PostProcessRender(colorGrading.RenderImage);
            updates += new PostProcessUpdate(colorGrading.UpdateParameter);
        }

        if (bloom != null && bloom.enabled)
        {
            inits += new PostProcessInit(bloom.Init);
            renderers += new PostProcessRender(bloom.RenderImage);
            updates += new PostProcessUpdate(bloom.UpdateParameter);
        }

        if (dof != null)
        {
            inits += new PostProcessInit(dof.Init);
            renderers += new PostProcessRender(dof.RenderImage);
            updates += new PostProcessUpdate(dof.UpdateParameter);
        }
    }
}
