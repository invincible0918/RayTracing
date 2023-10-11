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

## Scene Assets
We can convert the tungsten json format to our own format which is also using json. Use the python tool(unity-raytracing/Assets/RayTracing/Editor/convert_tungsten.py) for converting the tungsten scene. You can download the tungsten scenes at https://benedikt-bitterli.me/resources/ . 
  
## ScreenShops
### cornell box
![](ScreenShots/cornel-box.gif)
### staircase2
![](ScreenShots/staircase2.gif)
### bathroom2
20000 spp, Filmic tonemapping
![](ScreenShots/bathroom2.png)
### kitchen
15000 spp, ACE tonemapping
![](ScreenShots/kitchen.jpg)
### depth of field and glass material
![](ScreenShots/dof_glass.jpg)
