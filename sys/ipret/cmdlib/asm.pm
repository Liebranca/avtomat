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

  our $VERSION = v0.01.2;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# offset within current segment

cmdsub '$' => q() => q{

  my $main = $self->{frame}->{main};
  $branch->{vref}=$main->cpos;

  return;

};

# ---   *   ---   *   ---
# a label with extra steps

cmdsub 'blk' => q() => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};
  my $enc  = $main->{encoder};
  my $ISA  = $mc->{ISA};

  # get name of symbol
  my $name=$l1->is_sym(
    $branch->{vref}->{id}

  );

  my $full="$mc->{segtop}->{value}.$name";


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
  $ptr->{chan}       = $mc->{segtop}->{iced};

  $mc->{cas}->{ptr} += $align_t->{sizeof};


  # add reference to current segment!
  my $alt=$mc->{segtop}->{inner};
  $alt->force_set($ptr,$name);

  $alt->{'*fetch'}->{mem}=$ptr;


  # ^schedule for update ;>
  $enc->binreq(

    $branch,[

      $align_t,

      'data-decl',

      { id   => $full,

        type => 'sym-decl',
        data => $main->cpos,

      },

    ],

  );

  return;

};

# ---   *   ---   *   ---
# defines entry point

cmdsub 'entry' => q() => q{


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};

  # get name of symbol
  my $name=$l1->is_sym(
    $branch->{vref}->{id}

  );

  # can fetch symbol?
  my $seg=$mc->ssearch(
    'non',split $mc->{pathsep},$name

  );

  return $branch if ! length $seg;


  # validate, set and give
  $main->perr(
    "redeclaration of entry point"

  ) if defined $main->{entry};

  $main->{entry}=$name;


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
      $O->{reg}=$l1->quantize($key);


    # have immediate?
    } elsif($type eq 'i') {


      # command dereference
      if(defined (my $have=$l1->is_cmd($key))) {

        # TODO: move this bit somewhere else!
        my $cmd=$lib->fetch($have);
        $cmd->{fn}->($self,$nd);


        # delay value deref until encoding
        $O->{imm}=sub {
          ${$nd->{vref}}

        };

        $type=sub {
          $ISA->immsz(${$nd->{vref}})

        };


      # regular immediate ;>
      } else {
        $O->{imm}=$l1->quantize($key);
        $type=$ISA->immsz($O->{imm});

      };


    # have memory?
    } elsif($type eq 'm') {

      ($type,$opsz,$O)=
        $self->addrmode($branch,$nd);

      return null if ! length $type;


    # have symbol?
    } elsif($type eq 'sym') {

      ($type,$opsz,$O)=
        $self->symsolve($branch,$ARG,0);

      return null if ! length $type;


    };


    # give descriptor
    $O->{type}=$type;
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

cmdsub 'asm-ins' => q() => q{

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
    if(defined ($have=$l1->is_reg($ARG))) {

      $stk |= $have == $anima->stack_bot;
      push @reg,$have;

    # symbol name?
    } elsif(defined ($have=$l1->is_sym($ARG))) {
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


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};

  # default segment to use if none specified!
  my $seg    = $mc->{scope}->{mem};
  my $ptrseg = $seg->{iced};

  # out
  my $type = null;
  my $opsz = $branch->{vref}->{opsz};
  my $O    = {};


  # get type lists
  my $data=$self->addr_decompose($nd);
  return null if ! length $data;


  # have symbols?
  if(@{$data->{sym}}) {

    map {

      my ($sym_t,$sym_sz,$head)=
        $self->symsolve($branch,$ARG,1);

      return null if ! length $sym_t;


      # save segment bit separately
      $opsz   = $sym_sz;
      $ptrseg = $head->{seg};


      # delayed deref+sum
      if(defined $data->{imm}->[0]) {

        my $have=$data->{imm}->[0];

        $data->{imm}->[0]=sub {

          my ($isref_x,$x)=
            Chk::cderef $have,1;

          return $x + $head->{imm}->();

        };


      # ^as-is
      } else {
        $data->{imm}->[0]=$head->{imm};

      };


    } @{$data->{sym}};

  };


  # [sb-i]
  if($data->{stk}) {

    $data->{imm}->[0] //= 0;
    $O->{imm}=$data->{imm}->[0];

    $type='mstk';


  # [seg:r+i]
  } elsif(

     @{$data->{reg}} == 1
  && @{$data->{imm}} <= 1

  ) {

    $data->{imm}->[0] //= 0;

    $O->{seg}=$ptrseg;
    $O->{reg}=$data->{reg}->[0];
    $O->{imm}=$data->{imm}->[0];

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

    $O->{seg}   = $ptrseg;

    $O->{rX}    = $data->{reg}->[0];
    $O->{rY}    = $data->{reg}->[1];

    $O->{imm}   = $data->{imm}->[0];
    $O->{scale} = $data->{imm}->[1];

    $type='mlea';


  # [seg:i]
  } else {

    $data->{imm}->[0] //= 0;

    $O->{seg}=$ptrseg;
    $O->{imm}=$data->{imm}->[0];

    $type='mimm';

  };


  return ($type,$opsz,$O);

};

# ---   *   ---   *   ---
# delayed dereference ;>

sub symsolve($self,$branch,$vref,$deref) {


  # can solve destination?
  my $dst=$self->argproc($vref);
  return null if ! length $dst;


  # get ctx
  my $main  = $self->{frame}->{main};
  my $l1    = $main->{l1};
  my $mc    = $main->{mc};
  my $anima = $mc->{anima};
  my $ISA   = $mc->{ISA};
  my $enc   = $main->{encoder};


  # get pointer and bitsize
  my $fn=sub {


    # have ptr?
    my ($ptrv,$opsz,$seg);

    if(exists $dst->{type}) {

      $seg  = $dst->{chan};
      $ptrv = ($dst->{ptr_t})
      ? $dst->load(deref=>0)
      : $dst->{addr}
      ;

      $opsz = ($deref)
        ? $dst->{type}
        : $dst->{ptr_t}
        ;


    # ^have segment!
    } else {
      $seg  = $ptrv = $dst->{iced};
      $opsz = Type->ptr_by_size($ptrv);

    };

    $opsz //= typefet 'ptr';


    my $type=$ISA->immsz($ptrv);
    return ($seg,$ptrv,$opsz,$type);

  };


  my $O={
    seg  => sub {($fn->())[0]},
    imm  => sub {($fn->())[1]},

  };


  # have size modifier?
  my $opsz = ($branch->{vref}->{opsz_def})
    ? sub {($fn->())[2]}
    : $branch->{vref}->{opsz}
    ;

  my $type=sub {($fn->())[3]};
  return ($type,$opsz,$O);

};

# ---   *   ---   *   ---
# solves conditional part of
# an instruction

sub chksolve($self,$branch,$opsz) {


  # can solve condition?
  my $chk=$self->argproc(

    $branch->{vref}->{opera},

    delay    => 1,
    sym_asis => 1,

  );

  return null if ! length $chk;


  # get ctx
  my $main = $self->{frame}->{main};
  my $enc  = $main->{encoder};
  my $eng  = $main->{engine};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};
  my $ISA  = $mc->{ISA};


  # which flag are we checking?
  my $flag     = undef;
  my @prologue = ();

  my ($istag,$idex)=$l1->read_tag($chk);


  # have opera?
  if($istag) {


    # read last instruction in binary
    my $bytes = $eng->strseg($idex,decode=>0);
    my $exe   = $enc->decode($bytes);
    my $end   = $exe->[-1];


    # ^get name of instruction!
    my $idx = $end->{ins}->{idx};
    my $tab = $ISA->opcode_table;
    my $fn  = $tab->{exetab}->[$idx];


    # ^map instruction name to flag ;>
    $flag={

      _eq=>'z',
      _ne=>'nz'

    }->{$fn};

    # append operation to output
    @prologue=[$opsz,'raw',$bytes];


  # have flag!
  } else {

    $flag={

      zero  => 'z',
      nzero => 'nz'

    }->{$chk};

  };


  return $flag,@prologue;

};

# ---   *   ---   *   ---
# conditional instruction

cmdsub 'c-asm-ins' => q() => q{

  # get ctx
  my $main = $self->{frame}->{main};
  my $enc  = $main->{encoder};


  # can solve arguments?
  my ($opsz,$name,@args)=
    $self->argsolve($branch);

  return $branch
  if ! length $opsz;


  # can solve condition?
  my ($flag,@prologue)=
    $self->chksolve($branch,$opsz);

  return $branch
  if ! length $flag;


  # all OK, request and give
  $enc->binreq(

    $branch,

    @prologue,
    [$opsz,"$name-$flag",@args],

  );

  return;

};

# ---   *   ---   *   ---
1; # ret
