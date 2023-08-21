#ifndef _WHITTED_RAY_TRACING_
#define _WHITTED_RAY_TRACING_

// chapter3_1
float3 reflectFunction(float3 I, float3 N) 
{ 
    return I - 2 * dot(I, N) * N; 
} 

// chapter3_2
float3 refractFunction(float3 I, float3 N, float eta)
{
    float cosi = clamp(-1, 1, dot(-I, N));
    
    float c0 = cosi;
    float c1 = sqrt(1 - eta * eta * (1 - cosi * cosi));
    //当k小于零则表示全反射
    return eta * I + (eta * c0 - c1) * N;
}

float3 WhittedRayTracing(RayHit hit, inout Ray ray)
{
    // 这里return hit.normal之后，会整个场景变成黑色，是因为目前只有一次光线防线
    // return hit.normal;

    //////////////// chapter3_4 //////////////
    float3 shadow = 1;
    Ray shadowRay = CreateRay(hit.position + hit.normal * 0.01f, -lightParameter.xyz);
    RayHit shadowHit = BruteForceRayTrace(shadowRay);
    if (shadowHit.distance != 1.#INF)
        shadow = shadowParameter.rgb * shadowParameter.a;

    //////////////// chapter3_3 //////////////
    if (hit.transparent < 0)
    {
        // Chapter3_1,完全镜面反射，不考虑能量衰减 
        ray.origin = hit.position + hit.normal * 0.01f;
        ray.direction = reflectFunction(ray.direction, hit.normal);
    }
    else
    {
        // Chapter3_2, 折射
	    bool fromOutside = dot(ray.direction, hit.normal) < 0;
        float3 N = fromOutside ? hit.normal : -hit.normal;
        float3 bias = N * 0.01f;
        ray.origin = hit.position - bias;

        // refraction
        float etai = 1;
        float etat = 1.01;   // 看不出透明度的话可以调节这个值为1.01

        float eta = fromOutside ? etai / etat : etat / etai;
        ray.direction = normalize(refractFunction(ray.direction, N, eta));
    }

    //////////////// chapter3_4 //////////////
    return hit.albedo;
    //return hit.albedo * shadow;
}


#endif