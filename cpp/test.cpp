#define PRISM_FOR_UNREAL 0
#include "prism.h"

int main() {

    constexpr bool write_files = true;
    prism::documentation(write_files);

    return 0;
}