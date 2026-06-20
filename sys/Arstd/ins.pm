#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD INS
# execute me
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::ins;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Type qw(typetab);

  use Arstd::String qw(gstrip gsplit);


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT=qw(
    ins_new
    ins_unfold
    ins_tab
    ins_valid
    ins_signed
    ins_argcnt
    ins_pushcnt
    ins_rdnode
    ins_rdexpr
    ins_prich
  );

# ---   *   ---   *   ---
# info

  my $VERSION = "v0.00.2a";
  my $AUTHOR  = "IBN-3DILA";


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

sub ins_new {
  my ($x,@y)=@_;
  return [
    ins_new_inner($x),
    (@y ? ins_new(@y) : ()) ,
  ];
};
sub ins_new_inner {
  my ($s)=@_;
  my ($type,$name,@expr)=ins_rdexpr($s=>"",1);
  if(ins_valid($name)) {
    return {
      type => $type,
      cmd  => $name,
      tail => \@expr,
    };
  };
  return $name;
};


# ---   *   ---   *   ---
# turns a tree of instructions into
# a flattened array

sub ins_unfold {
  my ($rtype,$ins)=@_;
  my @tail=(
    map {ins_unfold($rtype,$ARG)}
    @{$ins->{tail}}
  );
  $ins->{type} //= $rtype;
  delete $ins->{tail};

  return (@tail,$ins);
};


# ---   *   ---   *   ---
# generic node processing

sub ins_rdnode {
  return ins_rdexpr(
    $_[0]->{cmd},
    $_[0]->{expr},$_[1]
  );
};
sub ins_rdexpr {
  my ($cmd,$expr,$pure)=(
    $_[0] // null,
    $_[1] // null,
    $_[2] // 0,
  );
  my $have=join(" ",gstrip($cmd,$expr));
  my ($type,$name,@expr)=(null,null,());

  if(! $pure && ($have=~ asg_re())) {
       $type = $+{type} // null;
       $name = $+{name};
       @expr = ($+{op},$+{expr});

  } else {
    @expr=gsplit($have);
    $name=pop @expr;
    $type=join(" ",gstrip(@expr));

    if( ($pure)
    &&! (is_null($type))
    &&! (exists typetab()->{$type}) ) {
      push @expr,$name;
      $type=null;
      $name=null;
    };
  };
  return ($type,$name,@expr);
};


# ---   *   ---   *   ---
# ROM

sub ins_tab {
  return {map {$ARG=>1} qw(
    ne eq eqz lt gt le ge
    mul div rem add sub
    ror rol shr shl
    xor or and
    const set get seep
    proc in out local
    block loop
    rept break crept cbreak
    ret end
  )};
};
sub ins_valid {
  return exists ins_tab()->{$_[0]};
};
sub ins_signed {
  return {map {$ARG=>1} qw(
    lt gt le gt
    div rem shr
  )};
};
sub ins_argcnt {
  return {
    proc    => 0,
    in      => 0,
    out     => 0,
    local   => 0,
    block   => 0,
    loop    => 0,
    break   => 0,
    cbreak  => 1,
    rept    => 0,
    crept   => 1,
    end     => 0,
    ret     => 0,
    const   => 0,
    get     => 0,
    seep    => 0,
    set     => 1,
    eqz     => 1,

  }->{$_[0]} // 2;
};
sub ins_pushcnt {
  return {
    proc    => 0,
    in      => 0,
    out     => 0,
    local   => 0,
    block   => 0,
    loop    => 0,
    break   => 0,
    cbreak  => 0,
    rept    => 0,
    crept   => 0,
    end     => 0,
    ret     => 0,
    set     => 0,

  }->{$_[0]} // 1;
};
sub asg_re {
  return qr{
    (?<type> [[:alnum:]_\s]+ \s+)?
    (?<name> [[:alnum:]_]+) \s*
    (?<op>   [^[:alnum:]_!=\s]?=) \s*
    (?<expr> .*)
  }x;
};


# ---   *   ---   *   ---
# dbout

sub ins_prich {
  my ($ins,%O)=@_;
  $O{pad}  //= "";
  $O{type} //= 1;

  my $type=($ins->{type})
    ? $ins->{type}->{name}
    : "void"
    ;
  $O{pad}=($O{type})
    ? "$O{pad}$type "
    : "$O{pad}"
    ;
  my $args=join(",",@{$ins->{args}});
  say "$O{pad}$ins->{cmd} $args";

  return;
};


# ---   *   ---   *   ---
1; # ret
