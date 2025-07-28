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
  use v5.36.0;
  use strict;
  use warnings;

  use English;
  use lib "$ENV{ARPATH}/lib/sys/";

  use Style;
  use Type;

  use Fmat;
  use A9M;


# ---   *   ---   *   ---
# the bit

my $mc  = A9M->new();
my $mem = $mc->mkseg(ram=>'data');

$mem->brk(16);
$mem->decl(typefet('byte') => chars => [
  0x24,0x00,0x11,0x11,
  0x11,0x11,0x0B,0x0B

]);

$mem->decl(typefet('long') => charsp =>
  $mc->ssearch(data=>'chars')

);

$mem->prich();


fatdump \$mc->ssearch(data=>'chars')->load();
fatdump \$mc->ssearch(data=>'charsp')->load(deref=>1);


# ---   *   ---   *   ---
1; # ret
