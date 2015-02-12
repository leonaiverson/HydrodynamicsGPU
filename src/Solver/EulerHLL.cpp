#include "HydroGPU/Solver/EulerHLL.h"
#include "HydroGPU/Equation/Euler.h"
#include "HydroGPU/HydroGPUApp.h"
#include "Common/File.h"

namespace HydroGPU {
namespace Solver {

void EulerHLL::createEquation() {
	equation = std::make_shared<HydroGPU::Equation::Euler>(*this);
}

std::string EulerHLL::getFluxSource() {
	return Common::File::read("EulerHLL.cl");
}

}
}

