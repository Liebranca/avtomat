#!/usr/bin/perl
# ---   *   ---   *   ---
# SIEVE
# File-list filters
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::Sieve;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Hash;

  use Shb7;

# ---   *   ---   *   ---
# constructor

sub nit($class,%O) {

  my $self=bless {

    # context data
    C      => $O{config},
    M      => $O{makescript},

    # iter elements
    name   => $NULLSTR,
    trsh   => $NULLSTR,
    dir    => $NULLSTR,
    lmod   => $NULLSTR,

    bindir => $O{bindir},
    libdir => $O{libdir},

    files  => [],

  },$class;

  # set paths
  $self->{name} = $O{config}->{name};
  $self->{dir}  = "./$self->{name}";
  $self->{trsh} = Shb7::rel(
    Shb7::obj_dir($self->{name})

  );

  my $name=$self->{name};

  # for pasting in subpaths
  $self->{lmod}=$self->{dir};
  $self->{lmod}=~ s[${Shb7::Root}/${name}][];

  $self->{lmod}.=($self->{lmod})
    ? q{/}
    : $NULLSTR
    ;

  return $self;

};

# ---   *   ---   *   ---
# walker

sub iter($self,$dirs) {

  for my $dir(@$dirs) {
    $self->get_files($dir);
    $self->take();

  };

  # post-build, single-source bins
  $self->side_build(
    $self->{M}->{utils},
    $self->{C}->{utils},

  );

  $self->side_build(
    $self->{M}->{tests},
    $self->{C}->{tests},

  );

};

# ---   *   ---   *   ---
# build file list from tree node

sub get_files($self,$node) {

  my $name=$self->{name};

  @{$self->{files}}=$node->get_file_list(
    full_path=>1,
    max_depth=>1,

  );

  # shorten paths
  map {
    $ARG=Shb7::shpath($ARG)

  } @{$self->{files}};

  # pop module name
  map {
    $ARG=~ s[^${name}/?][]

  } @{$self->{files}};

};

# ---   *   ---   *   ---
# pushes two entries per result

sub dual_out(

  $self,

  $dst,$src,
  $outdir,$outmod

) {

  my $matches=lfind($src,$self->{files});

  while(@$matches) {

    my $match=shift @$matches;
    delete $src->{$match};

    push @$dst,(
      "$self->{dir}/$match",
      "$outdir/$outmod$match"

    );

  };

};

# ---   *   ---   *   ---
# ^same, match is list

sub arr_dual_out($self,$dst,$src) {

  my $matches=lfind(
    $src,$self->{files}

  );

  while(@$matches) {

    my $match=shift @$matches;
    my ($outfile,$deps)=@{
      $src->{$match}

    };

    delete $src->{$match};
    map {$ARG="$self->{dir}/$ARG"} @$deps;

    push @$dst,(
      "$self->{dir}/$match",
      "$self->{dir}/$outfile",

      (join q{,},@$deps)

    );

  };

};

# ---   *   ---   *   ---
# turns *.ext into (*.o,*.d)

sub gcc_bfiles($key,$ext) {

  my $ob=$key;
  $ob=~ s[$ext][];
  $ob.='.o';

  my $dep=$key;
  $dep=~ s[$ext][];
  $dep.='.d';

  return ($ob,$dep);

};

# ---   *   ---   *   ---
# c/cpp to GCC

sub c_files($self,$dst_s,$dst_o) {

  state $c_ext=qr{\.(?:cpp|c)$}x;

  my @matches=grep m/$c_ext/,
    @{$self->{files}};

  while(@matches) {

    my $match=shift @matches;

    my ($ob,$dep)=gcc_bfiles(
      $match,$c_ext

    );

    push @$dst_s,"$self->{dir}/$match";
    push @$dst_o,(
      "$self->{trsh}/$ob",
      "$self->{trsh}/$dep"

    );

  };

};

# ---   *   ---   *   ---
# *.pm to MAM

sub pm_files($self,$dst_s,$dst_o,$outdir) {

  state $perl_ext=qr{\.pm$};

  my @matches=grep m/$perl_ext/,
    @{$self->{files}};

  my $name=$self->{name};

  while(@matches) {
    my $match=shift @matches;

    my $dep=$match;
    $dep.='d';

    push @$dst_s,"$self->{dir}/$match";

    my $lmod=$self->{dir};
    $lmod=~ s([.]/${name})();

    push @$dst_o,(
      "$outdir$lmod/$match",
      "$self->{trsh}$dep"

    );

  };

};

# ---   *   ---   *   ---
# walrus van rossum

sub py_files($self,$dst,$outdir) {

  state $python_ext=qr{\.py$};
  my $name=$self->{name};

  my @matches=grep m/$python_ext/,
    @{$self->{files}};

  while(@matches) {
    my $match=shift @matches;

    my $lmod=$self->{dir};
    $lmod=~ s([.]/${name})();

    push @$dst,(
      "$self->{dir}/$match",
      "$outdir$lmod/$match"

    );

  };

};

# ---   *   ---   *   ---
# pushes single entry per result

sub single_out($self,$dst,$src) {

  my $matches=lfind($src,$self->{files});

  while(@$matches) {

    my $match=shift @$matches;
    delete $src->{$match};

    push @$dst,"$self->{dir}/$match";

  };

};

# ---   *   ---   *   ---
# for snippets that require
# individual compilation

sub side_build($self,$dst,$src) {

  for my $outfile(keys %$src) {

    my $ref=$src->{$outfile};
    my ($srcfile,@flags)=@$ref;

    push @$dst,[
      $outfile,
      $srcfile,
      @flags,

    ];

  };

};

# ---   *   ---   *   ---
# processes file list boiler

sub take($self) {

  # generators
  $self->arr_dual_out(
    $self->{M}->{gens},
    $self->{C}->{gens},

  );

  # project ./bin copy
  $self->dual_out(
    $self->{M}->{fcpy},
    $self->{C}->{xcpy},

    $self->{bindir},$NULLSTR

  );

  # project ./lib copy
  $self->dual_out(
    $self->{M}->{fcpy},
    $self->{C}->{lcpy},

    $self->{libdir},$self->{lmod}

  );

  # headers for post-build scanning
  $self->single_out(
    $self->{M}->{xprt},
    $self->{C}->{xprt},

  );

  # selfex
  $self->c_files(
    $self->{M}->{srcs},
    $self->{M}->{objs},

  );

  $self->pm_files(
    $self->{M}->{srcs},
    $self->{M}->{objs},

    $self->{libdir},

  );

  $self->py_files(
    $self->{M}->{fcpy},
    $self->{libdir},

  );

};

# ---   *   ---   *   ---
1; # ret
