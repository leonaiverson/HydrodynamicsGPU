#include "HydroGPU/Equation/Euler.h"
#include "HydroGPU/Solver/EulerRoe.h"
#include "Common/File.h"

namespace HydroGPU {
namespace Solver {

void EulerRoe::createEquation() {
	equation = std::make_shared<HydroGPU::Equation::Euler>(*this);
}

std::vector<std::string> EulerRoe::getProgramSources() {
	std::vector<std::string> sources = Super::getProgramSources();
	sources.push_back(Common::File::read("EulerRoe.cl"));
	return sources;
}

}
}

