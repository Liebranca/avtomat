#!/usr/bin/perl

# AR
# boiler hed

# ---   *   ---   *   ---
# sanity check

BEGIN {

  # check env
  my $root=$ENV{'ARPATH'};if(!$root) {
    print "ARPATH missing from ENV; aborted\n";
    exit;

  # find lib
  };my $path=$ENV{'ARPATH'}.'/lib';
  if(! (-e $path) ) { `mkdir -p $path`; };

# ---   *   ---   *   ---

  # update
  for my $lib(
    '/peso/node.pm',
    '/peso/block.pm',

    '/avt.pm'

  ) {
    my $src=$root.'/avtomat'.$lib;

    my $do_cp=!(-e $path.$lib);
    $do_cp=(!$do_cp)
      ? !((-M $path.$lib)
      < (-M $src) )

      : $do_cp;
      ;

    my @ar=split '/',$path.$lib;
    my $basedir=join '/',@ar[0..$#ar-1];
    if(!(-e $basedir)) {
      `mkdir -p $basedir`;

    };if($do_cp) {`cp $src $path$lib`;};

  };

};

# ---   *   ---   *   ---
1; # ret
