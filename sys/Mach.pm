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

  use Arstd::Bytes;
  use Arstd::Array;
  use Arstd::String;
  use Arstd::Re;
  use Arstd::IO;

  use Mach::Seg;
  use Mach::Struc;
  use Mach::Reg;
  use Mach::Opcode;

  use Mach::Scope;
  use Mach::Value;

  use parent 'St';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
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

  my $Icemap={};

# ---   *   ---   *   ---
# constructor

sub new($class,%O) {

  # defaults
  $O{reg_struc} //= 'Anima';
  $O{optab}     //= ['Mach::Micro'];

  $O{idex}      //= 0;

  $O{fd}        //= [*STDIN,*STDOUT,*STDERR];


  # nit buffs for each standard
  # file descriptor
  my $fd_buff=[
    ($NULLSTR) x int(@{$O{fd}})

  ];


  # make ice
  my $frame = $class->get_frame($O{idex});
  my $self  = bless {

    reg      => undef,
    regmask  => 0,

    fast_seg => [],

    optab    => undef,

    stk      => [],
    stk_top  => 0,

    fd       => $O{fd},
    fd_buff  => $fd_buff,

    scope    => Mach::Scope->new(),

    frame    => $frame,

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


  return $self;

};

# ---   *   ---   *   ---
# ^retrieve or make

sub fetch($class,$id,%O) {

  my $out=undef;

  # create and save
  if(! exists $Icemap->{$id}) {
    $out=$class->new(%O);
    $Icemap->{$id}=$out;

  # get existing
  } else {
    $out=$Icemap->{$id};

  };

  return $out;

};

# ---   *   ---   *   ---
# ^retrieve memory segment

sub segfetch($self,@at) {

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

    my $frame  = Mach::Seg->get_frame($loc);
       $icebox = $frame->{-icebox};

  };

  return $icebox->[$addr];

};

# ---   *   ---   *   ---
# ^make new segment

sub segnew($self,$name,$size,%O) {

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
# write instructions to executable segment

sub xs_write($self,$key,@ins) {

  my $tab=$self->{optab};
  my $reg=$self->{reg};

  my $mem=$reg->{xs}->ptr_deref();
  my $ptr=$mem->brush();

  map {$tab->write($ptr,@$ARG)} @ins;

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
  map {
    my ($fn,@args)=@$ARG;
    $fn->(@args);

  } $self->xs_read();

  $O{epilogue}->();

};

# ---   *   ---   *   ---
# transform string to instructions

sub ipret($self,$s) {

  state $nterm=re_escaped(

    ';',

    mod   => '*',
    sigws => 1,

  );

  state $sep=re_sursplit_new($COMMA_RE,'\s*');

  my @out = ();

  my $ins = $self->{optab}->{re};
  my $re  = qr{$ins \s+ (?<nterm> $nterm) ;}x;

  strip(\$s);
  comstrip(\$s);

  my $fet=sub ($s) {

    state $is_addr = qr{^\[|\]$}x;

    my $ind=int($s=~ s[$is_addr][]sxmg);

    my $cpy=$s;

    my $ptr=

       $self->{scope}->cderef(0,\$cpy,'SYS')
    or $self->{scope}->cderef(0,\$cpy)

    ;

    # immediate
    return sstoi($cpy) if ! $ptr;


    # ^segment
    my $out=Mach::Struc->validate(
      $$ptr->deref()

    );

    if($ind) {
      my ($loc,$addr)=array_keys($out->{addr});
      $out=$addr | ($loc << 32);

    };

    return $out;

  };

  while($s=~ s[$re][]) {

    my @args=grep {
      defined $ARG

    } map {
      $fet->($ARG);

    } split $sep,$+{nterm};

    push @out,[$+{ins},@args];

  };

  return @out;

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
# blank value

sub null($self,$type='void') {
  return $self->vice($type,raw=>$NULL);

};

# ---   *   ---   *   ---
# make unbound value ice

sub vice($self,$type,%O) {

  return Mach::Value->new(
    $type,$NULLSTR,%O

  );

};

# ---   *   ---   *   ---
# ^declare

sub decl($self,$type,$id,%O) {

  my @path  = decl_prologue(\%O);
  my $value = Mach::Value->new($type,$id,%O);

  my $ptr   = $value->bind($self->{scope},@path);

  return $ptr;

};

# ---   *   ---   *   ---
# ^shorthand for existing values

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
