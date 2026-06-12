#!/usr/bin/perl
# ---   *   ---   *   ---
# WAT COMPILER
# call it "easy" on the eyes!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::spider::compile;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_file);
  use Type qw(typefet is_signed);

  use Arstd::String qw(
    cat
    strip
    gstrip
    gsplit
  );
  use Arstd::Array qw(flatten);
  use Arstd::Bin qw(
    orc
    deepcpy
  );
  use Arstd::Re qw(eiths);
  use Arstd::throw;
  use Arstd::strtok qw(strtok unstrtok);
  use Arstd::seq;
  use Tree::C;


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.00.1a";
  my $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# entry point; compiles C into WAT
#
# [0]: byte ptr ; fname || C code
# [<]: byte ptr ; WAT code
#
# TODO
#
# * fctl blocks
# * optimize const ops

sub import {
  # handle input
  my ($class,$src)=@_;
  my $body=(is_file($src) ? orc($src) : $src);

  # map C code to expression tree
  my $tree=Tree::C->rd($body);
  my @expr=$tree->to_expr();

  # generate WAT code from tree
  my $out=join("\n",map {
    split(qr"\n",node_xlate($ARG));

  } @expr);

  return "(module\n$out\n)";
};


# ---   *   ---   *   ---
# recursively translates node from C tree

sub node_xlate {
  my ($node)=@_;
  my $t=$node->{type};

  # go up one level
  my $pad   = node_state()->{pad};
  my $depth = node_enter();

  # get code translation for this node
  my $xlate=null;
  if($t eq "proc") {
    $xlate=node_proc($node,$depth);

  } elsif($t eq "asg") {
    $xlate=node_asg($node,$depth);

  } elsif($t eq "expr") {
    $xlate=node_expr($node,$depth);

  } else {
    throw "NYI: <$t> node";
  };
  # ^ not strictly necessary, but we want
  #   to add comments to the generated code
  #   while we debug the compiler
  my $args = (! is_null($node->{args}))
    ? "(" . join(",",@{$node->{args}}) . ")"
    : ""
    ;
  my $out  = cat(
    "\n$pad",
    ";; $node->{cmd} $node->{expr}",
    $args,
    $xlate,
  );
  # go down one level and give
  node_leave();
  return $out;
};


# ---   *   ---   *   ---
# book-keeping for node translation

sub node_state {
  state $out={
    depth => 0,
    pad   => null,
    sym   => {},
  };
  return $out;
};
sub node_enter {
  my $mem   = node_state();
  my $depth = $mem->{depth}++;

  $mem->{pad}=node_getpad();

  return $depth;
};
sub node_leave {
  my $mem=node_state();

  --$mem->{depth};
    $mem->{pad}=node_getpad();

  return $mem->{depth};
};
sub node_getpad {
  my $depth=$_[0] // node_state()->{depth};
  return "\n" . ("  " x $depth);
};


# ---   *   ---   *   ---
# translates func node

sub node_proc {
  my ($node,$depth)=@_;

  # get return type
  my ($type,$name,@expr)=rdnode($node);
  my $flg_re=qr{\b(public)\b};

  # ^handle flags
  my $flg={
    public=>0,
  };
  while($type=~ s[$flg_re][]) {
    my $x=$1;
    if($x eq "public") {
      $flg->{public}=1;
    };
  };
  # make new scope and register return type
  strip($type);
  proc_state(enter=>$name);

  # set arguments
  my @param=();
  for(@{$node->{args}}) {
    my ($t,$n,@e)=rdexpr($ARG);
    proc_state(param=>$t=>$n);
  };
  # set return type
  proc_state(result=>$type=>$name);

  # process function body
  my $body=cat(
    map {node_xlate($ARG)}
    @{$node->{blk}}
  );
  # ^give all
  my $head="\n(func \$$name";
  my $foot="\n)";
  if($flg->{public}) {
    $foot .= "\n(export \"$name\" (func \$$name))";
  };
  return cat(
    $head,
    proc_state(leave=>()),
    $body,
    $foot,
  );
};


# ---   *   ---   *   ---
# book keeping for current func node

sub proc_state_def {
  return (
    -order => [],
    -local => {},
    -sign  => {},
    -ret   => null,
  );
};
sub proc_state {
  state $reg={proc_state_def()};
  my ($cmd,$n)=@_;

  # opens new scope
  if($cmd eq "enter") {
    node_state()->{sym}->{$n}={
      ret  => {},
      args => [],
    };
    $reg->{-name}=$n;
    return;

  # outputs function signature and
  # local variables
  } elsif($cmd eq "leave") {
    my $pad=node_state()->{pad};
    my $out=$pad . join($pad,map {
      # return type
      if($ARG eq $reg->{-name}) {
        my $type=type_xlate($reg->{-ret});
        "(result $type)";

      # local or param
      } else {
        my $type=type_xlate($reg->{$ARG});
        my $scmd=(exists $reg->{-local}->{$ARG})
          ? "local"
          : "param"
          ;
        "($scmd \$$ARG $type)";
      };

    } @{$reg->{-order}});

    # reset state block
    %$reg=proc_state_def();
    return $out;

  # check if variable exists within scope
  } elsif($cmd eq "has") {
    return exists $reg->{$n};

  # ^get type of variable
  } elsif($cmd eq "get") {
    return $reg->{$n};

  # ^type of the return value itself
  } elsif($cmd eq "ret") {
    return $reg->{-ret};

  # variable decl
  } elsif($cmd=~ qr{^(?:param|local|result)$}) {
    my $t    = $n;
       $n    = $_[2];
       $t    = typefet($t);

    $reg->{$n}=$t;
    push @{$reg->{-order}},$n;

    # regular variable
    if($cmd eq "local") {
      $reg->{-local}->{$n}=1;

    # function parameter
    } elsif($cmd eq "param") {
      my $k   = $reg->{-name};
      my $sym = node_state()->{sym}->{$k};

      push @{$sym->{args}},[$t=>$n];

    # function return value
    } elsif($cmd eq "result") {
      my $k   = $reg->{-name};
      my $sym = node_state()->{sym}->{$t};

      $sym->{ret}=$reg->{-ret}=$t;
    };
    return $t;
  };
  # catch invalid
  throw "proc: undefined command <$cmd>";
};


# ---   *   ---   *   ---
# typecheck for local values

sub proc_typechk {
  my ($type,$x)=@_;
  my $have=proc_state(get=>$x);

  throw "spider: type mismatch for '$x'; "
  .     "$have->{name} != $type->{name}"

  if $type->{sizeof} != $have->{sizeof};

  return;
};


# ---   *   ---   *   ---
# handles assignment node

sub node_asg {
  my ($node,$depth)=@_;
  my ($type,$name,@expr)=rdnode($node);

  # get value type
  my $decl  =! is_null($type);
  my $scmd  =  ($decl) ? "local" : "get" ;
     $type  =  proc_state($scmd=>$type=>$name);

  # evaluate expression! \( ^ .^)/
  my @chain = ipret($type,$name,@expr);
  my $pad   = node_getpad($depth);
  return $pad . join($pad,
    gstrip(@chain),
    "local.set \$$name",
  );
};
sub asg_re {
  return qr{
    (?<type> [[:alnum:]_\s]+ \s+)?
    (?<name> [[:alnum:]_]+) \s*
    (?<op>   [^[:alnum:]_]|\s) =
    (?<expr> .*)
  }x;
};


# ---   *   ---   *   ---
# handles generic expression node

sub node_expr {
  my ($node,$depth)=@_;
  my ($type,$name,@expr)=rdnode($node,1);

  # valid type in this case means it's
  # a declaration without a value!
  if(! is_null($type)) {
    proc_state(local=>$type=>$name);
    return null;

  # fetch the current function's type
  # when encountering a return statement
  } elsif($expr[0] eq "return") {
    $type=proc_state(ret=>());
  };
  # evaluate this expression...
  my @chain=ipret(
    $type,
    null()=>join(" ",gstrip(@expr))
  );
  # ^give generated code
  my $pad=node_getpad($depth);
  return $pad . join($pad,gstrip(@chain));
};


# ---   *   ---   *   ---
# evaluates expressions from C node

sub ipret {
  my ($type,$name,@expr)=@_;
  my $strar = [];
  my $syx   = [Arstd::seq::delim()->{paren}];
  my @out   = ();
  for(@expr) {
    strtok($strar,$ARG,syx=>$syx);

    my $mem={
      dst   => [],
      strar => $strar,
    };
    opex($mem,$type,$ARG);
    push @out,(
      map {ipret_emit($ARG)}
      @{$mem->{dst}}
    );
  };
  return @out;
};


# ---   *   ---   *   ---
# ^generates code for each

sub ipret_emit {
  my ($ins)=@_;
  return (
    (map {ipret_emit($ARG)} @{$ins->{tail}}),
    (ipret_ins($ins)),
  );
};
sub ipret_ins {
  my ($ins)=@_;
  my ($type,$cmd,$args)=(
    $ins->{type},
    $ins->{cmd},
    $ins->{args},
  );
  # nop on null
  if(is_null($cmd)) {
    return null;

  # an operation from opex_tab
  } elsif(opex_rvalid($cmd)) {
    my $type_asm=type_xlate($type);
    if( (exists opex_signed()->{$cmd})
    &&  ($type_asm=~ qr{^(?:i32|i64)$}) ) {
      $cmd=(is_signed($type))
        ? "${cmd}_s"
        : "${cmd}_u"
        ;
    };
    $cmd="$type_asm.$cmd";

  # this is for "local", which doesn't use
  # the type of the value
  } elsif(exists ipret_rtyped()->{$cmd}) {
    $cmd=ipret_rtyped()->{$cmd} . ".$cmd";

  # catch invalid
  } elsif(! exists ipret_ntyped()->{$cmd}) {
    throw "spider: unrecognized command <$cmd>";
  };
  # give instruction
  return join(" ",gstrip($cmd,@$args));
};


# ---   *   ---   *   ---
# ^ROM

sub ipret_ntyped {
  return {
    map {$ARG=>1}
    qw(return call)
  };
};
sub ipret_rtyped {
  return {
    get => "local",
    set => "local",
  };
};


# ---   *   ---   *   ---
# operator expansion

sub opex {
  my ($mem,$type,$s)=@_;

  # get function calls out of the way first;
  #
  # the sub we use for this will recurse back
  # if the call itself must perform further
  # expansions
  opex_fn($mem,$type,\$s);

  # get operators in expression,
  # sorted by precedence
  my ($op,$value,$chain)=opex_sort(
    gsplit($s,opex_re())
  );
  # ^generate code from operators
  opex_inner($mem,$type,$chain,$ARG) for @$op;

  # catch unsolved values
  if(@$chain &&! is_null($chain->[0])) {
    opex_push_value($mem,$type,$chain->[0]);
  };
  return;
};


# ---   *   ---   *   ---
# expands function calls

sub opex_fn {
  my ($mem,$type,$sref)=@_;

  # this pattern detects a call;
  # NAME (...)
  my $tok_re = Arstd::seq::tok_re("scp");
  my $re     = qr{(?<cmd>[[:alnum:]_]+)\s*$tok_re};

  # for every F in string...
  my $tab=node_state()->{sym};
  while($$sref=~ s[$re][]) {
    my $cmd  = $+{cmd};
    my $idex = $+{idex};

    # validate F name
    throw "opex: undefined symbol <$cmd>"
    if!   exists $tab->{$cmd};

    # fetch arguments
    my @args=gsplit(
      scp_unpack($mem->{strar},$idex),
      qr{\s*,\s*},
    );
    my $argt=$tab->{$cmd}->{args};

    # we need to recurse in order to solve
    # the arguments...
    my $tail = [];
    my $old  = $mem->{dst};

    $mem->{dst}=$tail;
    for(0..$#args) {
      my $svalue = $args[$ARG];
      my $stype  = $argt->[$ARG]->[0];

      opex($mem,$stype,$svalue);
    };
    $mem->{dst}=$old;

    # *now* generate call
    my $stype=$tab->{$cmd}->{ret};
    opex_push(
      $mem,
      $stype,
      call=>["\$$cmd"],
      $tail,
    );
  };
  return;
};


# ---   *   ---   *   ---
# put value in stack

sub opex_push_value {
  my ($mem,$type,$x)=@_;
  my $cmd=opex_value($type,\$x);
  opex_push(
    $mem,
    $type,

    ($cmd ne $x)
      ? ($cmd=>[$x])
      : ($cmd=>[])
      ,
  );
};
sub opex_push {
  my ($mem,$type,$cmd,$args,@tail)=@_;
  my $tail=[flatten(\@tail)];

  push @{$mem->{dst}},{
    type => $type,
    cmd  => $cmd,
    args => $args // [],
    tail => $tail,
  };
};
sub opex_value {
  my ($type,$xref)=@_;
  if( ($$xref=~ qr{^[[:alnum:]_]+$})
  &&  proc_state(has=>$$xref) ) {
    proc_typechk($type,$$xref);

    $$xref=q[$] . $$xref;
    return "get";

  } elsif($$xref=~ qr{^(?:return|call)\b}) {
    return $$xref;

  } else {
    return "const";
  };
};


# ---   *   ---   *   ---
# sort operators in expression
# accto precedence

sub opex_sort {
  # get positions...
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
  my ($mem,$type,$chain,$i)=@_;

  # validate operator
  my $tab = opex_tab();
  my $s   = $chain->[$i];
  throw "opex: undefined operator '$s'"
  if!   exists $tab->{$s};

  # break it down...
  my $macro=deepcpy($tab->{$s});
  my ($lh,$rh)=($i != 0)
    ? ($chain->[$i-1],$chain->[$i+1])
    : (null,$chain->[$i+1])
    ;
  # recurse if either operand is a
  # parenthesized expression!
  my $tail = [];
  my $old  = $mem->{dst};

  $mem->{dst}=$tail;
  for($lh,$rh) {
    opex_recurse_chk($mem,$type,\$ARG);
  };
  $mem->{dst}=$old;

  # write opcode + operands
  my $unary = grep {$ARG eq $s} opex_unary();
  my $ins   = shift @$macro;
  opex_push(
    $mem,
    $type,
    $ins->{cmd},
    $ins->{args},
    (@$macro,@$tail)
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
  my ($mem,$type,$src)=@_;
  my $tok_re=Arstd::seq::tok_re("scp");

  # common values can simply be pushed
  # without further processing
  if(! ($$src=~ s[$tok_re][])) {
    opex_push_value($mem,$type,$$src);
    return;
  };
  # get string to process,
  # then expand into operation
  my $op=scp_unpack($mem->{strar},$+{idex});
  opex($mem,$type,$op);

  return;
};


# ---   *   ---   *   ---
# gets V from (V)!!

sub scp_unpack {
  my ($strar,$idex)=@_;
  my $re=  qr{^\(|\)$};
  my $op=  $strar->[$idex];
     $op=~ s[$re][]g;

  return $op;
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
    q[~]  => insar(xor  => -1),
    q[&]  => insar(and  => ()),
    q[|]  => insar(or   => ()),
    q[^]  => insar(xor  => ()),
    q[!]  => insar(eqz  => ()),

    q[<<] => insar(shl  => ()),
    q[>>] => insar(shr  => ()),
    q[<@] => insar(rotl => ()),
    q[@>] => insar(rotr => ()),

    q[*]  => insar(mul  => ()),
    q[/]  => insar(div  => ()),
    q[%]  => insar(rem  => ()),
    q[++] => insar(set  => add  => 1),
    q[+]  => insar(add  => ()),
    q[--] => insar(set  => sub  => 1),
    q[-]  => insar(sub  => ()),

    q[<]  => insar(lt   => ()),
    q[>]  => insar(gt   => ()),
    q[<=] => insar(le   => ()),
    q[>=] => insar(ge   => ()),

    q[==] => insar(eq   => ()),
    q[!=] => insar(ne   => ()),
    q[&&] => "nyi",
    q[||] => "nyi",
  };
};
sub opex_rtab {
  return {map {$ARG=>1} qw(
    ne eq eqz lt gt le ge
    mul div rem add sub
    rotr rotl shr shl
    xor or and
    const
  )};
};
sub opex_signed {
  return {
    map {$ARG=>1}
    qw(lt gt le gt div rem shr)
  };
};
sub opex_rvalid {
  return exists opex_rtab()->{$_[0]};
};


# ---   *   ---   *   ---
# generic node processing

sub rdnode {
  return rdexpr($_[0]->{cmd},$_[0]->{expr},$_[1]);
};
sub rdexpr {
  my ($cmd,$expr,$pure)=(
    $_[0] // null,
    $_[1] // null,
    $_[2] // 0,
  );
  my $have=join(" ",gstrip($cmd,$expr));
  my ($type,$name,@expr)=(null,null,());

  if(! $pure && ($have=~ asg_re())) {
    ($type,$name,@expr)=gsplit($have,asg_re());

  } else {
    @expr=gsplit($have);
    $name=pop @expr;
    $type=join(" ",gstrip(@expr));

    if($pure &&! type_valid($type)) {
      push @expr,$name;
      $type=null;
      $name=null;
    };
  };
  return ($type,$name,@expr);
};


# ---   *   ---   *   ---
# maps peso types to WASM

sub type_tab {
  return {
    q[dword]=>"i32",
    q[qword]=>"i64",

    q[sign dword]=>"i32",
    q[sign qword]=>"i64",

    null()=>null,
  };
};
sub type_xlate {
  throw  "spider: undefined type <$_[0]->{name}>"
  if!    type_valid($_[0]->{name});
  return type_tab()->{$_[0]->{name}};
};
sub type_valid {
  return exists type_tab()->{$_[0]};
};


# ---   *   ---   *   ---
# generates operation tree for
# macroinstructions
#
# for all intents and purposes,
# it can also generate trees for
# regular instructions...
#
# only difference is the resulting array
# will only have a single element!

sub insar {
  my ($x,@y)=@_;
  return [
    insar_inner($x),
    (@y ? insar(@y) : ()) ,
  ];
};
sub insar_inner {
  my ($s)=@_;
  my ($type,$name,@expr)=rdexpr($s=>"",1);
  return {
    type => $type,
    cmd  => $name,
    tail => \@expr,
  };
};


# ---   *   ---   *   ---
1; # ret
