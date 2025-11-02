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
# lib,

# ---   *   ---   *   ---
# deps

package Tree::File;
  use v5.42.0;
  use strict;
  use warnings;

  use Digest::MD5 qw(md5);
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null no_match any_match);
  use Chk qw(is_null is_file is_dir);
  use Arstd::String qw(catpath);
  use Arstd::Array qw(filter);
  use Arstd::Bin qw(dorc);

  use parent 'Tree';


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# ROM

sub type_file {return 0};
sub type_dir  {return 1};
sub type_unk  {return -1};


# ---   *   ---   *   ---
# cstruc

sub new($self,$name) {
  my $class = (ref $self) ? ref $self : $self ;
  my $tree  = Tree::new($self,$name);

  bless $tree,$class;

  $tree->{cksum}   = 0;
  $tree->{updated} = 0;
  $tree->{object}  = [];
  $tree->{type}    = $tree->get_type();

  return $tree;
};


# ---   *   ---   *   ---
# determines what a path is!
#
# [0]: mem  ptr ; ice
# [<]: byte     ; num representing type (see ROM)

sub get_type {
  my $full=$_[0]->get_full();
  return type_file() if is_file($full);
  return type_dir()  if is_dir($full);
  return type_unk();
};


# ---   *   ---   *   ---
# gets full path for node
#
# [0]: mem  ptr ; ice
# [<]: byte ptr ; full path (new string)

sub get_full {
  my $re   =  qr{/+};
  my $full =  $_[0]->ances(join_char=>'/');
     $full =~ s[$re][/]smg;

  return $full;
};


# ---   *   ---   *   ---
# completes tree by opening dirs

sub expand($self,%O) {
  # defaults
  $O{-r} //= 0;
  $O{-x} //= no_match;

  # prepend dotbeg to exclusion re
  my $exclude = qr{(?:^\.|$O{-x})};
  my $full    = $self->get_full();

  # open directory pointed to by root
  for(dorc($full)) {
    next if(($ARG=~ $exclude)
         || (catpath($full,$ARG)=~ $exclude));

    # make new node for each returned entry
    my $nd=$self->new($ARG);

    # ^recurse on dir?
    $nd->expand(%O)
    if $O{-r} && is_dir($nd->get_full());
  };

  return;
};


# ---   *   ---   *   ---
# runs checksums on whole tree

sub get_cksum_diff {
  return map {
    $ARG->get_cksum();

  } reverse $_[0]->get_dir_list();
};


# ---   *   ---   *   ---
# get checksums for file or directory
#
# [0]: mem ptr ; ice
#
# [<]: mem pptr ; instances whose checksums
#                 are different than old
#                 (new list)
#
# [!]: does not recurse twice for directories

sub get_cksum {
  my ($new,@diff)=(null,());

  # node is file file?
  if($_[0]->{type} eq type_file()) {
    $new=md5(orc($ARG->get_full()));

  # ^nope, directory!
  } elsif($_[0]->{type} eq type_file()) {
    for($_[0]->get_file_list(max_depth=>1)) {
      push @diff,$ARG->get_cksum();
      $new .= "$ARG->{cksum}";
    };
  };

  # have difference?
  push @diff,$_[0] if $_[0]->{cksum} ne $new;

  # ^overwrite old
  $ARG->{cksum}=$new;

  return @diff;
};


# ---   *   ---   *   ---
# returns node matching path

sub branch_from_path($self,$path,%O) {
  # defaults
  $O{root} //= null;

  my @ances=split '/',$path;
  $ances[0]="$O{root}$ances[0]";

  if(@ances > 2) {
    $ARG .= q[/] for @ances[1..$#ances-1];
  };

  my $n=undef;
  while(@ances) {
    my $d=shift @ances;
    $n=$self->branch_in(qr{$d});
  };

  return $n;
};


# ---   *   ---   *   ---
# give list of files in tree
#
# [0]: mem  ptr  ; instance
# [1]: byte pptr ; options
#
# [<]: mem pptr ; list of instances (new array)

sub get_file_list($self,%O) {
  return grep {
    $ARG->{type} eq type_file();
  } $self->branches_in(any_match,%O);
};

sub get_filepath_list($self,%O) {
  $O{full} //= 0;
  my @have=$self->get_file_list(%O);

  if($O{full}) {
    return map {$ARG->get_full()} @have;
  };

  return map {$ARG->{value}} @have;
};


# ---   *   ---   *   ---
# give list of directories in tree
#
# [0]: mem  ptr  ; instance
# [1]: byte pptr ; options
#
# [<]: mem pptr ; list of instances (new array)

sub get_dir_list($self,%O) {
  return grep {
    $ARG->{type} eq type_dir();
  } $self->branches_in(any_match,%O);
};

sub get_dirpath_list($self,%O) {
  $O{full} //= 0;
  my @have=$self->get_dir_list(%O);

  if($O{full}) {
    return map {$ARG->get_full()} @have;
  };

  return map {$ARG->{value}} @have;
};


# ---   *   ---   *   ---
1; # ret
