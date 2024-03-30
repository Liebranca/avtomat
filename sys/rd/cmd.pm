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
  use parent 'rd::cmd::argproc';
  use parent 'rd::cmd::treeproc';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.5;#a
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

    ['LIST','OPERA','CMD','SYM','BARE'],
    value=>'[^\{]+'

  ),


  # single token
  sym  => cmdarg(['SYM']),
  bare => cmdarg(['BARE']),
  num  => cmdarg(['NUM']),

  # sym=(any)
  arg => cmdarg(
    ['OPERA','SYM'],
    value=>'(?:[=]|[^=]+)'

  ),


  # optional variants
  opt_cmdarg(qw(qlist vlist sym num)),


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
  my $errme = join ',',@{$O{sig}};
  my $sig   = [map {

     strip(\$ARG);

     eval {$class->$ARG}
  or do   {croak "Bad signature: '$errme'"}


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
# it will try and find the given
# name in the class' table
#
# if that fails, it'll look into
# the global table!

sub cmdfn($self,$name) {

  my $class = ref $self;
  my $out   = $class->cmdtab->{$name}->{fn};

  if(! defined $out) {

    my $main = $self->{frame}->{main};
    my $lib  = $main->{cmdlib};

    my $have = $lib->fetch($name);

    $out=$have->{fn};

  };

  return $out;

};

# ---   *   ---   *   ---
# defines a new command and
# registers it for export

sub cmdsub($name,$sig,@body) {


  # find source class
  my $class = rcaller __PACKAGE__;

  croak "Unable to find source class for '$name'"
  if $class eq __PACKAGE__;


  # make definition
  my @args    = split $COMMA_RE,$sig;
  my $body    = join  ';',@body;

  my $codestr = "sub (\$self,\$branch) {\n$body\n}";
  my $fn      = eval "package $class;$codestr;";

  # ^validate
  if(! defined $fn) {

    say $codestr;
    die "Cannot define command '$name' $!";

  };


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
# two lines of code common
# to wrapper methods

sub wrapper($class,$name) {

  return

    "my \$fn=\$self->cmdfn('$name')",
    q{$fn->($self,$branch)};

};

# ---   *   ---   *   ---
# batch-wrap another method

sub w_cmdsub($name,$sig,@list) {

  my $class=caller;

  map { cmdsub $ARG
  => $sig
  => wrapper $class,$name

  } @list;

};

# ---   *   ---   *   ---
# ^batch-wrap mangled

sub wm_cmdsub($main,$name,$sig,@list) {

  my $class=caller;

  map { m_cmdsub $main,$ARG
  => $sig
  => wrapper $class,$name

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
1; # ret
