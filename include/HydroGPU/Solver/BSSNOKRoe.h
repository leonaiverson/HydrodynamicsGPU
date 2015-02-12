#pragma once

#include "HydroGPU/Solver/Roe.h"

namespace HydroGPU {
namespace Solver {

/*
Roe solver for BSSNOK equations
*/
struct BSSNOKRoe : public Roe {
	typedef Roe Super;
	using Super::Super;
protected:
	virtual void createEquation();
	virtual std::vector<std::string> getProgramSources();
};

}
}


