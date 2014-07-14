#pragma once

#include "HydroGPU/Integrator/Integrator.h"

namespace HydroGPU {
namespace Integrator {

struct ForwardEuler : public Integrator {
	typedef Integrator Super;
	ForwardEuler(Solver& solver);
	virtual void integrate(std::function<void(cl::Buffer)> callback);
protected:
	cl::Buffer derivBuffer;	//d/dt[state]
	cl::Kernel forwardEulerIntegrateKernel;
};

}
}

