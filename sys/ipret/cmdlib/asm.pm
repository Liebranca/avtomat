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

  our $VERSION = v0.02.5;#b
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
  my $hier = $mc->{hiertop};
  my $vref = $branch->{vref};

  # get name of symbol
  my $name = $vref->{spec};

  my @xp   = $top->{value};
  my @path = $top->ances_list;

  if(defined $hier && %$hier) {

    my ($par)=$hier->fullpath;

    push @path,$par;
    push @xp,$par;

  };


  my $full=join '::',@xp,$name;


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
  my $main  = $self->{frame}->{main};
  my $mc    = $main->{mc};
  my $anima = $mc->{anima};

  my $l1    = $main->{l1};
  my $vref  = $branch->{vref};


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

  # find children nodes
  my $re=$l1->re(CMD=>'proc');
  my @lv=$branch->match_up_to(

    $re,

    inclusive => 0,
    deep      => 1,

  );

  $branch->pushlv(@lv);


  # make object representing block
  my $ptr   = $fn->();
  my $tab   = \$branch->{vref};

  $$tab=rd::vref->new(

    type => 'HIER',
    spec => 'proc',

    data => $mc->mkhier(
      type=>'proc',
      node=>$branch,
      name=>$vref->{res}->{label},

    ),

    res  => $vref->{res},

  );


  # add closing call and give
  $$tab->{data}->enqueue(
    ribbon=>'asm::setup_stack'=>$branch

  );


  return $fn;

};

# ---   *   ---   *   ---
# decls inputs and outputs to a process

sub io($self,$branch) {


  # get ctx
  my $frame = $self->{frame};
  my $main  = $frame->{main};
  my $l1    = $main->{l1};
  my $mc    = $main->{mc};
  my $vref  = $branch->{vref};
  my $anima = $mc->{anima};

  # get process
  my $hier = $mc->{hiertop};
  my $tab  = $hier->{p3ptr}->{vref};

  my $dst  = $tab->{data};


  # unpack args
  my ($type,$sym,$value)=$vref->flatten();

  # alloc and give
  $dst->addio(
    $branch->{cmdkey},
    $sym->{spec},

  );


  # add var dummy to namespace
  $value=(defined $value)

    ? $l1->tag(
        $value->{type},
        $value->{spec},

      ) . $value->{data}

    : $l1->tag(NUM=>0)
    ;

  $vref->{spec} = typefet $type->{spec};
  $vref->{data} = [[$sym->{spec}=>$value]];

  my $cmd=$frame->fetch('data-decl');


  # mutate into decl and give
  %$self=%$cmd;
  return $cmd->{key}->{fn}->($cmd,$branch);

};

# ---   *   ---   *   ---
# replace aliases!

sub lisrepl($self,$branch) {


  # get ctx
  my $main = $self->{frame}->{main};
  my $l1   = $main->{l1};
  my $mc   = $main->{mc};

  my $proc = $mc->{hiertop};
  my $lis  = $proc->{p3ptr}->{vref}->{data};


  # unpack
  my $vref = $branch->{vref}->{res};
  my $name = $vref->{name};
  my $opsz = $vref->{opsz};

  # walk operands
  my @Q=map {$ARG->{data}} @{$vref->{args}};

  while(@Q) {

    my $nd   = shift @Q;

    my $key  = $nd->{value};
    my $have = $l1->xlate($key);


    # all aliases are symbols!
    if($have->{type} eq 'SYM'
    && exists $lis->{$have->{spec}}) {

      my $x    = $lis->{$have->{spec}};
      my $type = $x->{res};


      # typed alias?
      if(length $type) {


        # replace sole operation size?
        if($vref->{opsz_def}) {
          $vref->{opsz_def}=0;
          $opsz=$vref->{opsz}=$type;

        # ^nope, match against existing!
        } else {

          $main->err(
            "type specifier mismatch"

          ) if $type ne $opsz;

        };

      };


      # replace alias with value ;>
      $nd->{value}=$l1->tag(
        $x->{type}=>$x->{spec}

      ) . $x->{data};

      $nd->{vref}=$x;

    };

    unshift @Q,@{$nd->{leaves}};

  };


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

  $self->lisrepl($branch);


  # unpack
  my $vref = $branch->{vref};
  my $vres = $vref->{res};
  my $name = $vres->{name};
  my $opsz = $vres->{opsz};

  # walk operands
  my @args=map {

    my $nd   = $ARG->{data};
    my $key  = $nd->{value};
    my $type = $ARG->{type};
    my $have = $l1->xlate($key);

    if($type eq 'SYM'
    && $type ne $have->{type}) {
      $ARG  = $nd->{vref};
      $type = $have->{type};

    };

    my $O={};


    # have register?
    if($type eq 'REG') {
      $O->{reg}  = $eng->quantize($key);
      $O->{type} = 'r';


    # have immediate?
    } elsif($type eq 'NUM') {
      $O->{imm}  = $eng->quantize($key);
      $O->{type} = $ISA->immsz($O->{imm});


    # have operator?
    } elsif($type eq 'OPR') {

      $O->{imm}=$eng->opera_collapse(
        $nd,$have,

        noreg=>1,
        noram=>1,

      );


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


  } @{$vres->{args}};


  # have enqueued checks?
  if(defined $vref->{ctc}) {

    my $ok=$vref->{ctc}->(

      $self,
      $branch,

      $opsz,$name,@args

    );


    # need to discard or retry?
    return null if $ok eq $branch;
    return ($opsz,null) if ! length $ok;

    $opsz=$ok;


  };

  goto skip if $name=~ $ISA->{guts}->meta_re;


  # overwrite default type?
  my $nc_name=$name;

  my $def=$vres->{opsz_def};
  my $fix=$ISA->get_ins_fix_size($nc_name);

  if(defined $fix) {

    if($def) {
      $opsz=typefet $fix->[0];

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
  skip:
  return ($opsz,$name,@args);

};

# ---   *   ---   *   ---
# TODO: move this bit somewhere else!
#
#  # command dereference
#  if(my $have=$l1->typechk(CMD=>$key)) {
#
#    my $cmd   = $lib->fetch($have->{spec});
#    my $solve = $cmd->{key}->{fn}->($self,$nd);
#
#    return null if $solve && $solve eq $nd;
#
#
#    # ~
#    my $value=(defined $solve)
#      ? $solve
#      : $nd->{vref}
#      ;
#
#
#    # delay value deref until encoding
#    $O->{imm}=$value;
#
#    $O->{type}=sub ($x,$y) {
#      $x->immsz($y)
#
#    };
#
#    $O->{type_args}=[$ISA,$value];

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


  # instruction discarded?
  if(! length $name) {
    $branch->discard();
    return;

  };


  # all OK, request and give
  $branch->{vref}->{res}->{args}=[@args];
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

        spec => $have->{spec},

        neg  => 0,
        type => 'REG',

      };


    # symbol name?
    } elsif($have=$l1->typechk(SYM=>$key)) {

      push @tree,{

        spec => $have->{spec},

        neg  => $self->get_valid_ptr(SYM=>$nd),
        type => 'SYM',

      };


    # immediate?
    } elsif(! ($have=$l1->typechk(OPR=>$key))) {

      push @tree,{

        spec => $eng->quantize($key),

        neg  => $self->get_valid_ptr(IMM=>$nd),
        type => 'IMM',

      };


    # operator!
    } else {

      push @tree,{

        spec => $have->{spec},

        neg  => 0,
        type => 'OPR',

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
  @tree = grep {$ARG->{type} ne 'REG'} @tree;


  # give descriptor
  return {

    tree  => \@tree,
    reg   => $reg,

    sym   => [addr_elem SYM=>@tree],
    imm   => [addr_elem IMM=>@tree],

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
        ? $ar->[$ARG]->{spec}+1
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

        args => [$scale->{spec}],

      ) if ! ($scale->{spec}=~ qr{^(?:1|2|4|8)$});


      # ^remove multiplication from tree!
      my ($off)=grep {
         exists $tree->[$ARG]->{spec}
      && $tree->[$ARG]->{spec} eq '*'

      } reverse 0..@$tree-1;

      $tree->[$off]=undef;
      @$tree=grep {defined $ARG} @$tree;

      $scale={
        1 => 0,
        2 => 1,
        4 => 2,
        8 => 3,

      }->{$scale->{spec}};

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

    $O->{reg}      = $data->{reg}->[0]->{spec};

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
      $out = $ARG->{spec};
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
  my $vres  = $branch->{vref}->{res};

  my ($name,@path)=$dst->fullpath;


  # out
  my $O={

    imm      => \&symsolve_addr,
    imm_args => [$dst,$deref],

    id       => [$name,@path],

  };


  # using default size?
  if($vres->{opsz_def}) {

    $O->{opsz}      = \&symsolve_opsz;
    $O->{opsz_args} = [$dst,$deref];

  # have size modifier!
  } else {
    $O->{opsz}=$vres->{opsz};
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
cmdsub 'entry'    => q() => \&entry;
cmdsub 'blk'      => q() => \&blk;
cmdsub 'proc'     => q() => \&proc;
cmdsub 'io'       => q() => \&io;
cmdsub 'asm-ins'  => q() => \&asm_ins;

w_cmdsub 'io'     => q() => qw(in out);

# ---   *   ---   *   ---
1; # ret
