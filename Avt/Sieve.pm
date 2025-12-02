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
# lib,

# ---   *   ---   *   ---
# deps

package Avt::Sieve;
  use v5.42.0;
  use strict;
  use warnings;

  use Cwd qw(abs_path);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Arstd::Hash qw(lfind);
  use Arstd::String qw(catpath);
  use Shb7::Path qw(root relto_root);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.2';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {
  my $self=bless {
    # context data
    C      => $O{config},
    M      => $O{makescript},

    # iter elements
    name   => null,
    dir    => null,
    lmod   => null,

    bindir => $O{bindir},
    libdir => $O{libdir},

    file   => [],

  },$class;

  $self->set_paths();
  return $self;
};


# ---   *   ---   *   ---
# directory boiler

sub set_paths($self) {
  $self->{name} = $self->{C}->{name};
  $self->{dir}  = $self->{name};

  my $name=$self->{name};

  # for pasting in subpaths
  my $re=catpath(root(),$name);
     $re=qr{$re};

  $self->{lmod}  =  $self->{dir};
  $self->{lmod}  =~ s[$re][];
  $self->{lmod} .=  ($self->{lmod})
    ? q{/}
    : null
    ;

  # the mampy exception
  $self->{p_out}=  $self->{dir};
  $self->{p_out}=~ s([.]/${name})();

  $self->{p_out}=catpath(
    $self->{libdir},
    $self->{p_out}
  );

  return;
};


# ---   *   ---   *   ---
# walker

sub iter($self,$dirs) {
  # sorts stuff out
  for(@$dirs) {
    $self->get_files($ARG);
    $self->agroup_files();
  };

  # ^post-build, single-source bins
  $self->side_build(
    $self->{M}->{util},
    $self->{C}->{util},
  );

  $self->side_build(
    $self->{M}->{test},
    $self->{C}->{test},
  );

  return;
};


# ---   *   ---   *   ---
# build file list from tree node

sub get_files($self,$node) {
  my $name=$self->{name};
  @{$self->{file}}=$node->get_filepath_list(
    full=>1,
    max_depth=>1,
  );

  # shorten paths
  # pop mod from start
  for(@{$self->{file}}) {
    $ARG=abs_path($ARG);
    relto_root($ARG);

    $ARG=~ s[^${name}/?][];
  };

  return;
};


# ---   *   ---   *   ---
# processes file list boiler

sub agroup_files($self) {
  # generators
  $self->arr_dual_out(
    $self->{M}->{gen},
    $self->{C}->{gen},
  );

  # project ./bin copy
  $self->dual_out(
    $self->{M}->{fcpy},
    $self->{C}->{xcpy},

    $self->{bindir},null
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

  return;
};


# ---   *   ---   *   ---
# pushes two entries per result

sub dual_out(
  $self,
  $dst,$src,
  $outdir,$outmod
) {
  my $matches=lfind($src,$self->{file});
  while(@$matches) {
    my $match=shift @$matches;
    delete $src->{$match};

    push @$dst,(
      "$self->{dir}/$match",
      "$outdir/$outmod$match"
    );
  };
  return;
};


# ---   *   ---   *   ---
# ^same, match is list

sub arr_dual_out($self,$dst,$src) {
  my $matches=lfind($src,$self->{file});
  while(@$matches) {
    my $match=shift @$matches;
    my ($outfile,@deps)=@{$src->{$match}};

    delete $src->{$match};
    $ARG="$self->{dir}/$ARG" for @deps;

    push @$dst,[
      "$self->{dir}/$match",
      "$self->{dir}/$outfile",

      @deps
    ];
  };
  return;
};


# ---   *   ---   *   ---
# filter by extension
# single out

sub by_ext_s($self,$tab) {
  for(keys %$tab) {
    my $ext=$ARG;
    my $dst=$tab->{$ext};

    $dst->push_src("$self->{dir}/$ARG")
    for grep {$ARG=~ $ext} @{$self->{file}};
  };
  return;
};


# ---   *   ---   *   ---
# ^s/asm to fasm
# ^c/cpp to cmam

sub s_files($self) {
  my $tab={
    qr{\.(?:s|asm)$} => $self->{M}->{flat},
    qr{\.(?:cpp|c)$} => $self->{M}->{cmam},
  };
  $self->by_ext_s($tab);
  return;
};


# ---   *   ---   *   ---
# filter by extension
# dual out

sub by_ext_d($self,$tab) {
  my $name=$self->{name};
  for(keys %$tab) {
    my $ext=$ARG;
    my $dst=$tab->{$ext};

    for(grep m[$ext],@{$self->{file}}) {
      $dst->push_src(
        "$self->{dir}/$ARG",
        "$self->{p_out}/$ARG"
      );
    };
  };
  return;
};


# ---   *   ---   *   ---
# walrus van rossum

sub d_files($self) {
  my $tab={
    qr{\.pm$} => $self->{M}->{mam},
    qr{\.py$} => $self->{M}->{fcpy},
  };
  $self->by_ext_d($tab);
  return;
};


# ---   *   ---   *   ---
# pushes single entry per result

sub single_out($self,$dst,$src) {
  my $matches=lfind($src,$self->{file});
  while(@$matches) {
    my $match=shift @$matches;

    delete $src->{$match};
    push @$dst,"$self->{dir}/$match";
  };
  return;
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
  return;
};


# ---   *   ---   *   ---
1; # ret
