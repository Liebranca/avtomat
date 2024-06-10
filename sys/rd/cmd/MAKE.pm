#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:CMD MAKE
# Subroutine cstruc
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::cmd::MAKE;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;
  use Icebox;
  use Warnme;

  use Arstd::Array;
  use Arstd::String;
  use Arstd::PM;
  use Arstd::IO;
  use Arstd::WLog;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.6;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# add custom subroutine makers

sub defspkg($class,@args) {

  my $dst = rcaller;
  my $src = St::cpkg;

  map { Arstd::PM::add_symbol
    "$dst\::$ARG",
    "$src\::$ARG"

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
# ROM

St::vconst {


  # defnit
  DEFAULT => {

    lis   => 'nop',
    unrev => 0,

    pkg   => __PACKAGE__,

  },

  # location of method table used
  # by exporter
  TABID => 'public-methods',


  # list types
  qlist => [

    COMBO => [qw(
      LIST .+
      ANY  .+

    )],

  ],

  vlist => [

    COMBO => [qw(
    LIST .+
    OPR  .+
    CMD  .+
    SYM  .+

    )],

  ],

  list => [LIST => '.+'],


  # ^not a list!
  nlist => [

    COMBO => [qw(
      OPR   .+
      CMD   .+
      REG   .+
      EXE   .+
      NUM   .+
      SYM   .+
      BARE  .+

    )],

  ],


  # single token
  sym  => [SYM  => '.+'],
  bare => [BARE => '.+'],
  num  => [NUM  => '.+'],
  cmd  => [CMD  => '.+'],

  opr  => [OPR  => '.+'],
  any  => [ANY  => '.+'],

  # sym=(any)
  arg => [
    0 => [OPR =>  '='],
    1 => [SYM => '.+'],

  ],


  # delimiters
  curly  => [SCP => '\{'],
  brak   => [SCP => '\['],
  parens => [SCP => '\('],


  # used to read function signatures
  argparse  => qr{^

    (?<type> [^\s]+) \s+
    (?<name> [^= ]+) \s*

    (?: = \s*
      (?<defv> .+)

    )?

  $}x,


};

# ---   *   ---   *   ---
# GBL

St::vstatic {

  main      => undef,
  pkg       => __PACKAGE__,

  keytab    => undef,
  icetab    => {},


  -autoload => [qw(

    kick sigex
    add load fetch mutate

  )],

};

# ---   *   ---   *   ---
# nit frame

sub kick($class,$frame) {


  # get ctx
  my $main   = $frame->{main};
  my $l2     = $main->{l2};
  my $sigtab = $l2->sigtab_t;

  # build method table
  $frame->{keytab}=$sigtab->new($main);

  return;

};

# ---   *   ---   *   ---
# expands signature element

sub sigex($class,$frame,$name,$defv,$e,$idex=0) {


  # get ctx
  my $main = $frame->{main};
  my $l1   = $main->{l1};


  # array as hash
  my @ek=array_keys   $e;
  my @ev=array_values $e;


  # ^walk
  map {

    my $key   = $ek[$ARG];
    my $value = $ev[$ARG];


    # recurse on array of arrays!
    if($key ne 'COMBO' && is_arrayref $value) {

      $name="$name\[$idex]";

      return $frame->sigex(
        $name,$defv,$value,++$idex

      );


    # plain pattern ;>
    } else {

      $name=>{
        re   => $l1->re($key=>$value),
        defv => $defv,

      };

    };


  } 0..$#ek;


};

# ---   *   ---   *   ---
# cstruc

sub new($class,$frame,%O) {


  # get ctx
  my $main = $frame->{main};
  my $tab  = $frame->{keytab};
  my $l1   = $main->{l1};
  my $l2   = $main->{l2};

  # set defaults
  $class->defnit(\%O);


  # expand signature
  my $errme = join ',',@{$O{sig}};
  my @sig   = map {


    # parse signature elem
    my ($type,$name,$defv)=
      $ARG=~ $class->argparse;


    # ^fetch
    my @out=eval {
      $frame->sigex($name=>$defv,$class->$type)

    } or $WLog->err(

      "could not define method\n\n"
    . "[ctl]:%s [errtag]:%s\n"
    . "[ctl]:%s '%s'\n\n"

    . "bad signature (%s)",

      args => [

        package => $O{pkg},
        cmdsub  => $O{lis},

        $errme,

      ],

      lvl  => $AR_FATAL,
      from => $class,

    );

    @out;


  } @{$O{sig}};


  # make table entry
  $tab->begin($O{lis});
  $tab->complex_pattern(@sig);
  $tab->function($O{fn});
  $tab->regex($l1->re(

    COMBO=>[
      SYM=>$O{lis},
      CMD=>$O{lis},

    ],

  ));

  my $key=$tab->build();


  # make ice
  my $self=bless {
    key   => $key,
    unrev => $O{unrev},
    wraps => $O{wraps},

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

  $frame->{pkg}=$pkg;


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
  my $out   = $class->cmdtab->{$name};

  if(! defined $out) {

    my $main = $self->{frame}->{main};
    my $lib  = $main->{cmdlib};

    my $have = $lib->fetch($name);

    $out=$have->{key};

  }


  return $out->{fn};

};

# ---   *   ---   *   ---
# defines a new command and
# registers it for export

sub cmdsub($name,$sig,$fn) {


  # find source class
  my $class = rcaller __PACKAGE__;

  croak "Unable to find source class for '$name'"
  if $class eq __PACKAGE__;


  # TODO: map args to sig_t ice
  my @args =

    grep  {length $ARG}
    map   {strip(\$ARG);$ARG}

    split $SEMI_RE,$sig;


  # add to cache and give
  my $tab=$class->cmdtab;

  $tab->{$name}={

    pkg => $class,
    lis => $name,

    sig => \@args,
    fn  => \&$fn,

    wraps => null,

  };


  return $tab->{$name};

};

# ---   *   ---   *   ---
# ^plus name mangling
#
# we need this when a method depends
# on an instance of main

sub m_cmdsub($main,$lis,$sig,$fn) {

  my $name   = "$main\::$lis";
  my $cstruc = cmdsub $name,$sig,$fn;

  $cstruc->{lis} = $lis;

  return $cstruc;

};

# ---   *   ---   *   ---
# two lines of code common
# to wrapper methods

sub wrapper($self,$branch) {
  my $fn=$self->cmdfn($self->{wraps});
  $fn->($self,$branch);

};

# ---   *   ---   *   ---
# batch-wrap another method

sub w_cmdsub($name,$sig,@list) {

  map {
    my $cstruc=cmdsub($ARG,$sig,\&wrapper);
    $cstruc->{wraps}=$name;

  } @list;

};

# ---   *   ---   *   ---
# ^batch-wrap mangled

sub wm_cmdsub($main,$name,$sig,@list) {

  map {
    my $cstruc=m_cmdsub($main,$ARG,$sig,\&wrapper);
    $cstruc->{wraps}=$name;

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
