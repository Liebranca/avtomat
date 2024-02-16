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
  use Type;

  use Arstd::Re;
  use Arstd::PM;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,$rd) {
  return bless {rd=>$rd},$class;

};

# ---   *   ---   *   ---
# names of execution rounds

sub passes($self) { return qw(
  parse ctx solve xlate run

)};

# ---   *   ---   *   ---
# ^name of subroutine for this pass

sub passf($self,$key) {

  my $CMD  = $self->load_CMD();

  my $pass = $self->passname();
  my $fn   = $CMD->{$key}->{$pass};


  return $fn;

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
# ^shorthands

  Readonly my $QLIST=>cmdarg(['LIST','ANY']);
  Readonly my $VLIST=>cmdarg(

    ['LIST','OPERA','BARE'],
    value=>'[^\{]'

  );

  Readonly my $OPT_QLIST=>{%$QLIST,opt=>1};
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


  cmd        => [$BARE,$OPT_VLIST,$CURLY],
  'bat-cmd'  => [$PARENS,$OPT_VLIST,$CURLY],


  ( map {$ARG => [$VLIST,$OPT_QLIST]}
    qw  (byte word dword qword)

  ),

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
# value decl

sub decl_parse($self,$branch,$ezy) {

  # get ctx
  my $rd    = $self->{rd};
  my $l1    = $rd->{l1};
  my $l2    = $rd->{l2};

  my $scope = $rd->{scope};
  my $path  = $scope->{path};


  # get [name=>value] arrays
  my ($name,$value)=map {

    (defined $l1->is_list($ARG->{value}))
      ? $ARG->{leaves}
      : [$ARG]
      ;

  } @{$branch->{leaves}};


  # ensure value for each name
  # then attempt solving value
  my $idex     = 0;
  my @unsolved = grep {$ARG} map {

    $value->[$idex] //= $branch->inew(
      $l1->make_tag('NUM'=>0x00)

    );

    my $v=$value->[$idex++];


    # redecl guard
    $self->throw_redecl('data',$ARG->{value})
    if $scope->has(@$path,'DATA',$ARG->{value});

    # *attempt* solving
    # finish decl if solved ;>
    my $have=$self->value_solve($ARG,$v);

    # give if not solved!
    (! defined $have)
      ? [$ARG=>$v]
      : undef
      ;


  } @$name;


  $self->wait_next_pass($branch,\@unsolved);


};

# ---   *   ---   *   ---
# ^save [name=>value] to current namespace
# but only if we were able to solve it!

sub value_solve($self,$name,$value) {

  my $rd    = $self->{rd};
  my $l2    = $rd->{l2};
  my $scope = $rd->{scope};
  my $path  = $scope->{path};

  my $have  = $l2->value_solve($value);

  $scope->decl($have,@$path,'DATA',$name->{value})
  if defined $have;


  return $have;

};

# ---   *   ---   *   ---
# wait for next pass if values pending
# else discard branch

sub wait_next_pass($self,$branch,$Q) {

  if(@$Q) {

    $branch->{solve_Q} //= [];
    push @{$branch->{solve_Q}},@$Q;

    $branch->clear();


  } else {
    $branch->discard();

  };

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$self->decl_parse]=>q[$self,$branch],

  map {[
    "${ARG}_parse" => "\$branch,'$ARG'"

  ]} qw(byte word dword qword)

);

# ---   *   ---   *   ---
# attempts to solve pending values

sub decl_ctx($self,$branch,$ezy) {

  my $rd   = $self->{rd};
  my $l2   = $rd->{l1};

  my @have = grep {$ARG} map {

    my ($name,$value)=@$ARG;
    my $have=$self->value_solve($name,$value);

    (! defined $have)
      ? $ARG
      : undef
      ;

  } @{$branch->{solve_Q}};


  $self->wait_next_pass($branch,\@have);

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$self->decl_ctx]=>q[$self,$branch],

  map {[
    "${ARG}_ctx" => "\$branch,'$ARG'"

  ]} qw(byte word dword qword)

);

# ---   *   ---   *   ---
# makes new command!

sub cmd_parse($self,$branch) {

  my $rd=$self->{rd};


  # unpack
  my ($name,$args,$body)=
    @{$branch->{leaves}};

  my $scope = $rd->{scope};
  my $path  = $scope->{path};


  # redecl guard
  $name=$name->{value};
  $self->throw_redecl('user command'=>$name)
  if $scope->has(@$path,'UCMD',$name);


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

  # ^save to current namespace and remove branch
  $scope->decl($cmdtab,@$path,'UCMD',$name);
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
