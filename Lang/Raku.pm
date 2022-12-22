#!/usr/bin/perl
# ---   *   ---   *   ---
# perl && lyperl syntax

# ---   *   ---   *   ---

# deps
package Lang::Raku;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use parent 'Lang::Def';

# ---   *   ---   *   ---

BEGIN {

  Readonly my $OPS=>Lang::quick_op_prec(

    q{->}=>$Lang::OP_B,

    q{!}=>$Lang::OP_R,
    q{?}=>$Lang::OP_R,
    q{~}=>$Lang::OP_B,

    q{<<}=>$Lang::OP_B,
    q{>>}=>$Lang::OP_B,

    q{|}=>$Lang::OP_B,
    q{&}=>$Lang::OP_B,
    q{^}=>$Lang::OP_B,

    q{**}=>$Lang::OP_B,
    q{*}=>$Lang::OP_B,

    q{/}=>$Lang::OP_B,
    q{%}=>$Lang::OP_B,
    q{%%}=>$Lang::OP_B,

    q{++}=>$Lang::OP_L|$Lang::OP_R,
    q{+}=>$Lang::OP_B,

    q{--}=>$Lang::OP_L|$Lang::OP_R,
    q{-}=>$Lang::OP_B,

    q{<}=>$Lang::OP_B,
    q{<=}=>$Lang::OP_B,

    q{>}=>$Lang::OP_B,
    q{>=}=>$Lang::OP_B,

    q{<=>}=>$Lang::OP_B,
    q{=~=}=>$Lang::OP_B,

    q{!=}=>$Lang::OP_B,
    q{==}=>$Lang::OP_B,

    q{||}=>$Lang::OP_B,
    q{&&}=>$Lang::OP_B,
    q{^^}=>$Lang::OP_B,

    q{.}=>$Lang::OP_B,
    q{=>}=>$Lang::OP_B,
    q{,}=>$Lang::OP_B,

# ---   *   ---   *   ---
# assignment ops

    q{=}=>$Lang::OP_B|$Lang::OP_A,

    q{asg}=>[

      q{=},

      [qw(. // * / % + - ^ & |)],
      [qw(=~ ++ --)],

    ]

  );

# ---   *   ---   *   ---

Lang::Raku->nit(

  name=>'Raku',
  ext=>'\.pm?6$',
  hed=>'^#!.*raku',

  mag=>

    'Program written in '.
    'the language formerly '.
    'known as Perl 6',

  drfc=>'(::|->|.)',

  lcom=>Lang::eaf(Lang::lkback(
    q{$%&@\'"},q{\#}

  )),

  names=>q{\b[_A-Za-z][_A-Za-z0-9\-\']*\b},
  names_u=>q{\b[_A-Z][_A-Z0-9\-\']*\b},
  names_l=>q{\b[_a-z][_a-z0-9\-\']*\b},

# ---   *   ---   *   ---

  op_prec=>$OPS,

  mcut_tags=>[qw(
    chars strings shcmd qstrs regexes

  )],

# ---   *   ---   *   ---

  sigils=>q{\\\\?[\$@%&]},

# ---   *   ---   *   ---

  fn_key=>q{sub|multi|method},

  fn_decl=>q{

    \b$:fn_key;>\s+

    (?<name> $:names;>)?\s*
    (?<attrs> :$:names;>\s*)*

    \s*(?<args> \([\S\s]*?\))?\s*

    (?<scope> [{]

      (?<code> [^{}] | (?&scope))*

    [}])

  },

# ---   *   ---   *   ---

  ptr_decl=>q{

    (?<keyw> my|our|state)\s*
    (?<sigil> $:sigils;>+)

    (?<name> $:names;>)\s*
    (?<attrs> :$:names;>\s*)*

  },

  ptr_defn=>q{

    (?<sigil> $:sigils;>+)
    (?<name> $:names;>)?\s*

  },

  ptr_asg=>q{

    (?:

      (?<is_decl> $:ptr_decl;>)
    | (?<is_defn> $:ptr_defn;>)

    ) (?: $:asg_op;>)\s*

  },

# ---   *   ---   *   ---

  types=>[

    '([$%&@][!*\.:<=?\^~]?$:names;>)',

  qw(

    Bag Baggy BagHash

    Allomorph Any Array
    Associative AST atomicint

    Attribute Backtrace Blob
    Block Bool Buf Callable CallFrame

    Cancellation Capture Channel
    Code Collation Compiler Complex

    ComplexStr CompUnit Cool
    CurrentThreadScheduler CX

    Date Dateish DateTime
    Distribution Distro Duration

    Encoding Endian Enumeration
    Exception Failure FatRat

    ForeignCode Grammar Hash
    HyperSeq HyperWhatever

    Instant Int int IntStr
    IO Iterable Iterator

    Junction Kernel Label List
    Lock Macro Map Match

    Metamodel Method Mix MixHash
    Mixy Mu NFC NFD NFKC NFKD

    Nil Num Numeric NumStr ObjAt
    Order Pair Parameter Perl Pod

    Positional PositionalBinFailover
    PredictiveIterator Proc

    Promise Proxy PseudoStash
    QuantHash RaceSeq Raku Range

    Rat Rational RatStr Real Regex
    Routine Scalar Scheduler

    Semaphore Seq Sequence Set
    SetHash Setty Signature

    Slip Stash Str StrDistance
    Stringy Sub Submethod Supplier

    Supply Systemic Tap Telemetry
    Test Thread ThreadPoolScheduler

    UInt Uni utf8 ValueObjAt Variable
    Version VM Whatever WhateverCode

    X

  ),

  ],

  specifiers=>[qw(
    proto

  )],

# ---   *   ---   *   ---

  builtins=>[qw(

    accept alarm atan2 bin bind binmode
    bless blessed

    caller chdir chmod chop chown chroot close
    closedir connect cos crypt croak

    dbmclose dbmopen defined delete die dump
    each eof eval exec exists exit exp

    fcntl fileno flock fork

    getc getlogin getpeername getpgrp getppid
    getpriority getpwnam gethostbyname

    getnetbyname getprotobyname getservbyname
    getpwuid getgrgid gethostbyaddr getnetbyaddr

    getprotobynumber getservbyport

    getpwent getgrent gethostent
    getnetent getprotoent getservent

    setpwent setgrent sethostent
    setnetent setprotoent setservent

    endpwent endgrent endhostent
    endnetent endprotoent endservent

    getsockname getsockopt gmtime grep hex
    index int ioctl join keys kill

    length link listen local localtime
    log lstat m map mkdir

    msgctl msgget msgsnd msgrcv oct open
    opendir ord pack pipe pop print printf

    push q qq qx qr rand read readdir readlink
    readline recv rename require ref

    reverse rewinddir rindex rmdir

    s scalar seek seekdir select semctl semget
    semop send setpgrp setpriority setsockopt

    shift shmctl shmget shmread shmreadline
    shmwrite shutdown sin sleep socket socketpair

    sort splice split sprintf sqrt srand stat
    study substr symlink syscall sysread system

    say

    syswrite tell telldir time tr truncate

    umask undef unlink unpack unshift
    utime values vec wait waitpid

    wantarray warn write

  )],

# ---   *   ---   *   ---

  directives=>[qw(
    use no package my our sub state
    class method multi unit
    subset where os of is has
    role does module

  )],

  intrinsics=>[qw(
    eq ne lt gt le ge cmp x can isa
    rw

  )],

  fctls=>[qw(

    continue else elsif do for
    foreach if unless until while
    goto next last redo reset return
    try catch finally repeat loop
    grammar regex token rule

  )],

# ---   *   ---   *   ---

);
};

# ---   *   ---   *   ---

sub hier_sort($self,$rd) {

  my $id='-ROOT';
  my $block=$rd->select_block($id);
  my $tree=$block->{tree};

  my $nd_frame=$rd->{program}->{node};
  my @branches=$tree->branches_in(qr{^package$});

  my $i=0;
  my @scopes=();

# ---   *   ---   *   ---

  for my $branch(@branches) {

    $branch->{parent}->idextrav();

    my $pkgname=$branch->{leaves}->[0]->{value};
    my $idex_beg=$branch->{idex};
    my @children=@{$tree->{leaves}};

# ---   *   ---   *   ---

    my $ahead=$branches[$i+1];
    my $idex_end;

    if(defined $ahead) {
      $idex_end=$ahead->{idex}-1;

    } else {
      $idex_end=$#children;

    };

# ---   *   ---   *   ---

    @children=@children[$idex_beg..$idex_end];
    @children=$tree->pluck(@children);

    my $pkgroot=$nd_frame->nit(undef,$pkgname);
    push @scopes,$pkgroot;

    $pkgroot->clear_branches();
    $pkgroot->pushlv(@children);
    $i++;

# ---   *   ---   *   ---

  };

  $tree->clear_branches();
  $tree->pushlv(@scopes);

};

# ---   *   ---   *   ---
1; # ret
