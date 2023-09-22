using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CustomMaterialInfo : MonoBehaviour
{
    public BVH bvh;
    public Transform parent;

    Material[] materials;
    float[] ratios;

    // Start is called before the first frame update
    void Start()
    {
        materials = (from r in parent.GetComponentsInChildren<Renderer>() select r.sharedMaterial).ToArray();
        ratios = (from r in parent.GetComponentsInChildren<Renderer>() select float.Parse(r.name.Split("_")[1]) / 5.0f).ToArray();
    }

    public void OnMaterialChanged(int index)
    {
        float[] metallicArray = new float[6];
        float[] smoothnessArray = new float[6];
        float[] transparentArray = new float[6];
        float[] iorArray = new float[6];
        // 使用标记位来区分不同材质, 0：default opacity, 1: transparent, 2: emission, 3: clear coat
        int materialType = 0;

        switch (index)
        {
            case 0:
                metallicArray = new float[6] { 0, 0, 0, 0, 0, 0 };
                smoothnessArray = ratios;
                transparentArray = new float[6] { -1, -1, -1, -1, -1, -1 };
                iorArray = new float[6] { 1, 1, 1, 1, 1, 1 };
                materialType = 0;
                break;
            case 1:
                metallicArray = new float[6] { 1, 1, 1, 1, 1, 1 };
                smoothnessArray = ratios;
                transparentArray = new float[6] { -1, -1, -1, -1, -1, -1 };
                iorArray = new float[6] { 1, 1, 1, 1, 1, 1 };
                materialType = 0;
                break;
            case 2:
                metallicArray = new float[6] { 0, 0, 0, 0, 0, 0 };
                smoothnessArray = ratios;
                transparentArray = new float[6] { 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f };
                iorArray = new float[6] { 1.1f, 1.1f, 1.1f, 1.1f, 1.1f, 1.1f };
                materialType = 1;
                break;
            case 3:
                metallicArray = new float[6] { 0, 0, 0, 0, 0, 0 };
                smoothnessArray = new float[6] { 1, 1, 1, 1, 1, 1 };
                transparentArray = new float[6] { 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f };
                iorArray = (from v in ratios select (1f + v * 0.5f)).ToArray();
                materialType = 1;
                break;
            case 4:
                metallicArray = new float[6] { 1, 1, 1, 1, 1, 1 };
                smoothnessArray = new float[6] { 1, 1, 1, 1, 1, 1 };
                transparentArray = new float[6] { -1, -1, -1, -1, -1, -1 };
                iorArray = (from v in ratios select (1f + v * 0.5f)).ToArray();
                materialType = 3;
                break;
            case 5:
                metallicArray = new float[6] { 0, 0, 0, 0, 0, 0 };
                smoothnessArray = new float[6] { 1, 1, 1, 1, 1, 1 };
                transparentArray = ratios;
                iorArray = new float[6] { 1.1f, 1.1f, 1.1f, 1.1f, 1.1f, 1.1f };
                materialType = 1;
                break;
        }

        ChangeMaterial(metallicArray, smoothnessArray, transparentArray, iorArray, materialType);
    }

    void ChangeMaterial(float[] metallicArray, float[] smoothnessArray, float[] transparentArray, float[] iorArray, int materialType)
    {
        for (int i = 0; i < materials.Length; ++i)
        {
            Material mat = materials[i];

            mat.SetFloat("_Metallic", Mathf.Max(0.01f, metallicArray[i]));
            mat.SetFloat("_Glossiness", Mathf.Max(0.01f, smoothnessArray[i]));
            mat.SetFloat("_IOR", iorArray[i]);
            mat.SetFloat("_MaterialType", materialType);

            if (materialType == 1)
            {
                mat.SetFloat("_Mode", 3);
                mat.SetColor("_Color", new Color(mat.color.r, mat.color.g, mat.color.b, transparentArray[i]));
            }
            else
            {
                mat.SetFloat("_Mode", 0);
            }
        }

        bvh.UpdateMaterialData();
    }
}
