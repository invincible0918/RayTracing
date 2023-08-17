using System;
using System.Runtime.InteropServices;
using UnityEngine;

public class DataBuffer<T> : IDisposable where T : struct
{
    public ComputeBuffer computeBuffer;

    public DataBuffer(int size, T initialValue) : this(size)
    {
        T[] array = new T[size];
        for (int i = 0; i < size; i++)
            array[i] = initialValue;

        computeBuffer.SetData(array);
    }

    public DataBuffer(int size)
    {
        computeBuffer = new ComputeBuffer(size, Marshal.SizeOf(typeof(T)), ComputeBufferType.Structured);
    }

    public void SetData(T[] array)
    {
        computeBuffer.SetData(array);
    }

    public void GetData(out T[] array)
    {
        array = new T[computeBuffer.count];
        computeBuffer.GetData(array);
    }

    //public override string ToString()
    //{
    //    GetData(out T[] array);
    //    return Utils.ArrayToString(array).ToString();
    //}

    public void Dispose()
    {
        computeBuffer.Release();
    }
}