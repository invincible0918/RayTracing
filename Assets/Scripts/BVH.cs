using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Triangle
{
    public Vector3 v0, v1, v2;
    public int i0, i1, i2;

    public Triangle(Vector3 v0, Vector3 v1, Vector3 v2,
        int i0, int i1, int i2)
    {
        this.v0 = v0;
        this.v1 = v1;
        this.v2 = v2;
        this.i0 = i0;
        this.i1 = i1;
        this.i2 = i2;
    }
}

public class BoundingBox
{
    public Vector3 min = float.MaxValue * Vector3.one;
    public Vector3 max = float.MinValue * Vector3.one;

    public BoundingBox()
    {

    }

    public BoundingBox(Triangle triangle)
    {

    }
}


public class BVHNode
{
    public bool hasLeaf;
    public BoundingBox bb = new();

    public BVHNode left = null;
    public BVHNode right = null;
    public BVHNode parent = null;
    public List<Triangle> triangles = null;

    // Start is called before the first frame update
    public void CreateBVHNode(BVHNode node, ref int index)
    {

    }
}

public class BVHTree
{
    public List<Triangle> triangleList = new List<Triangle>();

    public BVHTree(MeshRenderer[] mrs)
    {
        triangleList.Clear();

        int indexOffset = 0;

        foreach (MeshRenderer mr in mrs)
        {
            Mesh mesh = mr.GetComponent<MeshFilter>().sharedMesh;
            // world space tri verts
            Vector3[] vertices = mesh.vertices.Select(v => mr.transform.TransformPoint(v)).ToArray();
            int[] indices = mesh.triangles;

            for (int i = 0; i < indices.Length; i += 3)
            {
                triangleList.Add(new Triangle(
                    vertices[indices[i]],
                    vertices[indices[i + 1]],
                    vertices[indices[i + 2]],
                    indices[i] + indexOffset,
                    indices[i + 1] + indexOffset,
                    indices[i + 2] + indexOffset));
            }

            // index offsets
            indexOffset += indices.Length;
        }
    }

    public void BuildNode(List<Triangle> tris)
    {

    }

    //BoundingBox BoundingBoxFromTris(List<Triangle> tris)
    //{
    //    BoundingBox bb = new BoundingBox();
    //    foreach(Triangle tri in tris)
    //    {

    //    }
    //}
}
