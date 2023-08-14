using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
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
            size = r.transform.localScale;
        }
    };
    ComputeBuffer planeBuffer;

    ////////////// chapter2_3 //////////////
    interface Primitive
    {
        public void Init(Renderer r)
        { 
        }
    };

    [StructLayout(LayoutKind.Sequential)]
    struct Sphere : Primitive
    {
        public Vector3 center;
        public float radius;

        public void Init(Renderer r)
        {
            center = r.transform.position;
            radius = r.transform.localScale.x / 2;
        }
    };
    public Transform sphereParent;
    ComputeBuffer sphereBuffer;

    [StructLayout(LayoutKind.Sequential)]
    struct Cube : Primitive
    {
        public Vector3 min;
        public Vector3 max;

        public void Init(Renderer r)
        {
            Vector3 pos = r.transform.position;
            Vector3 halfSize = r.transform.localScale / 2;
            min = pos - halfSize;
            max = pos + halfSize;
        }
    };
    public Transform cubeParent;
    ComputeBuffer cubeBuffer;

    ////////////// chapter2_2 //////////////
    public void Init(ComputeShader cs, int kernelHandle)
    {
        cam = Camera.main;

        InitPlane(cs, kernelHandle);
        ////////////// chapter2_3 //////////////
        InitPrimitive<Sphere>(cs, kernelHandle, ref sphereBuffer, sphereParent, "sphereBuffer", "sphereCount");
        InitPrimitive<Cube>(cs, kernelHandle, ref cubeBuffer, cubeParent, "cubeBuffer", "cubeCount");
    }

    void InitPlane(ComputeShader cs, int kernelHandle)
    {
        Plane[] planes = (from r in planeParent.GetComponentsInChildren<Renderer>(false) where r.gameObject.activeInHierarchy select new Plane(r)).ToArray();

        planeBuffer = new ComputeBuffer(planes.Length, sizeof(float) * 9);
        planeBuffer.SetData(planes);

        cs.SetBuffer(kernelHandle, "planeBuffer", planeBuffer);
        cs.SetInt("planeCount", planes.Length);
    }

    void InitPrimitive<T>(ComputeShader cs, int kernelHandle, ref ComputeBuffer buffer, Transform parent, string bufferName, string bufferCountName) where T : Primitive, new ()
    {
        T[] primitives = null;
        if (parent == null)
            primitives = new T[1] { new T() };
        else
        {
            Dictionary<Renderer, float> di = new Dictionary<Renderer, float>();
            // Sort by distance first
            foreach (Renderer r in parent.GetComponentsInChildren<Renderer>(false))
            {
                if (!r.gameObject.activeInHierarchy)
                    continue;
                float distance = Vector3.Distance(r.transform.position, cam.transform.position);
                di.Add(r, distance);
            }
            // 先示范不排序的结果
            di = di.OrderByDescending(o => o.Value).ToDictionary(o => o.Key, p => p.Value);

            primitives = new T[di.Keys.Count];
            Renderer[] rs = di.Keys.ToArray();

            for (int i = 0; i < rs.Length; ++i)
            {
                primitives[i] = new T();
                primitives[i].Init(rs[i]);
            }
        }

        if (primitives == null || primitives.Length == 0)
            primitives = new T[1] { new T() };

        buffer = new ComputeBuffer(primitives.Length, Marshal.SizeOf(typeof(T)));
        buffer.SetData(primitives);

        cs.SetBuffer(kernelHandle, bufferName, buffer);
        cs.SetInt(bufferCountName, primitives.Length);
    }

    private void OnDestroy()
    {
        planeBuffer?.Release();
        sphereBuffer?.Release();
        cubeBuffer?.Release();
    }
}
