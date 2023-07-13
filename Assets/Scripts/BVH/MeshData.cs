using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class MeshData
{
    public static void Calculate(uint dataLength,
        GraphicsBuffer vertexBuffer,
        GraphicsBuffer indexBuffer,
        ComputeBuffer mortonCodeBuffer,
        ComputeBuffer triangleIndexBuffer,
        ComputeBuffer aabbBuffer,
        ComputeBuffer triangleDataBuffer,
        ComputeBuffer materialIndexBuffer,
        Bounds bounds,
        ComputeShader meshShader)
    {
        int kernelCalculate = meshShader.FindKernel("Calculate");

        //// Byte Address Buffer, 读写的时候，把buffer里的内容（byte）做偏移，可用于寻址
        //// 对应的是HLSL的ByteAddressBuffer，RWByteAddressBuffer
        //// 4 (32-bit indices)
        //// IndexFormat.UInt16: 2 byte, 范围 0～65535 
        //// IndexFormat.UInt32: 4 byte, 范围 0～4294967295 
        //GraphicsBuffer indexBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Index | GraphicsBuffer.Target.Raw, triangles.Length, sizeof(int));
        //indexBuffer.SetData(triangles);

        //GraphicsBuffer vertexBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Vertex | GraphicsBuffer.Target.Raw, vertices.Length, 3 * sizeof(float));
        //vertexBuffer.SetData(vertices);

        //ComputeBuffer materialIndexBuffer = new ComputeBuffer(triangleIndexBuffer.count, sizeof(uint));
        //materialIndexBuffer.SetData(materialIndices);

        meshShader.SetBuffer(kernelCalculate, "indexBuffer", indexBuffer);
        meshShader.SetBuffer(kernelCalculate, "vertexBuffer", vertexBuffer);
        meshShader.SetBuffer(kernelCalculate, "materialIndexBuffer", materialIndexBuffer);
        meshShader.SetBuffer(kernelCalculate, "aabbBuffer", aabbBuffer);
        meshShader.SetBuffer(kernelCalculate, "triangleDataBuffer", triangleDataBuffer);
        meshShader.SetBuffer(kernelCalculate, "triangleIndexBuffer", triangleIndexBuffer);
        meshShader.SetBuffer(kernelCalculate, "mortonCodeBuffer", mortonCodeBuffer);
        meshShader.SetInt("trianglesCount", (int)dataLength);
        meshShader.SetVector("encompassingAABBMin", bounds.min);
        meshShader.SetVector("encompassingAABBMax", bounds.max);

        meshShader.Dispatch(kernelCalculate, (int)dataLength, 1, 1);

        // 使用以下写法则和bvh脚本中一样了，但是compute shader中需要修改
        //meshShader.Dispatch(kernelCalculate, Constants.BLOCK_SIZE, 1, 1);
        //void Calculate(uint3 tid : SV_GroupThreadID, uint3 gid : SV_GroupID)
        //{
        //      //const uint id = gid.x * THREADS_PER_BLOCK + tid.x;
        //      if (id >= trianglesCount)
        //          return;
        //      AllMemoryBarrierWithGroupSync();
        //            ...
        //}
    }
}
