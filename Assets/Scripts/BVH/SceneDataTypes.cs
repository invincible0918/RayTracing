using System.Runtime.InteropServices;
using UnityEngine;

[StructLayout(LayoutKind.Sequential, Pack = 16)]
public struct AABB
{
    public Vector3 min;
    public float _dummy0;
    public Vector3 max;
    public float _dummy1;

    //public override string ToString()
    //{
    //    return $"min:{min}, max:{max}, dummy0: {_dummy0}, dummy1: {_dummy1};\n";
    //}

    public static AABB NullAABB = new AABB()
    {
        min = Vector3.zero,
        _dummy0 = 0,
        max = Vector3.zero,
        _dummy1 = 0,
    };
}

[StructLayout(LayoutKind.Sequential, Pack = 16)]
public struct Triangle
{
    // TODO texture index, etc
    public Vector3 point0;
    float _dummy0;
    public Vector3 point1;
    float _dummy1;
    public Vector3 point2;
    float _dummy2;
    public Vector2 uv0;
    public Vector2 uv1;
    public Vector2 uv2;
    Vector2 _dummy3;

    public Vector3 normal0;
    float _dummy4;
    public Vector3 normal1;
    float _dummy5;
    public Vector3 normal2;
    float _dummy6;

    Vector3 tangent0;
    float _dummy7;

    Vector3 tangent1;
    float _dummy8;

    Vector3 tangent2;
    float _dummy9;

    int materialIndex;
    Vector3 _dummy10;

    //public override string ToString()
    //{
    //    //return $"point0:{point0}, point1:{point1}, point2:{point2}, normal0:{normal0}, normal1:{normal1}, normal2:{normal2}, materialIndex:{materialIndex}\n";
    //    return $"{materialIndex},";
    //}

    public static Triangle NullTriangle = new Triangle()
    {
        point0 = Vector3.zero,
        _dummy0 = 0,
        point1 = Vector3.zero,
        _dummy1 = 0,
        point2 = Vector3.zero,
        _dummy2 = 0,
        uv0 = Vector2.zero,
        uv1 = Vector2.zero,
        uv2 = Vector2.zero,
        _dummy3 = Vector2.zero,

        normal0 = Vector3.zero,
        _dummy4 = 0,
        normal1 = Vector3.zero,
        _dummy5 = 0,
        normal2 = Vector3.zero,
        _dummy6 = 0,

        tangent0 = Vector3.zero,
        _dummy7 = 0,

        tangent1 = Vector3.zero,
        _dummy8 = 0,

        tangent2 = Vector3.zero,
        _dummy9 = 0,

        materialIndex = 0,
        _dummy10 = Vector3.zero,
    };
}

[StructLayout(LayoutKind.Sequential, Pack = 16)]
public struct InternalNode
{
    public uint leftNode;
    public uint leftNodeType;
    public uint rightNode;
    public uint rightNodeType;
    public uint parent;
    public uint index;

    //public override string ToString()
    //{
    //    string GetNodeType(uint type)
    //    {
    //        return type == 0 ? "I" : "L";
    //    }

    //    return $"index:{index}, left:{leftNode} {GetNodeType(leftNodeType)}, right:{rightNode} {GetNodeType(rightNodeType)}, parent:{parent}\n";
    //}
    
    public static InternalNode NullLeaf = new InternalNode()
    {
        leftNode = 0xFFFFFFFF,
        leftNodeType = 0xFFFFFFFF,
        rightNode = 0xFFFFFFFF,
        rightNodeType = 0xFFFFFFFF,
        parent = 0xFFFFFFFF,
        index = 0xFFFFFFFF
    };
};

[StructLayout(LayoutKind.Sequential, Pack = 16)]
public struct LeafNode
{
    public uint parent;
    public uint index;

    //public override string ToString()
    //{
    //    return $"index:{index}, parent:{parent}\n";
    //}

    public static LeafNode NullLeaf = new LeafNode()
    {
        parent = 0xFFFFFFFF,
        index = 0xFFFFFFFF
    };
};