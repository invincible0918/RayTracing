using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AdjustCamera : MonoBehaviour
{
    public Transform[] players;
    public Transform midTrans;
    public Transform highTrans;

    Vector3 origPos;
    Transform target;

    int index = 0;

    // Start is called before the first frame update
    void Start()
    {
        origPos = transform.position;
    }

    [ContextMenu("Show")]
    public void Show()
    {
        index = index % players.Length;
        target = players[index];
        Debug.Log(target.name);

        string[] tmp = target.name.Split(" ");

        float h1 = 1.8f;
        float h2 = float.Parse(tmp[0]);

        Vector3 pos = Calc(h1, h2);
        pos.x = target.position.x;

        Camera.main.transform.position = pos;
        index += 1;
    }


    // Update is called once per frame
    void Update()
    {
        
    }

    Vector3 Calc(float h1, float h2)
    {
        float d = target.position.z - origPos.z;
        float h = origPos.y;

        float x = h2 * d / h1 - d;
        float y = h2 * h / h1 - h;

        return origPos + new Vector3(0, y, -x);
    }
}
