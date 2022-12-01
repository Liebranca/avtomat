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
  use Shb7::Bk;

  use Tree::Dep;

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;

  use Lang;
  use Avt;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.4;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $CWD_RE=>qr{^\./|(?<=,)\./}x;

# ---   *   ---   *   ---
# shorthand

sub get_build_files($self) {

  return (

    @{$self->{fasm}},
    @{$self->{gcc}},
    @{$self->{mam}},

  );

};

# ---   *   ---   *   ---
# adjust fpath arrays

sub abspath_arr($self) {

  for my $ref(

    $self->{xprt},
    $self->{fcpy},
    $self->{gens},
    $self->{incl},
    $self->{libs},

  ) {

    array_filter($ref);

    map {
      $ARG=~ s[$CWD_RE][$self->{root}]sxmg;

    } @$ref;

  };

};

# ---   *   ---   *   ---
# adjust fpath strings

sub abspath_str($self) {

  for my $ref(
    $self->{ilib},
    $self->{mlib},
    $self->{main},
    $self->{trash},

  ) {

    map {
      $ARG=~ s[$CWD_RE][$self->{root}]sxmg;

    } @$ref;

  };

};

# ---   *   ---   *   ---
# adjust fpaths on build file objects

sub abspath_bfile($self) {

  for my $bfile(@ar) {
    $bfile->{src}=~ s[$CWD_RE][$self->{root}]sxmg;
    $bfile->{obj}=~ s[$CWD_RE][$self->{root}]sxmg;
    $bfile->{asm}=~ s[$CWD_RE][$self->{root}]sxmg;
    $bfile->{out}=~ s[$CWD_RE][$self->{root}]sxmg;

  };

};

# ---   *   ---   *   ---
# ^ shorthand for all

sub abspaths($self) {
  $self->abspath_arr();
  $self->abspath_str();
  $self->abspath_bfile();

};

# ---   *   ---   *   ---
# constructor

sub nit($class) {

  my $self=bless {

    # name of target
    fswat => $NULLSTR,

    # build file containers
    fasm  => [],
    gcc   => [],
    mam   => [],

    # io paths
    root  => $NULLSTR,
    ilib  => $NULLSTR,
    mlib  => $NULLSTR,
    main  => $NULLSTR,
    trash => $NULLSTR,

    # fpath arrays
    xprt  => [],
    fcpy  => [],
    gens  => [],
    utils => [],
    tests => [],

    # search paths/deps
    incl  => [],
    libs  => [],

    # flags
    lmode => $NULLSTR,
    debug => 0,

  },$class;

  return $self;

};

# ---   *   ---   *   ---
# ^initialize existing hashref

sub nit_build($class,$self,$cli) {

  $self=bless $self,$class;

  $self->{debug} = $cli->{debug}!=$NULL;

  $self->{root}  = $Shb7::Root;
  $self->{trash} = Shb7::obj_dir($self->{fswat});

  Shb7::set_module($self->{fswat});
  $self->abspaths();

  return $self;

};

# ---   *   ---   *   ---
# add makescript includes to
# current search path

sub set_build_paths($self) {

  my @paths=();
  for my $inc(@{$self->{incl}}) {

    if($inc eq q{-I}.$Shb7::Path::Root) {next};
    push @paths,$inc;

  };

  push @paths,(
    Shb7::dir($self->{fswat}),q[.]

  );

  Shb7::set_includes(@paths);

};

# ---   *   ---   *   ---
# handle code generator scripts

sub update_generated($self) {

  my @GENS=@{$self->{gens}};

  if(@GENS) {

    say {*STDERR}
      $Emit::Std::ARSEP."running generators";

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
        if($msrc=~ $Shb7::WILDCARD_RE) {

          while(Shb7::wfind($msrc)) {
            my $src=shift @srcs;

            # found file is updated
            if(Shb7::ot($res,$src)) {
              $do_gen=1;last;

            };

          };

          if($do_gen) {last};

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

      say {*STDERR} Shb7::shpath($gen);
      `$gen`;

    };

  };
};

# ---   *   ---   *   ---
# plain cp

sub update_regular($self) {

  my @FCPY=@{$self->{fcpy}};

  if(@FCPY) {

    say {*STDERR}
      $Emit::Std::ARSEP,
      "copying regular files"

    ;

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

      say {*STDERR} "$og";
      `cp $og $cp`;

    };

  };

};

# ---   *   ---   *   ---
# re-run object file compilation

sub update_objects($self) {

  my $objblt = 0;
  my @files  = $self->get_build_files();

  # print notice
  if(@files) {

    say {*STDERR}

      $Emit::Std::ARSEP.
      "rebuilding objects"

    ;

  };

  # iter list of source files
  for my $bfile(@files) {
    $objblt+=$bfile->update();

  };

  my $objs=[map {
    $ARG->{obj}

  } @ar];

  array_filter($objs);
  return ($objs,$objblt);

};

# ---   *   ---   *   ---
# manages utils and tests

sub side_builds($self) {

  my $debug=($self->{debug})
    ? q[-g]
    : $NULLSTR
    ;

  my @calls=();

  for my $ref(@{$self->{utils}}) {
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

sub build_binaries($self,$objs,$objblt) {

# ---   *   ---   *   ---
# this sub only builds a new binary IF
# there is a target defined AND
# any objects have been updated

  my @calls = ();
  my @libs  = ();

  if($self->{main} && $objblt) {

    say {*STDERR }

      $Emit::Std::ARSEP,
      'compiling binary ',

      "\e[32;1m",
      Shb7::shpath($self->{main}),

      "\e[0m"

    ;

# ---   *   ---   *   ---
# build mode is 'static library'

    if($self->{lmode} eq 'ar') {

      push @callsALLS,[
        qw(ar -crs),
        $self->{main},@$objs

      ];

      @libs=@{$self->{libs}};

# ---   *   ---   *   ---
# otherwise it's executable or shared object

    } else {

      if(-e $self->{main}) {
        `rm $self->{main}`;

      };

# ---   *   ---   *   ---
# find any additional libraries we might
# need to link against

      @libs=Shb7::libexpand($self->{libs});

# ---   *   ---   *   ---
# build call is the exact same,
# only difference being the -shared flag

      push @CALLS,[

        q[gcc],$self->{lmode},

        ($self->{debug}) ? q[-g] : $NULLSTR,
        @PFLG,@OFLG,

        $self->{incl},@PFLG,@OBJS,@LIBS,
        q[-o],$self->{main}

      ];

# ---   *   ---   *   ---
# for executables we spawn a shadow lib

      if($self->{lmode} ne '-shared ') {

        push @CALLS,[
          qw(ar -crs),
          $self->{mlib},@OBJS

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

      $self->{fswat},
      $self->{ilib},

      $LIBS,

      @{$self->{xprt}}

    );

  };

};

# ---   *   ---   *   ---

sub depsmake($self) {

  my $md    = $Shb7::Makedeps;

  my @objs  = @{$md->{objs}};
  my @deps  = @{$md->{deps}};

  my $fswat = $self->{fswat};

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
