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

  our $VERSION = v0.00.6;#a
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
# generate/fetch set of commands

sub cmdset($self) {

#  # get ctx
#  my $rd    = $self->{rd};
#  my $mc    = $rd->{mc};
#  my $tree  = $mc->->{cas}->{inner};
#
#  # have user definitions?
#  my @ucmd    = $tree->branches_in(qr{^UCMD$});
#  my $USERDEF = {};
#
#  map {
#    map {$USERDEF->{$ARG}=[$OPT_QLIST]}
#    $ARG->branch_values();
#
#  } @ucmd;


  # asm whole set
  return {

    echo => [$QLIST],
    stop => [],


    # user command maker
    cmd        => [$BARE,$OPT_VLIST,$CURLY],
    'bat-cmd'  => [$PARENS,$OPT_VLIST,$CURLY],


    # value types
    ( map {$ARG => [$OPT_QLIST]}
      @{$Type::MAKE::ALL_FLAGS}

    ),

    'data-decl' => [$VLIST,$OPT_QLIST],


#    # paste user-defined commands
#    %$USERDEF

  };

};

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
# entry point for (exprtop)[*type] (values)
#
# not called directly, but rather
# by mutation of [*type] (see: type_parse)

sub data_decl_parse($self,$branch) {

  # get ctx
  my $rd    = $self->{rd};
  my $l1    = $rd->{l1};
  my $l2    = $rd->{l2};

  my $mc    = $rd->{mc};
  my $scope = $mc->{scope};
  my $type  = $branch->{vref};


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
  my @unsolved = map {

    $value->[$idex] //= $branch->inew(
      $l1->make_tag('NUM'=>0x00)

    );

    my $n=$ARG->{value};
    my $v=$value->[$idex++];


    # redecl guard
    $self->throw_redecl('value',$n)
    if $scope->has($n);

    # *attempt* solving
    my ($x,$have)=
      $self->value_solve($type,$n,$v);

    # ^reserve space
    $x=$l1->quantize($x);
    $mc->decl($type,$n,$x);

    # ^give if not solved!
    (! defined $have) ? [$n=>$v] : () ;


  } @$name;


  $self->wait_next_pass($branch,\@unsolved);


};

# ---   *   ---   *   ---
# ^save [name=>value] to current namespace
# but only if we were able to solve it!

sub value_solve($self,$type,$name,$value) {


  # get ctx
  my $rd    = $self->{rd};
  my $mc    = $rd->{mc};
  my $l1    = $rd->{l1};
  my $l2    = $rd->{l2};


  # can solve value now?
  my $have=$l2->value_solve($value);

  # ^zero on nope
  my $x=(! length $have)
    ? $l1->make_tag(NUM=>0)
    : $have
    ;


  return ($x,$have);

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
# collapses width/specifier list
#
# mutates node:
#
# * (? exprbeg) [*type] -> [*data-decl]
# * (! exprbeg) [*type] -> [Ttype]

sub type_parse($self,$branch) {

  # get ctx
  my $rd = $self->{rd};
  my $l1 = $rd->{l1};
  my $l2 = $rd->{l2};


  # first token is first specifier!
  my @type = $l1->is_cmd($branch->{value});
  my $par  = $branch->{parent};

  # ^get tokens from previous iterations
  push @type,@{$branch->{type_Q}}
  if exists $branch->{type_Q};


  # if parent is also a type, then
  # continue collapsing
  my $head = $l1->is_cmd($par->{value});
  if(defined $head) {

    # save types to parent, they'll be
    # picked up in the next run of this F
    $par->{type_Q} //= [];
    push @{$par->{type_Q}},@type;

    # ^remove this token
    $branch->discard();


    return;


  # ^stop at last node in the chain
  } else {


    # get hashref from flags
    # save it to branch
    my $type=$self->type_decode(@type);
    $branch->{vref}=$type;

    delete $self->{type_Q};


    # first token in expression?
    if($l2->is_exprtop($branch)) {

      # mutate into another command
      $branch->{value}=
        $l1->make_tag(CMD=>'data-decl')
      . "$type->{name}"
      ;


      return 'mut';


    # ^nope, last or middle
    } else {

      # mutate into command argument
      $branch->{value}=
        $l1->make_tag(TYPE=>$type->{name});


      return;

    };

  };

};

# ---   *   ---   *   ---
# ^fetch/errme

sub type_decode($self,@src) {

  # get type hashref from flags array
  my $rd   = $self->{rd};
  my $type = typefet @src;

  # ^catch invalid
  $rd->perr('invalid type')
  if ! defined $type;


  return $type;

};

# ---   *   ---   *   ---
# ^icef*ck

subwraps(

  q[$self->type_parse]=>q[$self,$branch],

  map {[
    "${ARG}_parse" => "\$branch"

  ]} @{$Type::MAKE::ALL_FLAGS}

);

# ---   *   ---   *   ---
# attempts to solve pending values

sub data_decl_ctx($self,$branch) {

  my $rd   = $self->{rd};
  my $mc   = $rd->{mc};
  my $l1   = $rd->{l1};
  my $type = $branch->{vref};

  my @have = map {

    my ($name,$value) = @$ARG;
    my ($have,$x)     = $self->value_solve(
      $type,$name,$value

    );

    if($have) {
      my $ref=$mc->search($name);
      $$ref->store($l1->quantize($x));

    };


    (! defined $have) ? $ARG : () ;

  } @{$branch->{solve_Q}};


  $self->wait_next_pass($branch,\@have);

};

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

  my $CMD=$self->load_CMD(1);

  use Fmat;
  fatdump(\$CMD);

  exit;

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

sub load_CMD($self,$update=0) {


  # skip update?
  state $CMD = {};
  return $CMD if int %$CMD &&! $update;


  # regen cache
  my $cmdset = $self->cmdset();
  my @keys   = keys %$cmdset;

  $CMD={


    # re to match any command name
    -re=>re_eiths(

      \@keys,

      opscape => 1,
      bwrap   => 1,
      whole   => 1,

    ),


    # command list [cmd=>attrs]
    map {


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


    } @keys

  };


  return $CMD;

};

# ---   *   ---   *   ---
1; # ret
