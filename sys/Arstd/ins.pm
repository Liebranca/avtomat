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
  use Style qw(null nop);
  use Chk qw(is_null is_hashref);
  use Type qw(typefet typetab sizeof derefof);

  use Arstd::String qw(gstrip gsplit);
  use Arstd::Bin qw(deepcpy);
  use Arstd::vm qw(
    vm_pop
    vm_push
    vm_skip
    vm_jmp
    vm_call
    vm_label
    vm_label_str
    vm_load
    vm_store
    vm_local
  );
  use Arstd::throw;
  use Tree::C qw(asg_re);
  use Arstd::IO qw(io_procin io_procout);

  use lib "$ENV{ARPATH}/lib/";
  use AR;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter "import";
  our @EXPORT=qw(
    ins_new
    ins_map
    ins_build
    ins_fold
    ins_unfold
    ins_tab
    ins_data
    ins_valid
    ins_signed
    ins_argcnt
    ins_pushcnt
    ins_term
    ins_fctl
    ins_rdnode
    ins_rdexpr
    ins_prich
    asg_re
  );

# ---   *   ---   *   ---
# info

  my $VERSION = "v0.01.6a";
  my $AUTHOR  = "IBN-3DILA";


# ---   *   ---   *   ---
# runs through a list of instructions
# and performs standard passes on them
#
# [0]: mem ptr  ; vm ice
# [1]: mem ptr  ; fallback type
# [2]: mem pptr ; ins array
#
# [<]: mem pptr ; *new* ins array

sub ins_build {
  return map {
    my $rtype=(! is_null($ARG->{type}))
      ? $ARG->{type}
      : $_[1]
      ;
    ins_propagate_t($ARG,$rtype);
    ins_unfold(
      {vm=>$_[0]},
      $ARG,
    );

  } ins_fold(@_[2..$#_]);
};


# ---   *   ---   *   ---
# cstruc

sub ins_new {
  my ($type,$cmd,@args)=@_;
  $type="void" if is_null($type);
  return {
    type => typefet($type),
    cmd  => $cmd,
    args => [@args],
    tail => [],
  };
};
sub ins_decl {
  state $opcode=0x00;
  my ($name,%O)=@_;
  $O{signed}   //= 0;
  $O{term}     //= 0;
  $O{argcnt}   //= 2;
  $O{pushcnt}  //= 1;
  $O{collapse} //= \&nop;
  $O{expand}   //= \&nop;
  $O{execute}  //= \&nop;
  $O{cleanup}  //= \&nop;
  $O{opcode}   //= $opcode++;

  return ($name=>\%O);
};


# ---   *   ---   *   ---
# generates operation tree for
# simple macroinstructions
#
# we use this mainly to map operators
# to instructions (see: Arstd::opex)
#
# for all intents and purposes,
# it can also generate trees for
# regular instructions...
#
# only difference is the resulting array
# will only have a single element!

sub ins_map {
  my ($x,@y)=@_;
  return [
    ins_map_inner($x),
    (@y ? ins_map(@y) : ()) ,
  ];
};
sub ins_map_inner {
  my ($s)=@_;
  my ($type,$name,@expr)=ins_rdexpr($s=>"",1);
  if(ins_valid($name)) {
    my $ins=ins_new($type,$name);
       $ins->{tail}=[@expr];

    return $ins;
  };
  return $name;
};


# ---   *   ---   *   ---
# makes tree from flat instruction array

sub ins_fold {
  my @out=();
  while(@_) {
    my $ins=shift @_;
    my $cnt=ins_argcnt($ins->{cmd});

    throw "ins-fold: undef ice in stack"
    if!   defined $ins;

    my @tail=@{$ins->{tail}};
    if(! int(@tail)) {
      throw "ins-fold: missing args in stack\n"
      .     "^at " . ins_prich($ins,mute=>1)

      if    int(@out) < $cnt;

      @{$ins->{tail}}=reverse(
        map {pop @out}
        (1..$cnt)
      );
    } else {
      @{$ins->{tail}}=ins_fold(@tail);
    };
    push @out,$ins;
  };
  return @out;
};


# ---   *   ---   *   ---
# ^iv, makes tree from flattened array

sub ins_unfold {
  my ($ctx,$ins)=@_;
  $ctx->{lvl}  //= 0;
  $ctx->{stk}  //= [];

  throw "ins-unfold: undef ice in stack"
  if!   defined $ins;

  # go up one recursion level
  ins_expand($ctx,$ins);
  ++$ctx->{lvl};

  # get values used by this instruction
  my @tail=(
    map {ins_unfold($ctx,$ARG)}
    @{$ins->{tail}}
  );
  # ^back to previous level
  --$ctx->{lvl};

  # some operations become redundant after
  # recursion, and we can detect this by
  # checking that they have no operands to
  # consume anymore!
  if( ins_stkn(@tail)
  <   ins_argcnt($ins->{cmd}) ) {
    return (@tail);
  };
  # optimize away constants where possible
  ($ins,@tail)=ins_cleanup_redundant(
    $ctx,
    $ins,
    @tail
  );
  # update context stack with flattened list,
  # removing deleted elements
  my @flat=(
    grep {! is_null($ARG->{cmd})}
    (@tail,$ins)
  );
  push @{$ctx->{stk}},@flat;

  # give flattened list
  @{$ins->{tail}}=();
  return @flat;
};

# ---   *   ---   *   ---
# propagate typing data whenever missing

sub ins_propagate_t {
  my ($ins,$type)=@_;
  $ins->{type}=$type if is_null($ins->{type});

  ins_propagate_t($ARG,$type)
  for @{$ins->{tail}};

  return;
};


# ---   *   ---   *   ---
# expands macroinstructions

sub ins_expand {
  my ($ctx,$ins)=@_;
  my $fn=ins_data($ins->{cmd})->{expand};
  return if $fn eq \&nop;

  $fn->($ctx,$ins);
  return 1;
};


# ---   *   ---   *   ---
# solve label for fctl instructions

sub macro_label {
  my ($ctx,$ins)=@_;

  # jumping to/outof current block?
  if(! @{$ins->{args}}) {
    my $have=vm_label_top($ctx->{vm})
    or throw "ins: no label for $ins->{cmd}";

    push @{$ins->{args}},$have;

  # ^nope, explicit target
  } elsif(! is_hashref($ins->{args}->[0])) {
    $ins->{args}->[0]=vm_label_find(
      $ctx->{vm},
      $ins->{args}->[0],
    );
  };
  # remember whether we're looping or
  # skipping this block!
  my $label=$ins->{args}->[0];
  if($ins->{cmd}=~ qr{break$}) {
    ++$label->{skip}->{cnt};

  } elsif($ins->{cmd}=~ qr{rept$}) {
    ++$label->{loop}->{cnt};

  # ~~
  } elsif($ins->{cmd}=~ qr{^(?:if|else|skip)$}) {
    vm_label($ctx->{vm},$label,"f");

  } else {
    vm_label($ctx->{vm},$label,"b");
  };
  return;
};


# ---   *   ---   *   ---
# logic and

sub macro_land {
  my ($ctx,$ins)=@_;

  # chaining calls (`fn1() && fn2() ...`)
  # should short circuit!
  my $branchless=! int(
    grep {$ARG->{cmd} eq "call"}
    @{$ins->{tail}}
  );
  # ^ so we use a different expansion F
  #   accto that
  my $fn=($branchless)
    ? \&macro_land_branchless
    : \&macro_land_branching
    ;
  # ^apply it to each operand
  my @tail=(
    map {$fn->($ctx,$ins,$ARG)}
    @{$ins->{tail}}
  );
  # in the branching case, we need to wrap
  # the function chain in a block, so that
  # we can break out of it
  if(! $branchless) {
    if(! $ctx->{lvl}) {
      # BUT we only apply said block-wrap
      # at the topmost level of the chain
      my @cpy=map {deepcpy($ARG)} @tail;
      @tail={
        cmd  => "eqz",
        type => $ins->{type},
        args => [],
        tail => [
          {
            cmd  => "const",
            type => null,
            args => [0],
            tail => [],
          },{
            cmd  => "skip",
            type => null,
            args => [],
            tail => [],
          },
          @cpy,
        ],
      };
      $ins->{cmd}="end";

    # nested levels shouldn't do anything
    } else {
      $ins->{cmd}=null;
    };

  # in the branchless case, all we do
  # is compare
  } else {
    $ins->{cmd}="and";
  };
  # replace instructions with expanded list
  @{$ins->{tail}}=@tail;
  return;
};
sub macro_land_branchless {
  my ($ctx,$ins,$v)=@_;
  if(! ($v->{cmd}=~ qr{^(?:l?and|cbreak)$})) {
    return {
      cmd  => "nez",
      type => $v->{type},
      args => [],
      tail => [$v],
    };
  };
  return $v;
};
sub macro_land_branching {
  my ($ctx,$ins,$v)=@_;
  my $cpy=deepcpy($v);
  return {
    cmd  => "cbreak",
    args => [],
    type => $cpy->{type},
    tail => [{
      cmd  => "eqz",
      type => $cpy->{type},
      args => [],
      tail => [$cpy],
    }],
  };
};


# ---   *   ---   *   ---
# memory read/write

sub macro_ptr {
  my ($ctx,$ins)=@_;

  my @tail=@{$ins->{tail}};
  my $have=$tail[0];
  if(int(@tail) == 1) {
    if($have->{cmd} eq "set") {
      $have->{cmd}="store";

      my $value=$have->{tail}->[1];

      $value->{type}=derefof($value->{type})
      if ($have->{type} && $value->{type})
      && ($value->{type} eq $have->{type});

    } else {
      $have->{cmd}="load";
    };
  # ~~
  } else {
    $ins->{cmd}  = $have->{cmd};
    $have->{cmd} = ($have->{cmd} eq "set")
      ? "load"
      : "store"
      ;
    $have->{args}=[];
    @{$ins->{tail}}=reverse @tail;
  };
  $have->{type}=derefof($have->{type});
  return;
};


# ---   *   ---   *   ---
# pointer calc

sub macro_at {
  my ($ctx,$ins)=@_;
  my ($base,$off)=@{$ins->{tail}};

#  $ins->{tail}->[1]={
#    cmd  => "mul",
#    type => $off->{type},
#    args => [],
#    tail => [$off,{
#      cmd  => "const",
#      type => $off->{type},
#      args => [sizeof(derefof($ins->{type}))],
#      tail => [],
#    }],
#  };
  return;
};


# ---   *   ---   *   ---
# executes instructions that can
# be solved at compile-time

sub ins_collapse {
  my ($ctx,$ins,@tail)=@_;

  # all operands are constant?<
  my $total = int(@tail);
  my @need  = reverse(
    grep {$ARG}
    map  {pop @tail}
    1..ins_argcnt($ins->{cmd})
  );
  my $const=int(@need) == int(
    grep {$ARG->{cmd} eq "const"}
    @need
  );
  if($total && $const) {
    # collapse if possible
    my $v=ins_collapse_inner($ctx,$ins,@need);
    if(defined $v) {
      if($ins->{cmd}=~ qr{^(?:cbreak)$}) {
        $ins->{cmd}  = $v;

      } else {
        $ins->{cmd}  = "const";
        $ins->{args} = [int($v)];
      };
    # ^undo on fail
    } else {
      goto restore;
    };
  # in case collapsing fails, we restore
  # the operands to the stack
  } else {
    restore: push @tail,$ARG for @need;
  };
  # give mutated
  return ($ins,@tail);
};
sub ins_collapse_inner {
  my ($ctx,$ins,@tail)=@_;
  my $fn=ins_data($ins->{cmd})->{collapse};
  return ($fn ne \&nop) ? $fn->(
    $ctx->{vm},
    map {@{$ARG->{args}}} @tail
  ) : () ;
};


# ---   *   ---   *   ---
# clears redundant operations

sub ins_cleanup_redundant {
  my ($ctx,$ins,@tail)=@_;
  ($ins,@tail)=ins_collapse($ctx,$ins,@tail);

  my $fn=ins_data($ins->{cmd})->{cleanup};
  return ($fn ne \&nop)
    ? $fn->($ctx,$ins,@tail)
    : ($ins,@tail)
    ;
};


# ---   *   ---   *   ---
# cleanup method for bitwise AND

sub ins_and_cl {
  my ($ctx,$ins,@tail)=@_;

  # get the arguments for this instruction
  my @have=ins_stkargs_need(@tail);

  # checking for 1 on the result of
  # nez/eqz is redundant!
  my $rule_a=sub {
     (  ins_constchk($_[0],1)
     && ins_bool($_[1]) )

  || (  ins_constchk($_[1],1)
     && ins_bool($_[0]) );
  };
  # anything AND'ed to zero is zero!
  my $rule_b=sub {
     ins_constchk($_[0],0)
  || ins_constchk($_[1],0);
  };
  # remove redundant instructions if any
  # of the rules are met
  my $ok=0;
  if($rule_a->(@have)) {
    @have=(
      $ins,
      grep {$ARG->{cmd} eq "const"} @have
    );
    $ok=1;

  } elsif($rule_b->(@have)) {
    $ins->{cmd}="const";
    $ins->{args}->[0]=0;
    @have = @tail;
    $ok   = 1;
  };
  if($ok) {
    $ARG->{cmd}=null for @have;
  };
  # give back mutated
  return ($ins,@tail);
};


# ---   *   ---   *   ---
# get whether element is a
# constant value

sub ins_constchk {
  my $x=$_[0]->{cmd} eq "const";
  return (defined $_[1])
    ? $x && $_[0]->{args}->[0] eq $_[1]
    : $x
    ;
};


# ---   *   ---   *   ---
# get whether instruction can
# only give 0 or 1

sub ins_bool {
  return $_[0]->{cmd}=~ qr{^(?:nez|eqz)$};
};


# ---   *   ---   *   ---
# get which arguments will be left in
# the stack after executing an array
# of instructions

sub ins_stkargs {
  my (@ar)=@_;
  my @out=();
  for my $ins(@ar) {
    map {pop @out} 1..ins_argcnt($ins->{cmd});
    push @out,$ins if ins_pushcnt($ins->{cmd});
  };
  return reverse @out;
};


# ---   *   ---   *   ---
# ^ get only the arguments that will be
#   used by a given instruction

sub ins_stkargs_need {
  my ($ins,@tail)=@_;
  my @have = ins_stkargs(@tail);
  my $cnt  = ins_argcnt($ins->{cmd});
  return @have[-1..-$cnt];
};


# ---   *   ---   *   ---
# same as stkargs, but gets only the
# number of arguments

sub ins_stkn {
  my (@ar)=@_;
  my $out=0;
  for my $ins(@ar) {
    $out -= ins_argcnt($ins->{cmd});
    $out += ins_pushcnt($ins->{cmd});
  };
  return $out;
};


# ---   *   ---   *   ---
# generic node processing

sub ins_rdnode {
  return ins_rdexpr(
    $_[0]->{cmd},
    $_[0]->{expr},
    $_[1],
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
    $type  = $+{type} // null;
    $name  = $+{name};
    $name .= $+{arr} // null;
    @expr  = ($+{op},$+{expr});

    my $re=qr{\s+};
    $name=~ s[$re][]g;

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

sub ins_tab_def {
  return {
    ins_decl(not=>(
      collapse=>sub {~ $_[0]},
      execute=>sub {
        my ($x)=vm_pop($_[0]);
        return vm_push(
          $_[0],
          $x->{type},
          ~ $x->{value},
        );
      },
    )),
    ins_decl(neg=>(
      collapse=>sub {- $_[0]},
      execute=>sub {
        my ($x)=vm_pop($_[0]);
        return vm_push(
          $_[0],
          $x->{type},
          - $x->{value},
        );
      },
    )),
    ins_decl(ne=>(
      collapse=>sub {$_[0] ne $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} ne $y->{value},
        );
      },
    )),
    ins_decl(eq=>(
      collapse=>sub {$_[0] eq $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} eq $y->{value},
        );
      },
    )),
    ins_decl(eqz=>(
      argcnt=>1,
      collapse=>sub {$_[0] eq 0},
      execute=>sub {
        my ($x)=vm_pop($_[0]);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} eq 0,
        );
      },
    )),
    ins_decl(nez=>(
      argcnt=>1,
      collapse=>sub {$_[0] ne 0},
      execute=>sub {
        my ($x)=vm_pop($_[0]);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} ne 0,
        );
      },
    )),

    ins_decl(lt=>(
      signed=>1,
      collapse=>sub {$_[0] <  $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} < $y->{value},
        );
      },
    )),
    ins_decl(le=>(
      signed=>1,
      collapse=>sub {$_[0] <= $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} <= $y->{value},
        );
      },
    )),
    ins_decl(gt=>(
      signed=>1,
      collapse=>sub {$_[0] >  $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} > $y->{value},
        );
      },
    )),
    ins_decl(ge=>(
      signed=>1,
      collapse=>sub {$_[0] >= $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} >= $y->{value},
        );
      },
    )),

    ins_decl(mul=>(
      collapse=>sub {$_[0] *  $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} * $y->{value},
        );
      },
    )),
    ins_decl(div=>(
      signed=>1,
      collapse=>sub {$_[0] /  $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} / $y->{value},
        );
      },
    )),
    ins_decl(rem=>(
      signed=>1,
      collapse=>sub {$_[0] %  $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} % $y->{value},
        );
      },
    )),
    ins_decl(add=>(
      collapse=>sub {$_[0] +  $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} + $y->{value},
        );
      },
    )),
    ins_decl(sub=>(
      collapse=>sub {$_[0] -  $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} - $y->{value},
        );
      },
    )),

    ins_decl(ror=>()),
    ins_decl(rol=>()),
    ins_decl(shr=>(
      collapse=>sub {$_[0] >> $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} >> $y->{value},
        );
      },
    )),
    ins_decl(shl=>(
      signed=>1,
      collapse=>sub {$_[0] << $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} << $y->{value},
        );
      },
    )),
    ins_decl(xor=>(
      collapse=>sub {$_[0] ^  $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} ^ $y->{value},
        );
      },
    )),
    ins_decl(or=>(
      collapse=>sub {$_[0] |  $_[1]},
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} | $y->{value},
        );
      },
    )),
    ins_decl(and=>(
      collapse=>sub {$_[0] &  $_[1]},
      cleanup=>\&ins_and_cl,
      execute=>sub {
        my ($x,$y)=vm_pop($_[0],2);
        return vm_push(
          $_[0],
          $x->{type},
          $x->{value} & $y->{value},
        );
      },
    )),

    ins_decl(lor=>(
      collapse=>sub {$_[0] || $_[1]},
    )),
    ins_decl(land=>(
      collapse=>sub {$_[0] && $_[1]},
      expand=>\&macro_land,
    )),

    ins_decl(const=>(
      argcnt=>0,
      execute=>sub {
        return vm_push(
          $_[0],
          $_[1]->{type},
          $_[1]->{args}->[0]
        );
      },
    )),
    ins_decl(get=>(
      argcnt=>0,
      execute=>sub {
        return vm_load(
          $_[0],
          $_[1]->{args}->[0]
        );
      },
    )),
    ins_decl(set=>(
      argcnt=>1,
      term=>1,
      pushcnt=>0,
      execute=>sub {
        return vm_store(
          $_[0],
          $_[1]->{args}->[0]
        );
      },
    )),
    ins_decl(seep=>(
      argcnt=>1,
      term=>1,
      execute=>sub {
        return vm_store(
          $_[0],
          $_[1]->{args}->[0],
          keep=>1,
        );
      },
    )),
    ins_decl(sel=>(
      collapse=>sub {$_[2] ? $_[0] : $_[1]},
      argcnt=>3,
      execute=>sub {
        my ($x,$y,$c)=vm_pop($_[0],3);
        return ($c ? $x : $y);
      },
    )),

    ins_decl(load=>(argcnt=>1)),
    ins_decl(store=>(argcnt=>2,term=>1,pushcnt=>0)),

    ins_decl(proc=>(argcnt=>0,pushcnt=>0)),
    ins_decl(in=>(argcnt=>0,pushcnt=>0)),
    ins_decl(out=>(argcnt=>0,pushcnt=>0)),
    ins_decl(local=>(
      argcnt=>0,
      pushcnt=>0,
      execute=>sub {
        return vm_local(
          $_[0],
          $_[1]->{type}->{name},
          $_[1]->{args}->[0],
        );
      },
    )),

    ins_decl(if=>(
      argcnt=>1,
      pushcnt=>0,
      fctl=>1,
      term=>1,
      expand=>\&macro_label,
      execute=>sub {
        my ($x)=vm_pop($_[0]);
        my $label=$_[1]->{args}->[0];
        return (! $x->{value})
          ? vm_jmp($_[0],$label,"f")
          : ()
          ;
      },
    )),
    ins_decl(else=>(
      argcnt=>0,
      pushcnt=>0,
      fctl=>1,
      term=>1,
      expand=>\&macro_label,
      execute=>sub {
        my $label=$_[1]->{args}->[0];
        return vm_jmp($_[0],$label,"f");
      },
    )),
    ins_decl(skip=>(
      argcnt=>0,
      pushcnt=>0,
      fctl=>1,
      term=>1,
      expand=>\&macro_label,
    )),
    ins_decl(loop=>(
      argcnt=>0,
      pushcnt=>0,
      fctl=>1,
      term=>1,
      expand=>\&macro_label,
    )),
    ins_decl(rept=>(
      argcnt=>0,
      pushcnt=>0,
      fctl=>1,
      expand=>\&macro_label,
      execute=>sub {
        my $label=$_[1]->{args}->[0];
        return vm_jmp($_[0],$label,"b");
      },
    )),
    ins_decl(break=>(
      argcnt=>0,
      pushcnt=>0,
      fctl=>1,
      expand=>\&macro_label,
      execute=>sub {
        my $label=$_[1]->{args}->[0];
        return vm_jmp($_[0],$label,"f");
      },
    )),
    ins_decl(crept=>(
      argcnt=>1,
      pushcnt=>0,
      fctl=>1,
      expand=>\&macro_label,
      collapse=>sub {
        ($_[1] == 0 ? null : "rept")
      },
      execute=>sub {
        my ($x)=vm_pop($_[0]);
        my $label=$_[1]->{args}->[0];
        return ($x->{value})
          ? vm_jmp($_[0],$label,"b")
          : ()
          ;
      },
    )),
    ins_decl(cbreak=>(
      argcnt=>1,
      pushcnt=>0,
      fctl=>1,
      expand=>\&macro_label,
      collapse=>sub {
        ($_[1] == 0 ? null : "break")
      },
      execute=>sub {
        my ($x)=vm_pop($_[0]);
        my $label=$_[1]->{args}->[0];
        return ($x->{value})
          ? vm_jmp($_[0],$label,"f")
          : ()
          ;
      },
    )),
    ins_decl(jmptab=>(
      argcnt=>0,
      pushcnt=>0,
      execute=>sub {
        my ($x)=vm_pop($_[0]);
        my $ar=$_[1]->{args};
        my $i=$x->{value};
           $i=$#$ar if $i < 0 || $i > $#$ar-1;

        return vm_jmp($_[0],$ar->[$i],"f");
      },
    )),
    ins_decl(call=>(
      argcnt=>0,
      pushcnt=>1,
      execute=>sub {
        my ($fn)=$_[1]->{args}->[0];
        return vm_call($_[0],$fn);
      },
    )),

    ins_decl(drop=>(argcnt=>1,pushcnt=>0)),
    ins_decl(ret=>(argcnt=>0,pushcnt=>0,term=>1)),
    ins_decl(end=>(argcnt=>0,pushcnt=>0)),

    ins_decl(at=>(
      expand=>\&macro_at,
    )),
    ins_decl(ptr=>(
      argcnt=>1,
      expand=>\&macro_ptr,
    )),
  };
};
sub ins_tab {
  state $out=ins_tab_def();
  return $out;
};
sub ins_valid {
  return exists ins_tab()->{$_[0]};
};
sub ins_data {
  return ins_tab()->{$_[0]};
};
sub ins_signed {
  return ins_tab()->{$_[0]}->{signed};
};
sub ins_argcnt {
  return ins_tab()->{$_[0]}->{argcnt};
};
sub ins_pushcnt {
  return ins_tab()->{$_[0]}->{pushcnt};
};
sub ins_term {
  return ins_tab()->{$_[0]}->{term};
};
sub ins_fctl {
  return ins_tab()->{$_[0]}->{fctl};
};


# ---   *   ---   *   ---
# dbout

sub ins_prich {
  my ($ins,%O)=@_;
  $O{dr}   //= undef;
  $O{type} //= 1;

  my $out=io_procin(\%O);

  if(defined $O{dr}
  && $ins->{cmd}=~ qr{^(?:end|else)$}) {
    --${$O{dr}};
  };
  my $type=($ins->{type})
    ? $ins->{type}->{name}
    : "void"
    ;
  $type=($type ne "void")
    ? sprintf("%-7s",$type)
    : null
    ;
  my $pad=(defined $O{dr})
    ? "  " x ${$O{dr}}
    : null
    ;
  $pad=($O{type} &&! is_null($type))
    ? "$pad$type "
    : "$pad"
    ;
  my $args=join(",",(
    map {(is_hashref($ARG))
      ? vm_label_str({},$ARG)
      : $ARG
      ;
    } @{$ins->{args}}
  ));
  my $outs=sprintf("$pad%-7s $args",$ins->{cmd});

  my $re=qr{\h+$};
  $outs=~ s[$re][];

  if(defined $O{dr}
  && $ins->{cmd}=~ qr{^(?:if|loop|skip|else|proc)$}) {
    ++${$O{dr}};
  };
  push @$out,"$outs\n";
  return io_procout(\%O);
};


# ---   *   ---   *   ---
1; # ret
