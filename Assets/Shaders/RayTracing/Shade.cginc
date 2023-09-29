#ifndef _SHADE_
#define _SHADE_

////////////// chapter3_1 //////////////
#include "WhittedRayTracing.cginc"
//////////////// chapter5_2 //////////////
#include "ImportanceSampling.cginc"
#if defined(UNIFORM_SAMPLING)
	#define FUNCTION_BSDF UniformSampling
#elif defined(COSINE_SAMPLING)
	#define FUNCTION_BSDF CosineWeightedSampling
#elif defined(LIGHT_IMPORTANCE_SAMPLING)
	#define FUNCTION_BSDF LightImportanceSampling
#elif defined(BSDF_IMPORTANCE_SAMPLING)
	#define FUNCTION_BSDF BSDFImportanceSampling
#elif defined(MULTIPLE_IMPORTANCE_SAMPLING)
	#define FUNCTION_BSDF MultipleImportanceSampling
#else
	#define FUNCTION_BSDF MultipleImportanceSampling
#endif
////////////// chapter3_1 //////////////
TextureCube<float4> skyboxCube;
SamplerState sampler_LinearClamp;

////////////// chapter5_3 //////////////
float skyboxRotation;
float skyboxExposure;

////////////// chapter5_3 //////////////
float3 RotateAroundYInDegrees(float3 dir, float degrees)
{
	float alpha = degrees * PI / 180.0;
	float sina, cosa;
    sincos(alpha, sina, cosa);

	float2x2 m = float2x2(cosa, -sina, sina, cosa);
	return float3(mul(m, dir.xz), dir.y).xzy;
}

static const float SPECCUBE_LOD_STEPS = 10;
half PerceptualRoughnessToMipmapLevel(half perceptualRoughness)
{
    return perceptualRoughness * SPECCUBE_LOD_STEPS;
}

////////////// chapter2_1 //////////////
float3 Shade(RayHit hit, inout Ray ray)
{
	if (hit.distance < 1.#INF)
	{
		// 考虑光能的衰减
		//ray.energy *= WhittedRayTracing(hit, /*inout */ray);

		////////////////// chapter3_3 //////////////
		//// return 0是因为该光线和物体交互，物体是没有自发光的，即不考虑发光材质
		//return 0;
		//////////////// chapter5_2 //////////////
		//if (any(hit.emissionColor))   // any(x): x!=0 return true
		//	return hit.emissionColor;
		//else
		//	return 0;
		if (hit.materialType == 2)  // 如果emission color有非0值，则直接返回emission color
            return hit.emissionColor;
		else if (hit.materialType == 4)
		{
			ray.origin = hit.position - hit.normal * NORMAL_BIAS;
			// ray.direction 不要修改，继续沿原方向进行传递
			return 0;
		}
		else
		{
			ray.energy *= FUNCTION_BSDF(hit, /*inout */ray);
            return 0;
		}
	}
	else
	{
		//ray.energy *= 1.0f;
		//return 1;

		ray.energy = 0.0f;

		// 如果射线和场景没有交点，则需要采集cubemap
		//float3 dir = ray.direction;

		//float perceptualRoughness = SmoothnessToPerceptualRoughness (hit.smoothness);
  //      perceptualRoughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
  //      half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);

		////////////// chapter5_3 //////////////
		float3 dir = RotateAroundYInDegrees(ray.direction, -skyboxRotation);

		float3 skyboxColor = skyboxCube.SampleLevel(sampler_LinearClamp, dir, 0).rgb;
		//////////////// chapter6_6 //////////////
		//skyboxColor *= pow(saturate(skyboxExposure), 2.2);
		skyboxColor = LinearToSRGB(skyboxColor);
		skyboxColor = saturate(skyboxColor) * skyboxExposure;
		skyboxColor = SRGBToLinear(skyboxColor);

		return skyboxColor;
	}
}

#endif