#!/usr/bin/perl
# ---   *   ---   *   ---
# AR
# boiler hed

# ---   *   ---   *   ---
# sanity check

use strict;
use warnings;

BEGIN {

  # check env
  my $root=$ENV{'ARPATH'};if(!$root) {
    print "ARPATH missing from ENV; aborted\n";
    exit;

  };

  chdir $ENV{'ARPATH'}.'/avtomat/';

  `rm -r ../trashcan/* &> /dev/null`;
  `rm -r ../lib/* &> /dev/null`;

  my $trashd=$ENV{'ARPATH'}.'/trashcan/avtomat/';
  my $libd=$ENV{'ARPATH'}.'/lib/';

  `mkdir -p $trashd`;
  `mkdir -p $libd`;

  `./BOOTSTRAP 0 > $trashd/MAM.pm`;

# ---   *   ---   *   ---

  my $FILE_LIST=[

# ---   *   ---   *   ---
# filters and hacks first

    '/hacks/shwl.pm',
    '/hacks/lyfil.pm',
    '/hacks/inlining.pm',
    '/hacks/inline.pm',

# ---   *   ---   *   ---
# then language and utils

    '/cli.pm',
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

    '/langdefs/plps.pm',
    '/langdefs/peso.pm',
    '/langdefs/perl.pm',
    '/langdefs/c.pm',

# ---   *   ---   *   ---
# then everything else

    '/queue.pm',
    '/stack.pm',
    '/avt.pm'

  ];

# ---   *   ---   *   ---

# in: file list,src path,dst path
# check dates, update older files

sub update {

  my $ref=shift;
  my $src=shift;
  my $dst=shift;
  my $md=shift;

  my $out=q{};
  my $depstr=q{};

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

    if($do_cp || defined $md) {
      if(!defined $md) {`cp $og $cp`}

# ---   *   ---   *   ---

      else {

        my $MAM_PATH=
          "-I$src".q{ }.
          "-I$src/hacks".q{ }.
          "-I$src/peso".q{ }.
          "-I$src/langdefs";

# ---   *   ---   *   ---

        my $PATH_TAKEN;
        my $MAM_ARGS;
        my ($obj,$pmd);

        if(!($src=~ qr{trashcan/})) {

          $PATH_TAKEN="PATH A";

          $MAM_ARGS='-MMAM=--rap';

          $pmd=$og;
          $pmd=~ s[$src][$dst];

          $obj=$pmd;
          $pmd.='d';

        } else {

          $PATH_TAKEN="PATH B";

          $MAM_ARGS='-MMAM';

          $pmd=$og;
          $obj=$cp;

        };

# ---   *   ---   *   ---

        my $ex=
          "perl  -c".q{ }.

          "$MAM_PATH".q{ }.
          "$MAM_ARGS".q{ }.

          "$og";

        $out=q{};
        $depstr=q{};

        $out=`$ex`; # 2> /dev/null

# ---   *   ---   *   ---

        my $re=qr{>>:__DEPS__:};
        my $depstr;

        if($out=~ s/$re(.*?)$re//s) {
          $depstr=${^CAPTURE[0]};

        } else {
          $depstr=q{};

        };

# ---   *   ---   *   ---

        for my $fname(
          $obj,$pmd

        ) {
          if(!(-e $fname)) {

            my @tmp=split m{/},$fname;
            my $path=join q{/},
              @tmp[0..$#tmp-1];

            `mkdir -p $path`;

          };
        };

# ---   *   ---   *   ---

if(!length $out) {

print "$PATH_TAKEN\n";
print "$MAM_PATH\n\n";
print "$og:\n";
print "$obj :: $pmd\n\n";

exit;

};

        my $FH;
        open $FH,'+>',$obj or die "$!";
        print {$FH} $out;

        close $FH;

        if($PATH_TAKEN ne 'PATH B') {
          open $FH,'+>',$pmd or die "$!";
          print {$FH} $depstr;

          close $FH;

        };

# ---   *   ---   *   ---

      };

      print

        "\e[37;1m<\e[34;22mAR\e[37;1m>\e[0m ".
        "updated \e[32;1m$f\e[0m\n";

    };
  };
};

# ---   *   ---   *   ---
# check libs

  my $path=$ENV{'ARPATH'}.'/trashcan/avtomat';
  if(! (-e $path) ) { `mkdir -p $path`; };

  update(

    $FILE_LIST,
    $root.'/avtomat',$path,1

  );

  `./BOOTSTRAP 1 > $libd/MAM.pm`;
  $path=$ENV{'ARPATH'}.'/lib';
  update(

    $FILE_LIST,
    $root.'/trashcan/avtomat',$path,1

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

# ---   *   ---   *   ---
# this effen script...

  #print `$ENV{'ARPATH'}'/avtomat/sygen'`;

};


# ---   *   ---   *   ---
1; # ret
