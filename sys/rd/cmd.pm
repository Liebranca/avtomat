#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:CMD
# Node subroutines
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmd;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Icebox;
  use Warnme;

  use Arstd::String;
  use Arstd::PM;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# add custom subroutine makers

sub defspkg($class,@args) {

  my $dst=rcaller;

  map { Arstd::PM::add_symbol
    "$dst\::$ARG",
    "$class\::$ARG"

  } qw(

    cmdsub
    m_cmdsub
    w_cmdsub
    wm_cmdsub

    unrev

  );

  return;

};

# ---   *   ---   *   ---
# makes command args

sub cmdarg($type,%O) {

  # defaults
  $O{opt}   //= 0;
  $O{value} //= '.+';

  # give descriptor
  return {%O,type=>$type};

};

# ---   *   ---   *   ---
# ^add variation on existing

sub opt_cmdarg(@list) {

  map {

    my $fn=$ARG;

    "opt_$ARG" => sub {

      my $class=$_[0];
      return {%{$class->$fn},opt=>1};

    };


  } @list;

};

# ---   *   ---   *   ---
# ROM

St::vconst {


  # defnit
  DEFAULT => {

    lis   => 'nop',
    sig   => [],

    fn    => '\&nop',
    unrev => 0,

    pkg   => __PACKAGE__,

  },

  # location of method table used
  # by exporter
  TABID => 'public-methods',


  # list types
  qlist => cmdarg(['LIST','ANY']),
  vlist => cmdarg(

    ['LIST','OPERA','SYM','BARE'],
    value=>'[^\{]+'

  ),


  # single token
  sym  => cmdarg(['SYM']),
  bare => cmdarg(['BARE']),


  # optional variants
  opt_cmdarg(qw(qlist vlist sym)),


  # delimiters
  curly  => cmdarg(
    ['OPERA'],
    value=>'\{',

  ),

  parens => cmdarg(
    ['OPERA'],
    value=>'\(',

  ),

};

# ---   *   ---   *   ---
# GBL

St::vstatic {

  main      => undef,
  icetab    => {},

  -autoload => [qw(add load fetch mutate)],

};

# ---   *   ---   *   ---
# cstruc

sub new($class,$frame,%O) {

  # set defaults
  $class->defnit(\%O);


  # expand signature
  my $sig=[map {

     strip(\$ARG);

     eval {$class->$ARG}
  or do   {croak "Bad signature: '$O{sig}'"}


  } @{$O{sig}}];


  # make ice
  my $self=bless {

    lis   => $O{lis},

    sig   => $sig,
    fn    => $O{fn},

    unrev => $O{unrev},

  },$O{pkg};


  # ^register and give
  my $id=$frame->icemake($self);
  $frame->{icetab}->{$O{lis}}=$id;


  return $self;

};

# ---   *   ---   *   ---
# ^bat from package!

sub load($class,$frame,$pkg) {


  # get ctx
  my $main=$frame->{main};

  # walk definitions
  cloadi $pkg;

  map {$frame->new(%$ARG)}
  $pkg->load($main);


  # update table interface
  my $lx  = $main->{lx};
  my $tab = $lx->load_CMD(1);


  return;

};

# ---   *   ---   *   ---
# clear icebox and load new

sub mutate($class,$frame,$oldpkg) {


  # get next in chain
  cloadi $oldpkg;
  my     $newpkg=$oldpkg->next_link;


  # clear cache
  delete $frame->{icebox};
  delete $frame->{icetab};

  $frame->{icebox}=Cask->new();

  #^load new
  $frame->load($newpkg);


  return $newpkg;

};

# ---   *   ---   *   ---
# get existing

sub fetch($class,$frame,$name) {


  # assume index is input
  my $idex=$name;

  # ^then make double sure ;>
  if(! ($name=~ qr{^\d+$})) {
    $idex=$frame->{icetab}->{$name};

  };


  # validate and give
  return (defined $idex)
    ? $frame->ice($idex)
    : warn_invalid($name)
    ;

};

# ---   *   ---   *   ---
# ^errme

sub warn_invalid($name) {

  Warnme::invalid 'command ID',

  obj  => $name,
  give => null;

};

# ---   *   ---   *   ---
# get table of public methods

sub cmdtab($class) {
  $class->classcache($class->TABID);

};

# ---   *   ---   *   ---
# dynamic table read
#
# this returns a string for a
# method builder!

sub cmdfn($class,$var,$name) {
  "my \$$var=$class->cmdtab->{'$name'}->{fn};";

};

# ---   *   ---   *   ---
# defines a new command and
# registers it for export

sub cmdsub($name,$sig,@body) {


  # make definition
  my @args    = split $COMMA_RE,$sig;
  my $body    = join  ';',@body;

  my $codestr = "sub (\$self,\$branch) {\n$body\n}";
  my $fn      = eval $codestr;

  # ^validate
  if(! defined $fn) {

    say $codestr;
    die "Cannot define command '$name' $!";

  };


  # find source class
  my $class = rcaller __PACKAGE__;

  croak "Unable to find source class for '$name'"
  if $class eq __PACKAGE__;


  # add to cache and give
  my $tab=$class->cmdtab;

  $tab->{$name}={

    pkg => $class,
    lis => $name,

    sig => \@args,
    fn  => $fn,

  };


  return $tab->{$name};

};

# ---   *   ---   *   ---
# ^plus name mangling
#
# we need this when a method depends
# on an instance of main

sub m_cmdsub($main,$lis,$sig,@body) {

  my $name   = "$main\::$lis";
  my $cstruc = cmdsub $name,$sig,@body;

  $cstruc->{lis} = $lis;

  return $cstruc;

};

# ---   *   ---   *   ---
# batch-wrap another method

sub w_cmdsub($name,$sig,@list) {

  my $class=caller;

  map { cmdsub $ARG => $sig

  => $class->cmdfn(fn=>$name)
  => q{$fn->($self,$branch)}

  } @list;

};

# ---   *   ---   *   ---
# ^batch-wrap mangled

sub wm_cmdsub($main,$name,$sig,@list) {

  my $class=caller;

  map { m_cmdsub $main,$ARG => $sig

  => $class->cmdfn(fn=>$name)
  => q{$fn->($self,$branch)}

  } @list;

};

# ---   *   ---   *   ---
# 'rev' stands for how the parser
# solves branch symbols from
# bottom to root
#
# 'unrev' means that a command wants
# to be processed first, and so
# the parser should put it's leafs
# on hold!

sub unrev($cstruc) {
  $cstruc->{unrev}=1;
  return $cstruc;

};

# ---   *   ---   *   ---
# placeholder method for any
# dynamic definitions

sub build($class,$main) {
  return $class->cmdtab;

};

# ---   *   ---   *   ---
# parse argname(=value)?

sub next_arg($self,$nd) {


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

    ($argname,$defval)=(
      $nd->{leaves}->[0]->{value},
      $nd->{leaves}->[1]

    );

  };


  return ($argname,$defval);

};

# ---   *   ---   *   ---
# proc branch leaf as a
# list of arguments

sub arglist($self,$branch,$idex=0) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  # get leaf to proc
  my $args_lv=$branch->{leaves}->[$idex];
  return [] if ! $args_lv;


  # got list or single elem?
  my $key  = $args_lv->{value};
  my $args = (defined $l1->is_list($key))
    ? $args_lv->{leaves}
    : [$args_lv]
    ;

  # ^pluck and give
  $branch->pluck($args_lv);
  return $args;

};

# ---   *   ---   *   ---
# ^proc && pop N leaves

sub argtake($self,$branch,$len=1) {


  # get ctx
  my $args = [map {@{
    $self->arglist($branch)

  }} 1..$len];


  # give [name => value]
  return map {

    my ($argname,$defval)=
      $self->next_arg($ARG);

    [$argname,$defval];


  } @$args;

};

# ---   *   ---   *   ---
# look at single type option for arg

sub argtypechk($self,$arg,$pos) {


  # get anchor
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  my $nd   = $main->{branch};


  # walk possible types
  for my $type(@{$arg->{type}}) {

    # get pattern for type
    my $re=$l1->tagre($type => $arg->{value});

    # return true on pattern match
    my $chd=$nd->{leaves}->[$pos];
    return $chd if $chd && $chd->{value}=~ $re;

  };


  return 0;

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
    ? $branch->{idex} + $offset
    : 0
    ;


  # walk signature
  my @out=();

  for my $arg(@$sig) {


    # get value matches type
    my $have=$self->argtypechk($arg,$pos);

    # ^die on not found && non-optional
    $self->throw_badargs($arg,$pos)
    if ! $have &&! $arg->{opt};


    # go forward if found
    push @out,$have;
    $pos++ if $have;

  };


  return @out;

};

# ---   *   ---   *   ---
# ^errme

sub throw_badargs($self,$arg,$pos) {

  # get ctx
  my $main  = $self->{frame}->{main};
  my $value = $main->{branch}->{leaves};

  my @types = @{$arg->{type}};


  # dbout branch
  $main->{branch}->prich(errout=>1);
  $value=$value->[$pos]->{value};


  # errout and die
  $main->perr(

    "invalid argtype for command '%s'\n"
  . "position [num]:%u: '%s'\n"

  . "need '%s' of type "
  . (join ",","'%s'" x int @types),

    args=>[

      $self->{lis},
      $pos,$value,

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
  my @have=$self->argchk(1);
  $branch->pushlv(@have);


  # restore and give
  $main->{branch}=$branch;
  return;

};

# ---   *   ---   *   ---
# template: collapse list in
# reverse hierarchical order

sub rcollapse_list($self,$branch,$fn) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};


  # first token, first command
  my @list = $l1->is_cmd($branch->{value});
  my $par  = $branch->{parent};

  # ^get tokens from previous iterations
  push @list,@{$branch->{vref}}
  if exists $branch->{vref};

  $branch->{vref} = \@list;


  # parent is command, keep collapsing
  my $head = $l1->is_cmd($par->{value});
  if(defined $head) {

    # save commands to parent, they'll be
    # picked up in the next run of this F
    $par->{vref} //= [];
    push @{$par->{vref}},@list;

    # ^remove this token
    $branch->flatten_branch();


    return;


  # ^stop at last node in the chain
  } else {
    $fn->();

  };

};

# ---   *   ---   *   ---
1; # ret
