#!/usr/bin/perl
# ---   *   ---   *   ---
# AVTO PL
# decompiles ir to perl /YES
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package avto::pl;
  use v5.42.0;
  use strict;
  use warnings;

  use English qw($ARG);
  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null);
  use Type qw(typefet);

  use Arstd::String qw(cat);
  use Arstd::ins qw(
    ins_argcnt
    ins_pushcnt
    ins_term
    ins_fctl
  );
  use Arstd::ir qw(ir_flat ir_prich);
  use Arstd::opex qw(opex_undo);
  use Arstd::vm qw(
    vm_call
    vm_prog
    vm_push
    vm_label_find
  );
  use Arstd::throw;


# ---   *   ---   *   ---
# ~~

sub import {
  my ($class,$vm,@ir)=@_;
  my $ctx={};

ir_prich($ARG) for(@ir);
vm_prog($vm,\@ir);
vm_push($vm,typefet("dword")=>3);
my $entry=vm_label_find($vm,"test");
map {
  say "$ARG->{type}->{name} [$ARG->{value}]";

} vm_call($vm,$entry,\@ir);
exit;
  return join("\n",map {xlate($ctx,$ARG)} @ir);
};


# ---   *   ---   *   ---
# ~~

sub xlate {
  my ($ctx,$ir)=@_;
  $ctx=(int(%{$ir->{ctx}}))
    ? $ir->{ctx}
    : $ctx
    ;
  $ctx->{-inptr} //= 0;
  $ctx->{-mmap}  //= {};
  $ctx->{-imap}  //= {};
  $ctx->{-stk}   //= [];
  return join(getpad($ir),
    null,
    "# $ir->{meta}",
    xlate_ir($ctx,$ir)
  );
};
sub xlate_blk {
  my $ctx=shift;
  return cat(map {xlate($ctx,$ARG)} @_);
};
sub xlate_ir {
  my ($ctx,$ir)=@_;
  my @head=emit($ctx,$ir->{ins});
  my @body=xlate_blk($ctx,@{$ir->{body}});
  my @foot=emit($ctx,$ir->{eins});

  return join(getpad($ir),@head,@body,@foot);
};
sub getpad {
  my $depth=$_[0]->{depth};
  return "\n" . ("  " x $depth);
};


# ---   *   ---   *   ---
# ~~

sub emit {
  my ($ctx,$ar)=@_;
  my $ptr  = \$ctx->{-inptr};
  my $mmap =  $ctx->{-mmap};
  my $imap =  $ctx->{-imap};

  my @out;

  for my $ins(@$ar) {
    my $type=$ins->{type};
    my @args=@{$ins->{args}};

    # ~~
    if($ins->{cmd} eq "proc") {
      push @out,"sub @args {";

    } elsif($ins->{cmd} eq "in") {
      my $name=$args[0];
      $imap->{$name}="\$_[$$ptr]";
      ++$$ptr;

    } elsif($ins->{cmd} eq "local") {
      my $name=$args[0];
      $imap->{$name}="\$$name";
      push @out,"my $imap->{$name};";

    } elsif($ins->{cmd} eq "end") {
      push @out,"};";

    } else {
      push @out,stkex($ctx,$ins);
    };
  };
  return @out;
};


# ---   *   ---   *   ---
# ~~

sub stkex {
  my ($ctx,$ins)=@_;
  my $stk  = $ctx->{-stk};
  my $mmap = $ctx->{-mmap};
  my $imap = $ctx->{-imap};

  # get instruction data
  my $term=ins_term($ins->{cmd});
  my $fctl=ins_fctl($ins->{cmd});
  my $take=ins_argcnt($ins->{cmd});
  my $give=ins_pushcnt($ins->{cmd});
  my $seep=$ins->{cmd} eq "seep";
  my @args=@{$ins->{args}};
  my $is_value=($give &&! $take);

  # ~~
  my $v   = imap($ctx,@args) // null;
  my $out = null;

  # ~~
  @args=map {pop @$stk} 0..$take-1;
  if($seep) {
    push @args,pop @$stk,$v;
    push @$stk,$v;
    $give=0;

  } elsif($ins->{cmd} eq "set") {
    push @args,$v;

  } elsif($ins->{cmd} eq "ret") {
    push @args,pop @$stk;
  };
  # ~~
  if(! $is_value || $seep) {
    $out=opex_undo(
      $ins->{cmd},
      reverse @args

    ) // xlate_cmd($ins->{cmd},@args);
    if($fctl &&! is_null($v)) {
      $out="$v: $out";
    };

  # ~~
  } else {
    $out=$v;
  };
  # ~~
  push @$stk,$out if $give;
  if($term) {
    $out .= ($fctl ? " {" : ";");
    return $out;
  };
  return ();
};
sub stksolve {
  return null;
};


# ---   *   ---   *   ---
# ~~

sub imap {
  return if is_null($_[1]);
  return (exists $_[0]->{-imap}->{$_[1]})
    ? $_[0]->{-imap}->{$_[1]}
    : $_[1]
    ;
};


# ---   *   ---   *   ---
# ROM

sub xlate_cmd {
  my ($cmd,@args)=@_;
  my $tab={
    proc    => "sub",
    loop    => "while",
    if      => "if",
    skip    => null,
    break   => "last",
    rept    => "next",
    cbreak  => "last if",
    crept   => "next if",
    ret     => "return",
  };
  return if! exists $tab->{$cmd};

  my $fn=$tab->{$cmd};
  return (int(@args) &&! is_null($fn))
    ? "$fn(" . join(",",@args) . ")"
    : $fn
    ;
};


# ---   *   ---   *   ---
1; # ret
