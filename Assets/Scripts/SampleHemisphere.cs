using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SampleHemisphere : MonoBehaviour
{
    public enum SamplingType
    {
        HemiSphere,
        Uniform,
        CosWeighted,
    }
    public SamplingType samplingType = SamplingType.HemiSphere;

    public ComputeShader cs;
    public Shader particleShader;
    public int count = 10000;

    ComputeBuffer cb;
    Material material;

    // Start is called before the first frame update
    void Start()
    {
        cb = new ComputeBuffer(count, sizeof(float) * 3);
        cs.SetBuffer(0, "directions", cb);
        cs.SetFloat("seed", Random.value);

        material = new Material(particleShader);
        material.SetBuffer("cb", cb);
    }

    // Update is called once per frame
    void Update()
    {
        cs.GetKernelThreadGroupSizes(0, out uint x, out uint _, out _);
        int groupX = Mathf.CeilToInt((float)count / x);

        cs.SetInt("samplingType", (int)samplingType);
        cs.SetVector("normal", transform.up);

        cs.Dispatch(0, groupX, 1, 1);
    }

    void OnRenderObject()
    {
        material.SetPass(0);
        Graphics.DrawProceduralNow(MeshTopology.Points, 1, count);
        material.SetPass(1);
        Graphics.DrawProceduralNow(MeshTopology.Points, 1, count);
    }

    private void OnDestroy()
    {
        cb?.Release();
    }
}
