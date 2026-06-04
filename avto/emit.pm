#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO EMIT
# makefile writer
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::emit;
  use v5.42.0;
  use strict;
  use warnings;

  use Storable qw(store);
  use Cwd qw(abs_path getcwd);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Arstd::String qw(cat gstrip gsplit);
  use Arstd::Bin qw(owc);

  use lib "$ENV{ARPATH}/lib/";
  use avto::make;


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# entry point

sub run {
  my ($px)=@_;

  # dump the boilerpaste
  my $body=join("\n",
    "#!/usr/bin/perl\n",
    deps_common(),
    $px->{boot},
    deps_avto(),
    hook(pre=>$px),
    build(),
    hook(post=>$px),
    "1;",
  );

  # ^cleanup
  $body=join("\n",gsplit($body,qr"\n"));

  # ^write makefile
  my $dst=$px->makefile();
  owc($dst,$body);

  return;
};


# ---   *   ---   *   ---
# dependencies for all makefiles

sub deps_common {
  my $pkg=cat(
    'package ',
    avto::make::sandbox_name(),
    ";\n"
  );
  return $pkg . q[
    use 5.42.0;
    use strict;
    use warnings;

  ] . join("\n",
    "BEGIN {",
    "\$ENV{ARPATH}//=q[$ENV{ARPATH}];",
    "};",
  );
};
sub deps_avto {
  return q[
    use English qw($ARG);
    use Storable qw(thaw);
    use lib "$ENV{ARPATH}/lib/sys/";
    use Log;
    use Arstd::throw;
    use lib "$ENV{ARPATH}/lib/";
    use avto::make;
  ];
};


# ---   *   ---   *   ---
# body of script

sub build {
  return q[
    my ($px,$sw)=(
      thaw(shift),
      thaw(shift),
    );
    my $ok=avto::make::build($px,$sw);
  ];
};


# ---   *   ---   *   ---
# pastes codestr for hook

sub hook {
  my ($which,$px)=@_;
  my @out=();

  # this is same for all hooks
  my @body=();
  if(! is_null($px->{$which})) {
    @body=(
      "Log->step('running $which-build hook');",
      $px->{$which},
    );
  };

  # in prebuild, just run
  if($which eq 'pre') {
    @out=(@body);

  # ^in postbuild, run failure check
  } else {
    @out=(
      build_failchk(),
      @body,
    );
  };

  # finally, assemble into block
  my $blk={
    pre  => 'INIT',
    post => 'END',

  }->{$which};

  my $out=join("\n",gstrip(@out));
  return (! is_null($out))
    ? "$blk {\n$out\n};"
    : null
    ;
};


# ---   *   ---   *   ---
# checks for failure ;>

sub build_failchk {
  return q[
    throw "avto: build failed"
    if! defined $ok;
  ];
};


# ---   *   ---   *   ---
1; # ret
