using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraMovement : MonoBehaviour
{
    public Transform target;
    public Vector3 offset = new Vector3(0, 1, 0);

    public float xSpeed = 500.0f;
    public float ySpeed = 500.0f;
    public float zoomSpeed = 5.0f;

    public float yMinLimit = 10f;
    public float yMaxLimit = 90f;

    public float distanceMin = .5f;
    public float distanceMax = 15f;

    public float rotationDamping;
    public float heightDamping;

    float distance = 0.0f;

    float x = 0.0f;
    float y = 0.0f;

    // Start is called before the first frame update
    void Start()
    {
        distance = Vector3.Distance(target.position + offset, transform.position);
        Vector3 angles = transform.eulerAngles;
        x = angles.y;
        y = angles.x;
    }

    // Update is called once per frame
    void LateUpdate()
    {
        if (target == null)
            return;

        Rotate();
    }

    void Rotate()
    {
        distance -= Input.GetAxis("Mouse ScrollWheel") * zoomSpeed;
        distance = Mathf.Clamp(distance, distanceMin, distanceMax);

        if (Input.GetMouseButton(0))
        {
            x += Input.GetAxis("Mouse X") * xSpeed * distance * 0.02f;
            y -= Input.GetAxis("Mouse Y") * ySpeed * 0.02f;
        }

        y = ClampAngle(y, yMinLimit, yMaxLimit);

        Quaternion rotation = Quaternion.Euler(y, x, 0);

        Vector3 negDistance = new Vector3(0.0f, 0.0f, -distance);
        Vector3 position = rotation * negDistance + target.position + offset;

        transform.rotation = rotation;
        transform.position = position;
    }

    float ClampAngle(float angle, float min, float max)
    {
        if (angle < -360F)
            angle += 360F;
        if (angle > 360F)
            angle -= 360F;
        return Mathf.Clamp(angle, min, max);
    }
}
