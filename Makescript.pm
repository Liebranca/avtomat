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

package Makescript;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Array;
  use Arstd::Path;
  use Arstd::IO;

  use Shb7;

  use Tree::Dep;

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;

  use Lang;
  use Avt;

# ---   *   ---   *   ---

  our $VERSION = v0.01.3;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# and now we need this again ;>
# converts relative paths to absolute

sub nit($class,$M,$cli) {

  $M->{debug}=$cli->{debug}!=$NULL;

  $M->{root}=$Shb7::Root;
  $M->{trash}=Shb7::obj_dir($M->{fswat});

  Shb7::set_module($M->{fswat});

  for my $ref(

    $M->{objs},
    $M->{srcs},
    $M->{xprt},
    $M->{fcpy},
    $M->{gens},

  ) {

    if(!@$ref) {next};

    map

      {$ARG=~ s[^\./|(?<=,)\./][$M->{root}]sg}
      @$ref

    ;

  };

  for my $key(qw(
    incl libs ilib mlib main trash

  )) {

    $M->{$key}//=$NULLSTR;
    $M->{$key}=~ s[\./][$M->{root}]sg;

  };

  $M->{incl}=[split $SPACE_RE,$M->{incl}];
  $M->{libs}=[split $SPACE_RE,$M->{libs}];

  return bless $M;

};

# ---   *   ---   *   ---

sub set_build_paths($M) {

  my @paths=();
  for my $inc(@{$M->{incl}}) {

    if($inc eq q{-I}.$Shb7::Root) {next};
    push @paths,$inc;

  };

  Shb7::stinc(

    @paths,q{.},
    q{-I}.Shb7::dir($M->{fswat})

  );

};

# ---   *   ---   *   ---

sub update_generated($M) {

  my @GENS=@{$M->{gens}};

  if(@GENS) {

    print {*STDERR}
      $Emit::Std::ARSEP."running generators\n";

  };

  # iter the list of generator scripts
  # ... and sources/dependencies for them
  while(@GENS) {

    my $gen=shift @GENS;
    my $res=shift @GENS;

    my @msrcs=Lang::ws_split(
      $COMMA_RE,shift @GENS

    );

# ---   *   ---   *   ---
# make sure we don't need to update

    my $do_gen=!(-e $res);
    if(!$do_gen) {$do_gen=Shb7::ot($res,$gen);};

# ---   *   ---   *   ---
# make damn sure we don't need to update

    if(!$do_gen) {
      while(@msrcs) {
        my $msrc=shift @msrcs;

        # look for wildcard
        if($msrc=~ m/\%/) {
          my @srcs=@{ Shb7::wfind($msrc) };
          while(@srcs) {
            my $src=shift @srcs;

            # found file is updated
            if(Shb7::ot($res,$src)) {
              $do_gen=1;last;

            };
          };if($do_gen) {last};

# ---   *   ---   *   ---

        # look for specific file
        } else {
          $msrc=Shb7::ffind($msrc);
          if(!$msrc) {next};

          # found file is updated
          if(Shb7::ot($res,$msrc)) {
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
        Shb7::shpath($gen)."\n";

      `$gen`;

    };

  };
};

# ---   *   ---   *   ---

sub update_regular($M) {

  my @FCPY=@{$M->{fcpy}};

  if(@FCPY) {

    print {*STDERR}
      $Emit::Std::ARSEP."copying regular files\n";

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

    if(!$do_cpy) {$do_cpy=Shb7::ot($cp,$og);};
    if($do_cpy) {

      print {*STDERR} "$og\n";
      `cp $og $cp`;

    };

  };

};

# ---   *   ---   *   ---

sub update_objects($M) {

  my @INCLUDES=split $SPACE_RE,$M->{incl};

  my $OBJS=$NULLSTR;
  my $objblt=0;

  # print notice
  if(@{$M->{bld}) {

    say {*STDERR}

      $Emit::Std::ARSEP.
      "rebuilding objects"

    ;

  };

  # iter list of source files
  for my $bfile($M->{bld}) {
    $OBJS.=$bfile->{obj}.q{ };
    $objblt+=$bfile->update();

  };

  return ($OBJS,$objblt);

};

# ---   *   ---   *   ---
# manages utils and tests

sub side_builds($M) {

  my $debug=($M->{debug})
    ? q[-g]
    : $NULLSTR
    ;

  my @calls=();

  for my $ref(@{$M->{utils}}) {
    my ($outfile,$srcfile,@flags)=@$ref;

    if($rebuild) {

      push @flags,$debug;
      push @calls,[

        $ENV{'ARPATH'}.
        q[/avtomat/bin/olink],

        (join q[ ],@flags),

        q[-o],$outfile,

        $srcfile

      ];

    };

  };

};

# ---   *   ---   *   ---
# the one we've been waiting for

sub build_binaries($M,$PFLG,$OBJS,$objblt) {

# ---   *   ---   *   ---
# this sub only builds a new binary IF
# there is a target defined AND
# any objects have been updated

  my @OFLG=split $SPACE_RE,$Shb7::OFLG;
  my @LFLG=split $SPACE_RE,$Shb7::LFLG;
  my @PFLG=split $SPACE_RE,$PFLG;

  my @OBJS=split $SPACE_RE,$OBJS;

  my $LIBS=$NULLSTR;
  my @CALLS=();

  if($M->{main} && $objblt) {

    say {*STDERR }

      $Emit::Std::ARSEP,
      'compiling binary ',

      "\e[32;1m",
      Shb7::shpath($M->{main}),

      "\e[0m"

    ;

# ---   *   ---   *   ---
# build mode is 'static library'

    if($M->{lmode} eq 'ar') {

      push @CALLS,[
        qw(ar -crs),
        $M->{main},@OBJS

      ];

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

      $LIBS=Shb7::libexpand($M->{libs});
      my @LIBS=split $SPACE_RE,$LIBS;

# ---   *   ---   *   ---
# build call is the exact same,
# only difference being the -shared flag

      push @CALLS,[

        q[gcc],$M->{lmode},

        ($M->{debug}) ? q[-g] : $NULLSTR,
        @PFLG,@OFLG,

        $M->{incl},@PFLG,@OBJS,@LIBS,
        q[-o],$M->{main}

      ];

# ---   *   ---   *   ---
# for executables we spawn a shadow lib

      if($M->{lmode} ne '-shared ') {

        push @CALLS,[
          qw(ar -crs),
          $M->{mlib},@OBJS

        ];

      };

# ---   *   ---   *   ---
# run build calls and make symbol tables

    };
  };

  if(length $LIBS) {

    for my $call(@CALLS) {
      array_filter($call);
      system {$call->[0]} @$call;

    };

    Avt::symscan(

      $M->{fswat},
      $M->{ilib},

      $LIBS,

      @{$M->{xprt}}

    );

  };

};

# ---   *   ---   *   ---

sub depsmake($M) {

  my $md    = $Shb7::Makedeps;

  my @objs  = @{$md->{objs}};
  my @deps  = @{$md->{deps}};

  my $fswat = $M->{fswat};

  if(@objs && @deps) {

    say {*STDERR}

      $Emit::Std::ARSEP,
      'rebuilding dependencies',

    ;

  };

  my $ex=$AVTOPATH.q[/bin/pmd];

  while(@objs && @deps) {

    my $obj=shift @objs;
    my $dep=shift @deps;

    next if $obj=~ m[Depsmake\.pm$];
    owc($dep,`$ex $fswat $obj`);

  };

  Shb7::clear_makedeps();

};

# ---   *   ---   *   ---
1; # ret
