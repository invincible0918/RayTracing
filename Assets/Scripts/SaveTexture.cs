using System.IO;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

public class SaveTexture : MonoBehaviour
{
    public RayTracing rayTracing;
    public CameraMovement cameraMovement;
    public bool autoSave = false;
    public uint autoSaveSPP = 0;

    [ContextMenu("Save")]
    void Save()
    {
        if (rayTracing.postProcessRT != null)
            StartCoroutine(SavePNG(rayTracing.postProcessRT));
        else
            StartCoroutine(SavePNG(rayTracing.convergedRT));
    }

    IEnumerator SavePNG(RenderTexture rt)
    {
        Texture2D texture = new Texture2D(rt.width, rt.height, TextureFormat.RGB24, false, false);
        RenderTexture.active = rt;
        texture.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        texture.Apply();
        yield return new WaitForEndOfFrame();

        Color[] linearColors = texture.GetPixels();
        Color[] sColors = new Color[linearColors.Length];

        for (int i = 0; i < linearColors.Length; ++i)
            sColors[i] = LinearToSRGB(linearColors[i]);
        texture.SetPixels(sColors);
        texture.Apply();
        byte[] bytes = texture.EncodeToPNG();

        var dt = System.DateTime.Now;
        string textureName = dt.ToString("yyyy_MM_dd_HH_mm_ss");
        string path = $"{Application.dataPath}/Outputs/{textureName}.png";
        File.WriteAllBytes(path, bytes);
        Destroy(texture);
    }

    void Update()
    {
        if (!autoSave)
            return;

        if (rayTracing.samplePrePixel % autoSaveSPP == (autoSaveSPP - 1))
        {
            cameraMovement.PlayAtFrame();
            StartCoroutine(SavePNG(rayTracing.convergedRT));
        }
    }

    Color LinearToSRGB(Color col)
    {
        float r = Mathf.Clamp(col.r, 0.0f, 1.0f);
        float g = Mathf.Clamp(col.g, 0.0f, 1.0f);
        float b = Mathf.Clamp(col.b, 0.0f, 1.0f);
        float a = Mathf.Clamp(col.a, 0.0f, 1.0f);

        Color c = new Color()
        {
            r = LinearToSRGB(r),
            g = LinearToSRGB(g),
            b = LinearToSRGB(b),
            a = LinearToSRGB(a)
        };
        return c;
    }

    float LinearToSRGB(float v)
    {
        float c = Mathf.Clamp(v, 0.0f, 1.0f);

        return Mathf.Lerp(
            Mathf.Pow(v, 1.0f / 2.4f) * 1.055f - 0.055f,
            v * 12.92f,
            LessThan(v, 0.0031308f)
        );
    }

    float LessThan(float f, float value)
    {
        return f < value ? 1.0f : 0.0f;
    }

}
