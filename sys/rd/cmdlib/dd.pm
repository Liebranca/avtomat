#!/usr/bin/perl
# ---   *   ---   *   ---
# DD
# Data declarations
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmdlib::dd;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.7;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# pass definitions to cmdlib

sub build($class,$main) {


  # get ctx
  my $mc    = $main->{mc};
  my $flags = $mc->{bk}->{flags};

  # generate flag types
  wm_cmdsub $main,'flag-type' => q(
    qlist src

  ) => @{$flags->list};


  # give table
  return rd::cmd::MAKE::build($class,$main);

};

# ---   *   ---   *   ---
# parse and collapse flag list

sub flag_type($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # proc list
  $self->rcollapse_list($branch,sub {

      # mutate into another command
      $branch->{value}=
        $l1->tag(CMD=>'flag-type')
      . "$branch->{cmdkey}"
      ;


      return;

  });

};

# ---   *   ---   *   ---
# read segment decl

sub seg_type($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # clean name
  my $lv   = $branch->{leaves};
  my $name = $lv->[0]->{value};
     $name = $l1->untag($name)->{spec};


  # prepare branch for ipret
  my $type=$branch->{cmdkey};

  $branch->{vref}={
    type=>$type,
    name=>$name,

  };

  $branch->clear();


  # need mutate?
  if($type ne 'seg-type') {

    $branch->{value}=
      $l1->tag(CMD=>'seg-type')
    . "$type"
    ;

  };


  # set preproc namespace!
  my $scope = $main->{scope};
  my @path  = $scope->ances_list(root=>0);

  pop @path if @path > 1;


  $main->{inner}->force_get(@path,$name);
  $main->{scope}=$main->{inner}->{'*fetch'};


  return;

};

# ---   *   ---   *   ---
# make/swap addressing space

sub clan($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # read input
  my $name = $branch->leaf_value(0);
     $name = $l1->untag($name)->{spec};

  $branch->{vref}=$name;
  $branch->clear();


  # set preproc namespace!
  $main->{inner}->force_get($name);
  $main->{scope}=$main->{inner}->{'*fetch'};

  return;

};

# ---   *   ---   *   ---
# entry point for (exprtop)[*type] (values)
#
# not called directly, but rather
# by mutation of [*type] (see: type_parse)
#
# reads a data declaration!

sub data_decl($self,$branch) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $l2    = $main->{l2};

  my $mc    = $main->{mc};
  my $scope = $mc->{scope};
  my $type  = $branch->{vref};


  # get [name=>value] arrays
  my ($name,$value)=map {

    ($l1->typechk(LIST=>$ARG->{value}))
      ? $ARG->{leaves}
      : [$ARG]
      ;

  } @{$branch->{leaves}};


  # get [name=>value] array
  my $idex = 0;
  my @list = map {


    # ensure default value for each name
    $value->[$idex] //= $branch->inew(
      $l1->tag('NUM'=>0x00)

    );

    # get symbol name
    my $n=$ARG->{value};
       $n=$l1->untag($n)->{spec};

    # give [name=>value] and go next
    my $v=$value->[$idex++];
    [$n=>$v];


  } @$name;


  # prepare branch for ipret
  $branch->{vref}={
    type => $type,
    list => \@list,

  };

  $branch->clear();

  return;

};

# ---   *   ---   *   ---
# collapses width/specifier list
#
# mutates node:
#
# * (? exprbeg) [*type] -> [*data-decl]
# * (! exprbeg) [*type] -> [Ttype]

sub data_type($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};


  # rwalk specifier list
  $self->rcollapse_list($branch,sub {


    # get hashref from flags
    # save it to branch
    my @list=@{$branch->{vref}};
    my $type=$self->type_decode(@list);

    $branch->{vref}=$type;


    # first token in expression?
    if($l2->is_exprtop($branch)) {

      # mutate into another command
      $branch->{value}=
        $l1->tag(CMD=>'data-decl')
      . "$type->{name}"
      ;


      $branch->{cmdkey}=undef;
      return $l2->node_mutate();


    # ^nope, last or middle
    } else {


      # look for next node!
      my $par    = $branch->{parent};
      my $anchor = $branch;
      my $ok     = 0;


      while(defined (
        $anchor=$anchor->next_leaf()

      )) {


        # stop at first non-list
        my $have  = $l1->xlate($anchor->{value});
        my $ahead = undef;

        if($have->{type} ne 'LIST') {

          $anchor->{vref} //= [];
          push @{$anchor->{vref}},
            $type->{name};

          $ok=1;
          last;

        };

      };


      # throw if nothing found
      $main->perr("redundant type specifier")
      if ! $ok;


      # merging ([LIST],type X) lists?
      if($branch eq $par->{leaves}->[-1]
      && $l1->typechk(LIST=>$par->{value})) {


        my $tail=$anchor->{parent};

        # have (type X,type Y) ?
        if($l1->typechk(LIST=>$tail->{value})) {
          $par->pushlv(@{$tail->{leaves}});
          $tail->discard();

        # ^nope, plain ;>
        } else {
          $par->pushlv($anchor);

        };

      };


      $branch->discard();
      return;

    };

  });

};

# ---   *   ---   *   ---
# ^fetch/errme

sub type_decode($self,@src) {

  # get type hashref from flags array
  my $main = $self->{frame}->{main};
  my $type = typefet @src;

  # ^catch invalid
  $main->perr('invalid type')
  if ! defined $type;


  return $type;

};

# ---   *   ---   *   ---
# add entry points

cmdsub 'flag-type' => q(qlist src) => \&flag_type;
cmdsub 'seg-type' => q(sym type) => \&seg_type;

cmdsub 'clan' => q(sym name) => \&clan;

cmdsub 'data-decl' => q(
  vlist name;
  qlist value;

) => \&data_decl;

cmdsub 'data-type' => q(
  qlist any;

) => \&data_type;

w_cmdsub 'seg-type'

=>q(sym type)
=>qw(rom ram exe);

w_cmdsub 'data-type'

=> q(qlist any)
=> @{Type::MAKE->ALL_FLAGS};

# ---   *   ---   *   ---
1; # ret
