using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class CarPreprocessing : MonoBehaviour
{
    public string[] materialHasNoShadow;

    [ContextMenu("Preprocessing")]
    public void Preprocessing()
    {
        foreach(MeshRenderer mr in transform.GetComponentsInChildren<MeshRenderer>(false))
        {
            Material mat = mr.sharedMaterial;
            if (materialHasNoShadow.Contains(mat.name))
                mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        }
    }
}
