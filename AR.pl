#!/usr/bin/perl
# ---   *   ---   *   ---
# AR
# makescript for a makescript maker

# ---   *   ---   *   ---
# sanity check

use strict;
use warnings;

my $clean=0;
for my $v(@ARGV) {
  if($v=~ m/clean/) {
    $clean=1;

  };
};

# check env
my $root=$ENV{'ARPATH'};if(!$root) {
  print "ARPATH missing from ENV; aborted\n";
  exit;

};

chdir $ENV{'ARPATH'}.'/avtomat/';

my $ARTAG="\e[37;1m<\e[34;22mAR\e[37;1m>\e[0m";
my $trashd=$ENV{'ARPATH'}.'/.trash/avtomat/';
my $libd=$ENV{'ARPATH'}.'/lib/';

if($clean) {

  `rm -r ../.trash/* &> /dev/null`;
  `rm -r ../.cache/* &> /dev/null`;
  `rm -r ../lib/* &> /dev/null`;

  `mkdir -p $trashd`;
  `mkdir -p $libd`;

};

`./BOOTSTRAP 0 > $trashd/MAM.pm`;

# ---   *   ---   *   ---

my $FILE_LIST=[

# ---   *   ---   *   ---
# sys first

  '/sys/style.pm',
  '/sys/arstd.pm',

  '/sys/queue.pm',
  '/sys/stack.pm',
  '/sys/tree.pm',

  '/sys/shb7.pm',
  '/sys/vault.pm',

  '/sys/cli.pm',

# ---   *   ---   *   ---
# then filters and hacks

  '/hacks/shwl.pm',
  '/hacks/lyfil.pm',
  '/hacks/inlining.pm',
  '/hacks/inline.pm',

# ---   *   ---   *   ---
# then language and utils

  '/lang.pm',

  '/peso/st.pm',
  '/peso/defs.pm',

  '/peso/ops.pm',
  '/peso/type.pm',

  '/peso/rd.pm',
  '/peso/node.pm',
  '/peso/ptr.pm',
  '/peso/blk.pm',
  '/peso/sbl.pm',
  '/peso/program.pm',

  '/emit/std.pm',
  '/emit/c.pm',

  '/langdefs/plps.pm',
  '/langdefs/peso.pm',
  '/langdefs/perl.pm',
  '/langdefs/c.pm',

  '/peso/ipret.pm',

# ---   *   ---   *   ---
# then everything else

  '/avt.pm',
  '/makescript.pm',

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

      elsif($do_cp) {

        my $MAM_PATH=
          "-I$src".q{ }.
          "-I$src/hacks".q{ }.
          "-I$src/peso".q{ }.
          "-I$src/langdefs";

# ---   *   ---   *   ---

        my $PATH_TAKEN;
        my $MAM_ARGS;
        my ($obj,$pmd);

        if(!($src=~ qr{.trash/})) {

          $PATH_TAKEN="PATH A";

          $MAM_ARGS=
            '-MMAM'.q{=}.
            '-md'.q{,}.
            '--rap'.q{,}.

            '--module=avtomat'

          ;

          $pmd=$og;
          $pmd=~ s[$src][$dst];

          $obj=$pmd;
          $pmd.='d';

# ---   *   ---   *   ---

        } else {

          $PATH_TAKEN="PATH B";

          $MAM_ARGS='-MMAM'.q{=}.
            '--module=avtomat';

          $pmd=$og;
          $obj=$cp;

        };

# ---   *   ---   *   ---

        my $ex=
          "perl".q{ }.

          "$MAM_PATH".q{ }.
          "$MAM_ARGS".q{ }.

          "$og";

        $out=q{};
        $depstr=q{};

        $out=`$ex 2> .errlog`;

# ---   *   ---   *   ---

        my $re="^\:__DEPS__\:(.*?)\:__DEPS__\:";
        my $depstr;

        if($out=~ s/$re//sm) {
          $depstr=${^CAPTURE[0]};

        } elsif($PATH_TAKEN ne 'PATH B') {
          print {*STDERR} "$out\n";

          print {*STDERR} "$PATH_TAKEN\n";
          print {*STDERR} "$MAM_PATH\n\n";
          print {*STDERR} "$og:\n";
          print {*STDERR} "$obj :: $pmd\n\n";

          my $log=`cat .errlog`;
          print {*STDERR} "$log\n";

          die "Can't find deps for $og\n";

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

          print {*STDERR} "$PATH_TAKEN\n";
          print {*STDERR} "$MAM_PATH\n\n";
          print {*STDERR} "$og:\n";
          print {*STDERR} "$obj :: $pmd\n\n";

          my $log=`cat .errlog`;
          print {*STDERR} "$log\n";

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

      if(!defined $md || $do_cp && $md!=2) {

        print {*STDERR}

          "\e[37;1m::\e[0m".
          "updated \e[32;1m$f\e[0m\n";

      };

    };
  };
};

# ---   *   ---   *   ---
# check libs

my $path=$ENV{'ARPATH'}.'/.trash/avtomat';
if(! (-e $path) ) { `mkdir -p $path`; };


# pretty out
print {*STDERR} "$ARTAG starting update\n";

# ---   *   ---   *   ---

update(

  $FILE_LIST,
  $root.'/avtomat',$path,2

);

`./BOOTSTRAP 1 > $libd/MAM.pm`;
$path=$ENV{'ARPATH'}.'/lib';
update(

  $FILE_LIST,
  $root.'/.trash/avtomat',$path,1

);

## ---   *   ---   *   ---
# check bins

$path=$ENV{'ARPATH'}.'/bin';
if(! (-e $path) ) { `mkdir -p $path`; };

update(

  [ '/AR.pl',

  ],$root.'/avtomat',$path

);

## ---   *   ---   *   ---
## check headers
#
#$path=$ENV{'ARPATH'}.'/include';
#if(! (-e $path) ) { `mkdir -p $path`; };
#
#update(
#
#  [ '/plps/peso.lps',
#    '/plps/c.lps',
#
#  ],$root.'/avtomat',$path
#
#);

# ---   *   ---   *   ---
# this effen script...

print {*STDERR}
  "\e[37;1m::\e[0mrebuilding syntax files\n";

print {*STDERR}
  `$ENV{'ARPATH'}'/avtomat/sygen'`;

# ---   *   ---   *   ---

print {*STDERR} "\e[37;1m::\e[0mdone\n\n";


# ---   *   ---   *   ---
1; # ret
