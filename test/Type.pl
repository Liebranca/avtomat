# ---   *   ---   *   ---
# TYPE TEST
# width making me mad (.\ _ /.) !
#
# TEST FILE
# jmp EOF for bits
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# ~~

package TEST_Type;
  use v5.42.0;
  use strict;
  use warnings;

  use English;
  use lib "$ENV{ARPATH}/lib/sys/";
  use Type qw(struc);
  use Arstd::fatdump;


# ---   *   ---   *   ---
# the bit

my $type=struc("test"=>q[

byte b1;
byte b2;

struct {
  byte b3;
  byte b4;
};

]);

fatdump \$type;


# ---   *   ---   *   ---
1; # ret
