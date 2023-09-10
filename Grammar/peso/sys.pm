#!/usr/bin/perl
# ---   *   ---   *   ---
# PESO SYS
# Do you even int $80?
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::peso::sys;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Int;
  use Arstd::Re;
  use Arstd::IO;
  use Arstd::PM;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Grammar;
  use Grammar::peso::std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

BEGIN {

  # beqs
  $PE_STD->use_common();
  $PE_STD->use_eye();

  # class attrs
  fvars('Grammar::peso::file');


  # attr defaults
  Readonly my $PE_SYSF=>{

    'alloc'   => [qw(ptr size)],
    'dealloc' => [qw(ptr size)]

  };

# ---   *   ---   *   ---
# GBL

  our $REGEX={
    q[sys-key] => re_pekey(qw(sys)),

  };

# ---   *   ---   *   ---
# parser rules

  rule('~<sys-key>');
  rule('$<sys> sys-key nterm term');

# ---   *   ---   *   ---
# ^post-parse

sub sys($self,$branch) {

  my ($type,$fn,$args)=
    $self->rd_name_nterm($branch);

  $type   = lc $type;

  $fn   //= [];
  $args //= [];


  # get line for debug
  my $nterm=$branch->{leaves}->[-1];
     $nterm=$nterm->{value};


  # ^repack
  $branch->{value}={

    type => $type,

    fn   => $fn,
    args => $args,

    db   => $nterm,

  };

  $branch->clear();

};

# ---   *   ---   *   ---
# ^bind

sub sys_walk($self,$branch) {

  my $st   = $branch->{value};

  my $type = $st->{type};
  my $fn   = $st->{fn};
  my $args = $st->{args};

  my $db   = $st->{db};


  # validate passed F
  throw_no_sysf($type,$db) if ! $fn->[0];
  $fn=$self->deref($fn->[0],key=>1)->get();

  throw_sysf($fn)
  if ! exists $PE_SYSF->{$fn};


  # ^validate argcnt
  my $src=$PE_SYSF->{$fn};

  throw_sysargs($fn,$args,$src)
  if int(@$args) != int(@$src);


  # reset
  $st->{fn}=$fn;

};

# ---   *   ---   *   ---
# ^errme for missing F

sub throw_no_sysf($type,$db) {

  errout(

    q[SYSF missing at [ctl]:%s [err]:%s],

    lvl  => $AR_FATAL,
    args => [$type,$db],

  );

};

# ---   *   ---   *   ---
# ^F not found

sub throw_sysf($fn) {

  errout(

    q[Invalid SYSF: [err]:%s],

    lvl  => $AR_FATAL,
    args => [$fn],

  );

};

# ---   *   ---   *   ---
# ^bad argcnt

sub throw_sysargs($fn,$args,$src) {

  errout(

    q[Got (:%u) args for [ctl]:%s -- ]
  . q[expected (:%u)],

    lvl  => $AR_FATAL,
    args => [int(@$args),$fn,int(@$src)],

  );

};

# ---   *   ---   *   ---
# asm fcall proto

sub _temple_fargs($self,@args) {

  my @out = ();
  my @r   = qw(rdi rsi rdx r10 r8 r9);

  while(@args) {

    my $dst=shift @r;
    my $src;

    if($dst) {
      $src=shift @args;
      push @out,"  mov $dst,$src";

    } else {
      $src=pop @args;
      push @out,"  push $src";

    };

  };


  return @out;

};

# ---   *   ---   *   ---
# ^adds mov rax for syscall

sub _temple_syscall($self,$id,@args) {

  return

    $self->_temple_fargs(@args),

    "  mov rax,$id",
    "  syscall"

  ;

};

# ---   *   ---   *   ---
# alloc args proto

sub _alloc_args($self,$ptr,$size) {

  # align size to page
  $size=$self->deref($size,-key=>1)->get();
  $size=int_align($size,0x1000);

  # get destination addr
  $ptr=$self->deref($ptr);
  $ptr=(Mach::Value->is_valid($ptr))
    ? $ptr->get_fasm_lis()
    : $ptr
    ;

  return ($ptr,$size);

};

# ---   *   ---   *   ---
# mmap wrapper

sub sysf_alloc($self,$ptr,$size) {

  # deref
  ($ptr,$size)=$self->_alloc_args($ptr,$size);

  # pass args
  my @out=$self->_temple_syscall(

    '$09',

    '$00',$size,
    qw($03 $22 -1 $00)

  );


  # ^cat
  push    @out,"  mov [$ptr],rax";
  unshift @out,'  ; mmap N pages';


  return join "\n",@out,"\n";

};

# ---   *   ---   *   ---
# ^munmap

sub sysf_dealloc($self,$ptr,$size) {

  # deref
  ($ptr,$size)=$self->_alloc_args($ptr,$size);

  # pass args
  my @out=$self->_temple_syscall(
    '$0B',"[$ptr]",$size

  );


  # ^cat
  unshift @out,'  ; munmap N pages';

  return join "\n",@out,"\n";

};

# ---   *   ---   *   ---
# out codestr

sub sys_fasm_xlate($self,$branch) {

  my $st   = $branch->{value};

  my $fn   = $st->{fn};
     $fn   = "sysf_$fn";

  my $args = $st->{args};

  $branch->{fasm_xlate}=$self->$fn(@$args);

};

# ---   *   ---   *   ---
# do not make a parser tree!

  our @CORE=qw();

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
1; # ret
