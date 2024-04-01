#!/usr/bin/perl
# ---   *   ---   *   ---
# ASM
# Pseudo assembler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package ipret::cmdlib::asm;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match-vars);
  use lib $ENV{ARPATH}.'/lib/sys/';

  use Style;
  use Type;
  use Bpack;

  use Arstd::Bytes;
  use Arstd::IO;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'ipret::cmd';
  BEGIN {ipret::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.3;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# solve instruction arguments

cmdsub 'asm-ins' => q() => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};
  my $enc  = $main->{encoder};

  # unpack
  my $vref = $branch->{vref};
  my $name = $vref->{name};
  my $opsz = $vref->{opsz};


  # solve args
  my @args=map {

    my $nd   = $ARG->{value};
    my $key  = $nd->{value};
    my $type = $ARG->{type};

    my %O    = ();


    # have register?
    if($type eq 'r') {
      %O=(reg=>$l1->quantize($key));


    # have immediate?
    } elsif($type eq 'i') {
      $type=$ISA->immsz($O{imm});
      %O=(imm=>$l1->quantize($key));


    # have memory?
    } elsif($type eq 'm') {

      ($type,$opsz,%O)=
        $self->addrmode($branch,$nd);


    # symbol deref
    } elsif($type eq 'sym') {

      my $have=$l1->quantize($nd->{value});
      return $branch if ! length $have;

      ($type,$opsz,%O)=
        $self->addrsym($branch,$have,0);


    };


    # give descriptor
    $O{type}=$type;
    \%O;


  } @{$vref->{args}};


  # all OK? then dump code to memory
  $enc->exewrite_order(
    $branch->{-uid},
    $opsz,$name,@args

  );

  return;

};

# ---   *   ---   *   ---
# build memory operand from symbol

sub addrsym($self,$branch,$have,$deref) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};


  # have size modifier?
  my $opsz = ($branch->{vref}->{opsz_def})
    ? $have->{type}
    : $branch->{vref}->{opsz}
    ;


  # get location
  my $seg  = $have->getseg;
  my $addr = $have->{addr};


  # ^have pointer?
  if($have->{ptr_t} && $deref) {
    ($seg,$addr)=$have->read_ptr;

  };


  # give read
  my %O=(
    seg  => $mc->segid($seg),
    imm  => $addr,

  );

  return ('mimm',$opsz,%O);

};

# ---   *   ---   *   ---
# determine type of memory operand

sub addr_decompose($self,$nd) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $anima = $main->{mc}->{anima};


  # get first branch:
  #
  # [`[]
  # \-->[b0]
  # .  \-->(beg)

  my $beg = $nd->{leaves}->[0];
     $beg = $beg->{leaves}->[0];


  # get elements of address
  my @reg = ();
  my @sym = ();
  my @imm = ();
  my $stk = 0;

  map {

    my $have=undef;


    # register name?
    if(defined ($have=$l1->is_reg($ARG))) {

      $stk |= $have == $anima->stack_bot;
      push @reg,$have;

    # symbol name?
    } elsif(defined ($have=$l1->is_sym($ARG))) {
      push @sym,$l1->quantize($ARG);

    # immediate!
    } else {
      push @imm,$l1->quantize($ARG);

    };


  # ^from branch values
  } map {
    $ARG->{value}

  } map {

    my @lv=@{$ARG->{leaves}};
       @lv=$ARG if ! @lv;

    @lv;


  # ^from branch leaves, if we have a branch
  # ^else proc single leaf!
  } (int @{$beg->{leaves}})

    ? @{$beg->{leaves}}
    : $beg
    ;


  # give type lists
  return {

    sym=>\@sym,
    reg=>\@reg,
    imm=>\@imm,

    stk=>$stk,

  };

};

# ---   *   ---   *   ---
# build memory operand from
# operation tree

sub addrmode($self,$branch,$nd) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};

  # default segment to use if none specified!
  my $seg    = $mc->{scope}->{mem};
  my $ptrseg = $mc->segid($seg);

  # out
  my $type = null;
  my $opsz = $branch->{vref}->{opsz};
  my %O    = ();


  # get type lists
  my $data=$self->addr_decompose($nd);

  # have symbols?
  if(@{$data->{sym}}) {

    map {

      my ($sym_t,$sym_sz,%head)=
        addrsym($self,$branch,$ARG,1);

      $opsz   = $sym_sz;
      $ptrseg = $head{seg};

      push @{$data->{imm}},$head{imm};


    } @{$data->{sym}};

  };


  # [sb-i]
  if($data->{stk}) {
    %O=(imm=>$data->{imm}->[0]);
    $type='mstk';


  # [seg:r+i]
  } elsif(

     @{$data->{reg}} == 1
  && @{$data->{imm}} <= 1

  ) {

    $data->{imm}->[0] //= 0;

    %O=(

      seg=>$ptrseg,

      reg=>$data->{reg}->[0],
      imm=>$data->{imm}->[0],

    );

    $type='msum';


  # [seg:r+r+i*x]
  } elsif(

     @{$data->{reg}} == 2
  || @{$data->{imm}} == 2

  ) {

    $data->{reg}->[0] //= 0;
    $data->{reg}->[1] //= 0;

    $data->{imm}->[0] //= 0;
    $data->{imm}->[1] //= 0;

    %O=(

      seg   => $ptrseg,

      rX    => $data->{reg}->[0],
      rY    => $data->{reg}->[1],

      imm   => $data->{imm}->[0],
      scale => $data->{imm}->[1],

    );

    $type='mlea';


  # [seg:i]
  } else {

    $data->{imm}->[0] //= 0;

    %O=(

      seg=>$ptrseg,
      imm=>$data->{imm}->[0],

    );

    $type='mimm';

  };


  return ($type,$opsz,%O);

};

# ---   *   ---   *   ---
# sets current scope

cmdsub 'self' => q() => q{


  # can solve symbol?
  my $sym=$self->symfet($branch->{vref});
  return $branch if ! length $sym;

  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};


  # set scope
  $mc->scope($sym->{value});

  return;

};

# ---   *   ---   *   ---
# sets program counter

cmdsub 'jump' => q() => q{


  # can solve symbol?
  my $sym=$self->symfet($branch->{vref});
  return $branch if ! length $sym;


  # get ctx
  my $main  = $self->{frame}->{main};
  my $enc   = $main->{encoder};
  my $mc    = $main->{mc};
  my $anima = $mc->{anima};
  my $ISA   = $mc->{ISA};



  # get pointer and bitsize
  my $ptrv=$sym->as_ptr;
  my $type=$ISA->immsz($ptrv);

  # load to xp register!
  $enc->exewrite_order(

    $branch->{-uid},
    $ISA->align_t,

    'load',

    {type=>'r',reg=>$anima->exec_ptr},
    {type=>$type,imm=>$ptrv},

  );


  return;

};

# ---   *   ---   *   ---
1; # ret
