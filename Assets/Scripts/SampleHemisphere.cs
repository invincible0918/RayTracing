using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SampleHemisphere : MonoBehaviour
{
    public ComputeShader cs;
    public int count = 100;
    public float radius = 10f;
    public bool isCosineSample;

    ComputeBuffer cb;
    Vector3[] directions;


    // http://corysimon.github.io/articles/uniformdistn-on-sphere/
    // Start is called before the first frame update
    void Start()
    {
        cb = new ComputeBuffer(count, sizeof(float) * 3);
        directions = new Vector3[count];
        cs.SetBuffer(0, "directions", cb);
        cs.SetBool("isCosineSample", isCosineSample);
        cs.SetFloat("_Seed", Random.value);

        cb.GetData(directions);
    }

    private void Update()
    {
        cs.GetKernelThreadGroupSizes(0, out uint x, out uint _, out _);

        int groupX = Mathf.CeilToInt((float)count / x);

        cs.SetBool("isCosineSample", isCosineSample);
        cs.SetFloat("_Seed", Random.value);
        cs.Dispatch(0, groupX, 1, 1);
    }


    private void OnDrawGizmos()
    {
        Gizmos.DrawWireSphere(Vector3.zero, radius);
        if (directions != null)
        {
            for (int i = 0; i < directions.Length; ++i)
            {
                Gizmos.DrawLine(Vector3.zero, directions[i] * radius);
            }
        }
    }

    private void OnDestroy()
    {
        cb?.Release();
    }
}
