using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraMovement : MonoBehaviour
{
    public enum MoveType
    {
        Rotate,
        Track,
    }
    public MoveType moveType;

    [Header("Rotate")]
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

    [Header("Track")]
    public Animation animation;
    public string animationName;
    int frameIndex;
    int frameCount;

    // Start is called before the first frame update
    void Start()
    {
        switch (moveType)
        {
            case MoveType.Rotate:
                distance = Vector3.Distance(target.position + offset, transform.position);
                Vector3 angles = transform.eulerAngles;
                x = angles.y;
                y = angles.x;
                break;
            case MoveType.Track:
                animation[animationName].speed = 0f;
                frameCount = (int)(animation[animationName].length * 30f);
                break;
        }
    }

    // Update is called once per frame
    void LateUpdate()
    {
        switch(moveType)
        {
            case MoveType.Rotate:
                Rotate();
                break;
            case MoveType.Track:
                break;
        }
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

    public void PlayAtFrame()
    {
        animation[animationName].time = (float)frameIndex / frameCount;
        animation.Play(animationName);
        frameIndex += 1;
    }
}
