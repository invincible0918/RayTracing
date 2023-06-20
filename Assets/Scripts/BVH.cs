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

    public BoundingBox(Vector3 min, Vector3 max)
    {
        this.min = min;
        this.max = max;
    }

    public BoundingBox(Triangle triangle)
    {
        min = Vector3.Min(Vector3.Min(triangle.v0, triangle.v1), triangle.v2);
        max = Vector3.Max(Vector3.Max(triangle.v0, triangle.v1), triangle.v2);
    }

    public BoundingBox Union(BoundingBox bb)
    {
        return new BoundingBox(Vector3.Min(min, bb.min), Vector3.Max(max, bb.max));
    }
}


public class BVHNode
{
    public bool hasLeaf;

    public BVHNode left = null;
    public BVHNode right = null;
    public BVHNode parent = null;
    public List<Triangle> triangles = null;

    // Start is called before the first frame update
    public void CreateBVHNode(BVHNode node, ref int index)
    {

    }
}

public class BVHTree : MonoBehaviour
{
    public ComputeShader cs;

    public List<Triangle> triangleList = new List<Triangle>();

    int treeConstructorKernel;
    ComputeBuffer mortonCodeCB;


    int bvhConstructorKernel;

    enum Axis
    {
        X,
        Y,
        Z
    }

    Axis axis;

    public BVHTree(MeshRenderer[] mrs)
    {
        triangleList.Clear();

        int indexOffset = 0;

        // 1.0 create triangle structure
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

        // 2.0 create bvh tree recursively
        BuildNode(triangleList);

        // 使用compute shader来计算
        InitShader();
    }

    public void BuildNode(List<Triangle> tris)
    {
        BoundingBox bb = BoundingBoxFromTris(tris);

        // split bb by longest axis
        // 开始划分
        // 比较基础的
        /* 中点划分和等量划分
        首先我们找出现存的所有包围盒的中点构成的包围盒，找出 span 最大的维度作为分割的维度。
        中点划分就选择这个区间的中点，左侧和右侧分别放在一起，
        等量划分则在这个维度上分割且保证两部分物体的数目完全相等，都是比较基本的划分方式。
        */

    }

    BoundingBox BoundingBoxFromTris(List<Triangle> tris)
    {
        BoundingBox bb = new BoundingBox();
        foreach(Triangle tri in tris)
            bb = bb.Union(new BoundingBox(tri));
        return bb;
    }

    Axis GetLongest(BoundingBox bb)
    {
        Vector3 d = bb.max - bb.min;
        if (d.x > d.y && d.x > d.z)
            return Axis.X;

        if (d.y > d.z)
            return Axis.Y;

        return Axis.Z;
    }

    void InitShader()
    {
        treeConstructorKernel = cs.FindKernel("TreeConstructor");
        bvhConstructorKernel = cs.FindKernel("BVHConstructor");
    }
}
