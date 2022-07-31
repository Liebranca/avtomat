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
  use Arstd;

  use parent 'Tree';

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---

sub nit($class,$frame,@args) {

  my $tree=Tree::nit($class,$frame,@args);

  $tree->{cksum}=0;
  return $tree;

};

# ---   *   ---   *   ---

sub get_file_list($self,%O) {

  # defaults
  $O{full_path}//=1;

  my $files=$self->leafless();

# ---   *   ---   *   ---
# skip for plain node list

goto TAIL if(!$O{full_path});

  for my $file(@$files) {
    $file=$file->ances($NULLSTR);

  };

# ---   *   ---   *   ---

TAIL:
  return @$files;

};

# ---   *   ---   *   ---

sub get_dir_list($self,%O) {

  # defaults
  $O{full_path}//=1;

  my $dirs=$self->leafless(
    give_parent=>1,

  );

# ---   *   ---   *   ---
# skip for plain node list

goto TAIL if(!$O{full_path});

  for my $dir(@$dirs) {
    $dir=$dir->ances($NULLSTR);

  };

# ---   *   ---   *   ---

TAIL:
  return @$dirs;

};

# ---   *   ---   *   ---
1; # ret
