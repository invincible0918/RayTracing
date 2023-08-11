using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MeshCollector : MonoBehaviour
{
    ////////////// chapter2_2 //////////////
    public Transform planeParent;

    Camera cam;

    struct Plane
    {
        public Vector3 normal;
        public Vector3 position;
        public Vector3 size;

        public Plane(Renderer r)
        {
            normal = r.transform.up;
            position = r.transform.position;
            Vector3 bcSize = r.transform.GetComponent<BoxCollider>().size;
            Vector3 scale = r.transform.localScale;
            size = new Vector3(bcSize.x * scale.x, bcSize.y * scale.y, bcSize.z * scale.z);
        }
    };
    ComputeBuffer planeBuffer;

    public void Init(ComputeShader cs, int kernelHandle)
    {
        cam = Camera.main;

        InitPlanes(cs, kernelHandle);
    }

    void InitPlanes(ComputeShader cs, int kernelHandle)
    {
        Plane[] planes = null;
        if (planeParent == null)
        {
            planes = new Plane[1];
        }
        else
        {
            Dictionary<Renderer, float> di = new Dictionary<Renderer, float>();
            // Sort by distance first
            foreach (Renderer r in planeParent.GetComponentsInChildren<Renderer>(false))
            {
                if (!r.gameObject.activeInHierarchy)
                    continue;
                float distance = Vector3.Distance(r.transform.position, cam.transform.position);
                di.Add(r, distance);
            }
            //di = di.OrderByDescending(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

            planes = new Plane[di.Keys.Count];
            Renderer[] rs = di.Keys.ToArray();

            for (int i = 0; i < rs.Length; ++i)
                planes[i] = new Plane(rs[i]);
        }

        planeBuffer = new ComputeBuffer(planes.Length, sizeof(float) * 9);
        planeBuffer.SetData(planes);

        cs.SetBuffer(kernelHandle, "planeBuffer", planeBuffer);
        cs.SetInt("planeCount", planes.Length);
    }

    private void OnDestroy()
    {
        planeBuffer?.Release();
    }
}
