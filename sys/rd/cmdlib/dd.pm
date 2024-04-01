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

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# pass definitions to cmdlib

sub build($class,$main) {


  # get ctx
  my $mc    = $main->{mc};
  my $flags = $mc->{bk}->{flags};

  # generate flag types
  wm_cmdsub $main,'flag-type' => q(
    opt_qlist

  ) => @{$flags->list()};


  # give table
  return rd::cmd::MAKE::build($class,$main);

};

# ---   *   ---   *   ---
# parse and collapse flag list

cmdsub 'flag-type' => q(opt_qlist) => q{
  $self->rcollapse_list($branch,$NOOP);

};

# ---   *   ---   *   ---
# read segment decl

cmdsub 'seg-type' => q(sym) => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # clean name
  my $lv   = $branch->{leaves};
  my $name = $lv->[0]->{value};
     $name = $l1->is_sym($name);


  # prepare branch for ipret
  my $type=$l1->is_cmd($branch->{value});

  $branch->{vref}={
    type=>$type,
    name=>$name,

  };

  $branch->clear();


  # need mutate?
  if($type ne 'seg-type') {

    $branch->{value}=
      $l1->make_tag(CMD=>'seg-type')
    . "$type"
    ;

  };


  return;

};

# ---   *   ---   *   ---
# ^icef*ck

w_cmdsub 'seg-type'

=>q(sym)
=>qw(rom ram exe);

# ---   *   ---   *   ---
# entry point for (exprtop)[*type] (values)
#
# not called directly, but rather
# by mutation of [*type] (see: type_parse)
#
# reads a data declaration!

cmdsub 'data-decl' => q(
  vlist,opt_qlist

) => q{


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $l2    = $main->{l2};

  my $mc    = $main->{mc};
  my $scope = $mc->{scope};
  my $type  = $branch->{vref};


  # get [name=>value] arrays
  my ($name,$value)=map {

    (defined $l1->is_list($ARG->{value}))
      ? $ARG->{leaves}
      : [$ARG]
      ;

  } @{$branch->{leaves}};


  # get [name=>value] array
  my $idex = 0;
  my @list = map {


    # ensure default value for each name
    $value->[$idex] //= $branch->inew(
      $l1->make_tag('NUM'=>0x00)

    );

    # get symbol name
    my $n=$ARG->{value};
       $n=$l1->is_sym($n);

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

cmdsub 'data-type' => q(opt_qlist) => q{


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
        $l1->make_tag(CMD=>'data-decl')
      . "$type->{name}"
      ;


      return $l2->node_mutate();


    # ^nope, last or middle
    } else {

      # mutate into command argument
      $branch->{value}=
        $l1->make_tag(TYPE=>$type->{name});


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
# ^icef*ck

w_cmdsub 'data-type'

=> q(opt_qlist)
=> @{Type::MAKE->ALL_FLAGS};

# ---   *   ---   *   ---
1; # ret
