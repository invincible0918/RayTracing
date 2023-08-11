#ifndef _SHADE_
#define _SHADE_

float3 Shade(RayHit hit, inout Ray ray)
{
	////////////// chapter2_1 //////////////
	//return 1;

	////////////// chapter2_2 //////////////
	if (hit.distance < 1.#INF)
	{
		//return ray.direction;
		return hit.normal;
	}
	else
	{
		return 0;
	}
}

#endif