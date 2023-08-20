#!/usr/bin/perl
# ---   *   ---   *   ---
# MACH
# Barebones emulator
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Mach;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Fmat;

  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use Cask;

  use Mach::Seg;
  use Mach::Struc;
  use Mach::Reg;
  use Mach::Opcode;

  use Mach::Scope;
  use Mach::Value;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.8;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  strucs(q[

    <Anima>

      # IO struc ptrs
      reg64 in;
      reg64 out;

      # ptr to exec blk
      reg64 xs;

      # GPR
      reg64 ar;
      reg64 br;
      reg64 cr;
      reg64 dr;
      reg64 er;

  ]);

# ---   *   ---   *   ---
# GBL

  our $Icemap={};
  our $Models={};

# ---   *   ---   *   ---
# ^get class statics

sub get_icemap($class) {
  return get_static($class,'Icemap');

};

sub get_modeltab($class) {
  return get_static($class,'Models');

};

# ---   *   ---   *   ---
# defines set of configs
# for a given key

sub new_model($class,$name,%O) {

  # defaults
  $O{reg_struc} //= 'Anima';
  $O{optab}     //= ['Mach::Micro'];

  $O{fd}        //= [*STDIN,*STDOUT,*STDERR];


  # ^write new to table
  my $tab=$class->get_modeltab();

  throw_model('redecl',$name,$tab->{$name})
  unless ! exists $tab->{$name};

  $tab->{$name}=\%O;

};

# ---   *   ---   *   ---
# ^ensure existance of

  Mach->new_model('default')
  unless exists $Models->{default};

# ---   *   ---   *   ---
# ^fetches model config

sub get_model($class,$name) {

  my $tab=$class->get_modeltab();

  throw_model('badfet',$name,undef)
  unless exists $tab->{$name};

  return $tab->{$name};

};

# ---   *   ---   *   ---
# ^multi-purpose errme

sub throw_model($type,$name,$h=undef) {

  state $tab={

    redecl=>q[Mach model '%s' already declared],
    badfet=>q[Mach model '%s' doesn't exist],

    grammar=>
      q[No Grammar found for Mach model '%s'],

  };

  errcaller(
    fatdump=>$h,

  );

  errout(

    $tab->{$type},

    lvl  => $AR_FATAL,
    args => [$name],

  );

};

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  # defaults
  $O{model} //= 'default';
  $O{frame} //= 0;

  # ^cat config to options
  my $model=$class->get_model($O{model});
  %O=(%O,%$model);


  # nit buffs for each standard
  # file descriptor
  my $fd_buff=[
    ($NULLSTR) x int(@{$O{fd}})

  ];


  # make ice
  my $frame = $class->get_frame($O{frame});
  my $self  = bless {

    id        => 0,
    model     => $O{model},

    reg       => undef,
    regmask   => 0,

    fast_seg  => [],
    seg_cask  => Cask->new(),

    optab     => undef,

    stk       => [],
    stk_top   => 0,
    stk_frame => [],

    fd        => $O{fd},
    fd_buff   => $fd_buff,

    scope     => Mach::Scope->new(),

    frame     => $frame,

  },$class;


  # nit registers
  $self->{regmask}=bitsize(
    Mach::Struc->field_cnt($O{reg_struc})-1

  );

  $self->{reg}=Mach::Struc->ice(
    $O{reg_struc},
    mach=>$self,

  );


  # ^add registers to non::SYS
  map {

    $self->decl(

      'seg',
      $ARG,

      raw   => $self->{reg}->{$ARG},
      path  => ['SYS'],

      const => 0,

    )

  } grep {
    0 > index $ARG,'-'

  } keys %{$self->{reg}};


  # nit instruction table
  my $opframe=Mach::Opcode->new_frame(
    -mach=>$self

  );

  $opframe->engrave(@{$O{optab}});
  $self->{optab}=$opframe->regen();


  # register ice
  my $icemap=$class->get_icemap();
  $icemap->{$O{model}} //= [];

  my $box=$icemap->{$O{model}};
  $self->{id}=int @$box;

  push @$box,$self;


  return $self;

};

# ---   *   ---   *   ---
# ^retrieve or make

sub fetch($class,$id,%O) {

  # defaults
  $O{model} //= 'default';


  my $out    = undef;

  my $icemap = $class->get_icemap();
  my $box    = $icemap->{$O{model}};

  # make new
  if(! $box ||! $box->[$id]) {
    $out=$class->new(%O);

  # get existing
  } else {
    $out=$box->[$id];

  };

  return $out;

};

# ---   *   ---   *   ---
# ^retrieve memory segment

sub fetch_seg($self,@at) {

  my $out    = undef;
  my $icebox = undef;

  my $loc    = 0x00;
  my $addr   = 0x00;

  # register or cache
  if(1 eq int @at) {

    $addr   = $at[0];
    $icebox = $self->{fast_seg};

  # ^ regular memory
  } else {

    ($loc,$addr)=@at;

    my $cask   = $self->{seg_cask};

    my $frame  = $cask->view($loc);
       $icebox = $frame->{-icebox};

  };

  return $icebox->[$addr];

};

# ---   *   ---   *   ---
# ^converts raw addr to segment

sub decode_ptr($self,$ptr) {

  my $out=$ptr;

  if(! Mach::Seg->is_valid($ptr)) {
    my @addr=($ptr >> 32, $ptr & bitmask(32));
    $out=$self->fetch_seg(@addr);

  };

  return $out;

};

# ---   *   ---   *   ---
# ^make new segment

sub new_seg($self,$name,$size,%O) {

  my $seg=Mach::Seg->new(

    $size,

    %O,
    mach=>$self

  );

  $self->decl(

    seg   => $name,

    path  => ['SYS'],
    raw   => $seg,

  );


  return $seg;

};

# ---   *   ---   *   ---
# ^spawns frame for base segments

sub new_baseg($self) {

  my $cask=$self->{seg_cask};

  # make new frame
  my $frame=Mach::Seg->new_frame(
    -mach=>$self

  );

  # ^automatically re-utilize free id
  # or crate new if non avail
  $frame->{-id}=$cask->give($frame);

  return $frame;

};

# ---   *   ---   *   ---
# generae machine instructions
# from [key => args]

sub xs_encode($self,@ins) {

  my $total = 0;
  my $tab   = $self->{optab};

  $tab->branch_ok(@ins);

  my @out=map {

    my ($opcode,$width)=
      $tab->get_opcode(@$ARG);

    $total+=$width;
    substr $opcode,0,$width;

  } @ins;

  return ($total,@out);

};

# ---   *   ---   *   ---
# ^write encoded to current
# executable segment

sub xs_write($self,@opcodes) {

  my $reg=$self->{reg};
  my $mem=$reg->{xs}->ptr_deref();
  my $tab=$self->{optab};

  $mem->set(rstr=>(join $NULLSTR,@opcodes));

};

# ---   *   ---   *   ---
# ^read

sub xs_read($self) {

  my $tab=$self->{optab};
  my $reg=$self->{reg};

  my $mem=$reg->{xs}->ptr_deref();

  return $tab->read($mem);

};

# ---   *   ---   *   ---
# ^exec

sub xs_run($self,%O) {

  # defaults
  $O{prologue} //= $NOOP;
  $O{epilogue} //= $NOOP;

  # ^wrap around instructions
  $O{prologue}->();


  # ^load ins from xseg
  my $reg = $self->{reg};
  my $old = $reg->{xs}->ptr_deref();
  my @blk = $self->xs_read();


REPEAT:

  # ^re-read xseg on jumps
  my $new=$reg->{xs}->ptr_deref();

  @blk=($new ne $old)
    ? $self->xs_read()
    : @blk
    ;


  # ^exec loaded instructions
  for my $ins(@blk) {

    my ($fn,@args)=@$ins;
    my $irupt=$fn->(@args);

    ! $irupt or goto REPEAT;

  };


  $O{epilogue}->();

};

# ---   *   ---   *   ---
# ^subdivide block into
# execution paths

sub xs_branch($self,$pos) {

  my $reg=$self->{reg};
  my $seg=$reg->{xs}->ptr_deref();

  my $ptr=$seg->brush($pos);
  $reg->{xs}->ptr_cpy($ptr);

  return 'IRUPT';

};

# ---   *   ---   *   ---
# stack control

sub stkpush($self,$x) {
  push @{$self->{stk}},$x;
  $self->{stk_top}++;

};

sub stkpop($self) {
  my $x=pop @{$self->{stk}};

  --$self->{stk_top} > -1
  or throw_stack_underflow();

  return $x;

};

# ---   *   ---   *   ---
# ^errmes

sub throw_stack_underflow() {

  errout(
    q[Stack underflow],
    lvl=>$AR_FATAL,

  );

};

# ---   *   ---   *   ---
# pass args through stack

sub set_args($self,@input) {

  my $beg=$self->{stk_top};

  map {
    $self->stkpush($ARG);

  } reverse @input;

  my $end=$self->{stk_top}-1;

  push @{$self->{stk_frame}},[$beg,$end];

};

# ---   *   ---   *   ---
# ^retrieve

sub get_args($self) {

  my $range=pop @{$self->{stk_frame}}
  or return ();

  my ($beg,$end)=@$range;

  return map {
    $self->stkpop()

  } $beg..$end;

};

# ---   *   ---   *   ---
# blank value

sub null($self,$type='void') {
  return $self->vice($type,raw=>$NULL);

};

# ---   *   ---   *   ---
# ^bat

sub defnull($self,$type,$aref,@src) {

  $$aref //= [];

  map {
    $$aref->[$ARG]//=
      $self->null($type)

  } 0..$#src;

};

# ---   *   ---   *   ---
# make unbound value ice

sub vice($self,$type,%O) {

  return Mach::Value->new(
    $type,$NULLSTR,%O

  );

};

# ---   *   ---   *   ---
# ^shorthand for flg

sub flg($self,$raw) {

  state $re=qr{[^\w\d]};

  my $sigil = substr $raw,0,1,$NULLSTR;
  my $name  = $raw;

  my $type  = ($name=~ $re)
    ? 'seal'
    : 'bare'
    ;

  return $self->vice(

    'flg',

    raw   => "$sigil$name",
    sigil => $sigil,

    q[flg-type] => $type,
    q[flg-name] => $name,

  );

};

# ---   *   ---   *   ---
# declare bound value

sub decl($self,$type,$id,%O) {

  my @path  = decl_prologue(\%O);
  my $value = Mach::Value->new($type,$id,%O);

  my $ptr   = $value->bind($self->{scope},@path);

  return $ptr;

};

# ---   *   ---   *   ---
# ^shorthand for existing ones

sub bind($self,$value,%O) {

  my @path = decl_prologue(\%O);
  my $ptr  = $value->bind($self->{scope},@path);

  return $ptr;

};

# ---   *   ---   *   ---
# ^alias

sub lis($self,$to,$from,%O) {

  $O{raw}=$from;

  my @path  = (decl_prologue(\%O),q[$LIS]);
  my $value = Mach::Value->new('lis',$to,%O);

  $value->bind($self->{scope},@path);

  return $value;

};

# ---   *   ---   *   ---
# ^common chore

sub decl_prologue($o) {

  # defaults
  $o->{path} //= [];

  # ^lis and pop
  my @path=@{$o->{path}};
  delete $o->{path};

  return @path;

};

# ---   *   ---   *   ---
# use Grammar matching own
# model to parse instructions
#
# pure sugar!

sub parse($self,$s) {

  my $class='Grammar::peso::mach';
  cload($class);

  # check that a parser exists
  $class->dhave($self->{model})
  or throw_model('grammar',$self->{model});

  return $class->parse(

    $s,

    mach => $self,
    iced => $self->{model},

  );

};

# ---   *   ---   *   ---
# ^parse and exec program list

sub ipret($self,@ar) {

  map {
    $self->parse($ARG);
    $self->xs_run();

  } @ar;

};

# ---   *   ---   *   ---
# IO

sub sow($self,$dst,$src) {

  my ($fd,$buff)=$self->fd_solve($dst);
  $$buff.=$src;

};

sub reap($self,$dst) {

  my ($fd,$buff)=$self->fd_solve($dst);

  if(defined $fd) {
    print {$fd} $$buff;
    $fd->flush();

  };

  $$buff=$NULLSTR;

};

# ---   *   ---   *   ---
# work out file descriptor
# from a relative ptr

sub fd_solve($self,$ptr) {

  # out
  my $fd;
  my $buff;

  # dst idex OK
  my $valid=defined $ptr
    && $ptr =~ m[^\d+$]
    && $ptr <  @{$self->{fd}}
    ;

  # attempt fetch on fail
  if(! $valid) {
    my @path=$self->{scope}->path();
    $buff=$self->{scope}->get(@path,$ptr);

  # get buff && descriptor
  } else {
    $fd   = $self->{fd}->[$ptr];
    $buff = \($self->{fd_buff}->[$ptr]);

  };

  return ($fd,$buff);

};

# ---   *   ---   *   ---
1; # ret
