using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LightImportanceSampling : MonoBehaviour
{
    public Transform sphereLightParent;
    public Transform areaLightParent;
    public Transform discLightParent;

    ComputeBuffer sphereLightBuffer;
    ComputeBuffer areaLightBuffer;
    ComputeBuffer discLightBuffer;

    struct SphereLight
    {
        public Vector3 position;
        public float radius;
        public SphereLight(Transform trans)
        {
            position = trans.position;
            radius = trans.GetComponent<SphereCollider>().radius * trans.localScale.x;
        }
    }

    struct AreaLight
    {
        public Vector3 position;
        public Vector3 normal;
        public Vector3 up;
        public Vector2 size;
        public AreaLight(Transform trans)
        {
            position = trans.position;
            normal = -trans.forward;
            up = trans.up;
            size = trans.GetComponent<BoxCollider>().size;
            size.x *= trans.localScale.x;
            size.y *= trans.localScale.y;
        }
    }

    struct DiscLight
    {
        public Vector3 position;
        public Vector3 normal;
        public float radius;
        public DiscLight(Transform trans)
        {
            position = trans.position;
            normal = -trans.forward;
            radius = trans.GetComponent<SphereCollider>().radius * trans.localScale.x;
        }
    }

    public void Init(ComputeShader shader, int handle)
    {
        ComputeShader rayTracingShader = shader;
        int kernelHandle = handle;

        List<SphereLight> sphereLightList = new List<SphereLight>(from light in sphereLightParent.GetComponentsInChildren<Transform>(false) where light != sphereLightParent select new SphereLight(light));    // position, radius,
        List<AreaLight> areaLightList = new List<AreaLight>(from light in areaLightParent.GetComponentsInChildren<Transform>(false) where light != areaLightParent select new AreaLight(light));      // position, forward, width, height, 8 float
        List<DiscLight> discLightList = new List<DiscLight>(from light in discLightParent.GetComponentsInChildren<Transform>(false) where light != discLightParent select new DiscLight(light));      // position, forward, radius, 7 float

        if (sphereLightList.Count > 0)
        {
            rayTracingShader.EnableKeyword("SPHERE_LIGHT");

            sphereLightBuffer = new ComputeBuffer(sphereLightList.Count, sizeof(float) * 4);
            sphereLightBuffer.SetData(sphereLightList);
            rayTracingShader.SetBuffer(kernelHandle, "sphereLightBuffer", sphereLightBuffer);
            rayTracingShader.SetInt("sphereLightCount", sphereLightList.Count);
        }
        else
            rayTracingShader.DisableKeyword("SPHERE_LIGHT");

        if (areaLightList.Count > 0)
        {
            rayTracingShader.EnableKeyword("AREA_LIGHT");

            areaLightBuffer = new ComputeBuffer(areaLightList.Count, sizeof(float) * 11);
            areaLightBuffer.SetData(areaLightList);
            rayTracingShader.SetBuffer(kernelHandle, "areaLightBuffer", areaLightBuffer);
            rayTracingShader.SetInt("areaLightCount", areaLightList.Count);
        }
        else
            rayTracingShader.DisableKeyword("AREA_LIGHT");

        if (discLightList.Count > 0)
        {
            rayTracingShader.EnableKeyword("DISC_LIGHT");

            discLightBuffer = new ComputeBuffer(discLightList.Count, sizeof(float) * 7);
            discLightBuffer.SetData(discLightList);
            rayTracingShader.SetBuffer(kernelHandle, "discLightBuffer", discLightBuffer);
            rayTracingShader.SetInt("discLightCount", discLightList.Count);
        }
        else
            rayTracingShader.DisableKeyword("DISC_LIGHT");
    }

    private void OnDestroy()
    {
        sphereLightBuffer?.Release();
        areaLightBuffer?.Release();
        discLightBuffer?.Release();
    }
}
