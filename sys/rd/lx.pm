#!/usr/bin/perl
# ---   *   ---   *   ---
# RD:LX
# Slow runner ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package rd::lx;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match-vars);

  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Chk;

  use Arstd::Re;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,$rd) {
  return bless {rd=>$rd},$class;

};

# ---   *   ---   *   ---
# names of execution rounds

sub passes($self) { return qw(
  parse solve ipret

)};

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
# ^shorthands

  Readonly my $QLIST=>cmdarg(['LIST','ANY']);

  Readonly my $VLIST=>cmdarg(

    ['LIST','OPERA','BARE'],
    value=>'[^\{]'

  );

  Readonly my $OPT_VLIST=>{%$VLIST,opt=>1};

  Readonly my $BARE  => cmdarg(['BARE']);
  Readonly my $CURLY => cmdarg(
    ['OPERA'],value=>'\{'

  );

  Readonly my $PARENS => cmdarg(
    ['OPERA'],value=>'\('

  );

# ---   *   ---   *   ---
# default set of commands

sub cmdset($self) { return {

  echo => [$QLIST],
  stop => [],


  cmd       => [$BARE,$OPT_VLIST,$CURLY],
  'bat-cmd' => [$PARENS,$OPT_VLIST,$CURLY],

}};

# ---   *   ---   *   ---
# get name of current pass

sub passname($self) {
  return ($self->passes())[$self->{rd}->{pass}];

};

# ---   *   ---   *   ---
# selfex

sub stop_parse($self,$branch) {

  my $rd=$self->{rd};

  $rd->{tree}->prich();
  $rd->perr('STOP');

};

# ---   *   ---   *   ---
# makes new command!

sub cmd_parse($self,$branch) {

  my $rd=$self->{rd};


  # unpack
  my ($name,$args,$body)=
    @{$branch->{leaves}};

  my $ucmd=$rd->{xns}->{ucmd};


  # redecl guard
  $name=$name->{value};
  $self->throw_redecl('user command'=>$name)
  if exists $ucmd->{$name};


  # ^collapse optional
  if(! defined $body) {
    $body=$args;
    $args=undef;

  };


  # have arguments?
  $args=($args)
    ? $self->argread($args,$body)
    : []
    ;


  # make table for ipret
  my $cmdtab={

    name   => $name,
    body   => $body,

    args   => $args,

  };

  # ^save and remove branch
  $ucmd->{$name}=$cmdtab;
  $branch->discard();

};

# ---   *   ---   *   ---
# ^errme

sub throw_redecl($self,$type,$name) {

  $self->{rd}->perr(
    "re-declaration of %s '%s'",
    args=>[$type,$name]

  );

};


# ---   *   ---   *   ---
# prepares a table of arguments
# with default values and
# replacement paths into
# command body

sub argread($self,$args,$body) {

  my $rd=$self->{rd};
  my $l1=$rd->{l1};

  # got list or single elem?
  my $ar=(defined $l1->is_list($args->{value}))
    ? $args->{leaves}
    : [$args]
    ;


  # make argsfield
  my $idex = 0;
  my $tab  = [ map {


    # [name => default value]
    my $argname = $ARG->{value};
    my $defval  = undef;


    # have default value?
    my $opera=$l1->is_opera($ARG->{value});

    # ^yep
    if(defined $opera && $opera eq '=') {

      ($argname,$defval)=(
        $ARG->{leaves}->[0]->{value},
        $ARG->{leaves}->[1]

      );

    };


    # make replacement paths
    # this helps insert value later
    my $replpath = [];
    my @pending  = $body;

    my $subst    = "\Q$argname";
    my $subststr = "\%$subst\%";
       $subst    = qr{\b(?:$subst)\b};
       $subststr = qr{(?:$subststr)};

    my $place    = ":__ARG[$idex]__:";
    my $replre   = qr"\Q$place";


    # recursive walk tree of body
    while(@pending) {

      my $nd=shift @pending;

      # have string?
      my $re=(defined $l1->is_string($nd->{value}))
        ? $subststr
        : $subst
        ;


      if($nd->{value}=~ s[$re][$place]) {
        my $path=$nd->ancespath($body);
        push @$replpath,$path;

      };

      unshift @pending,@{$nd->{leaves}};

    };

    $idex++;


    # give argname => argdata
    $argname=>{

      repl   => {
        path => $replpath,
        re   => $replre,

      },

      defval => $defval,

    };


  } @$ar ];


  $args->discard();

  return $tab;

};

# ---   *   ---   *   ---
# type-checks command arguments

sub argchk($self) {

  my $rd=$self->{rd};

  # get command meta
  my $CMD  = $self->load_CMD();
  my $key  = $rd->{branch}->{cmdkey};
  my $args = $CMD->{$key}->{-args};
  my $pos  = 0;


  # walk child nodes and type-check them
  for my $arg(@$args) {

    my $have=$self->argtypechk($arg,$pos);

    $self->throw_badargs($key,$arg,$pos)
    if ! $have &&! $arg->{opt};

    $pos += $have;

  };

};

# ---   *   ---   *   ---
# ^guts, looks at single
# type option for arg

sub argtypechk($self,$arg,$pos) {

  my $rd=$self->{rd};
  my $l1=$rd->{l1};

  # get anchor
  my $nd  = $rd->{branch};
  my $par = $nd->{parent};

  # walk possible types
  for my $type(@{$arg->{type}}) {

    # get pattern for type
    my $re=$l1->tagre($type => $arg->{value});

    # return true on pattern match
    my $chd=$nd->{leaves}->[$pos];
    return 1 if $chd && $chd->{value}=~ $re;

  };


  return 0;

};

# ---   *   ---   *   ---
# ^errme

sub throw_badargs($self,$key,$arg,$pos) {

  my $rd    = $self->{rd};

  my $value = $rd->{branch}->{leaves};
     $value = $value->[$pos]->{value};

  my @types = @{$arg->{type}};


  $rd->perr(

    "invalid argtype for command '%s'\n"
  . "position [num]:%u: '%s'\n"

  . "need '%s' of type "
  . (join ",","'%s'" x int @types),

    args=>[$key,$pos,$value,$arg->{value},@types],

  );

};

# ---   *   ---   *   ---
# generate/fetch command table

sub load_CMD($self) {

  state $cmdset = $self->cmdset();
  state @keys   = keys %$cmdset;

  state $CMD    = {

    ( map {

      # get name of command
      my $key   = $ARG;
      my $args  = $cmdset->{$key};

      my $plkey =  $key;
         $plkey =~ s[\-][_]sxmg;

      # get subroutine variants of
      # command per execution layer
      $key => {

        -args=>$args,

        map { $ARG => codefind(
          (ref $self),"${plkey}_$ARG"

        )} $self->passes()

      };


    } @keys ),


    -re=>re_eiths(

      \@keys,

      bwrap=>1,
      whole=>1

    ),

  };


  return $CMD;

};

# ---   *   ---   *   ---
1; # ret
