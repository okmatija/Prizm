#define PRISM_FOR_UNREAL 0
#include "prism.h"


int main() {

    bool write_obj = false;
    prism::example_basic_api(write_obj);
    prism::example_concise_api(write_obj);
    prism::example_advanced_api(write_obj);
    prism::example_printf_logging(write_obj);

    return 0;
}