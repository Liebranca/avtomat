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

  our $VERSION = v0.00.5;#a
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

cmdsub 'token-type' => q(arg) => q{

  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $lv   = $branch->{leaves}->[0];


  # proc input
  my $type = $l1->is_cmd($branch->{value});
  my $have = $self->argproc($lv);

  # ^save and clear
  $have->{type}   = $type;
  $branch->{vref} = $have;

  $branch->clear();

  return;

};

# ---   *   ---   *   ---
# ^icef*ck

w_cmdsub 'token-type' => q(arg) => qw(
  sym bare num

);

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
      undef,$l1->make_tag(LIST=>'X')

    );

    map {$nd->inew($ARG)} @$value;
    $value=$nd;

  };


  # replacing branches
  if(Tree->is_valid($value)) {

    map {

      my $nd=$body->from_path($ARG);
      $nd->repl($value);

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
# ~

cmdsub 'macro-paste' => q(opt_qlist) => q{

  # get ctx
  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};
  my $scope = $mc->{scope};
  my @path  = @{$mc->{path}};


  # macro in namespace?
  my $name=$branch->{cmdkey};
  push @path,macro=>$name;

  $main->throw_undefined(macro=>$name)
  if ! $scope->has(@path);


  # ^yep, deref
  my $have=$scope->{'*fetch'};
     $have=$have->leaf_value(0);


  # duplicate tree
  my $body=$have->{body}->dup();

  # process arguments
  my $sig  = $have->{args};
  my @args = $self->argtake($branch);

  my $idex = 0;

  map {


    # set default value?
    $args[$idex]=(defined $args[$idex])

    ? ($ARG->{type} eq 'qlist')
      ? [map {$ARG->{id}} @args[$idex..$#args]]
      : $args[$idex]->{id}

    : $ARG->{defval}
    ;

    # replace arg in body
    $self->macro_repl(
      $body,$ARG->{repl},$args[$idex]

    );


    # go next
    $idex++;

  } @$sig;


  # replace own with generated!
  my $par=$branch->{parent};
  $branch->deep_repl($body);


  # recurse for each sub-branch
  my $l2 = $main->{l2};
  my @Q  = @{$branch->{leaves}};

  map {
    my $lv=$ARG;
    $l2->recurse($lv);

  } @Q;

  $branch->flatten_branch();


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
    my $re=(defined $l1->is_string($nd->{value}))
      ? $subststr
      : $subst
      ;

    # argument name fond?
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

    $ARG->{repl}=$self->macro_repl_args(
      $body,$ARG->{id},$idex++

    );

  } @args;


  return;

};

# ---   *   ---   *   ---
# points at your foot ;>

unrev cmdsub macro => q(
  sym,opt_vlist,curly

) => q{

  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $mc    = $main->{mc};
  my $scope = $mc->{scope};
  my @path  = @{$mc->path};


  # unpack
  my $lv=$branch->{leaves};

  # have arguments?
  my ($name,@args)=(3 <= @$lv)
    ? $self->argtake($branch,2)
    : $self->argtake($branch,1)
    ;


  # last node is macro body
  my $body=$branch->{leaves}->[0];

  # redecl guard
  $name=$l1->is_sym($name->{id});
  push @path,macro=>$name;

  $main->throw_redecl(macro=>$name)
  if $scope->has(@path);


  # prepare replacement paths
  $self->macro_proc_args($body,@args);


  # generate signature
  my @sig=map {

    my $opt=(defined $ARG->{defval})
      ? 'opt_'
      : null
      ;

    "${opt}$ARG->{type}";

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

    fn    => $solve->{fn},
    unrev => 1,

  );

  # save to current namespace and remove branch
  $scope->force_set($data,@path);
  $branch->discard();

  $body->{parent}=undef;


  # update command table and give
  $main->{lx}->load_CMD(1);
  return;

};

# ---   *   ---   *   ---
# hammer time!

cmdsub stop => q(opt_sym) => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $lx   = $main->{lx};
  my $list = $lx->stages;


  # name of stage says *when* to stop!
  my $stage=$branch->{leaves}->[0];

  if($stage) {
    $stage=$l1->is_sym($stage->{value});

  };

  $stage //= $list->[0];


  # are we there yet? ;>
  if($stage eq $list->[$main->{stage}]) {
    $main->{tree}->prich();
    $main->perr('STOP');

  # ^nope, wait
  } else {
    $branch->{vref}=$stage;
    $branch->clear();

  };

};

# ---   *   ---   *   ---
# dbout

w_cmdsub 'csume-list' => q(qlist) => 'echo';

# ---   *   ---   *   ---
1; # ret
