#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:CMD ARGCHK
# Typechecked madness
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmd::argchk;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Warnme;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# look at single type option for arg

sub argtypechk($self,$arg,$pos,$subpos) {


  # get anchor
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  my $nd   = $main->{branch};
  my $list = 0;


  # ^get node to type-check!
  my $chd  = $nd->{leaves}->[$pos];

  if($chd && $arg->{type}->[0] ne 'LIST'
  && defined $l1->is_list($chd->{value})) {

    my $have=$chd->{leaves};
       $list=$subpos < @$have;

    $chd=$have->[$subpos] if $list;

  };


  # walk possible types
  for my $type(@{$arg->{type}}) {

    # get pattern for type
    my $re=$l1->tagre($type => $arg->{value});

    # return true on pattern match
    my $match=

       defined $chd
    && defined $chd->{value}

    && int($chd->{value}=~ $re);


    return ($chd,$list,$match) if $match;


  };


  return ($chd,$list,0);

};

# ---   *   ---   *   ---
# walk signature and typechk
# command arguments

sub argchk($self,$offset=undef) {


  # get ctx
  my $main   = $self->{frame}->{main};
  my $branch = $main->{branch};

  # get command meta
  my $key  = $self->{lis};
  my $sig  = $self->{sig};
  my $pos  = (defined $offset)
    ? $offset
    : 0
    ;


  # walk signature
  my @out=();

  for my $subpos(0..@$sig-1) {


    # get value matches type
    my $arg=$sig->[$subpos];
    my ($have,$list,$match)=$self->argtypechk(
      $arg,$pos,$subpos

    );

    # ^die on not found && non-optional
    $self->throw_badargs($arg,[$pos,$subpos],$list)
    if (! $have &&! $arg->{opt})
    || (  $have &&! $match && $list);


    # go forward if found
    $have=undef if ! $match;

    push @out,$have;
    $pos++ if $have &&! $list;

  };


  return @out;

};

# ---   *   ---   *   ---
# ^errme

sub throw_badargs($self,$arg,$pos,$list) {

  # get ctx
  my $main  = $self->{frame}->{main};
  my $value = $main->{branch}->{leaves};

  my @types = @{$arg->{type}};


  # dbout branch
  $main->{branch}->prich(errout=>1);
  $value=($list)
    ? $value->[$pos->[0]]->leaf_value($pos->[1])
    : $value->[$pos->[0]]->{value}
    ;


  # errout and die
  $main->perr(

    "invalid argtype for command '%s'\n"
  . "position [num]:%u: '%s'\n"

  . "need '%s' of type "
  . (join ",","'%s'" x int @types),

    args=>[

      $self->{lis},
      $pos->[1],$value,

      $arg->{value},
      @types

    ],

  );

};

# ---   *   ---   *   ---
# consume argument nodes for command

sub argsume($self,$branch) {


  # skip if nodes parented to branch
  # or parent is invalid
  my @lv  = @{$branch->{leaves}};
  my $par = $branch->{parent};

  return if @lv ||! $par;


  # get siblings, skip if none
  my @sib=@{$par->{leaves}};
     @sib=@sib[$branch->{idex}+1..$#sib];

  return if ! @sib;


  # save current
  my $main=$self->{frame}->{main};
  $main->{branch}=$par;

  # consume sibling nodes as arguments
  my @have=$self->argchk($branch->{idex}+1);
  $branch->pushlv(@have);


  # restore and give
  $main->{branch}=$branch;
  return;

};

# ---   *   ---   *   ---
1; # ret
