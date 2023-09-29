#ifndef _WHITTED_RAY_TRACING_
#define _WHITTED_RAY_TRACING_

////////////// chapter3_1 //////////////
float3 reflectFunction(float3 I, float3 N) 
{
	return I - 2 * dot(I, N) * N;
}

////////////// chapter3_2 //////////////
float3 refractFunction(float3 I, float3 N, float eta) 
{
	float cosi = clamp(-1, 1, dot(-I, N));
	float c0 = cosi;
	float c1 = sqrt(1 - eta * eta * (1 - cosi * cosi));
	return eta * I + (eta * c0 - c1) * N;
}

float3 WhittedRayTracing(RayHit hit, inout Ray ray)
{
	////////////////// chapter3_4 //////////////
	//float3 shadow = 1;
	//Ray shadowRay = CreateRay(hit.position + hit.normal * NORMAL_BIAS, -lightParameter.xyz);
	//RayHit shadowHit = BruteForceRayTrace(shadowRay);
	//if (shadowHit.distance != 1.#INF)
	//{
	//	// 阴影的实现同样需要考虑物体的透明材质
	//	if (shadowHit.transparent < 0)
	//		shadow = shadowParameter.rgb * shadowParameter.a;
	//	else
	//		shadow = 0.55;
	//}

	//////////////// chapter3_3 //////////////
	if (hit.transparent < 0)
	{
		////////////// chapter3_1 //////////////
		// 实现完全镜面反射
		ray.origin = hit.position + hit.normal * NORMAL_BIAS;
		//ray.direction = reflectFunction(ray.direction, hit.normal);
		ray.direction = reflect(ray.direction, hit.normal);
	}
	else
	{
		////////////// chapter3_2 //////////////
		// 实现折射
		float etai = 1;
		float etat = 1.1;

		bool fromOutside = dot(ray.direction, hit.normal) < 0;
		float3 N = fromOutside ? hit.normal : -hit.normal;
		float3 bias = N * 0.01f;
		ray.origin = hit.position - bias;

		float eta = fromOutside ? etai / etat : etat / etai;
		//ray.direction = refractFunction(ray.direction, hit.normal, eta);
		ray.direction = refract(ray.direction, hit.normal, eta);
	}
	//////////////// chapter3_4 //////////////
	//return hit.albedo * shadow * 2;
	return hit.albedo;
}

#endif