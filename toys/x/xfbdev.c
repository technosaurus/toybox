/* xfbdev.c - Toybox wrapper for TinyX Framebuffer X Server */

#define CLEANUP_xfbdev
#define FOR_xfbdev
#include "toys.h"

// 1. Register global flags into Toybox's internal TT struct.
// The string tells Toybox's parser to accept "-s" (screen) and "-m" (mouse).
GLOBALS(
  char *s; // Screen resolution/depth (e.g. 1024x768x16)
  char *m; // Mouse device node path (e.g. /dev/input/mice)
)

// 2. Toybox help macro parsed during build-generation
#define HELP_xfbdev "usage: Xfbdev [-s SCREEN] [-m MOUSE]\n\n" \
  "A minimalist standalone framebuffer X11 Server targeting /dev/fb0.\n" \
  "Options:\n" \
  "  -s SCREEN   Specify widthxheightxdepth (e.g., 800x600x16)\n" \
  "  -m MOUSE    Path to mouse node (e.g., /dev/input/event0)\n"

// 3. Declare the internal engine entry point inside your x/src/xserver/ directory
extern int xfbdev_main_engine(int argc, char *argv[]);

void xfbdev_main(void)
{
  int argc = 1;
  char **argv = xmalloc(sizeof(char*) * 10); // Allocate space for manipulated arguments

  argv[0] = "Xfbdev";

  // Re-encode Toybox parsed options back into standard Xorg command-line parameters
  if (TT.s) {
    argv[argc++] = "-screen";
    argv[argc++] = TT.s;
  } else {
    // Sensible embedded defaults if flags are omitted
    argv[argc++] = "-screen";
    argv[argc++] = "1024x768x16";
  }

  if (TT.m) {
    argv[argc++] = "-mouse";
    // Appending ',5' or ',3' tells Kdrive the protocol/wheel configuration if needed
    argv[argc++] = xmprintf("%s,5", TT.m); 
  } else {
    argv[argc++] = "-mouse";
    argv[argc++] = "/dev/input/mice,5";
  }

  // Turn off the standard text-terminal cursor on the display console screen
  argv[argc++] = "-br";
  argv[argc] = NULL;

  // Hand over control execution to the isolated Xorg core engine loop
  // Note: If you used objcopy prefixing, this will map to xfb_xfbdev_main_engine
  xfbdev_main_engine(argc, argv);
}
