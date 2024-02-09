using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ShowCamera : MonoBehaviour
{
    public RayTracing rayTracing;
    public SaveTexture saveTexture;

    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        if (rayTracing.samplePrePixel > 200)
        {
            saveTexture.Save();
            transform.localEulerAngles += Vector3.up * 0.1f; // new Vector3(0, 0.1f, 0);
            RayTracing.SetDirty();
        }
    }
}
