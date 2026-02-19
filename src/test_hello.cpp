// Minimal Obfusk8 test
// No _main wrapper for fast compile verification
// To test the full VM engine, change to:
#include "Obfusk8/Instrumentation/materialization/state/Obfusk8Core.hpp"
//   _main({ printf("Hello from test_hello.cpp\n"); printf("2 + 3 = %d\n", 2 + 3); })
#include <cstdio>

int main(void) {
    printf("Hello from test_hello.cpp\n");
    printf("2 + 3 = %d\n", 2 + 3);
    fflush(stdout);
    return 0;
}
