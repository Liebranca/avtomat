#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:CMD ARGPROC
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

package rd::cmd::argproc;

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
# parse argname(=value)?

sub argproc($self,$nd) {


  # assume already processed if
  # input is not a tree
  return $nd
  if ! Tree->is_valid($nd);


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # [name => default value]
  my $argname = $nd->{value};
  my $defval  = undef;


  # have default value?
  my $opera=$l1->is_opera($argname);

  # ^yep
  if(defined $opera && $opera eq '=') {

    ($argname,$defval)=map {

      my $out=$nd->{leaves}->[$ARG];

      (! @{$out->{leaves}})
        ? $out->{value}
        : $out
        ;

    } 0..1;

  };


  return {

    id     => $argname,
    type   => 'sym',

    defval => $defval,

  };

};

# ---   *   ---   *   ---
# expand token tree accto
# type of first token

sub argex($self,$lv) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # fstate
  my $key  = $lv->{value};
  my @nest = @{$lv->{leaves}};
  my $have = undef;


  # have list?
  if(defined $l1->is_list($key)) {
    return map {$self->argex($ARG)} @nest;

  # have [list]?
  } elsif(defined ($have=$l1->is_opera($key))
    && $have eq '['

  ) {

    # validate
    $main->perr(
      "Multiple identifiers for list arg"

    ) if 1 < @{$lv->{leaves}};

    my $branch=$lv->{leaves}->[0];

    return {

      id     => $branch->leaf_value(0),
      defval => undef,

      type   => 'qlist',

    };


  # ^have operator tree?
  } elsif(defined $have) {

    return {

      id     => $lv,
      defval => undef,

      type   => 'opera',

    };


  # have sub-branch?
  } elsif(defined $l1->is_branch($key)) {

    return

      map {$self->argex($ARG)}
      map {@{$ARG->{leaves}}} @nest;


  # have command?
  } elsif(defined ($have=$l1->is_cmd($key))) {

    if(! $lv->{escaped}) {
      my $l2=$main->{l2};
      $l2->recurse($lv);

      return $lv->{vref};

    } else {
      return {id=>$lv,defval=>undef};

    };


  # have single token!
  } else {
    return $lv;

  };

};

# ---   *   ---   *   ---
# proc branch leaf as a
# list of arguments

sub arglist($self,$branch,$idex=0) {


  # get leaf to proc
  my $lv=$branch->{leaves}->[$idex];
  return [] if ! $lv;

  # ^pluck and give
  ($lv)=$branch->pluck($lv);
  return $self->argex($lv);

};

# ---   *   ---   *   ---
# ^proc && pop N leaves

sub argtake($self,$branch,$len=1) {


  # give [name => value]
  return map {
    $self->argproc($ARG);


  # ^from expanded token tree
  } map {
    $self->arglist($branch)

  } 1..$len;

};

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
