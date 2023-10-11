# unity-raytracing
GPU Raytracing renderer which runs in compute shader in unity.
This project is implemented by pure vertex shader, fragment shader and compute shader in Unity, not using any raytracing shaders.
## Features
- Whitted style path tracing
- Monte Carlo ray tracing
- Cosine Weighted sampling, Light importance sampling, BRDF importance sampling and Multiple importance sampling
- Physical Base Materials like plastic, metallic, clear coat, etc
- Split BVH acceleration structure by compute shader
- Complex triangle intersection
- PDF calculation based on importance sampling
- High quality soft shadow
- HDRI Environment Maps
- Depth of field
- Bloom
- Color correction and color grading

## ScreenShops
### Uniform Sampling
![](Assets/Outputs/UniformSampling.png)
### Cosine Weighted Sampling
![](Assets/Outputs/CosineSampling.png)
### Light Sampling
![](Assets/Outputs/LightSampling.png)
### Cornell Box
![](Assets/Outputs/CornellBox.png)
### Multiple Importance Sampling
![](Assets/Outputs/MIS.png)