#!/usr/bin/perl
# ---   *   ---   *   ---
# MACRO
# The original copy-paste
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmdlib::macro;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.8;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# token-types are only meaningful
# to the parser
#
# we turn them into commands so that
# it restrucs the following tree:
#
# (top)
# \-->token-type
# \-->token
#
#
# to look like this:
#
# (top)
# \-->[*token-type]
# .  \-->token
#
#
# that makes it so lists of such commands
# can be parsed without a (parens) wrap!

sub token_type($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $lv   = $branch->{leaves}->[0];


  # proc input
  my $type = $branch->{cmdkey};
  my $have = $self->argproc($lv);

  # ^save and clear
  $have->{type}   = $type;
  $branch->{vref} = rd::vref->new(
    type=>'RDTYPE',
    spec=>'~',
    data=>$have,

  );

  $branch->clear();

  return;

};

# ---   *   ---   *   ---
# puts argument values in
# body of macro

sub macro_repl($self,$body,$repl,$value) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $path = $repl->{path};
  my $re   = $repl->{re};


  # array to list
  if(is_arrayref $value) {

    my $nd=$main->{tree}->{frame}->new(
      undef,$l1->tag(LIST=>'X')

    );

    map {$nd->inew($ARG)} @$value;
    $value=$nd;

  };


  # replacing branches
  if(Tree->is_valid($value)) {

    map {

      my $nd=$body->from_path($ARG);
      my @lv=$nd->pluck_all();

      $nd->repl($value);
      $value->pushlv(@lv);

    } reverse @$path;


  # replacing text
  } else {

    map {

      my $nd=$body->from_path($ARG);
      $nd->{value}=~ s[$re][$value]sxmg;

    } @$path;

  };

  return;

};

# ---   *   ---   *   ---
# reads macro args

sub macro_take($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # get next child
  my ($nd) = $branch->ipluck(0);
  my $key  = $nd->{value};


  # give token as-is
  for my $type(qw(
    sym num

  )) {

    if($l1->typechk(uc $type => $key)) {
      return {type=>$type,id=>$key};

    };

  };

  # ^give node!
  for my $type(qw(cmd list)) {

    if($l1->typechk(uc $type => $key)) {
      return {type=>$type,id=>$nd};

    };

  };

  # too lazy to write proper errme ;>
  die "macro take fail";

};

# ---   *   ---   *   ---
# expands macro [args]

sub macro_paste($self,$branch) {


  # unwrap list
  $branch->{leaves}->[0]->flatten_branch();


  # get ctx
  my $main  = $self->{frame}->{main};
  my $scope = $main->{scope};
  my @path  = @{$scope->ances_list(root=>0)};


  # macro in namespace?
  my $name=$branch->{cmdkey};
  push @path,macro=>$name;

  $main->throw_undefined(macro=>$name)
  if ! $scope->has(@path);


  # ^yep, deref
  my $have=$scope->{'*fetch'};
     $have=$have->leaf_value(0);


  # duplicate tree
  my $body=$have->{body}->dupa(
    undef,'lineno'

  );


  # process arguments
  my $sig  = $have->{args};
  my @args = ();

  while(int @{$branch->{leaves}}) {
    push @args,[$self->macro_take($branch)];

  };


  # replace own with generated!
  my $par=$branch->{parent};
  $branch=$branch->deep_repl($body);


  # recurse for each sub-branch
  my $l2 = $main->{l2};
  my @Q  = @{$branch->{leaves}};

  map {
    my $lv=$ARG;
    $l2->recurse($lv);

  } @Q;


  $branch->flatten_tree(max_depth=>1);
  return;


};

# ---   *   ---   *   ---
# replace argument name with
# placeholder for later replacement

sub macro_repl_args($self,$body,$argname,$idex) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # make regexes for finding arg
  my $subst    = "\Q$argname";
  my $subststr = "\%$subst\%";
     $subst    = qr{^(?:$subst)$};
     $subststr = qr{(?:$subststr)};

  my $place    = ":__ARG[$idex]__:";
  my $replre   = qr"\Q$place";


  # recursive walk tree of body
  my $replpath = [];
  my @pending  = $body;

  while(@pending) {

    my $nd=shift @pending;


    # have string?
    my $re=($l1->typechk(STR=>$nd->{value}))
      ? $subststr
      : $subst
      ;

    # argument name found?
    if($nd->{value}=~ s[$re][$place]sxmg) {
      my $path=$nd->ancespath($body);
      push @$replpath,$path;

    };


    # go next
    unshift @pending,@{$nd->{leaves}};

  };


  # give regexes
  return {
    path => $replpath,
    re   => $replre,

  };

};

# ---   *   ---   *   ---
# prepares a table of arguments
# with default values and
# replacement paths into
# command body

sub macro_proc_args($self,$body,@args) {

  my $idex=0;

  map {

    map {

      $ARG->{repl}=$self->macro_repl_args(
        $body,$ARG->{id},$idex++

      );

    } @$ARG;

  } @args;

  return;

};

# ---   *   ---   *   ---
# points at your feet ;>

sub macro($self,$branch) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $scope = $main->{scope};
  my @path  = @{$scope->ances_list(root=>0)};


  # unpack
  my $lv=$branch->{leaves};


  # first node is name of macro
  my ($name) = $self->argtake($branch,1);
     $lv     = $branch->{leaves};

  # middle nodes are arguments!
  my @args=();
  while(@$lv > 1) {
    push @args,[$self->argtake($branch,1)];
    $lv=$branch->{leaves};

  };


  # last node is macro body
  my $body=$branch->{leaves}->[0];


  # redecl guard
  $name=$l1->untag($name->{id})->{spec};
  push @path,macro=>$name;

  $main->throw_redecl(macro=>$name,@path)
  if $scope->has(@path);


  # prepare replacement paths
  $self->macro_proc_args($body,@args);


  # generate signature
  my @sig = 'list @_' => map {

    map {

      my $id=$l1->untag($ARG->{id});
         $id=($id) ? $id->{spec} : $ARG->{id} ;

      (defined $ARG->{defv})
        ? "$ARG->{type} $id=$ARG->{defv}"
        : "$ARG->{type} $id"
        ;

    } @$ARG;

  } @args;


  # source data for macro-paste
  my $data={
    body => $body,
    args => \@args,

  };

  # write to command table
  #
  # this lets the parser recognize the macro
  # and load the macro-paste sub for it!

  my $cmdlib = $main->{cmdlib};
  my $solve  = $cmdlib->fetch('macro-paste');
  my $class  = ref $self;

  $cmdlib->new(

    lis   => $name,
    pkg   => $class,
    sig   => \@sig,

    fn    => $solve->{key}->{fn},
    unrev => 1,

  );

  # save to current namespace and remove branch
  $scope->force_set($data,@path);
  $branch->discard();

  $body->{parent}=undef;


  # update command table and give
  $main->{lx}->load_CMD(1);
  $main->{rerun}=1;

  return;

};

# ---   *   ---   *   ---
# add entry points

cmdsub 'token-type' => q(
  arg type;

) => \&token_type;

w_cmdsub 'token-type' => q(arg type) => qw(
  sym bare num cmd vlist

);

unrev cmdsub 'macro-paste' => q(
  qlist data;

) => \&macro_paste;

unrev cmdsub macro => q(
  sym   name;
  vlist args;
  curly body;

) => \&macro;

# ---   *   ---   *   ---
1; # ret
