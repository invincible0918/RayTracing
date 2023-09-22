using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class MeshData
{
    public static void Calculate(ComputeShader meshShader, 
        uint dataLength,
        Bounds bounds,
        GraphicsBuffer vertexBuffer,
        GraphicsBuffer indexBuffer,
        ComputeBuffer materialIndexBuffer,
        ComputeBuffer shadowIndexBuffer,
 /*out*/ComputeBuffer aabbBuffer,
 /*out*/ComputeBuffer triangleDataBuffer,
 /*out*/ComputeBuffer triangleIndexBuffer,
 /*out*/ComputeBuffer mortonCodeBuffer)
    {
        int kernelCalculate = meshShader.FindKernel("Calculate");

        meshShader.SetInt("trianglesCount", (int)dataLength);
        meshShader.SetBuffer(kernelCalculate, "vertexBuffer", vertexBuffer);
        meshShader.SetBuffer(kernelCalculate, "indexBuffer", indexBuffer);
        meshShader.SetBuffer(kernelCalculate, "materialIndexBuffer", materialIndexBuffer);
        meshShader.SetBuffer(kernelCalculate, "shadowIndexBuffer", shadowIndexBuffer);

        meshShader.SetVector("encompassingAABBMin", bounds.min);
        meshShader.SetVector("encompassingAABBMax", bounds.max);

        // out
        meshShader.SetBuffer(kernelCalculate, "aabbBuffer", aabbBuffer);
        meshShader.SetBuffer(kernelCalculate, "triangleDataBuffer", triangleDataBuffer);
        meshShader.SetBuffer(kernelCalculate, "triangleIndexBuffer", triangleIndexBuffer);
        meshShader.SetBuffer(kernelCalculate, "mortonCodeBuffer", mortonCodeBuffer);

        meshShader.Dispatch(kernelCalculate, Constants.BLOCK_SIZE, 1, 1);
    }
}
