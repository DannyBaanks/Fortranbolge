#include <stdio.h>

void fb_putc(int value) { putchar(value & 0xff); }
void fb_flush(void) { fflush(stdout); }
