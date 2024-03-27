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

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'rd::cmd';
  BEGIN {rd::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

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


  # process arguments
  my $repl = $have->{repl};
  my $sig  = $have->{sig};

  my @args = $self->argtake($branch);

  # ~
  use Fmat;
  fatdump \[@args];
  fatdump \$repl;

  exit;

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
    if($nd->{value}=~ s[$re][$place]) {
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


    # unpack
    my ($argname,$defval)=@$ARG;

    # make replacement paths
    my $repl=$self->macro_repl_args(
      $body,$argname,$idex++

    );


    # give argname => argdata
    $argname=>{
      repl   => $repl,
      defval => $defval,

    };

  } @args;

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
  my @path  = @{$mc->{path}};


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
  $name=$l1->is_sym($name->[0]);
  push @path,macro=>$name;

  $main->throw_redecl(macro=>$name)
  if $scope->has(@path);


  # prepare replacement paths
  @args=$self->macro_proc_args($body,@args);

  # generate signature for internal check
  my $real_sig=[];

  for my $i(0..(@args >> 1)-1) {

    my ($tag,$data)=(
      $args[($i << 1)+0],
      $args[($i << 1)+1],

    );

    my $opt=(defined $data->{defval})
      ? 'opt_'
      : null
      ;

    push @$real_sig,"${opt}sym";

  };

  # ^fake signature for the parser ;>
  my $fake_sig=(@$real_sig)
    ? ['opt_vlist']
    : []
    ;


  # source data for macro-paste
  my $data={

    body   => $body,
    repl   => \@args,

    sig    => $real_sig,

  };


  # write to command table
  #
  # this lets the parser recognize the macro
  # and load the macro-paste sub for it!

  my $cmdlib = $main->{cmdlib};
  my $solve  = $cmdlib->fetch('macro-paste');

  $cmdlib->new(

    lis => $name,
    pkg => __PACKAGE__,
    sig => $fake_sig,

    fn  => $solve->{fn},

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
# dbout (placeholder)

cmdsub echo => q(qlist) => q{
  say 'NYI: ECHOVARS';

};

# ---   *   ---   *   ---
1; # ret
