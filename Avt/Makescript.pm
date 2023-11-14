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

package Avt::Makescript;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;
  use English qw(-no_match_vars);
  use Cwd qw(abs_path);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Array;
  use Arstd::Path;
  use Arstd::IO;

  use Arstd::WLog;

  use Shb7;
  use Cli;

  use Shb7::Bfile;
  use Shb7::Build;
  use Shb7::Bk::gcc;
  use Shb7::Bk::mam;
  use Shb7::Bk::flat;
  use Shb7::Bk::fake;

  use Tree::Dep;

  use lib $ENV{'ARPATH'}.'/lib/hacks';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit::Std;

  use Lang;
  use Lang::C;
  use Lang::Perl;

  use Avt::Xcav;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.5;
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $CWD_RE=>qr{^\./|(?<=,)\./}x;

# ---   *   ---   *   ---
# get bfiles of all containers

sub get_build_files($self) {

  use Avt::flatten;

# ---   *   ---   *   ---
# NOTE:
#
# fasm headers can't be included
# out of order as they are generated
# by the build itself!
#
# due to this, we have to sort this
# flist accto the dependency list

  my @src  = $self->{flat}->bfiles();
  my %keys = map {abs_path($ARG->{src})=>$ARG} @src;

  my @flat = map {
    $keys{$ARG}

  } grep {
    exists $keys{$ARG};

  } Avt::flatten->cpproc(
    'build_deps',
    @src

  );

# ---   *   ---   *   ---


  return (

    @flat,

    $self->{gcc}->bfiles(),
    $self->{mam}->bfiles(),

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

    next if !defined $ref;
    $ref=~ s[$CWD_RE][$self->{root}]sxmg;

  };

};

# ---   *   ---   *   ---
# adjust fpaths on build file objects

sub abspath_bfile($self) {

  for my $bfile($self->get_build_files()) {
    $bfile->{src}=~ s[$CWD_RE][$self->{root}]sxmg;
    $bfile->{obj}=~ s[$CWD_RE][$self->{root}]sxmg;
    $bfile->{asm}=~ s[$CWD_RE][$self->{root}]sxmg;
    $bfile->{out}=~ s[$CWD_RE][$self->{root}]sxmg;

  };

};

# ---   *   ---   *   ---
# ^shorthand for all

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
    mkwat => $NULLSTR,

    # build file containers
    flat  => Shb7::Bk::flat->new(
      pproc=>'Avt::flatten::pproc',

    ),

    gcc   => Shb7::Bk::gcc->new(),
    mam   => Shb7::Bk::mam->new(),

    # io paths
    root  => $NULLSTR,
    ilib  => $NULLSTR,
    mlib  => $NULLSTR,
    main  => $NULLSTR,
    trash => $NULLSTR,

    # fpath arrays
    xprt  => [],
    fcpy  => Shb7::Bk::fake->new(),
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

sub nit_build($class,$self,@cmd) {

  my ($cli,@args)=$class->read_cli(@cmd);

  $self=bless $self,$class;

  $self->{debug} = $cli->{debug}!=$NULL;

  $self->{root}  = $Shb7::Path::Root;
  $self->{trash} = Shb7::obj_dir($self->{fswat});

  Shb7::set_module($self->{fswat});
  $self->abspaths();

  $self->{bld}=Shb7::Build->new(

    files  => [],
    name   => $self->{main},

    incl   => $self->{incl},
    libs   => $self->{libs},

    shared => $self->{lmode} eq '-shared',
    debug  => $self->{debug},
    tgt    => $Shb7::Bk::TARGET->{x64},

    flat   => ($cli->{flat} ne $NULL)
      ? 1
      : 0
      ,

  );


  return $self;

};

# ---   *   ---   *   ---
# ^iface

sub read_cli($class,@cmd) {

  state @tab=(

    { id    => 'debug',
      short => '-d',
      long  => '--debug',
      argc  => 0

    },

    { id    => 'flat',
      short => '-f',
      long  => '--flat',
      argc  => 0

    },

  );


  # ^make ice and run
  my $cli  = Cli->nit(@tab);
  my @args = $cli->take(@cmd);

  # ^give
  return ($cli,@args);

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

  my @GENS = @{$self->{gens}};
  my $done = 0;

  $WLog->step("running generators")
  if @GENS;

  # iter the list of generator scripts
  # ... and sources/dependencies for them
  for my $ref(@GENS) {

    my ($res,$gen,@msrcs)=@$ref;

# ---   *   ---   *   ---
# make sure we don't need to update

    my $do_gen=(-e $res)
      ? Shb7::ot($res,$gen)
      : 1
      ;

# ---   *   ---   *   ---
# make damn sure we don't need to update

    if(! $do_gen) {

      while(@msrcs) {
        my $msrc=shift @msrcs;

        # look for wildcard
        if($msrc=~ $Shb7::WILDCARD_RE) {

          for my $src(Shb7::wfind($msrc)) {

            # found file is updated
            if(Shb7::ot($res,$src)) {
              $do_gen=1;
              last;

            };

          };

          last if $do_gen;

# ---   *   ---   *   ---

        # look for specific file
        } else {
          $msrc=Shb7::ffind($msrc);
          next if !$msrc;

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

      $WLog->ex(Shb7::shpath($gen));
      `$gen`;

      $done=1;

    };

  };

  $WLog->line() if $done;

};

# ---   *   ---   *   ---
# plain cp

sub update_regular($self) {

  my @FCPY = map {

    (Shb7::Bfile->is_valid($ARG))
      ? $ARG->unroll('src','out')
      : $ARG
      ;

  } @{$self->{fcpy}};


  my $done = 0;

  $WLog->step("copying regular files")
  if @FCPY;

  while(@FCPY) {
    my $og=shift @FCPY;
    my $cp=shift @FCPY;

    my @ar=split '/',$cp;
    my $base_path=join '/',@ar[0..$#ar-1];

    if(! -e $base_path) {
      `mkdir -p $base_path`;

    };

    my $do_cpy=!(-e $cp);

    $do_cpy=(! $do_cpy)
      ? Shb7::ot($cp,$og)
      : $do_cpy
      ;

    if($do_cpy) {

      $WLog->substep($og);
      `cp $og $cp`;

      $done=1;

    };

  };

  $WLog->line() if $done;

};

# ---   *   ---   *   ---
# re-run object file compilation

sub update_objects($self) {

  my $bfiles = [];
  my $objblt = 0;

  my @files  = $self->get_build_files();

  $WLog->step("rebuilding objects")
  if @files;

  # iter list of source files
  for my $bfile(@files) {
    $objblt+=$bfile->update($self->{bld});

    push @$bfiles,$bfile
    if $bfile->linkable();

  };

  $self->{bld}->push_files(@$bfiles);
  $WLog->line() if $objblt;


  return $objblt;

};

# ---   *   ---   *   ---
# picks backend from source ext

sub bk_for($self,$src) {

  my $out=undef;

  if($src=~ Lang::C->{ext}) {
    $out=$self->{gcc};

  } elsif($src=~ Lang::Perl->{ext}) {
    $out=$self->{mam};

  };

  return $out;

};

# ---   *   ---   *   ---
# manages utils and tests

sub side_builds($self) {

  my @calls  = ();
  my $done   = 0;

  my $bindir = $self->{root}.'bin/';
  my $srcdir = $self->{root}.$self->{fswat}.q[/];

  for my $ref(@{$self->{utils}}) {

    my ($outfile,$srcfile,@flags)=@$ref;

    my $bld=Shb7::Build->new(

      files  => [],
      name   => $bindir.$outfile,

      incl   => $self->{incl},
      libs   => [
        q[-l].$self->{mkwat},
        @{$self->{libs}},

      ],

      shared => 0,
      debug  => $self->{debug},

      tgt    => $Shb7::Bk::TARGET->{x64},
      flat   => 0,

    );

    my $bk    = $self->bk_for($srcfile);
    my $bfile = $bk->push_src($srcdir.$srcfile);

    $done|=$bfile->update($bld);

    $bld->push_files($bfile);
    $bld->push_flags(@flags);

    if($bfile->linkable()) {
      $bld->olink();

    };

  };

  $WLog->line() if $done;

};

# ---   *   ---   *   ---
# the one we've been waiting for

sub build_binaries($self,$objblt) {

# ---   *   ---   *   ---
# this sub only builds a new binary IF
# there is a target defined AND
# any objects have been updated

  my @calls = ();
  my @libs  = ();

  my @objs  = map {
    $ARG->{obj}

  } @{$self->{bld}->{files}};

  @libs=@{$self->{bld}->{libs}};

  if($self->{main} && $objblt && @objs) {

    $WLog->fupdate(
      Shb7::shpath($self->{main}),
      'compiling binary'

    );

# ---   *   ---   *   ---
# build mode is 'static library'

    if($self->{lmode} eq 'ar') {

      push @calls,[
        qw(ar -crs),
        $self->{main},@objs

      ];

# ---   *   ---   *   ---
# otherwise it's executable or shared object

    } else {

      if(-f $self->{main}) {
        unlink $self->{main};

      };

# ---   *   ---   *   ---
# for executables we spawn a shadow lib

      if($self->{lmode} ne '-shared ') {

        push @calls,[
          qw(ar -crs),
          $self->{mlib},@objs

        ];

      };

      $self->{bld}->olink();

# ---   *   ---   *   ---
# run build calls and make symbol tables

    };

  };

  for my $call(@calls) {
    array_filter($call);
    system {$call->[0]} @$call;

  };

  if(@libs && $self->{ilib}) {

    $WLog->fupdate(
      $self->{fswat},
      'compiling shwl for'

    );

    Avt::Xcav::symscan(

      $self->{fswat},
      $self->{ilib},

      \@libs,

      @{$self->{xprt}}

    );

  };

};

# ---   *   ---   *   ---
# writes *.pm dependency files

sub depsmake($self) {

  my $md    = $Shb7::Build::Makedeps;

  my @objs  = @{$md->{objs}};
  my @deps  = @{$md->{deps}};

  my $fswat = $self->{fswat};

  $WLog->step('rebuilding dependencies')
  if @objs && @deps;

  my $ex=$AVTOPATH.q[/bin/pmd];

  while(@objs && @deps) {

    my $obj=shift @objs;
    my $dep=shift @deps;

    next if $obj=~ m[Depsmake\.pm$];

    my $body=`$ex $fswat $obj`;
    owc($dep,$body);

  };

  Shb7::clear_makedeps();

};

# ---   *   ---   *   ---
1; # ret
