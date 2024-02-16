#!/usr/bin/perl
# ---   *   ---   *   ---
# AR
# makescript for a makescript maker

# ---   *   ---   *   ---
# sanity check

use v5.36.0;
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

  `rm -rf ../.trash/* ../.trash/.[!.]* &> /dev/null`;
  `rm -rf ../.cache/* ../.cache/.[!.]* &> /dev/null`;
  `rm -rf ../lib/* ../.lib/.[!.]* &> /dev/null`;

  `mkdir -p $trashd`;
  `mkdir -p $libd`;

};

`./BOOTSTRAP 0 > $trashd/MAM.pm`;

# ---   *   ---   *   ---

my $FILE_LIST=[

# ---   *   ---   *   ---
# sys first

  '/sys/Style.pm',
  '/sys/Arstd.pm',

  '/sys/Arstd/Bytes.pm',
  '/sys/Arstd/Int.pm',
  '/sys/Arstd/String.pm',
  '/sys/Arstd/Array.pm',
  '/sys/Arstd/Hash.pm',
  '/sys/Arstd/Re.pm',
  '/sys/Arstd/Path.pm',
  '/sys/Arstd/IO.pm',
  '/sys/Arstd/PM.pm',
  '/sys/Arstd/WLog.pm',
  '/sys/Arstd/Test.pm',

  '/sys/Chk.pm',
  '/sys/St.pm',
  '/sys/Frame.pm',

  '/sys/Queue.pm',
  '/sys/Cask.pm',
  '/sys/Tree.pm',
  '/sys/Tree/File.pm',
  '/sys/Tree/Dep.pm',

  '/sys/Type.pm',
  '/sys/Type/C.pm',
  '/sys/Type/Cpp.pm',
  '/sys/Type/Platypus.pm',

  '/sys/Shb7.pm',
  '/sys/Shb7/Path.pm',
  '/sys/Shb7/Find.pm',
  '/sys/Shb7/Bfile.pm',
  '/sys/Shb7/Bk.pm',
  '/sys/Shb7/Bk/flat.pm',
  '/sys/Shb7/Bk/gcc.pm',
  '/sys/Shb7/Bk/mam.pm',
  '/sys/Shb7/Bk/fake.pm',
  '/sys/Shb7/Build.pm',

  '/sys/Vault.pm',
  '/sys/Cli.pm',
  '/sys/Fmat.pm',

# ---   *   ---   *   ---
# then build Mach

  '/sys/Mach/Seg.pm',
  '/sys/Mach/Struc.pm',
  '/sys/Mach/Reg.pm',
  '/sys/Mach/Micro.pm',
  '/sys/Mach/Opcode.pm',

  '/sys/Mach.pm',

# ---   *   ---   *   ---
# then filters and hacks

  '/hacks/Shwl.pm',
  '/hacks/Lyfil.pm',

# ---   *   ---   *   ---
# then language and utils

  '/Lang.pm',
  '/Lang/Def.pm',


  '/Grammar.pm',
  '/Grammar/C.pm',

  '/Emit.pm',
  '/Emit/Std.pm',
  '/Emit/C.pm',
  '/Emit/Perl.pm',

  '/Lang/fasm.pm',
  '/Lang/peso.pm',

  '/Lang/C.pm',
  '/Lang/Rust.pm',

  '/Lang/SinGL.pm',

  '/Lang/Perl.pm',
  '/Lang/Raku.pm',

# ---   *   ---   *   ---
# then everything else

  '/Avt/Sieve.pm',
  '/Avt/Xcav.pm',
  '/Avt/Makescript.pm',
  '/Avt.pm',

  '/Lang/Mny.pm',
  '/Lang/Python.pm',

# ---   *   ---   *   ---
# trash goes in last

  '/Lang/Js.pm',

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


      elsif($do_cp) {

        my $MAM_PATH=
          "-I$src".q{ }.
          "-I$src/sys".q{ }.
          "-I$src/hacks".q{ }.
          "-I$src/Lang";


        my $PATH_TAKEN;
        my $MAM_ARGS;
        my ($obj,$pmd);

        if(!($src=~ qr{.trash/})) {

          $PATH_TAKEN="PATH A";

          $MAM_ARGS=
            '-MMAM'.q{=}.
            '--rap'.q{,}.

            '--module=avtomat'

          ;

          $pmd=$og;
          $pmd=~ s[$src][$dst];

          $obj=$pmd;
          $pmd.='d';


        } else {

          $PATH_TAKEN="PATH B";

          $MAM_ARGS='-MMAM'.q{=}.
            '--module=avtomat';

          $pmd=$og;
          $obj=$cp;

        };


        my $ex=
          "perl -c".q{ }.

          "$MAM_PATH".q{ }.
          "$MAM_ARGS".q{ }.

          "$og";

        $out=q{};
        $depstr=q{};

        $out=`$ex 2> .errlog`;


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
  `$ENV{'ARPATH'}'/avtomat/bin/sygen'`;

# ---   *   ---   *   ---

print {*STDERR} "\e[37;1m::\e[0mdone\n\n";


# ---   *   ---   *   ---
1; # ret

