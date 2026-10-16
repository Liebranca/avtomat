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
  use Chk qw(is_null is_file is_hashref);
  use Type qw(typefet is_signed is_real);

  use Arstd::String qw(
    cat
    jag
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
  use Arstd::strtok qw(strtok);
  use Arstd::seq;
  use Arstd::vm qw(
    vm_new
    vm_enter
    vm_leave
    vm_var_has
    vm_sym_in
    vm_sym_out
  );
  use Arstd::ins qw(
    ins_new
    ins_signed
    ins_valid
  );
  use Arstd::ir qw(
    ctoir
    ir_prich
  );


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.00.8a";
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
  my ($clss,$src)=@_;
  my $body=(is_file($src) ? orc($src) : $src);

  # map C code to expression tree,
  # then generate IR from that
  my $vm=vm_new();
  my @ir=ctoir($vm,$body);

  # for running and previewing the IR itself
  AR::run("avto::pl",$vm,@ir);
  exit;

  # TODO
  # optimization passes to the IR should
  # be performed right here ;>

  # generate WAT code from IR
  my $out=join("\n",map {xlate($vm,$ARG)} @ir);
  return "(module\n$out\n)";
};
sub xlate {
  state $depth=-1;
  ++$depth;
  my ($vm,$ir)=@_;
  my $xlate;

  if($ir->{node_t} eq "proc") {
    $xlate=xlate_proc($vm,$ir);

  } elsif($ir->{node_t} eq "asg") {
    $xlate=xlate_asg($vm,$ir);

  } elsif( $ir->{node_t}=~
           qr{^(?:expr|null|term)$} ) {
    $xlate=xlate_expr($vm,$ir);

  } elsif($ir->{node_t} eq "fctl") {
    $xlate=xlate_fctl($vm,$ir);

  } else {
    throw "NYI: <$ir->{node_t}> node";
  };
  my $pad=("  " x $depth);
  --$depth;

  my $meta=(! is_null($ir->{meta}))
    ? "$pad;; $ir->{meta}\n"
    : ""
    ;

  $xlate=(! is_null($xlate))
    ? join("\n",map {
        ($ARG=~ qr{^\h})
          ? "$ARG"
          : "$pad$ARG"

      } split(qr"\n",$xlate))

    : ""
    ;

  return "$meta$xlate";
};
sub xlate_blk {
  return map {xlate($_[0],$ARG)} @_[1..$#_];
};


# ---   *   ---   *   ---
# translates func node

sub xlate_proc {
  my ($vm,$ir)=@_;
  my $name = $ir->{name};
  my $body = $ir->{body};
  my $flg  = $ir->{flg};

  vm_enter($vm,$name);
  my @param=map {
    "(param \$$ARG->{id} "
  . xlate_type($vm,$ARG)
  . ")";
  } vm_sym_in($vm);

  my $result="(result "
  . xlate_type($vm,vm_sym_out($vm))
  . ")";

  my $out=join("\n",
    join(" ",
      emit($vm,$ir->{ins}),
      @param,
      $result,
    ),
    xlate_blk($vm,@$body),
    emit($vm,$ir->{eins}),
  );
  if($flg->{public}) {
    $out .= qq[\n(export "$name" (func \$$name))]
  };
  vm_leave($vm);
  return $out;
};


# ---   *   ---   *   ---
# all other nodes can be treated
# as generic expressions!

sub xlate_asg {
  my ($vm,$ir)=@_;
  my $body=$ir->{body};
  my @head=emit($vm,$ir->{ins});
  my @body=xlate_blk($vm,@$body);
  my @foot=emit($vm,$ir->{eins});

  return join("\n",@head,@body,@foot);
};
sub xlate_expr {
  return xlate_asg(@_);
};
sub xlate_fctl {
  return xlate_asg(@_);
};


# ---   *   ---   *   ---
# generates code for instruction array

sub emit {
  my ($vm,$ar)=@_;
  my (@out)=();
  my $end_re=qr{
    ^(?:end\h+) \$?
     (?<name> [[:alnum:]_]+)
  }x;
  for(0..$#$ar) {
    my $cmd=emit_inner($vm,$ar->[$ARG]);
    if($cmd=~ s[$end_re][]) {
      push @out,")";

    } else {
      push @out,$cmd;
    };
  };
  return @out;
};
sub emit_inner {
  my ($vm,$ins)=@_;

  # nop on null
  if(is_null($ins->{cmd})) {
    return null;

  # map ir to wasm
  } elsif(ins_valid($ins->{cmd})) {
    return xlate_ins($vm,$ins);

  # catch invalid
  } else {
    throw "spider: unrecognized command "
    .     "<$ins->{cmd}>";
  };
};


# ---   *   ---   *   ---
# maps ir to wasm

sub xlate_ins {
  my ($vm,$ins)=@_;
  return join("\n",
    map {xlate_ins_inner($vm,$ARG)}
    xlate_ins_expand($vm,$ins)
  );
};

sub xlate_ins_inner {
  my ($vm,$ins)=@_;

  # get wasm equivalent of...
  my $type = xlate_type($vm,$ins);
  my $cmd  = xlate_cmd($ins->{cmd});

  # ^add suffix for signed/unsigned if need
  if( ins_signed($ins->{cmd})
  &&  ($type=~ qr{^(?:i32|i64)$}) ) {
    $cmd .= (is_signed($ins->{type}))
      ? "_s"
      : "_u"
      ;
  };
  # handle args...
  my $args=join(" ",xlate_args($ins->{args}));
  $cmd=(xlate_usearg($ins->{cmd}))
    ? "$cmd $args"
    : $cmd
    ;
  # OK so here is where wat is just silly:
  # * some instructions [must] `type.?cmd arg?`
  # * but others `(cmd arg type?)`
  #
  # imho its bad design, sorry /( ~ ,~)\
  # just pick _one_ syntax and stick to it
  $cmd=(xlate_rtyped($ins->{cmd}))
    ? "(" . join(" ",gstrip($cmd,$type)) . ")"
    : join(".",gstrip($type,$cmd))
    ;
  # ^furthermore,
  #
  # sometimes you can do this:
  # ```
  # cmd
  # ...
  # end
  # ```
  #
  # instead of this `(cmd ...)`
  #
  # but some other times you cannot flatten
  # the lispian sex, so you must stick
  # with the second form no matter what
  #
  # its needless; plain old silly /( ~ ,~)\
  if(xlate_sex($ins->{cmd})) {
    $cmd="($cmd";
  };
  return $cmd;
};


# ---   *   ---   *   ---
# some instructions expand to multiple,
# so we do that here

sub xlate_ins_expand {
  my ($vm,$ins)=@_;
  my $tab={
    # ~x
    not => sub {
      return (
        ins_new($ins->{type},const=>(-1)),
        ins_new($ins->{type},xor=>()),
      );
    },
    # -x
    neg => sub {
      return ($ins) if is_real($ins->{type});
      return (
        ins_new($ins->{type},const=>(0)),
        ins_new($ins->{type},sub=>()),
      );
    },
    # x != 0
    nez => sub {
      return (
        ins_new($ins->{type},const=>0),
        ins_new($ins->{type},ne=>()),
      );
    },
  };
  return (exists $tab->{$ins->{cmd}})
    ? $tab->{$ins->{cmd}}->()
    : ($ins)
    ;
};


# ---   *   ---   *   ---
# the ir uses different names for
# some instructions, so map those

sub xlate_cmd {
  return {
    proc    => "func",
    in      => "param",
    out     => "result",
    break   => "br",
    rept    => "br",
    cbreak  => "br_if",
    crept   => "br_if",
    ret     => "return",
    rcall   => "return_call",
    seep    => "tee",
    sel     => "select",
    rol     => "rotl",
    ror     => "rotr",
    skip    => "block",
    jmptab  => "br_table",

  }->{$_[0]} // $_[0];
};


# ---   *   ---   *   ---
# maps peso types to wasm

sub xlate_type {
  my ($vm,$ins)=@_;
  return null if is_null($ins->{type});

  # catch invalid
  #
  # note that not all instructions use their
  # typing data, but all of them have it
  # nonetheless; doesn't hurt to sanity check!
  throw  "spider: undefined type "
  .      "<$ins->{type}->{name}>"

  if!    xlate_type_valid($ins->{type}->{name});

  # these instructions do not require a type
  # (see above note ;>)
  if( exists $ins->{cmd}
  &&  xlate_ntyped($ins->{cmd}) ) {
    if(xlate_varins($ins->{cmd})) {
      my $n=$ins->{args}->[0];
      return (vm_var_has($vm,$n))
        ? "local"
        : "global"
        ;
    };
    return null;
  };
  # ^else *do* perform typing mambo
  my $tab  = xlate_type_tab();
  my $type = $tab->{$ins->{type}->{name}};
  my $suf  = null;


  return $type;
};
sub xlate_type_valid {
  return exists xlate_type_tab()->{$_[0]};
};


# ---   *   ---   *   ---
# mostly superfluous, as it's only
# adding a `$` to barewords...
#
# but separating this operation JIC
# there's more to it in the future

sub xlate_args {
  my ($ar)=@_;
  return () if! int(@$ar);

  return map {
    ($ARG=~ qr{^(?:[[:alpha:]_])})
      ? "\$"
      . (is_hashref($ARG) ? $ARG->{name} : $ARG)

      : $ARG
      ;
  } @$ar;
};


# ---   *   ---   *   ---
# ROM

sub xlate_type_tab {
  return {
    q[dword]=>"i32",
    q[qword]=>"i64",

    q[sign dword]=>"i32",
    q[sign qword]=>"i64",

    null() => null,
    void   => null,
  };
};
sub xlate_ntyped {
  return {map {$ARG=>1} qw(
    get set seep
    block loop end
    break rept cbreak crept
    proc ret call rcall

  )}->{$_[0]} // 0;
};
sub xlate_rtyped {
  return {map {$ARG=>1} qw(
    in out local

  )}->{$_[0]} // 0;
};
sub xlate_varins {
  return {map {$ARG=>1} qw(
    get set seep

  )}->{$_[0]} // 0;
};
sub xlate_usearg {
  return {map {$ARG=>1} qw(
    get set seep const
    in out local
    proc end
    skip loop jmptab
    break rept cbreak crept

  )}->{$_[0]} // 0;
};
sub xlate_sex {
  return {map {$ARG=>1} qw(
    clan proc

  )}->{$_[0]} // 0;
};


# ---   *   ---   *   ---
1; # ret
