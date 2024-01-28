#!/usr/bin/perl
# ---   *   ---   *   ---
# FILE TREE
# Adds file-specific stuff
# to the tree class
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Tree::File;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::Array;

  use parent 'Tree';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,$frame,@args) {

  my $tree=Tree::new($class,$frame,@args);

  $tree->{cksum}=0;
  $tree->{updated}=0;
  $tree->{objects}=[];

  return $tree;

};

# ---   *   ---   *   ---
# runs checksums recursively

sub get_cksum($self) {

  my @old_sums=();
  my @new_sums=();

  my @dirs=($self->get_dir_list(
    full_path=>0

  ));

  array_filter(\@dirs,sub {-d $ARG->{value}});

  for my $dir(reverse @dirs) {

    my @files=$dir->get_file_list(
      full_path=>0,
      max_depth=>1,

    );

    @files=grep {-f $ARG} @files;

    my $files=join q{ },
      map {$ARG->ances(join_char=>$NULLSTR)} @files;

    next if !length $files;

    my $own_sum=`cksum $files`;


    # sum files in directory
    my @file_sums=split $NEWLINE_RE,$own_sum;
    for my $file(@files) {

      my $sum=shift @file_sums;
      push @old_sums,$file->{cksum};

      $file->{cksum}=$sum;

      push @new_sums,$file->{cksum};

    };


    # ^sum all results for directory's sum
    my @children=map {$ARG->{cksum}} @files;
    my $children=join "\n",@children;

    push @old_sums,$dir->{cksum};

    $dir->{cksum}=
      `echo "$own_sum$children" | cksum`;

    chomp $dir->{cksum};
    $dir->{cksum}.=q{ }.$dir->ances(
      join_char=>$NULLSTR

    );

    push @new_sums,$dir->{cksum};


  };


  # return list of detected changes
  return [grep {

    (shift @old_sums) ne $ARG

  } @new_sums];

};

# ---   *   ---   *   ---
# returns node matching path

sub branch_from_path($self,$path,%O) {

  # defaults
  $O{root}//=q{};

  my @ances=split m[/],$path;
  $ances[0]=$O{root} . $ances[0];

  if(@ances>2) {
    map {$ARG=$ARG.q[/]} @ances[1..$#ances-1];

  };

  my $n=undef;
  while(@ances) {
    my $d=shift @ances;
    $n=$self->branch_in(qr{$d});

  };

  return $n;

};

# ---   *   ---   *   ---
# selfex

sub get_file_list($self,%O) {

  # defaults
  $O{full_path}//=1;

  my @files=$self->leafless(%O);

  # skip for plain node list
  goto TAIL if ! $O{full_path};


  for my $file(@files) {
    $file=$file->ances(join_char=>'/');
    $file=~ s[/+][/]sxmg;

  };


  TAIL:
  return @files;

};

# ---   *   ---   *   ---
# ^also selfex

sub get_dir_list($self,%O) {

  # defaults
  $O{full_path}//=1;
  my @dirs=$self->hasleaves(%O);

  # skip for plain node list
  goto TAIL if ! $O{full_path};


  for my $dir(@dirs) {
    $dir=$dir->ances(join_char=>'/');
    $dir=~ s[/+][/]sxmg;

  };


  TAIL:
  return @dirs;

};

# ---   *   ---   *   ---
1; # ret
