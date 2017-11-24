#!/bin/sh
# This has to be a separate file from scripts/make.sh so it can be called
# before menuconfig.  (It's called again from scripts/make.sh just to be sure.)

mkdir -p generated

. configure

probecc()
{
  "${CROSS_COMPILE}${CC}" ${CFLAGS} -xc -o /dev/null "$1" -
}

# Probe for a single config symbol with a "compiles or not" test.
# Symbol name is first argument, flags second, feed C file to stdin
probesymbol()
{
  probecc "$2" 2>/dev/null && DEFAULT=y || DEFAULT=n
  rm a.out 2>/dev/null
  printf 'config %s\n\tbool'  "$1" || exit 1
  printf '\tdefault %s\n' "$DEFAULT" || exit 1
}

probeconfig()
{
  touch generated/cflags
  # llvm produces its own really stupid warnings about things that aren't wrong,
  # and although you can turn the warning off, gcc reacts badly to command line
  # arguments it doesn't understand. So probe.
  printf '#warn warn' | probecc -Wno-string-plus-int 2>&1 | grep -q string-plus-int &&
    printf '%s\n' '-Wno-string-plus-int' >> generated/cflags

  # Probe for container support on target
  probesymbol TOYBOX_CONTAINER << EOF
    #include <linux/sched.h>
    int x=CLONE_NEWNS|CLONE_NEWUTS|CLONE_NEWIPC|CLONE_NEWNET;

    int main(int argc, char *argv[]) { setns(0,0); return unshare(x); }
EOF

  probesymbol TOYBOX_FIFREEZE -c << EOF
    #include <linux/fs.h>
    #ifndef FIFREEZE
    #error nope
    #endif
EOF

  # Work around some uClibc limitations
  probesymbol TOYBOX_ICONV -c << EOF
    #include "iconv.h"
EOF
  probesymbol TOYBOX_FALLOCATE << EOF
    #include <fcntl.h>

    int main(int argc, char *argv[]) { return posix_fallocate(0,0,0); }
EOF
  
  # Android and some other platforms miss utmpx
  probesymbol TOYBOX_UTMPX -c << EOF
    #include <utmpx.h>
    #ifndef BOOT_TIME
    #error nope
    #endif
    int main(int argc, char *argv[]) {
      struct utmpx *a; 
      if (0 != (a = getutxent())) return 0;
      return 1;
    }
EOF

  # Android is missing shadow.h
  probesymbol TOYBOX_SHADOW -c << EOF
    #include <shadow.h>
    int main(int argc, char *argv[]) {
      struct spwd *a = getspnam("root"); return 0;
    }
EOF

  # Some commands are android-specific
  probesymbol TOYBOX_ON_ANDROID -c << EOF
    #ifndef __ANDROID__
    #error nope
    #endif
EOF

  probesymbol TOYBOX_ANDROID_SCHEDPOLICY << EOF
    #include <cutils/sched_policy.h>

    int main(int argc,char *argv[]) { get_sched_policy_name(0); }
EOF

  # nommu support
  probesymbol TOYBOX_FORK << EOF
    #include <unistd.h>
    int main(int argc, char *argv[]) { return fork(); }
EOF
  printf '\tdepends on !TOYBOX_MUSL_NOMMU_IS_BROKEN\n'

  probesymbol TOYBOX_PRLIMIT << EOF
    #include <sys/time.h>
    #include <sys/resource.h>

    int main(int argc, char *argv[]) { prlimit(0, 0, 0, 0); }
EOF
}

genconfig()
{
  # Reverse sort puts posix first, examples last.
  for j in $(ls toys/*/README | sort -s -r)
  do
    DIR="$(dirname "$j")"

    [ $(ls "$DIR" | wc -l) -lt 2 ] && continue

    echo "menu \"$(head -n 1 "$j")\""
    echo

    # extract config stanzas from each source file, in alphabetical order
    for i in $DIR/*.c; do
      # Grab the config block for Config.in
      echo "# $i"
      sed -n '/^\*\//q;/^config [A-Z]/,$p' "$i" || return 1
      echo
    done

    echo endmenu
  done
}

probeconfig > generated/Config.probed || rm generated/Config.probed
genconfig > generated/Config.in || rm generated/Config.in

# Find names of commands that can be built standalone in these C files
toys()
{
  grep 'TOY(.*)' "$@" | grep -v TOYFLAG_NOFORK | grep -v "0))" | \
    sed -rn 's/([^:]*):.*(OLD|NEW)TOY\( *([a-zA-Z][^,]*) *,.*/\1:\3/p'
}

WORKING=
PENDING=
toys toys/*/*.c | (
while IFS=":" read FILE NAME
do
  [ "$NAME" = "help" ] && continue
  [ "$NAME" = "install" ] && continue
  printf '%s: %s *.[ch] '"lib/*.[ch]"'\n\tscripts/single.sh %s\n' "$NAME" "$FILE" "$NAME"
  printf 'test_%s:\n\tscripts/test.sh %s\n' "$NAME" "$NAME"
  case "$FILE" in
  *pending*)WORKING="$WORKING $NAME";;
  *)PENDING="$PENDING $NAME";;
  esac
done &&
printf 'clean::\n\trm -f %s %s\n' "$WORKING" "$PENDING" &&
printf 'list:\n\t@echo %s' "$(echo "$WORKING" | tr ' ' '\n' | sort | xargs)" &&
printf 'list_pending:\n\t@echo %s' "$(echo "$PENDING" | tr ' ' '\n' | sort | xargs)" &&
printf '.PHONY: %s %s' "$WORKING" "$PENDING" | sed 's/ \([^ ]\)/ test_\1/g'
) > .singlemake
