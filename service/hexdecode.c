#include <stdio.h>

static int hex_value(int character) {
    if (character >= '0' && character <= '9') {
        return character - '0';
    }
    if (character >= 'a' && character <= 'f') {
        return character - 'a' + 10;
    }
    if (character >= 'A' && character <= 'F') {
        return character - 'A' + 10;
    }
    return -1;
}

int main(void) {
    int high = -1;
    int character;

    while ((character = getchar()) != EOF) {
        int value = hex_value(character);
        if (value < 0) {
            continue;
        }
        if (high < 0) {
            high = value;
        } else {
            if (putchar((high << 4) | value) == EOF) {
                return 2;
            }
            high = -1;
        }
    }

    if (high >= 0) {
        return 3;
    }
    return fflush(stdout) == 0 ? 0 : 2;
}
