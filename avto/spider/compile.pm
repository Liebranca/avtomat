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
  use Type qw(typefet is_signed);

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
  use Arstd::ins qw(
    ins_signed
    ins_valid
  );
  use Arstd::ir qw(
    ir_new
    ir_prich
  );
  use Tree::C;


# ---   *   ---   *   ---
# info

  my $VERSION = "v0.00.3a";
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

  # map C code to expression tree,
  # then generate IR from that
  my $tree = Tree::C->rd($body);
  my @ir   = map {ir_new($ARG)} $tree->to_expr();

  # TODO
  # optimization passes to the IR should
  # be performed right here ;>

  # generate WAT code from IR
  my $ctx={};
  my $out=join("\n",map {xlate($ctx,$ARG)} @ir);

  say $out;
  exit;
  return "(module\n$out\n)";
};
sub xlate {
  my ($ctx,$ir)=@_;
  my $xlate;
  if($ir->{node_t} eq "proc") {
    $xlate=xlate_proc($ctx,$ir);

  } elsif($ir->{node_t} eq "asg") {
    $xlate=xlate_asg($ctx,$ir);

  } elsif($ir->{node_t} eq "expr") {
    $xlate=xlate_expr($ctx,$ir);

  } elsif($ir->{node_t} eq "fctl") {
    $xlate=xlate_fctl($ctx,$ir);

  } else {
    throw "NYI: <$ir->{node_t}> node";
  };
  my $pad=getpad($ir);
  return "$pad;; $ir->{meta}$pad$xlate";
};
sub blk_xlate {
  my $ctx=shift;
  return cat(map {xlate($ctx,$ARG)} @_);
};


# ---   *   ---   *   ---
# ~~

sub getpad {
  my $depth=$_[0]->{depth};
  return "\n" . ("  " x $depth);
};


# ---   *   ---   *   ---
# translates func node

sub xlate_proc {
  # get ctx
  my ($ctx,$ir)=@_;
  my $name = $ir->{name};
  my $body = $ir->{body};
  my $flg  = $ir->{flg};

  # emit code
#  if($flg->{public}) {
#    push @foot,"(export \"$name\" (func \$$name))";
#  };
  my $pad=getpad($ir);
  return join($pad,xlate_expr($ir->{ctx},$ir));
};


# ---   *   ---   *   ---
# all other nodes can be treated
# as generic expressions!

sub xlate_asg {
  my ($ctx,$ir)=@_;
  my $body=$ir->{body};
  my @head=emit($ctx,$ir->{ins});
  my @body=blk_xlate($ctx,@$body);
  my @foot=emit($ctx,$ir->{eins});

  my $sex=shift @head;
  push @foot,")" if $sex;

  $sex=shift @foot;
  push @foot,")" if $sex;

  return join(getpad($ir),@head,@body,@foot);
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
  my ($ctx,$ar)=@_;
  my (@out)=(0);

  for(0..$#$ar) {
    my ($sex,$cmd)=emit_inner($ctx,$ar->[$ARG]);
    if($sex &&! $ARG) {
      $out[0]=1;

    } elsif($sex && $ARG) {
      throw "spider: opened s-expression "
      .     "in the middle of an IR chain";
    };
    push @out,$cmd;
  };
  return @out;
};
sub emit_inner {
  my ($ctx,$ins)=@_;

  # nop on null
  if(is_null($ins->{cmd})) {
    return null;

  # map ir to wasm
  } elsif(ins_valid($ins->{cmd})) {
    return xlate_ins($ctx,$ins);

  # catch invalid
  } else {
    throw "spider: unrecognized command "
    .     "<$ins->{cmd}>";
  };
};


# ---   *   ---   *   ---
# maps ir to wasm

sub xlate_ins {
  my ($ctx,$ins)=@_;

  # get wasm equivalent of...
  my $type = xlate_type($ctx,$ins);
  my $cmd  = xlate_cmd($ins->{cmd});

  # ^add suffix for signed/unsigned if need
  if( (exists ins_signed()->{$ins->{cmd}})
  &&  ($type=~ qr{^(?:i32|i64)$}) ) {
    $cmd .= (is_signed($ins->{type}))
      ? "_s"
      : "_u"
      ;
  };
  # handle args...
  my $args=xlate_args($ins->{args});
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
  my $sex=0;
  if(xlate_sex($ins->{cmd})) {
    $sex=1;
    $cmd="($cmd";
  };
  return ($sex,$cmd);
};


# ---   *   ---   *   ---
# ^ the ir uses different names for
#   some instructions, so map those

sub xlate_cmd {
  return {
    proc   => "func",
    in     => "param",
    out    => "result",
    break  => "br",
    rept   => "br",
    cbreak => "br_if",
    crept  => "br_if",
    ret    => "return",
    seep   => "tee",

  }->{$_[0]} // $_[0];
};


# ---   *   ---   *   ---
# maps peso types to wasm

sub xlate_type {
  my ($ctx,$ins)=@_;
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
  if(xlate_ntyped($ins->{cmd})) {
    if(xlate_varins($ins->{cmd})) {
      my $n=$ins->{args}->[0];
      return (exists $ctx->{$n})
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
  return null if! int(@$ar);

  return ($ar->[0]=~ qr{^(?:[[:alpha:]_])})
    ? "\$$ar->[0]"
    : $ar->[0]
    ;
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
    proc ret call

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
    proc

  )}->{$_[0]} // 0;
};
sub xlate_sex {
  return {map {$ARG=>1} qw(
    clan proc

  )}->{$_[0]} // 0;
};


# ---   *   ---   *   ---
1; # ret
