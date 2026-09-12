#include <stdio.h>

void fb_putc(int value) { putchar(value & 0xff); }
void fb_flush(void) { fflush(stdout); }

/* raw byte read from stdin (>=0), -1 at EOF */
int fb_getc(void) { return getchar(); }
