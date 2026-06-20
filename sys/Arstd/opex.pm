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
  use Chk qw(is_null is_hashref);
  use Type qw(typefet is_signed);

  use Arstd::String qw(gsplit);
  use Arstd::Array qw(flatten);
  use Arstd::Bin qw(deepcpy);
  use Arstd::Re qw(eiths);
  use Arstd::throw;
  use Arstd::seq;
  use Arstd::ins qw(
    ins_new
  );
  use Tree::C;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT=qw(opex);


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.00.3a";
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

  # get operators in expression,
  # sorted by precedence
  my ($op,$value,$chain)=opex_sort(
    gsplit($s,opex_re())
  );
  # ^generate code from operators
  opex_inner($mem,$chain,$ARG) for @$op;

  # catch unsolved values
  for(
    grep {! is_null($chain->[0])}
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
  my $tab=$mem->{sym};
  while($$sref=~ s[$re][]) {
    my $cmd  = $+{cmd};
    my $idex = $+{idex};

    # validate F name
    throw "opex: call to undefined symbol <$cmd>"
    if!   exists $tab->{$cmd};

    # we keep track of which functions were
    # invoked within each scope!
    push @{$mem->{call}},$cmd;

    # fetch arguments
    my @args=gsplit(
      scp_unpack($mem->{strar},$idex),
      qr{\s*,\s*},
    );
    my $argt=$tab->{$cmd}->{in};

    # we need to recurse in order to solve
    # the arguments...
    my $tail = [];
    my $type = $mem->{type};
    my $old  = $mem->{dst};

    $mem->{dst}=$tail;
    for(0..$#args) {
      my $svalue = $args[$ARG];
      my $stype  = $argt->[$ARG]->[0];

      $mem->{type}=$stype;
      opex($mem,$svalue);
    };
    $mem->{type} = $type;
    $mem->{dst}  = $old;

    # *now* generate call
    my $stype = $tab->{$cmd}->{out};
       $type  = $mem->{type};

    $mem->{type}=$stype;
    opex_push(
      $mem,
      call=>["$cmd"],
      $tail,
    );
    $mem->{type}=$type;
  };
  return;
};


# ---   *   ---   *   ---
# put value in stack

sub opex_push_value {
  my ($mem,$x)=@_;
  return opex_push($mem,$x->{cmd})
  if is_hashref($x);

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
  my $tail=[flatten(\@tail)];
  return push @{$mem->{dst}},{
    type => $mem->{type},
    cmd  => $cmd,
    args => $args // [$mem->{tgt}],
    tail => $tail,
  };
};
sub opex_value {
  my ($mem,$xref)=@_;

  # null means nop
  if(is_null($$xref)) {
    return null;

  # is it a named variable?
  } elsif( ($$xref=~ qr{^[[:alnum:]_]+$})
  &&  (exists $mem->{var}->{$$xref}) ) {
    $mem->{type}=opex_typechk(
      $mem,
      $mem->{type},
      $$xref
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
  my ($mem,$type,$x)=@_;
  my $have=(exists $mem->{var}->{$x})
    ? $mem->{var}->{$x}
    : null
    ;

  # edge case: void !!
  if(is_null($have) && is_null($type)) {
    return {name=>null};

  } elsif(is_null($type) &&! is_null($have)) {
    return $have;

  } elsif(! is_null($type) && is_null($have)) {
    return $type;
  };
  # catch invalid
  throw "opex: type mismatch for '$x'; "
  .     "[$have->{name}] != [$type->{name}]"

  if $type->{sizeof} != $have->{sizeof};

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
        throw "opex: undefined operator '$ARG'"
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
  > $order->{$chain->[$b]}

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
  my $unary = grep {$ARG eq $s} opex_unary();
  my $tail  = [];
  my $old   = $mem->{dst};
  my @have  = ($unary)
    ? (is_null($rh) ? ($lh) : ($rh))
    : ($lh,$rh)
    ;
  push @have,flatten($macro);

  $mem->{dst}=$tail;
  for(@have) {
    opex_recurse_chk($mem,\$ARG);
  };
  $mem->{dst}=$old;

  # write opcode + operands
  opex_push(
    $mem,
    $ins->{cmd},
    undef,
    @$tail,
  );
  # mark value(s) as already pushed
  my @asg=($i != 0)
    ? ($i-1,$i+0,$i+1)
    : ($i+0,$i+1)
    ;
  $chain->[$ARG]=null for @asg;
  return;
};


# ---   *   ---   *   ---
# expands anything in (parens)

sub opex_recurse_chk {
  my ($mem,$src)=@_;
  my $tok_re=Arstd::seq::tok_re("scp");

  # common values can simply be pushed
  # without further processing
  if(! ($$src=~ s[$tok_re][])) {
    opex_push_value($mem,$$src);
    return;
  };
  # get string to process,
  # then expand into operation
  my $op=scp_unpack($mem->{strar},$+{idex});
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
  return qw(
    ~ & | ^ !
    << >> <@ @>
    * / % ++ + -- -
    < > <= >=
    == != && ||
    += =
  );
};
sub opex_unary {
  return qw(~ ! ++ --);
};
sub opex_order {
  my $i=0;
  return {map {$ARG=>$i++} opex_all()};
};
sub opex_tab {
  return {
    q[~]  => ins_new(xor  => -1),
    q[&]  => ins_new(and  => ()),
    q[|]  => ins_new(or   => ()),
    q[^]  => ins_new(xor  => ()),
    q[!]  => ins_new(eqz  => ()),

    q[<<] => ins_new(shl  => ()),
    q[>>] => ins_new(shr  => ()),
    q[<@] => ins_new(rol  => ()),
    q[@>] => ins_new(ror  => ()),

    q[*]  => ins_new(mul  => ()),
    q[/]  => ins_new(div  => ()),
    q[%]  => ins_new(rem  => ()),
    q[++] => ins_new(set  => 1  => "add"),
    q[+]  => ins_new(add  => ()),
    q[--] => ins_new(set  => 1  => "sub"),
    q[-]  => ins_new(sub  => ()),

    q[<]  => ins_new(lt   => ()),
    q[>]  => ins_new(gt   => ()),
    q[<=] => ins_new(le   => ()),
    q[>=] => ins_new(ge   => ()),

    q[==] => ins_new(eq   => ()),
    q[!=] => ins_new(ne   => ()),
    q[&&] => "nyi",
    q[||] => "nyi",
    q[+=] => ins_new(set => add => ()),
    q[=]  => ins_new(set => ()),
  };
};


# ---   *   ---   *   ---
1; # ret
