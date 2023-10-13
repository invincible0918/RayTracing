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

## Importance Sampling
### Uniform sampling
![](Assets/Outputs/UniformSampling.png)
### Cosine weighted sampling
![](Assets/Outputs/CosineSampling.png)
### Light sampling
![](Assets/Outputs/LightSampling.png)
### Cornell box
![](Assets/Outputs/CornellBox.png)
### Multiple importance sampling
![](Assets/Outputs/MIS.png)
## Physical Base Material
### Opaque spheres of increasing surface smoothness, metallic = 0
![](Assets/Outputs/pbr0.png)
### Opaque spheres of increasing surface smoothness, metallic = 1
![](Assets/Outputs/pbr1.png)
### Transparent  spheres of increasing surface smoothness, metallic = 0
![](Assets/Outputs/pbr2.png)
### Transparent spheres of increasing IOR
![](Assets/Outputs/pbr3.png)
### Opaque spheres of increasing IOR
![](Assets/Outputs/pbr4.png)
### Transparent spheres becoming increasingly diffuse
![](Assets/Outputs/pbr5.png)
## High Quality Soft Shadow
### Light radius = 0.01
![](Assets/Outputs/soft_shadow0.png)
### Light radius = 0.1
![](Assets/Outputs/soft_shadow1.png)
### Light radius = 0.5
![](Assets/Outputs/soft_shadow2.png)
## Realistic Car Rendering
![](Assets/Outputs/car0.png)
![](Assets/Outputs/car1.png)
![](Assets/Outputs/car2.png)