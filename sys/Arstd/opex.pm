#!/usr/bin/perl
# ---   *   ---   *   ---
# OPEX
# operator expansion
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::opex;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_hashref is_arrayref);
  use Type qw(typefet is_signed);

  use Arstd::String qw(gsplit);
  use Arstd::Array qw(flatten);
  use Arstd::Bin qw(deepcpy);
  use Arstd::Re qw(eiths);
  use Arstd::throw;
  use Arstd::seq;
  use Arstd::strtok qw(strtok);
  use Arstd::vm qw(
    vm_var_get
    vm_sym_get
    vm_sym_in
    vm_sym_out
    vm_label_find
  );
  use Arstd::ins qw(ins_map ins_new);
  use Tree::C qw(array_re);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT_OK=qw(opex opex_undo);


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.01.1a";
  my $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# entry point

sub opex {
  my ($mem,$s)=@_;

  # get function calls out of the way first;
  #
  # the sub we use for this will recurse back
  # if the call itself must perform further
  # expansions
  opex_fn($mem,\$s);

  # solve array indexing
  opex_arr($mem,\$s);

  # get operators in expression,
  # sorted by precedence
  my ($op,$value,$chain)=opex_sort(
    gsplit($s,opex_re())
  );
  # ^generate code from operators
  opex_inner($mem,$chain,$ARG) for @$op;

  # catch unsolved values
  for(
    grep    {! is_null($ARG)}
    reverse @$chain
  ) {
    opex_push_value($mem,$ARG);
  };
  return;
};


# ---   *   ---   *   ---
# expands function calls

sub opex_fn {
  my ($mem,$sref)=@_;

  # this pattern detects a call;
  # NAME (...)
  my $tok_re = Arstd::seq::tok_re("scp");
  my $re     = qr{(?<cmd>[[:alnum:]_]+)\s*$tok_re};

  # for every F in string...
  while($$sref=~ s[$re][]) {
    my $cmd  = $+{cmd};
    my $idex = $+{idex};

    # validate F name
    my $sym=vm_sym_get($mem->{vm},$cmd);
    throw "opex: call to undefined symbol <$cmd>"
    if!   defined $sym;

    # we keep track of which functions were
    # invoked within each scope!
    push @{$mem->{call}},$cmd;

    # fetch arguments
    my @args=gsplit(
      scp_unpack($mem->{strar},$idex),
      qr{\s*,\s*},
    );
    my @in=vm_sym_in($mem->{vm},$sym);

    # we need to recurse in order to solve
    # the arguments...
    my $tail = [];
    my $type = $mem->{type};
    my $old  = $mem->{dst};

    $mem->{dst}=$tail;
    for my $i(0..$#args) {
      my $svalue = $args[$i];
      my $stype  = $in[$i]->{type};

      $mem->{type}=$stype;
      opex($mem,$svalue);
    };
    $mem->{type} = $type;
    $mem->{dst}  = $old;

    # *now* generate call
    my $out  = vm_sym_out($mem->{vm},$sym);
       $type = $mem->{type};

    $mem->{type}=$out->{type};
    opex_push(
      $mem,
      call=>[vm_label_find($mem->{vm},$cmd)],
      $tail,
    );
    $mem->{type}=$type;
  };
  return;
};


# ---   *   ---   *   ---
# expand array indexing

sub opex_arr {
  my ($mem,$sref)=@_;

  # for every array idex in string...
  my $re  = array_re();
  my @out = ();
  while($$sref=~ s[$re][::mark]) {
    # make fetch operation
    my $ptr=vm_var_get(
      $mem->{vm},
      "$+{base}\[$+{elem}]"
    );
    push @out,$ptr->{id};
  };
  # ^put generated operations back
  $re=qr{::mark};
  while($$sref=~ $re) {
    my $id=shift @out;
    $$sref=~ s[$re][$id];
  };
  # tokenize the parens and give
  strtok($mem->{strar},$$sref,syx=>$mem->{syx});
  return;
};


# ---   *   ---   *   ---
# put value in stack

sub opex_push_value {
  my ($mem,$x)=@_;
  return opex_push($mem,$x->{cmd})
  if     is_hashref($x);

  my $cmd=opex_value($mem,\$x);
  return if is_null($cmd);

  return opex_push(
    $mem,
    ($cmd ne $x)
      ? ($cmd=>[$x])
      : ($cmd=>[])
      ,
  );
};
sub opex_push {
  my ($mem,$cmd,$args,@tail)=@_;
  my $tail   = [flatten(\@tail)];
     $args //= [$mem->{tgt}];

  my $ins=ins_new($mem->{type},$cmd=>(@$args));
     $ins->{tail}=$tail;

  return push @{$mem->{dst}},$ins;
};
sub opex_value {
  my ($mem,$xref)=@_;

  # we check if the value corresponds with
  # a registered variable
  my $ptr=vm_var_get($mem->{vm},$$xref);

  # null/opstr means nop
  if(is_null($$xref)
  || is_arrayref($$xref)
  || exists opex_tab()->{$$xref}) {
    return null;

  # is it a variable?
  } elsif(defined $ptr) {
    $mem->{type}=opex_typechk(
      $mem,
      $mem->{type},
      $ptr
    );
    $mem->{tgt}=$$xref;
    return "get";

  # keyword?
  } elsif($$xref=~ qr{^(?:return|call)\b}) {
    if($$xref eq "return") {
      $$xref="ret";
    };
    return $$xref;

  # constant!
  } else {
    return "const";
  };
};


# ---   *   ---   *   ---
# typecheck for local values

sub opex_typechk {
  my ($mem,$type,$ptr)=@_;

  # edge case: void !!
  if(is_null($ptr) && is_null($type)) {
    return {name=>null};

  } elsif(is_null($type) &&! is_null($ptr)) {
    return $ptr->{type};

  } elsif(! is_null($type) && is_null($ptr)) {
    return $type;
  };
#  # catch invalid
#  throw "opex: type mismatch for '$ptr->{id}'; "
#  .     "[$ptr->{type}->{name}] != "
#  .     "[$type->{name}]"
#
#  if $type->{sizeof} != $ptr->{type}->{sizeof};

  return $type;
};


# ---   *   ---   *   ---
# sort operators in expression
# accto precedence

sub opex_sort {
  # get positions...
  my $tab      = opex_tab();
  my $op       = [];
  my $value    = [];
  my $chain    = [];
  my $i        = 0;
  my $split_re = eiths(
    [opex_all()],
    opscape => 1,
    capt    => 1,
  );
  for(@_) {
    if($ARG=~ opex_re()) {
      my @ar=gsplit($ARG,$split_re);
      for(@ar) {
        throw "opex: undefined operator '$ARG'\n"
        .     "^at '" . join(" ",@_) . "'"

        if!   exists $tab->{$ARG};

        push @$chain,$ARG;
        push @$op,$i++;
      };
    } else {
      push @$chain,$ARG;
      push @$value,$i++;
    };
  };
  # get order of operations...
  my $order=opex_order();
  @$op=sort {
      $order->{$chain->[$a]}
  <=> $order->{$chain->[$b]}

  } @$op;

  return ($op,$value,$chain);
};


# ---   *   ---   *   ---
# map operators to instructions

sub opex_inner {
  my ($mem,$chain,$i)=@_;

  # validate operator
  my $tab = opex_tab();
  my $s   = $chain->[$i];

  # break it down...
  my $macro = deepcpy($tab->{$s});
  my $ins   = shift @$macro;

  # LH (OP) RH
  my ($lh,$rh)=($i != 0)
    ? ($chain->[$i-1],$chain->[$i+1])
    : (null,$chain->[$i+1])
    ;
  # recurse if either operand is a
  # parenthesized expression!
  my $unary = opex_unary($s);
  my $tail  = [];
  my $old   = $mem->{dst};
  my @have  = ($unary)
    ? (is_null($rh) ? ($lh) : ($rh))
    : grep {defined $ARG} ($lh,$rh)
    ;
  # recurse for operands
  $mem->{dst}=$tail;
  my $tgt=$mem->{tgt};

  push @have,flatten($macro);
  opex_recurse_chk($mem,\$ARG) for @have;

  $mem->{dst}=$old;
  $mem->{tgt}=$tgt;

  # generating a "get" for the element being
  # set is redundant!!
  if($s eq "=") {
    my $tmp=shift @$tail;
    for(@$tail,$ins) {
      $ARG->{args}->[0]=$tmp->{args}->[0]
      if is_null($ARG->{args}->[0]);
    };
  };
  # write opcode + operands
  opex_push(
    $mem,
    $ins->{cmd},
    (@{$ins->{args}} ? $ins->{args} : undef),
    @$tail
  );
  # mark value(s) as already pushed
  my @asg=($i != 0 &&! $unary)
    ? ($i-1,$i+0,$i+1)
    : ($i+0,$i+1)
    ;
  for(@asg) {
    next if! defined $chain->[$ARG];
    if( $ARG == $i
    ||! exists $tab->{$chain->[$ARG]}) {
      $chain->[$ARG]=$old;
    };
  };
  return;
};


# ---   *   ---   *   ---
# expands anything in (parens)

sub opex_recurse_chk {
  my ($mem,$src)=@_;
  my $tok_re=Arstd::seq::tok_re("scp");

  # solved values are pushed
  if(is_arrayref($$src)) {
    push @{$mem->{dst}},@{$$src};
    @{$$src}=();

    return;

  # common values can simply be pushed
  # without further processing
  } elsif(! ($$src=~ s[$tok_re][])) {
    opex_push_value($mem,$$src);
    return;
  };
  # get string to process,
  # then expand into operation
  my $op=scp_unpack($mem->{strar},$+{idex});
  strtok($mem->{strar},$op,syx=>$mem->{syx});
  opex($mem,$op);

  return;
};


# ---   *   ---   *   ---
# gets V from (V)!!

sub scp_unpack {
  my ($strar,$idex)=@_;
  my $re=  paren_re();
  my $op=  $strar->[$idex];
     $op=~ s[$re][]g;

  return $op;
};
sub paren_re {
  return qr{^\(|\)$};
};


# ---   *   ---   *   ---
# ROM

sub opex_re {
  return qr{([^[:alnum:]_]+)};
};
sub opex_all {
  return gsplit(q[
    -> ~ & | ^ !
    << >> <@ @>
    * / % ++ + -- -
    < > <= >=
    == != && || ,
    += *= = *>
  ]);
};
sub opex_unary {
  return {map {$ARG=>1} qw(
    ~ ! ++ --

  )}->{$_[0]} // 0;
};
sub opex_order {
  my $i=0;
  return {map {$ARG=>$i++} opex_all()};
};
sub opex_tab {
  return {
    q[->] => ins_map(qw(at)),
    q[~]  => ins_map(qw(not)),
    q[&]  => ins_map(qw(and)),
    q[|]  => ins_map(qw(or)),
    q[^]  => ins_map(qw(xor)),
    q[!]  => ins_map(qw(eqz)),

    q[<<] => ins_map(qw(shl)),
    q[>>] => ins_map(qw(shr)),
    q[<@] => ins_map(qw(rol)),
    q[@>] => ins_map(qw(ror)),

    q[*]  => ins_map(qw(mul)),
    q[/]  => ins_map(qw(div)),
    q[%]  => ins_map(qw(rem)),
    q[++] => ins_map(qw(set 1 add)),
    q[+]  => ins_map(qw(add)),
    q[--] => ins_map(qw(set 1 sub)),
    q[-]  => ins_map(qw(sub)),

    q[<]  => ins_map(qw(lt)),
    q[>]  => ins_map(qw(gt)),
    q[<=] => ins_map(qw(le)),
    q[>=] => ins_map(qw(ge)),

    q[==] => ins_map(qw(eq)),
    q[!=] => ins_map(qw(ne)),

    q[||] => ins_map(qw(lor)),
    q[&&] => ins_map(qw(land)),
    q[,]  => ins_map(qw(list)),
    q[+=] => ins_map(qw(set add)),
    q[*=] => ins_map(qw(set mul)),
    q[=]  => ins_map(qw(set)),
    q[*>] => ins_map(qw(ptr)),
  };
};


# ---   *   ---   *   ---
# decompiles instructions back
# into operators

sub opex_undo {
  my ($cmd,@args)=@_;
  my $tab={
    shl     => "<<",
    shr     => ">>",
    eqz     => "!",
    nez     => "!=",
    xor     => "^",
    and     => "&",

    mul     => "*",
    div     => "/",
    rem     => "%",
    add     => "+",
    sub     => "-",

    lt      => "<",
    le      => "<=",
    gt      => ">",
    ge      => ">=",
    eq      => "==",
    ne      => "!=",

    set     => "=",
    seep    => "=",
    list    => ",",
  };
  return if! exists $tab->{$cmd};

  my $op=$tab->{$cmd};
  return join($op,@args) if $op eq "=";
  return "(" . join($op,@args,0) . ")" if $cmd eq "nez";
  return (opex_unary($op))
    ? "($op " . $args[0] . ")"
    : "(" . join($op,@args) . ")"
    ;
};


# ---   *   ---   *   ---
1; # ret
