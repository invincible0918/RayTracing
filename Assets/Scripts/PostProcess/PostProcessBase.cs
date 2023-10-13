using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PostProcessBase : MonoBehaviour
{
    protected ComputeShader cs;
    protected int kernelHandle;

    protected virtual void Start()
    {
        Camera.main.allowHDR = true;
    }

    protected virtual void OnEnable()
    {
    }

    protected virtual void OnDisable()
    {
    }

    public virtual void Init(ComputeShader cs, int kernelHandle)
    {
        this.cs = cs;
        this.kernelHandle = kernelHandle;
    }

    public virtual void RenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination);
    }

    public virtual void UpdateParameter()
    {
    }
}
