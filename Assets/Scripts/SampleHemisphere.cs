using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SampleHemisphere : MonoBehaviour
{
    public Transform inTrans;
    public Transform outTrans;

    // http://corysimon.github.io/articles/uniformdistn-on-sphere/
    // Start is called before the first frame update
    void Start()
    {
    }

    Vector3 DoIt(Vector3 normal)
    { 
        // Uniformly sample hemisphere direction
        float cosTheta = Random.value;
        float sinTheta = Mathf.Sqrt(Mathf.Max(0.0f, 1.0f - cosTheta * cosTheta));
        float phi = 2 * Mathf.PI * Random.value;
        Vector3 tangentSpaceDir = new Vector3(Mathf.Cos(phi) * sinTheta, Mathf.Sin(phi) * sinTheta, cosTheta);
        // Transform direction to world space
        return GetTangentSpace(normal).MultiplyVector(tangentSpaceDir);
    }

    Matrix4x4 GetTangentSpace(Vector3 normal)
    {
        // Choose a helper vector for the cross product
        Vector3 helper = new Vector3(1, 0, 0);
        if (Mathf.Abs(normal.x) > 0.99f)
            helper = new 
                Vector3(0, 0, 1);
        // Generate vectors
        Vector3 tangent = Vector3.Normalize(Vector3.Cross(normal, helper));
        Vector3 binormal = Vector3.Normalize(Vector3.Cross(normal, tangent));
        Matrix4x4 mat = Matrix4x4.identity;
        mat.SetRow(0, tangent);
        mat.SetRow(1, binormal);
        mat.SetRow(2, normal);
        return mat;
    }


    [ContextMenu("Test")]
    void Test()
    {
        Vector3 a = new Vector3(0, 0, 1);
        Matrix4x4 mat = Matrix4x4.identity;
        mat.SetTRS(Vector3.zero, inTrans.localRotation, Vector3.one);

        Vector3 outDir = DoIt(mat.MultiplyVector(a));
        outTrans.localRotation = Quaternion.FromToRotation(a, outDir);
    }
}
