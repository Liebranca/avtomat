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

  $self->set_paths();
  return $self;

};

# ---   *   ---   *   ---
# directory boiler

sub set_paths($self) {

  $self->{name} = $self->{C}->{name};
  $self->{dir}  = "./$self->{name}";
  $self->{trsh} = Shb7::rel(
    Shb7::trash($self->{name})

  );

  my $name=$self->{name};

  # for pasting in subpaths
  $self->{lmod}=$self->{dir};
  $self->{lmod}=~ s[${Shb7::Path::Root}/${name}][];

  $self->{lmod}.=($self->{lmod})
    ? q{/}
    : $NULLSTR
    ;

  # the mampy exception
  $self->{p_out}=$self->{dir};
  $self->{p_out}=~ s([.]/${name})();

  $self->{p_out}=
    $self->{libdir}.
    $self->{p_out}

  ;

};

# ---   *   ---   *   ---
# walker

sub iter($self,$dirs) {

  for my $dir(@$dirs) {
    $self->get_files($dir);
    $self->agroup_files();

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
    my ($outfile,@deps)=@{
      $src->{$match}

    };

    delete $src->{$match};
    map {$ARG="$self->{dir}/$ARG"} @deps;

    push @$dst,[
      "$self->{dir}/$match",
      "$self->{dir}/$outfile",

      @deps

    ];

  };

};

# ---   *   ---   *   ---
# filter by extension
# single out

sub by_ext_s($self,$tab) {

  map {

    my $ext=$ARG;
    my $dst=$tab->{$ext};

    map {
      $dst->push_src("$self->{dir}/$ARG");

    } grep m/$ext/,@{$self->{files}};

  } keys %$tab;

}

# ---   *   ---   *   ---
# ^s/asm to fasm
# ^c/cpp to gcc

sub s_files($self) {

  state $tab={
    qr{\.(?:s|asm)$}x => $self->{M}->{flat},
    qr{\.(?:cpp|c)$}x => $self->{M}->{gcc},

  };

  $self->by_ext_s($tab);

};

# ---   *   ---   *   ---
# filter by extension
# dual out

sub by_ext_d($self,$tab) {

  my $name=$self->{name};

  map {

    my $ext=$ARG;
    my $dst=$tab->{$ext};

    map {

      $dst->push_src(
        "$self->{dir}/$ARG",
        "$self->{p_out}/$ARG"

      );

    } grep m/$ext/,@{$self->{files}};

  } keys %$tab;

};

# ---   *   ---   *   ---
# walrus van rossum

sub d_files($self) {

  state $tab={
    qr{\.pm$} => $self->{M}->{mam},
    qr{\.py$} => $self->{M}->{fcpy},

  };

  $self->by_ext_d($tab);

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

sub agroup_files($self) {

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

  # push source to builders
  $self->s_files();
  $self->d_files();

};

# ---   *   ---   *   ---
1; # ret
