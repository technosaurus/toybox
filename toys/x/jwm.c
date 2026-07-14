/* jwm.c - Toybox wrapper for Joe's Window Manager */

#define CLEANUP_jwm
#define FOR_jwm
#include "toys.h"

// 1. Register global configuration parameters
GLOBALS(
  char *d; // Display destination (e.g. :0)
  char *c; // Alternative configuration file path
)

// 2. Toybox help macro parsed during build-generation
#define HELP_jwm "usage: jwm [-d DISPLAY] [-c CONFIG_FILE]\n\n" \
  "Joe's Window Manager. Handles window decoration, switching, and frames.\n" \
  "Options:\n" \
  "  -d DISPLAY      X11 display socket target (Default is :0)\n" \
  "  -c CONFIG_FILE  Path to custom jwmrc XML configuration\n"

// 3. Declare the internal engine entry point inside your x/src/jwm/ directory
extern int jwm_main_engine(int argc, char *argv[]);

void jwm_main(void)
{
  int argc = 1;
  char **argv = xmalloc(sizeof(char*) * 10);

  argv[0] = "jwm";

  // Handle targeting a specific X11 server socket
  if (TT.d) {
    argv[argc++] = "-display";
    argv[argc++] = TT.d;
  } else {
    // Fall back to standard default local display frame if omitted
    argv[argc++] = "-display";
    argv[argc++] = ":0";
  }

  // Allow passing a fully hardcoded or micro embedded configuration layout path
  if (TT.c) {
    argv[argc++] = "-f";
    argv[argc++] = TT.c;
  }

  argv[argc] = NULL;

  // Hand over execution control to the JWM entry engine loop
  // Note: If you used objcopy prefixing, this maps to jwm_jwm_main_engine
  jwm_main_engine(argc, argv);
}
