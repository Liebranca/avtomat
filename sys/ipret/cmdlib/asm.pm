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
  use Chk;
  use Type;
  use Bpack;

  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::IO;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'ipret::cmd';
  BEGIN {ipret::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.01.4;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# offset within current segment

sub current_byte($self,$branch) {

  my $main = $self->{frame}->{main};
  $branch->{vref}=$main->cpos;

  return;

};

# ---   *   ---   *   ---
# a label with extra steps

sub blk($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};
  my $enc  = $main->{encoder};

  my $ISA  = $mc->{ISA};
  my $top  = $mc->{segtop};

  # get name of symbol
  my $name=$l1->untag(
    $branch->{vref}->{id}

  )->{spec};

  my $full="$name";


  # make fake ptr
  my $align_t=$ISA->align_t;
  $mc->{cas}->brkfit($align_t->{sizeof});

  my $ptr=$mc->{cas}->lvalue(

    0x00,

    type  => $align_t,
    label => $full,

  );

  $ptr->{ptr_t}      = $align_t;
  $ptr->{addr}       = $mc->{cas}->{ptr};
  $ptr->{chan}       = $top->{iced};

  $mc->{cas}->{ptr} += $align_t->{sizeof};


  # add reference to current segment!
  my $alt=$top->{inner};
  $alt->force_set($ptr,$name);

  $alt->{'*fetch'}->{mem}=$ptr;


  # ^schedule for update ;>
  my $fn=(ref $main) . '::cpos';
     $fn=\&$fn;

  $enc->binreq(

    $branch,[

      $align_t,

      'data-decl',

      { id        => [$name,$top->ances_list],

        type      => 'sym-decl',

        data      => $fn,
        data_args => [$main],

      },

    ],

  );

  return;

};

# ---   *   ---   *   ---
# defines entry point

sub entry($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};
  my $sep  = $mc->{pathsep};

  # get name of symbol
  my $name=$l1->untag(
    $branch->{vref}->{id}

  )->{spec};


  # ^as a path!
  my @path=split $sep,$name;

  # can fetch symbol?
  my $seg=$mc->ssearch(@path);
  return $branch if ! length $seg;


  # validate, set and give
  $main->perr(
    "redeclaration of entry point"

  ) if defined $main->{entry};

  $main->{entry}=\@path;


  return;

};

# ---   *   ---   *   ---
# solve instruction arguments

sub argsolve($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};
  my $lib  = $main->{cmdlib};


  # unpack
  my $vref = $branch->{vref};
  my $name = $vref->{name};
  my $opsz = $vref->{opsz};


  # walk operands
  my @args=map {

    my $nd   = $ARG->{id};
    my $key  = $nd->{value};
    my $type = $ARG->{type};

    my $O    = {};

    # have register?
    if($type eq 'r') {
      $O->{reg}  = $l1->quantize($key);
      $O->{type} = 'r';


    # have immediate?
    } elsif($type eq 'i') {


      # command dereference
      if(my $have=$l1->typechk(CMD=>$key)) {


        # TODO: move this bit somewhere else!
        my $cmd=$lib->fetch($have);
        $cmd->{fn}->($self,$nd);


        # delay value deref until encoding
        $O->{imm}=sub ($x) {
          ${$x->{vref}}

        };

        $O->{imm_args}=[$nd];

        $O->{type}=sub ($x,$y) {
          $x->immsz(${$y->{vref}})

        };

        $O->{type_args}=[$ISA,$nd];


      # regular immediate ;>
      } else {
        $O->{imm}  = $l1->quantize($key);
        $O->{type} = $ISA->immsz($O->{imm});

      };


    # have memory?
    } elsif($type eq 'm') {
      $O=$self->addrmode($branch,$nd);
      return null if ! length $O;


    # have symbol?
    } elsif($type eq 'sym') {
      $O=$self->symsolve($branch,$ARG,0);
      return null if ! length $O;


    };


    # give descriptor
    $O;


  } @{$vref->{args}};


  # overwrite default type?
  my $nc_name =  $name;
     $nc_name =~ s[^c(jump|load)][$1];

  my $def=$vref->{opsz_def};
  my $fix=$ISA->get_ins_fix_size($nc_name);

  if(defined $fix) {

    if($def) {
      $opsz=$fix->[0];

    } else {

      my $have=array_iof $fix,$opsz->{name};

      $main->perr(

        "[ctl]:%s [good]:%s: "
      . "invalid size for instruction",

        args => [$name,$opsz->{name}],

      ) if ! defined $have;

    };

  };


  # give descriptor
  return ($opsz,$name,@args);

};

# ---   *   ---   *   ---
# generic instruction

sub asm_ins($self,$branch) {

  # get ctx
  my $main = $self->{frame}->{main};
  my $enc  = $main->{encoder};
  my $ISA  = $main->{mc}->{ISA};

  # can solve arguments?
  my ($opsz,$name,@args)=
    $self->argsolve($branch);

  return $branch
  if ! length $opsz;


  # all OK, request and give
  $enc->binreq(
    $branch,[$opsz,$name,@args],

  );

  return $ISA->ins_ipret($main,$name,@args);

};

# ---   *   ---   *   ---
# determine type of memory operand

sub addr_decompose($self,$nd) {


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $anima = $main->{mc}->{anima};
  my $eng   = $main->{engine};


  # get first branch:
  #
  # [`[]
  # \-->[b0]
  # .  \-->(beg)

  my $beg = $nd->{leaves}->[0];
     $beg = $beg->{leaves}->[0];


  # solve const ops
  $eng->branch_collapse(

    $beg,

    noreg=>1,
    noram=>1,

  );


  # get elements of address
  my @reg = ();
  my @sym = ();
  my @imm = ();
  my $stk = 0;

  map {

    my $have=undef;


    # register name?
    if($have=$l1->typechk(REG=>$ARG)) {

      $stk |= $have == $anima->stack_base;
      push @reg,$have;

    # symbol name?
    } elsif($have=$l1->typechk(SYM=>$ARG)) {
      push @sym,{type=>'sym',id=>$ARG};

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


  # get type lists
  my $data=$self->addr_decompose($nd);
  return null if ! length $data;


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};

  # out
  my $type      = null;
  my $opsz      = $branch->{vref}->{opsz};
  my $opsz_args = [];
  my $O         = {};


  # have symbol?
  if(defined $data->{sym}->[0]) {


    # skip if can't solve!
    my $head=$self->symsolve(
      $branch,$data->{sym}->[0],1

    );

    return null if ! length $head;


    # ^overwrite operation size
    $opsz      = $head->{opsz};
    $opsz_args = $head->{opsz_args};


    # delayed deref+sum?
    if(defined $data->{imm}->[0]) {

      my $have=$data->{imm}->[0];

      $data->{imm}->[0]=sub ($x,$y) {

        my ($isref_z,$z)=
          Chk::cderef $have,1,@{$y->{imm_args}};

        return $z + $y->{imm}->();

      };

      $O->{imm_args}=[$have,$head];


    # ^as-is
    } else {
      $data->{imm}->[0] = $head->{imm};
      $O->{imm_args}    = $head->{imm_args};

    };

  };


  # [sb-i]
  if($data->{stk}) {

    $data->{imm}->[0] //= 0;

    $O->{imm}  = $data->{imm}->[0];
    $O->{type} = 'mstk';


  # [seg:r+i]
  } elsif(

     @{$data->{reg}} == 1
  && @{$data->{imm}} <= 1

  ) {

    $data->{imm}->[0] //= 0;

    $O->{reg}  = $data->{reg}->[0];
    $O->{imm}  = $data->{imm}->[0];

    $O->{type} = 'msum';


  # [seg:r+r+i*x]
  } elsif(

     @{$data->{reg}} == 2
  || @{$data->{imm}} == 2

  ) {

    $data->{reg}->[0] //= 0;
    $data->{reg}->[1] //= 0;

    $data->{imm}->[0] //= 0;
    $data->{imm}->[1] //= 0;


    $O->{rX}    = $data->{reg}->[0];
    $O->{rY}    = $data->{reg}->[1];

    $O->{imm}   = $data->{imm}->[0];
    $O->{scale} = $data->{imm}->[1];

    $O->{type}  = 'mlea';


  # [seg:i]
  } else {

    $data->{imm}->[0] //= 0;

    $O->{imm}  = $data->{imm}->[0];
    $O->{type} = 'mimm';

  };


  # give descriptor
  $O->{opsz}      = $opsz;
  $O->{opsz_args} = $opsz_args;

  return $O;

};

# ---   *   ---   *   ---
# delayed dereference ;>

sub symsolve($self,$branch,$vref,$deref) {


  # can solve destination?
  my $dst=$self->argproc($vref);
  return null if ! length $dst;


  # get ctx
  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};
  my $ISA   = $mc->{ISA};


  # out
  my $O={
    imm      => \&symsolve_addr,
    imm_args => [$dst,$deref],

  };


  # using default size?
  if($branch->{vref}->{opsz_def}) {
    $O->{opsz}      = \&symsolve_opsz;
    $O->{opsz_args} = [$dst,$deref];

  # have size modifier!
  } else {
    $O->{opsz}      = $branch->{vref}->{opsz};
    $O->{opsz_args} = [];

  };


  # get *minimum* required size ;>
  $O->{type}      = \&symsolve_min;
  $O->{type_args} = [$ISA,$dst,$deref];

  return $O;

};

# ---   *   ---   *   ---
# ^get address of symbol

sub symsolve_addr($dst,$deref) {

  if(! $deref && defined $dst->{type}) {
    my ($seg,$off)=$dst->read_ptr();
    return $off+$seg->update_absloc();

  } else {

    $dst=$dst->{route}
    if $dst->{route};

    return $dst->update_absloc();

  };

};

# ---   *   ---   *   ---
# ^get operation size for symbol

sub symsolve_opsz($dst,$deref) {

  my $opsz=undef;

  if(exists $dst->{type}) {

    $opsz=($deref)
      ? $dst->{type}
      : $dst->{ptr_t}
      ;

  } else {

    $dst=$dst->{route}
    if $dst->{route};

    $opsz=Type->ptr_by_size($dst->absloc);

  };

  $opsz //= typefet 'ptr';
  return $opsz;

};

# ---   *   ---   *   ---
# ^get minimum size of operand

sub symsolve_min($ISA,$dst,$deref) {
  return $ISA->immsz(symsolve_addr($dst,$deref));

};

# ---   *   ---   *   ---
# add entry points

cmdsub '$' => q() => \&current_byte;
cmdsub 'blk' => q() => \&blk;
cmdsub 'entry' => q() => \&entry;
cmdsub 'asm-ins' => q() => \&asm_ins;

# ---   *   ---   *   ---
1; # ret
