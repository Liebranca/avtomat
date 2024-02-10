#!/usr/bin/perl
# ---   *   ---   *   ---
# DROID
# A pathway to deep hell
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::Droid;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Cwd qw(abs_path);
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

  use parent 'Shb7::Bk::front';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  my $self=Shb7::Bk::front::new(

    $class,

    lang    => 'Kotlin',

    bk      => 'jar',
    entry   => 'main',
    linking => 'jar',

    pproc   => 'Avt::Droid::pproc',

    %O

  );

};

# ---   *   ---   *   ---
# ^kotlin preprocessor

package Avt::Droid::pproc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Cwd qw(abs_path);
  use English qw(-no_match_vars);
  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::Path;
  use Arstd::Re;
  use Arstd::IO;

  use Shb7::Path;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit;
  use Emit::Std;

# ---   *   ---   *   ---
1; # ret
