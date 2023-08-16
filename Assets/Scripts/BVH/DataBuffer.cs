using System;
using System.Runtime.InteropServices;
using UnityEngine;

public class DataBuffer<T> : IDisposable where T : struct
{
    public ComputeBuffer DeviceBuffer => deviceBuffer;
    public T[] LocalBuffer => localBuffer;

    private readonly ComputeBuffer deviceBuffer;
    private readonly T[] localBuffer;
    private bool synced;

    public DataBuffer(int size, T initialValue) : this(size)
    {
        for (int i = 0; i < size; i++)
        {
            localBuffer[i] = initialValue;
        }

        deviceBuffer.SetData(localBuffer);
        synced = true;
    }

    public DataBuffer(int size)
    {
        deviceBuffer = new ComputeBuffer(size, Marshal.SizeOf(typeof(T)), ComputeBufferType.Structured);
        localBuffer = new T[size];
        synced = false;
    }

    public T this[uint i]
    {
        get
        {
            if (!synced)
            {
                GetData();
            }

            return localBuffer[i];
        }
        set
        {
            localBuffer[i] = value;
            synced = false;
        }
    }

    public void GetData()
    {
        deviceBuffer.GetData(localBuffer);
        synced = true;
    }

    public void Sync()
    {
        deviceBuffer.SetData(localBuffer);
        synced = true;
    }

    public override string ToString()
    {
        if (!synced)
        {
            GetData();
        }

        return Utils.ArrayToString(localBuffer).ToString();
    }

    public void Dispose()
    {
        deviceBuffer.Release();
    }
}