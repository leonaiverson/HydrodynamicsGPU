#pragma once

#include "HydroGPU/Solver.h"
#include "Profiler/Stat.h"
#include "Tensor/Vector.h"
#include <OpenCL/cl.hpp>
#include <vector>

struct HydroGPUApp;

struct BurgersSolver : public Solver {
	cl::Program program;
	cl::CommandQueue commands;
	
	cl::Buffer stateBuffer;
	cl::Buffer interfaceVelocityBuffer;
	cl::Buffer stateSlopeRatioBuffer;
	cl::Buffer fluxBuffer;
	cl::Buffer pressureBuffer;
	cl::Buffer cflBuffer;
	cl::Buffer cflTimestepBuffer;
	
	cl::Kernel calcCFLKernel;
	cl::Kernel calcCFLMinReduceKernel;
	cl::Kernel calcCFLMinFinalKernel;
	cl::Kernel calcInterfaceVelocityKernel;
	cl::Kernel calcStateSlopeRatioKernel;
	cl::Kernel calcFluxKernel;
	cl::Kernel integrateFluxKernel;
	cl::Kernel computePressureKernel;
	cl::Kernel diffuseMomentumKernel;
	cl::Kernel diffuseWorkKernel;
	cl::Kernel convertToTexKernel;
	cl::Kernel addDropKernel;
	cl::Kernel addSourceKernel;
	
	struct EventProfileEntry {
		EventProfileEntry(std::string name_) : name(name_) {}
		std::string name;
		cl::Event clEvent;
		Profiler::Stat stat;
	};

	HydroGPUApp &app;

	EventProfileEntry calcCFLEvent;
	EventProfileEntry calcCFLMinReduceEvent;
	EventProfileEntry calcCFLMinFinalEvent;
	EventProfileEntry calcInterfaceVelocityEvent;
	EventProfileEntry calcStateSlopeRatioEvent;
	EventProfileEntry calcFluxEvent;
	EventProfileEntry integrateFluxEvent;
	EventProfileEntry computePressureEvent;
	EventProfileEntry diffuseMomentumEvent;
	EventProfileEntry diffuseWorkEvent;
	EventProfileEntry addSourceEvent;
	std::vector<EventProfileEntry*> entries;

	cl::NDRange globalSize, localSize;

	cl_float2 addSourcePos, addSourceVel;
	
	real cfl;

	BurgersSolver(HydroGPUApp &app);
	virtual ~BurgersSolver();

	virtual void update();
	virtual void addDrop(Tensor::Vector<float,DIM> pos, Tensor::Vector<float,DIM> vel);
	virtual void screenshot();
};


