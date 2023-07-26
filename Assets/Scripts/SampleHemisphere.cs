using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SampleHemisphere : MonoBehaviour
{
    public enum SampleType
    {
        Semi,
        Uniform,
        CosWeighted,
        Light,
        BRDF,
        MultipleImportance,
    }
    public SampleType sampleType;

    public ComputeShader cs;
    public Shader particleShader;
    public int count = 100;
    public GameObject arrow;

    #region Light
    public enum LightType
    {
        SkyLight,
        SphereLight,
        AeraLight
    }
    public LightType lightType = LightType.SphereLight;
    public float sphereLightRadius;

    public GameObject sphereLight;
    public GameObject areaLight;
    #endregion

    ComputeBuffer cb;
    Vector3[] directions;

    Material material;

    // http://corysimon.github.io/articles/uniformdistn-on-sphere/
    // Start is called before the first frame update
    void Start()
    {
        cb = new ComputeBuffer(count, sizeof(float) * 3);
        directions = new Vector3[count];
        cs.SetBuffer(0, "directions", cb);
        cs.SetFloat("seed", Random.value);
        material = new Material(particleShader);
        material.SetBuffer("cb", cb);

        sphereLightRadius = sphereLight.GetComponent<SphereCollider>().radius * sphereLight.transform.localScale.x;
    }

    private void Update()
    {
        cs.GetKernelThreadGroupSizes(0, out uint x, out uint _, out _);

        int groupX = Mathf.CeilToInt((float)count / x);

        cs.SetInt("sampleType", (int)sampleType);
        cs.SetVector("normal", arrow.transform.up);
        // light start
        cs.SetVector("sphereLight", new Vector4(sphereLight.transform.position.x,
            sphereLight.transform.position.y,
            sphereLight.transform.position.z,
            sphereLightRadius));
        // light end

        cs.Dispatch(0, groupX, 1, 1);
        cb.GetData(directions);
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
