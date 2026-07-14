/* term.c - Toybox wrapper for st (Simple Terminal) */

#define CLEANUP_term
#define FOR_term
#include "toys.h"

GLOBALS(
  char *font;
  char *geom;
  char *e_cmd;
)

#define HELP_term "usage: st [-font FONT] [-geom GEOMETRY] [-e COMMAND...]\n\n" \
  "The Suckless Simple Terminal emulator compiled for the embedded X environment."

extern int st_main_engine(int argc, char *argv[]);

void term_main(void)
{
  // Reconstruct standard Unix argv array out of Toybox's parsed optargs
  int argc = toys.optc + 1;
  char **argv = xmalloc(sizeof(char*) * (argc + 10)); // Provide padding for injected arguments
  
  argv[0] = "st";
  for(int i = 0; i < toys.optc; i++) {
    argv[i+1] = toys.optargs[i];
  }

  if (TT.font) {
    argv[argc++] = "-f";
    argv[argc++] = TT.font;
  }
  if (TT.geom) {
    argv[argc++] = "-g";
    argv[argc++] = TT.geom;
  }
  if (TT.e_cmd) {
    argv[argc++] = "-e";
    argv[argc++] = TT.e_cmd;
  }
  argv[argc] = NULL;

  st_main_engine(argc, argv);
}
