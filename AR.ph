#!/usr/bin/perl
# ---   *   ---   *   ---
# AR
# boiler hed

# ---   *   ---   *   ---
# sanity check

BEGIN {

  # check env
  my $root=$ENV{'ARPATH'};if(!$root) {
    print "ARPATH missing from ENV; aborted\n";
    exit;

  };

# ---   *   ---   *   ---

# in: file list,src path,dst path
# check dates, update older files

sub update {

  my $ref=shift;
  my $src=shift;
  my $dst=shift;

  for my $f(@$ref) {

    my $og=$src.$f;
    my $cp=$dst.$f;

    my $do_cp=!(-e $cp);

    $do_cp=(!$do_cp)
      ? !((-M $cp)
      <   (-M $og))

      : $do_cp;
      ;

    my @ar=split '/',$cp;
    my $basedir=join '/',@ar[0..$#ar-1];

    if(!(-e $basedir)) {
      `mkdir -p $basedir`;

    };

    if($do_cp) {
      `cp $og $cp`;

      print

        "\e[37;1m<\e[34;22mAR\e[37;1m>\e[0m ".
        "updated \e[32;1m$f\e[0m\n";

    };

  };

};

# ---   *   ---   *   ---
# check libs

  my $path=$ENV{'ARPATH'}.'/lib';
  if(! (-e $path) ) { `mkdir -p $path`; };

  update(

    [ '/hacks/inlining.pm',
      '/hacks/inline.pm',
      '/hacks/shadowlib.pm',

      '/lang.pm',
      '/style.pm',
      '/arstd.pm',

      '/peso/fndmtl.pm',
      '/peso/defs.pm',

      '/peso/ops.pm',
      '/peso/type.pm',

      '/peso/rd.pm',
      '/peso/node.pm',
      '/peso/ptr.pm',
      '/peso/blk.pm',
      '/peso/sbl.pm',
      '/peso/program.pm',

      '/queue.pm',
      '/stack.pm',
      '/avt.pm'

    ],$root.'/avtomat',$path

  );

# ---   *   ---   *   ---
# check headers

  $path=$ENV{'ARPATH'}.'/include';
  if(! (-e $path) ) { `mkdir -p $path`; };

  update(

    [ '/AR.ph',

      '/plps/peso.lps',
      '/plps/c.lps',

    ],$root.'/avtomat',$path

  );

};

# ---   *   ---   *   ---
1; # ret
