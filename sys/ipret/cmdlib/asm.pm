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

  use rd::vref;

# ---   *   ---   *   ---
# adds to main::cmdlib

  use   parent 'ipret::cmd';
  BEGIN {ipret::cmd->defspkg};

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.0;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# offset within current segment

sub current_byte($self,$branch) {

  my $main = $self->{frame}->{main};
  $branch->{vref}->{res}=$main->cpos;

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
  my $vref = $branch->{vref};

  # get name of symbol
  my $name = $vref->{spec};

  my @path=$top->ances_list;
  my $full=join '::',$top->{value},$name;


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
  $ptr->{p3ptr}      = $branch;


  # add refere nce to current segment!
  my $alt=$top->{inner};
  $alt->force_set($ptr,$name);

  $alt->{'*fetch'}->{mem}=$ptr;
  $top->route_anon_ptr($ptr);


  # ^schedule for update ;>
  my $fn   = (ref $main) . '::cpos';
     $fn   = \&$fn;

  $enc->binreq(

    $branch,[

      $align_t,

      'data-decl',

      { id        => [$name,@path],

        type      => 'sym-decl',

        data      => $fn,
        data_args => [$main],

      },

    ],

  );


  # reset and give
  $fn=sub {$mc->{blktop}=$ptr;$ptr};

  $vref->{res}=$ptr;
  $fn->();

  return $fn;

};

# ---   *   ---   *   ---
# defines entry point

sub entry($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $l1   = $main->{l1};
  my $sep  = $mc->{pathsep};
  my $vref = $branch->{vref};

  # get name of symbol
  my $name=$vref->{spec};


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
# template:
#
# * prepend segment declaration
#   to current branch

sub segpre($self,$branch,$type,$name=null) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};
  my $mc    = $main->{mc};
  my $l1    = $main->{l1};


  # locate expression
  my $anchor = $branch;
     $anchor = $anchor->{parent}

  while $anchor->{parent}
  &&    $anchor->{parent} ne $main->{tree};


  # get segment type
  $type={
    'executable' => 'exe',
    'readable'   => 'rom',
    'writeable'  => 'ram',

  }->{$type};

  # ^make segment node
  my ($nd) = $anchor->{parent}->insert(
    $anchor->{idex},

    $l1->tag(CMD=>'seg-type')
  . $type

  );


  $nd->{vref}=rd::vref->new(

    type => 'SYM',
    spec => (length $name)
      ? $name
      : $mc->{cas}->mklabel()
      ,


    data => $type,

  );


  # execute segment function!
  my $cmd  = $frame->fetch('seg-type');
  my $fn   = $cmd->{key}->{fn};

  $fn->($self,$nd);

  return;

};

# ---   *   ---   *   ---
# ^conditionally ;>

sub csegpre($self,$branch,@flags) {

  # get ctx
  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};


  # ensure segment of the right type
  my $top = $mc->{segtop};
  my $ok  = @flags == grep {$top->{$ARG}} @flags;

  $ok &=~ ($top eq $mc->{cas});


  # no deal? then generate!
  $self->segpre($branch,shift @flags)
  if ! $ok;


  return;

};

# ---   *   ---   *   ---
# template:
#
# * if the current segment type
#   does not match flags, then
#   prepend one that does
#
# * slap a new label on it

sub segpre_blk($self,$branch,@flags) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};
  my $mc    =


  # ensure segment
  $self->csegpre($branch,@flags);

  # run label function and give
  my $cmd = $frame->fetch('blk');
  my $fn  = $cmd->{key}->{fn};

  return $fn->($self,$branch);

};

# ---   *   ---   *   ---
# ^iceof

sub proc($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};


  # generate segment and block
  my $fn=$self->segpre_blk(
    $branch,'executable'

  );


  # set hierarchical anchor!
  my $old=$fn;

  $fn=sub {
    my $have=$old->();
    $mc->{hiertop}=$have;

    return $have;

  };


  # reset and give
  $fn->();
  return $fn;

};

# ---   *   ---   *   ---
# ~

sub in($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};
  my $vref = $branch->{vref};

  # unpack
  my ($type,$sym)=$vref->flatten();

  use Fmat;

  fatdump \$mc->{hiertop},blessed=>1;

  fatdump \$type,blessed=>1;
  fatdump \$sym,blessed=>1;
  exit;

  return;

};

# ---   *   ---   *   ---
# solve instruction arguments

sub argsolve($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};
  my $eng  = $main->{engine};
  my $ISA  = $mc->{ISA};
  my $lib  = $main->{cmdlib};


  # unpack
  my $vref = $branch->{vref}->{res};
  my $name = $vref->{name};
  my $opsz = $vref->{opsz};

  # walk operands
  my @args=map {

    my $nd   = $ARG->{id};
    my $key  = $nd->{value};
    my $type = $ARG->{type};

    my $O    = {};


    # have register?
    if($type eq 'REG') {
      $O->{reg}  = $eng->quantize($key);
      $O->{type} = 'r';


    # have immediate?
    } elsif($type eq 'NUM') {


      # command dereference
      if(my $have=$l1->typechk(CMD=>$key)) {


        # TODO: move this bit somewhere else!
        my $cmd   = $lib->fetch($have->{spec});
        my $solve = $cmd->{key}->{fn}->($self,$nd);

        return null if $solve && $solve eq $nd;


        # ~
        my $value=(defined $solve)
          ? $solve
          : $nd->{vref}
          ;


        # delay value deref until encoding
        $O->{imm}=$value;

        $O->{type}=sub ($x,$y) {
          $x->immsz($y)

        };

        $O->{type_args}=[$ISA,$value];


      # regular immediate ;>
      } else {
        $O->{imm}  = $eng->quantize($key);
        $O->{type} = $ISA->immsz($O->{imm});

      };


    # have memory?
    } elsif($type eq 'MEM') {
      $O=$self->addrmode($branch,$nd);
      return null if ! length $O;


    # have symbol?
    } elsif($type eq 'SYM') {
      $O=$self->symsolve($branch,$ARG,0);
      return null if ! length $O;

    };


    # give descriptor
    $O;


  } @{$vref->{args}};


  # overwrite default type?
  my $nc_name=$name;

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
# get chain of operations is
# valid for an addressing mode

sub get_valid_ptr($self,$type,$nd,@args) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};

  my $out  = 0;


  # have register?
  if($type eq 'REG') {

    my ($stk)=@args;


    # check stack addressing?
    if($stk) {

      $main->perr(

        'invalid operation; '

      . 'stack base can only be used as '
      . 'destination for substraction'

      ) if(
         $nd->{idex} > 0
      || $self->get_opr_parent($nd,qr{^(?:\-)$})

      );


    # check common LH usage?
    } elsif(! $nd->{idex}) {

      $main->perr(

        'invalid operation; '

      . 'register can only be used as '
      . 'destination for addition, substraction '
      . 'or multiplication'

      ) if $self->get_opr_parent(
        $nd,qr{^(?:\-|\+|\*)$}

      );


      # scale applied to register?
      my $value = $nd->{parent}->{value};
      my $have  = $l1->typechk(OPR=>$value);

      $out=$have->{spec} eq '*' if $have;


    # check common RH usage?
    } else {


      $main->perr(

        'invalid operation; '

      . 'register can only be used as '
      . 'source for addition'

      ) if $self->get_opr_parent(
        $nd,qr{^(?:\+)$}

      );


    };


  # have symbol or immediate?
  } else {


    # forbid symbol as scale
    if($type eq 'SYM') {

      $main->perr(

        'invalid operation; '

      . 'symbol can only be used as '
      . 'source for addition or '
      . 'substraction'

      ) if $nd->{idex} && $self->get_opr_parent(
        $nd,qr{^(?:\-|\+)$}

      );

    };


    # apply negation to value?
    my $value = $nd->{parent}->{value};
    my $have  = $l1->typechk(OPR=>$value);

    $out=(

       $nd->{idex}
    && $have->{spec} eq '-'

    ) if $have;


  };


  return $out;

};

# ---   *   ---   *   ---
# ^find valid operator above a node

sub get_opr_parent($self,$nd,$opr) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};


  # walk up the hierarchy!
  my $par  = $nd->{parent};
  my $have = 0;

  while($par) {


    # operator found?
    if(my $desc=$l1->typechk(
      OPR=>$par->{value}

    )) {

      $have=! ($desc->{spec}=~ $opr);
      last if $have;

    };


    # ^nope, keep going!
    $par=$par->{parent};

  };


  return $have;

};

# ---   *   ---   *   ---
# get idex of element in addr
# decomposition tree

sub addr_elem($type,@tree) {

  grep {
    $tree[$ARG]->{type} eq $type

  } 0..$#tree;

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

    delay=>1,

    noreg=>1,
    noram=>1,
    norom=>1,
    noptr=>1,

  );


  # decompose address
  my @tree = ();

  my $stk  = 0;
  my $lea  = 0;

  my @Q    = $beg;

  while(@Q) {

    my $nd   = shift @Q;

    my $key  = $nd->{value};
    my $have = undef;

    unshift @Q,@{$nd->{leaves}};


    # register name?
    if($have=$l1->typechk(REG=>$key)) {


      $stk |= $have->{spec} == $anima->stack_base;
      $lea |= $self->get_valid_ptr(REG=>$nd,$stk);

      push @tree,{

        id   => $have->{spec},

        neg  => 0,
        type => 'reg',

      };


    # symbol name?
    } elsif($have=$l1->typechk(SYM=>$key)) {

      push @tree,{

        id   => $have->{spec},

        neg  => $self->get_valid_ptr(SYM=>$nd),
        type => 'sym',

      };


    # immediate?
    } elsif(! ($have=$l1->typechk(OPR=>$key))) {

      push @tree,{

        id   => $eng->quantize($key),

        neg  => $self->get_valid_ptr(IMM=>$nd),
        type => 'imm',

      };


    # operator!
    } else {

      push @tree,{

        id   => $have->{spec},

        neg  => 0,
        type => 'opr',

      } if ! ($have->{spec}=~ qr{^(?:\-|\+)$});


    };


  };


  # check legal register use
  my $reg  = [addr_elem reg=>@tree];
     $lea |= @$reg > 1;

  $main->perr(

    'cannot use more than two '
  . 'registers to calculate pointer'

  ) if @$reg > 2;


  # ^remove registers from tree!
  @$reg = map  {$tree[$ARG]} @$reg;
  @tree = grep {$ARG->{type} ne 'reg'} @tree;


  # give descriptor
  return {

    tree  => \@tree,
    reg   => $reg,

    sym   => [addr_elem sym=>@tree],
    imm   => [addr_elem imm=>@tree],

    stk   => $stk,
    lea   => $lea,

  };

};

# ---   *   ---   *   ---
# build memory operand from
# operation tree

sub addrmode($self,$branch,$nd) {


  # get type lists
  my $data=$self->addr_decompose($nd);
  return null if ! length $data;

  my $tree=$data->{tree};


  # get ctx
  my $main = $self->{frame}->{main};
  my $mc   = $main->{mc};

  # out
  my $type      = null;
  my $opsz      = $branch->{vref}->{opsz};
  my $opsz_args = [];
  my $O         = {};


  # have symbols?
  map {


    # skip if can't solve!
    my $idex = $ARG;
    my $head = $self->symsolve(
      $branch,$tree->[$idex],1

    );

    return null if ! length $head;


    # overwrite operation size if
    # symbol is the sole component!
    if(! defined $opsz &&! @$tree-1) {
      $opsz      = $head->{opsz};
      $opsz_args = $head->{opsz_args};

    };


    # put symbol descriptor in tree
    $head->{neg}   = $tree->[$idex]->{neg};
    $tree->[$idex] = $head;


  } @{$data->{sym}};


  # [sb-i]
  if($data->{stk}) {

    $O->{imm}      = \&addrsolve_collapse;
    $O->{imm_args} = $tree;

    $O->{type}     = 'mstk';


  # [r+r+i*x]
  } elsif($data->{lea}) {

    my ($rX,$rY)=map {

      my $ar=$data->{reg};

      (defined $ar->[$ARG])
        ? $ar->[$ARG]->{id}+1
        : 0
        ;

    } 0..1;


    # validate scale value
    my $scale=0;
    if(@$tree > 2) {

      $scale=pop @$tree;
      $main->perr(

        'invalid scale factor of [num]:%u '
      . 'for address',

        args => [$scale->{id}],

      ) if ! ($scale->{id}=~ qr{^(?:1|2|4|8)$});


      # ^remove multiplication from tree!
      my ($off)=grep {
         exists $tree->[$ARG]->{id}
      && $tree->[$ARG]->{id} eq '*'

      } reverse 0..@$tree-1;

      $tree->[$off]=undef;
      @$tree=grep {defined $ARG} @$tree;

      $scale={
        1 => 0,
        2 => 1,
        4 => 2,
        8 => 3,

      }->{$scale->{id}};

    };


    # make descriptor
    $O->{rX}       = $rX;
    $O->{rY}       = $rY;

    $O->{imm}      = \&addrsolve_collapse;
    $O->{imm_args} = $tree;

    $O->{scale}    = $scale;
    $O->{type}     = 'mlea';


  # [r+i]
  } elsif(@{$data->{reg}}) {

    $O->{reg}      = $data->{reg}->[0]->{id};

    $O->{imm}      = \&addrsolve_collapse;
    $O->{imm_args} = $tree;

    $O->{type}     = 'msum';


  # [i]
  } else {

    $O->{imm}      = \&addrsolve_collapse;
    $O->{imm_args} = $tree;

    $O->{type}     = 'mimm';

  };


  # give descriptor
  $O->{opsz}      = $opsz;
  $O->{opsz_args} = $opsz_args;

  return $O;

};

# ---   *   ---   *   ---
# adds symbols and immediates
# inside an address tree

sub addrsolve_collapse(@tree) {

  use Fmat;

  my $opera = qr{^(?:\/|\*)$};
  my @have  = map {

    my $neg = 0;
    my $out = 0;

    # have fetch?
    if(exists $ARG->{imm}) {
      $out = $ARG->{imm}->(@{$ARG->{imm_args}});
      $neg = $ARG->{neg};

    # have value!
    } else {
      $out = $ARG->{id};
      $neg = $ARG->{neg};

    };

    $out *= 1-(2*$neg)
    if ! ($out=~ $opera);

    $out;


  } @tree;

  my $out=0;
  while(@have) {

    my $x=shift @have;
    if($x=~ $opera) {
      my ($lh,$rh)=(shift @have,shift @have);
      $out += eval "$lh $x $rh";

    } else {
      $out += $x;

    };

  };


  return int $out;

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

  my ($name,@path)=$dst->fullpath;


  # out
  my $O={

    imm      => \&symsolve_addr,
    imm_args => [$dst,$deref],

    id       => [$name,@path],

  };


  # using default size?
  if($branch->{vref}->{data}->{opsz_def}) {
    $O->{opsz}      = \&symsolve_opsz;
    $O->{opsz_args} = [$dst,$deref];

  # have size modifier!
  } else {

    $O->{opsz}=
      $branch->{vref}->{data}->{opsz};

    $O->{opsz_args}=[];

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

cmdsub '$'        => q() => \&current_byte;
cmdsub 'blk'      => q() => \&blk;
cmdsub 'entry'    => q() => \&entry;
cmdsub 'proc'     => q() => \&proc;
cmdsub 'in'       => q() => \&in;
cmdsub 'asm-ins'  => q() => \&asm_ins;

# ---   *   ---   *   ---
1; # ret
