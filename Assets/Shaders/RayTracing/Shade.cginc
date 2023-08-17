#ifndef _SHADE_
#define _SHADE_

//#include "WhittedRayTracing.cginc"
//////////////// chapter5_2 //////////////
#include "ImportanceSampling.cginc"
#define FUNCTION_BSDF UniformSampling

////////////// chapter3_1 //////////////
TextureCube<float4> skyboxCube;
SamplerState sampler_LinearClamp;

float3 Shade(RayHit hit, inout Ray ray)
{
	////////////// chapter2_1 //////////////
	//return 1;

	////////////// chapter2_2 //////////////
	if (hit.distance < 1.#INF)
	{
		//return ray.direction;
		//return hit.normal;

		//////////////// chapter3_1 //////////////
		//// 考虑 能量的衰减
		//ray.energy *= WhittedRayTracing(hit, /*inout */ray);
		////// 不考虑发光材质，直接return 0
		////return 0;

		////////////////// chapter3_3 //////////////
		//if (any(ray.energy))   // any(x): x!=0 return true
		//	return hit.emissionColor;
		//else
		//	return 0;
		//////////////// chapter5_2 //////////////
		if (hit.materialType == 2)  // 如果emission color有非0值，则直接返回emission color
            return hit.emissionColor;
        else
        {
            ray.energy *= FUNCTION_BSDF(hit, ray);
            return 0;
        }
	}
	else
	{
		////////////// chapter3_1 //////////////
		// 此时要处理当射线没有交点的情况了，不能直接return 0，需要返回一个天光
		ray.energy = 0.0f;

		float3 dir = ray.direction;
		float3 skyboxColor = skyboxCube.SampleLevel(sampler_LinearClamp, dir, 0).xyz;
        return skyboxColor;
	}
}

#endif