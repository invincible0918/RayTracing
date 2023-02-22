using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SampleHemisphere : MonoBehaviour
{
    ComputeShader cs;

    public Transform inTrans;
    public Transform outTrans;

    public int lineCount = 10000;

    // http://corysimon.github.io/articles/uniformdistn-on-sphere/
    // Start is called before the first frame update
    void Start()
    {
    }

    private void Update()
    {
        cs.Dispatch(0, Mathf.CeilToInt(lineCount / 8f), 1, 1);
    }
}
