#!/usr/bin/perl
# ---   *   ---   *   ---
# MAKESCRIPT
# Builds your shit
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps

package makescript;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use style;
  use arstd;
  use shb7;

  use emit::std;

  use lang;
  use avt;

# ---   *   ---   *   ---

  our $VERSION=v0.01.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# and now we need this again ;>
# converts relative paths to absolute

sub nit($M) {

  $M->{root}=$shb7::root;
  $M->{trash}=shb7::obj_dir($M->{fswat});

  for my $ref(

    $M->{objs},
    $M->{srcs},
    $M->{xprt},
    $M->{fcpy},
    $M->{gens},

  ) {

    if(!@$ref) {next};

    map

      {$ARG=~ s[^\./|(?<=,)\./][$M->{root}/]sg}
      @$ref

    ;

  };

  for my $key(qw(
    incl libs ilib mlib main trash

  )) {

    $M->{$key}//=$NULLSTR;
    $M->{$key}=~ s[\./][$M->{root}/]sg;

  };

  return bless $M;

};

# ---   *   ---   *   ---

sub set_build_paths($M) {

  my @paths=();
  for my $inc(lang::ws_split(
    $SPACE_RE,$M->{incl})

  ) {

    if($inc eq q{-I}.$shb7::root) {next};
    push @paths,$inc;

  };

  avt::stinc(

    @paths,q{.},
    q{-I}.$shb7::dir($M->{fswat})

  );

};

# ---   *   ---   *   ---

sub update_generated($M) {

  my @GENS=@{$M->{gens}};

  if(@GENS) {

    print {*STDERR}
      $emit::std::ARSEP."running generators\n";

  };

  # iter the list of generator scripts
  # ... and sources/dependencies for them
  while(@GENS) {

    my $gen=shift @GENS;
    my $res=shift @GENS;

    my @msrcs=lang::ws_split(
      $COMMA_RE,shift @GENS

    );

# ---   *   ---   *   ---
# make sure we don't need to update

    my $do_gen=!(-e $res);
    if(!$do_gen) {$do_gen=shb7::ot($res,$gen);};

# ---   *   ---   *   ---
# make damn sure we don't need to update

    if(!$do_gen) {
      while(@msrcs) {
        my $msrc=shift @msrcs;

        # look for wildcard
        if($msrc=~ m/\%/) {
          my @srcs=@{ avt::wfind($msrc) };
          while(@srcs) {
            my $src=shift @srcs;

            # found file is updated
            if(shb7::ot($res,$src)) {
              $do_gen=1;last;

            };
          };if($do_gen) {last};

# ---   *   ---   *   ---

        # look for specific file
        } else {
          $msrc=avt::ffind($msrc);
          if(!$msrc) {next};

          # found file is updated
          if(shb7::ot($res,$msrc)) {
            $do_gen=1;
            last;

          };

        };
      };
    };

# ---   *   ---   *   ---
# run the generator script

    if($do_gen) {

      print {*STDERR}
        shb7::shpath($gen)."\n";

      `$gen`;

    };

  };
};

# ---   *   ---   *   ---

sub update_regular($M) {

  my @FCPY=@{$M->{fcpy}};

  if(@FCPY) {

    print {*STDERR}
      $emit::std::ARSEP."copying regular files\n";

  };

  while(@FCPY) {
    my $og=shift @FCPY;
    my $cp=shift @FCPY;

    my @ar=split '/',$cp;
    my $base_path=join '/',@ar[0..$#ar-1];

    if(!(-e $base_path)) {
      `mkdir -p $base_path`;

    };

    my $do_cpy=!(-e $cp);

    if(!$do_cpy) {$do_cpy=shb7::ot($cp,$og);};
    if($do_cpy) {

      print {*STDERR} "$og\n";
      `cp $og $cp`;

    };

  };

};

# ---   *   ---   *   ---

sub update_objects($M,$DFLG,$PFLG) {

  state $obj_ext=qr{\.o$};

  my @SRCS=@{$M->{srcs}};
  my @OBJS=@{$M->{objs}};

  my $INCLUDES=$M->{incl};

  my $OBJS=$NULLSTR;
  my $objblt=0;

  if(@SRCS) {

    print {*STDERR}
      $emit::std::ARSEP."rebuilding objects\n";

  };

# ---   *   ---   *   ---
# iter list of source files

  for(my ($i,$j)=(0,0);$i<@SRCS;$i++,$j+=2) {

    my $src=$SRCS[$i];

    my $obj=$OBJS[$j+0];
    my $mmd=$OBJS[$j+1];

    if($src=~ lang->perl->{ext}) {
      $M->pcc($src,$obj,$mmd);
      next;

    };

    $OBJS.=$obj.q{ };
    my @deps=($src);

# ---   *   ---   *   ---
# look at *.d files for additional deps

    my $do_build=!(-e $obj);
    if($mmd) {
      @deps=@{parsemmd($mmd)};

    };

    # no missing deps
    static_depchk($src,\@deps);

    # make sure we need to update
    buildchk(\$do_build,$obj,\@deps);

# ---   *   ---   *   ---
# rebuild the object

    if($do_build) {

      print {*STDERR} shb7::shpath($src)."\n";

      my $asm=$obj;
      $asm=~ s[$obj_ext][.asm];

      my $call=''.
        'gcc -MMD'.q{ }.$avt::OFLG.q{ }.
        "$INCLUDES $DFLG $PFLG ".
        "-Wa,-a=$asm -c $src -o $obj";

      `$call`;$objblt++;

    };

# ---   *   ---   *   ---
# return string containing list of objects
# + the count of objects built

  };

  return $OBJS,$objblt;

};

# ---   *   ---   *   ---
# the one we've been waiting for

sub build_binaries($M,$PFLG,$OBJS,$objblt) {

# ---   *   ---   *   ---
# this sub only builds a new binary IF
# there is a target defined AND
# any objects have been updated

  my $LIBS=$NULLSTR;
  my @CALLS=();

  if($M->{main} && $objblt) {

    print {*STDERR }
      $emit::std::ARSEP.'compiling binary '.

      "\e[32;1m".
      shb7::shpath($M->{main}).

      "\e[0m\n";

# ---   *   ---   *   ---
# build mode is 'static library'

    if($M->{lmode} eq 'ar') {
      push @CALLS,"ar -crs $M->{main} $OBJS";
      $LIBS=$M->{libs};

# ---   *   ---   *   ---
# otherwise it's executable or shared object

    } else {

      if(-e $M->{main}) {
        `rm $M->{main}`;

      };

# ---   *   ---   *   ---
# find any additional libraries we might
# need to link against

      $LIBS=avt::libexpand($M->{libs});

# ---   *   ---   *   ---
# build call is the exact same,
# only difference being the -shared flag

      push @CALLS,"gcc $M->{lmode} ".

        $avt::OFLG.q{ }.$avt::LFLG.q{ }.

        "$M->{incl} $PFLG $OBJS $LIBS ".
        " -o $M->{main}";

# ---   *   ---   *   ---
# for executables we spawn a shadow lib

      if($M->{lmode} ne '-shared ') {
        push @CALLS,"ar -crs $M->{mlib} $OBJS";

      };

# ---   *   ---   *   ---
# run build calls and make symbol tables

    };
  };

  if(length $LIBS) {

    for my $call(@CALLS) {`$call`};
    avt::symscan(

      $M->{fswat},
      $M->{ilib},

      $LIBS,

      @{$M->{xprt}}

    );

  };

};

# ---   *   ---   *   ---

sub static_depchk($src,$deps) {

  for(my $x=0;$x<@$deps;$x++) {
    if($deps->[$x] && !(-e $deps->[$x])) {

      arstd::errout(

        "%s missing dependency %s\n",

        args=>[shb7::shpath($src),$deps->[$x]],
        lvl=>$FATAL,

      );
    };
  };
};

# ---   *   ---   *   ---

sub buildchk($do_build,$obj,$deps) {

  if(!$$do_build) {
    while(@$deps) {
      my $dep=shift @$deps;
      if(!(-e $dep)) {next};

      # found dep is updated
      if(shb7::ot($obj,$dep)) {
        $$do_build=1;
        last;

      };
    };
  };
};

# ---   *   ---   *   ---
# makes file list out of gcc .d files

sub parsemmd($dep) {

  my $out=[];
  if(!(-e $dep)) {goto TAIL};

  $dep=arstd::orc($dep);
  $dep=~ s/\\//g;
  $dep=~ s/\s/\,/g;
  $dep=~ s/.*\://;

# ---   *   ---   *   ---

  my @tmp=lang::ws_split($COMMA_RE,$dep);
  my @deps=();

  while(@tmp) {
    my $f=shift @tmp;
    if($f) {push @deps,$f;};

  };

# ---   *   ---   *   ---

  $out=\@deps;

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# makes file list out of pcc .pmd files

sub parsepmd($dep) {

  my $out=[];

  if(!(-e $dep)) {goto TAIL};

  open my $FH,'<',$dep or croak STRERR($dep);

  my $fname=readline $FH;
  my $depstr=readline $FH;

  close $FH;

  if(!defined $fname || !defined $depstr) {
    goto TAIL;

  };

  my @tmp=lang::ws_split($SPACE_RE,$depstr);
  my @deps=();

  while(@tmp) {
    my $f=shift @tmp;
    if($f) {push @deps,$f};

  };

# ---   *   ---   *   ---

  $out=\@deps;

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# 0-800-Call MAM

sub pcc($M,$src,$obj,$pmd) {

  if($src=~ m[MAM\.pm]) {
    goto TAIL;

  };

  my @deps=($src);

# ---   *   ---   *   ---
# look at *.d files for additional deps

  my $do_build=!(-e $obj);

  if($pmd) {
    @deps=@{parsepmd($pmd)};

  };

  # no missing deps
  static_depchk($src,\@deps);

  # make sure we need to update
  buildchk(\$do_build,$obj,\@deps);

# ---   *   ---   *   ---

  if($do_build) {

    print {*STDERR} shb7::shpath($src)."\n";

    my $ex=
      "perl".q{ }.

      "-I$ENV{ARPATH}/avtomat/".q{ }.
      "-I$ENV{ARPATH}/avtomat/hacks".q{ }.
      "-I$ENV{ARPATH}/avtomat/peso".q{ }.
      "-I$ENV{ARPATH}/avtomat/langdefs".q{ }.

      "-I$ENV{ARPATH}/$M->{fswat}".q{ }.
      "$M->{incl}".q{ }.

      "-MMAM=-md,--rap,--module=$M->{fswat}".q{ }.

      "$src";

    my $out=`$ex 2> $ENV{ARPATH}/avtomat/.errlog`;

    if(!length $out) {
      my $log=`cat $ENV{ARPATH}/avtomat/.errlog`;
      print {*STDERR} "$log\n";

    };

# ---   *   ---   *   ---

    my $re=$shwl::DEPS_RE;
    my $depstr;

    if($out=~ s/$re//sm) {
      $depstr=${^CAPTURE[0]};

    } else {
      croak "Can't fetch dependencies for $src";

    };

# ---   *   ---   *   ---

    for my $fname($obj,$pmd) {
      if(!(-e $fname)) {
        my $path=arstd::dirof($fname);
        `mkdir -p $path`;

      };
    };

# ---   *   ---   *   ---

    my $FH;

    open $FH,'+>',$pmd or croak STRERR($pmd);
    print {$FH} $depstr;

    close $FH;

    open $FH,'+>',$obj or croak STRERR($obj);
    print {$FH} $out;

    close $FH;

  };

# ---   *   ---   *   ---

TAIL:
  return;

};

# ---   *   ---   *   ---
1; # ret
