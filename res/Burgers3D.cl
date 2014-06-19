#include "HydroGPU/Shared/Common3D.h"

real8 slopeLimiter(real8 r);

__kernel void calcCFL(
	__global real* cflBuffer,
	const __global real8* stateBuffer,
	const __global real* gravityPotentialBuffer,
	int3 size,
	real3 dx,
	real cfl)
{
	int3 i = (int3)(get_global_id(0), get_global_id(1), get_global_id(2));
	int index = INDEXV(i);
	if (i.x < 2 || i.y < 2 || i.z < 2 || i.x >= size.x - 2 || i.y >= size.y - 2 || i.z >= size.z - 2) {
		cflBuffer[index] = INFINITY;
		return;
	}

	real8 state = stateBuffer[index];
	real density = state.s0;
	real3 velocity = state.s123 / density;
	real specificTotalEnergy = state.s4 / density;
	real specificKineticEnergy = .5f * dot(velocity, velocity);
	real specificPotentialEnergy = gravityPotentialBuffer[index]; 
	real specificInternalEnergy = specificTotalEnergy - specificKineticEnergy - specificPotentialEnergy;
	real speedOfSound = sqrt(GAMMA * (GAMMA - 1.f) * specificInternalEnergy);
	real3 dum = dx / (speedOfSound + fabs(velocity));
	cflBuffer[index] = cfl * min(dum.x, min(dum.y, dum.z));
}

__kernel void calcInterfaceVelocity(
	__global real* interfaceVelocityBuffer,
	const __global real8* stateBuffer,
	int3 size,
	real3 dx)
{
	int3 i = (int3)(get_global_id(0), get_global_id(1), get_global_id(2));
	if (i.x < 2 || i.y < 2 || i.z < 2 || i.x >= size.x - 1 || i.y >= size.y - 1 || i.z >= size.z - 1) return;
	int index = INDEXV(i);
	
	for (int side = 0; side < 3; ++side) {
		int3 iPrev = i;
		--iPrev[side];
		int indexPrev = INDEXV(iPrev);
		
		real8 stateL = stateBuffer[indexPrev];
		real densityL = stateL.s0;
		real velocityL = stateL[side+1] / densityL;
		
		real8 stateR = stateBuffer[index];
		real densityR = stateR.s0;
		real velocityR = stateR[side+1] / densityR;
		
		interfaceVelocityBuffer[side + 3 * index] = .5f * (velocityL + velocityR);
	}
}

real8 slopeLimiter(real8 r) {
	//donor cell
	//return (real8)(0.f);
	//Lax-Wendroff
	//return (real8)(1.f);
	//superbee
	return max(0.f, max(min(1.f, 2.f * r), min(2.f, r)));
}

//crashes when building
//#define CAUSES_COMPILER_TO_SEGFAULT

__kernel void calcFlux(
	__global real8* fluxBuffer,
	const __global real8* stateBuffer,
	const __global real* interfaceVelocityBuffer,
	int3 size,
	real3 dx,
	const __global real* dtBuffer)
{
#ifdef CAUSES_COMPILER_TO_SEGFAULT
	real dt = dtBuffer[0];
	real3 dt_dx = dt / dx;
#endif
	
	int3 i = (int3)(get_global_id(0), get_global_id(1), get_global_id(2));
	if (i.x < 2 || i.y < 2 || i.z < 2 || i.x >= size.x - 1 || i.y >= size.y - 1 || i.z >= size.z - 1) return;
	int index = INDEXV(i);
	
	for (int side = 0; side < 3; ++side) {	
		int3 iPrev = i;
		iPrev[side] = iPrev[side]- 1;
		int indexPrev = INDEXV(iPrev);
	
#ifdef CAUSES_COMPILER_TO_SEGFAULT
		int3 iPrev2 = iPrev;
		--iPrev2[side];
		int indexPrev2 = INDEXV(iPrev2);
		
		int3 iNext = i;
		++iNext[side];
		int indexNext = INDEXV(iNext);
#endif

		int indexL1 = indexPrev;
		int indexR1 = index;
#ifdef CAUSES_COMPILER_TO_SEGFAULT
		int indexL2 = indexPrev2;
		int indexR2 = indexNext;
#endif

		real8 stateL = stateBuffer[indexL1];
		real8 stateR = stateBuffer[indexR1];
#ifdef CAUSES_COMPILER_TO_SEGFAULT
		real8 stateL2 = stateBuffer[indexL2];
		real8 stateR2 = stateBuffer[indexR2];

		real8 deltaStateL = stateL - stateL2;
		real8 deltaState = stateR - stateL;
		real8 deltaStateR = stateR2 - stateR;
#endif

		real interfaceVelocity = interfaceVelocityBuffer[side + 3 * index];
		real theta = step(0.f, interfaceVelocity);
		
#ifdef CAUSES_COMPILER_TO_SEGFAULT
		real8 stateSlopeRatio = mix(deltaStateR, deltaStateL, theta) / deltaState;
		real8 phi = slopeLimiter(stateSlopeRatio);
		real8 delta = phi * deltaState;
#endif

		real8 flux = mix(stateR, stateL, theta) * interfaceVelocity;
#ifdef CAUSES_COMPILER_TO_SEGFAULT
		flux += delta * .5f * (.5f * fabs(interfaceVelocity) * (1.f - fabs(interfaceVelocity * dt_dx[side])));
#endif
			
		fluxBuffer[side + 3 * index] = flux;
	}
}

__kernel void integrateFlux(
	__global real8* stateBuffer,
	const __global real8* fluxBuffer,
	int3 size,
	real3 dx,
	const __global real* dtBuffer)
{
	real3 dt_dx = dtBuffer[0] / dx;
	
	int3 i = (int3)(get_global_id(0), get_global_id(1), get_global_id(2));
	if (i.x < 2 || i.y < 2 || i.z < 2 || i.x >= size.x - 2 || i.y >= size.y - 2 || i.z >= size.z - 2) return;
	int index = INDEXV(i);
	
	for (int side = 0; side < 3; ++side) {
		int3 iNext = i;
		++iNext[side];
		int indexNext = INDEXV(iNext);
		
		real8 fluxL = fluxBuffer[side + 3 * index];
		real8 fluxR = fluxBuffer[side + 3 * indexNext];
	
		real8 df = fluxR - fluxL;
		stateBuffer[index] -= df * dt_dx[side];
	}
}

__kernel void computePressure(
	__global real* pressureBuffer,
	const __global real8* stateBuffer,
	const __global real* gravityPotentialBuffer,
	int3 size)
{
	int3 i = (int3)(get_global_id(0), get_global_id(1), get_global_id(2));
	if (i.x < 1 || i.y < 1 || i.z < 1 || i.x >= size.x - 1 || i.y >= size.y - 1 || i.z >= size.z - 1) return;
	int index = INDEXV(i);
	
	real8 state = stateBuffer[index];
	
	real density = state.s0;
	real3 velocity = state.s123 / density;
	real energyTotal = state.s4 / density;
	
	real energyKinetic = .5f * dot(velocity, velocity);
	real energyPotential = gravityPotentialBuffer[index];
	real energyInternal = energyTotal - energyKinetic - energyPotential;
	
	real pressure = (GAMMA - 1.f) * density * energyInternal;
#if 0
	//von Neumann-Richtmyer artificial viscosity
	real deltaVelocitySq = 0.f;
	for (int side = 0; side < 3; ++side) {
		int3 iPrev = i;
		--iPrev[side];
		int indexPrev = INDEXV(iPrev);
		
		int3 iNext = i;
		++iNext[side];
		int indexNext = INDEXV(iNext);

		real velocityL = stateBuffer[indexPrev][side+1];
		real velocityR = stateBuffer[indexNext][side+1];
		const float ZETA = 2.f;
		real deltaVelocity = ZETA * .5f * (velocityR - velocityL);
		deltaVelocitySq += deltaVelocity * deltaVelocity; 
	}
	pressure += deltaVelocitySq * density;
#endif	
	pressureBuffer[index] = pressure;
}

__kernel void diffuseMomentum(
	__global real8* stateBuffer,
	const __global real* pressureBuffer,
	int3 size,
	real3 dx,
	const __global real* dtBuffer)
{
	real3 dt_dx = dtBuffer[0] / dx;
	
	int3 i = (int3)(get_global_id(0), get_global_id(1), get_global_id(2));
	if (i.x < 2 || i.y < 2 || i.z < 2 || i.x >= size.x - 2 || i.y >= size.y - 2 || i.z >= size.z - 2) return;
	int index = INDEXV(i);

	for (int side = 0; side < 3; ++side) {
		int3 iPrev = i;
		--iPrev[side];
		int indexPrev = INDEXV(iPrev);
		
		int3 iNext = i;
		++iNext[side];
		int indexNext = INDEXV(iNext);

		real pressureL = pressureBuffer[indexPrev];
		real pressureR = pressureBuffer[indexNext];

		real deltaPressure = .5f * (pressureR - pressureL);
		stateBuffer[index][side+1] -= deltaPressure * dt_dx[side];
	}
}

__kernel void diffuseWork(
	__global real8* stateBuffer,
	const __global real* pressureBuffer,
	int3 size,
	real3 dx,
	const __global real* dtBuffer)
{
	real3 dt_dx = dtBuffer[0] / dx;
	
	int3 i = (int3)(get_global_id(0), get_global_id(1), get_global_id(2));
	if (i.x < 2 || i.y < 2 || i.z < 2 || i.x >= size.x - 2 || i.y >= size.y - 2 || i.z >= size.z - 2) return;
	int index = INDEXV(i);

	for (int side = 0; side < 3; ++side) {
		int3 iPrev = i;
		--iPrev[side];
		int indexPrev = INDEXV(iPrev);
		
		int3 iNext = i;
		++iNext[side];
		int indexNext = INDEXV(iNext);

		real8 stateL = stateBuffer[indexPrev];
		real8 stateR = stateBuffer[indexNext];

		real velocityL = stateL[side+1] / stateL.s0;
		real velocityR = stateR[side+1] / stateR.s0;
		
		real pressureL = pressureBuffer[indexPrev];
		real pressureR = pressureBuffer[indexNext];

		real deltaWork = .5f * (pressureR * velocityR - pressureL * velocityL);

		stateBuffer[index].s4 -= deltaWork * dt_dx[side];
	}
}
