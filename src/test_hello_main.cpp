#include "Obfusk8/Instrumentation/materialization/state/Obfusk8Core.hpp"

#if defined(OBF_LEVEL_HEAVY)

_main({
    // heavy: string encryption + bogus flow + MBA arithmetic
    OBF_BOGUS_FLOW_LABYRINTH
    NOP()
    auto s1 = OBFUSCATE_STRING("Hello from test_hello.cpp");
    auto s2 = OBFUSCATE_STRING("2 + 3 = %d\n");
    printf("%s\n", s1.c_str());
    printf(s2.c_str(), OBF_MBA_ADD(2, 3));
})

#elif defined(OBF_LEVEL_MEDIUM)

_main({
    // medium: string encryption only
    auto s1 = OBFUSCATE_STRING("Hello from test_hello.cpp");
    auto s2 = OBFUSCATE_STRING("2 + 3 = %d\n");
    printf("%s\n", s1.c_str());
    printf(s2.c_str(), 2 + 3);
})

#else

_main({
    // light: just _main VM wrapper, no extra macros
    printf("Hello from test_hello.cpp\n");
    printf("2 + 3 = %d\n", 2 + 3);
})

#endif
