using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DepthOfField : PostProcessBase
{
    [Range(0.1f, 1f)]
    public float axisLength = 0.2f;
    [Range(0.01f, 1f)]
    public float lensRadius = 0.1f;
    public float focalLength = 1;
    public Camera cam;

    protected override void Start()
    {
        base.Start();

        if (cam == null)
            cam = Camera.main;
    }

    public override void Init(ComputeShader cs, int kernelHandle)
    {
        base.Init(cs, kernelHandle);

        if (enabled)
            cs.EnableKeyword("DEPTH_OF_FIELD");
        else
            cs.DisableKeyword("DEPTH_OF_FIELD");
    }

    public override void UpdateParameter()
    {
        cs.SetFloat("_LensRadius", lensRadius);
        cs.SetFloat("_FocalLength", focalLength);
    }

    void OnValidate()
    {
        if (!enabled)
            return;

        if (cs != null)
            RayTracing.SetDirty();
    }

    private void OnDrawGizmos()
    {
        if (!enabled || cam == null)
            return;

        Gizmos.color = Color.white;
        Gizmos.matrix = Matrix4x4.TRS(cam.transform.position, cam.transform.rotation, Vector3.one);

        Vector3 aim = Vector3.forward * focalLength;
        Gizmos.DrawLine(Vector3.zero, aim);

        Gizmos.color = Color.red;
        Gizmos.DrawLine(aim, aim + Vector3.right * axisLength);

        Gizmos.color = Color.green;
        Gizmos.DrawLine(aim, aim + Vector3.up * axisLength);

        Gizmos.color = Color.blue;
        Gizmos.DrawLine(aim, aim + Vector3.forward * axisLength);

        Gizmos.matrix = Matrix4x4.identity;
    }
}
