#include <stdio.h>

int add(int a, int b) {
    return a + b;
}

int main(void) {
    int result = add(2, 3);
    puts("Hello from test_hello.c");
    puts("2 + 3 = 5");
    return 0;
}
