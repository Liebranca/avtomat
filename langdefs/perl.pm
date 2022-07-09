#!/usr/bin/perl
# ---   *   ---   *   ---
# perl && lyperl syntax

# ---   *   ---   *   ---

# deps
package langdefs::perl;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---

  Readonly my $OPS=>{

    q{->}=>[

      undef,
      undef,

      [-1,sub($x,$y) {return "$$x->$$y"}],

    ],q{!}=>[

      undef,
      [0,sub($x) {return "!$$x"}],

      undef,

    ],q{.}=>[

      undef,
      undef,

      [0,sub($x,$y) {return "$$x.$$y"}],

    ],q{=>}=>[

      undef,
      undef,

      [97,sub($x,$y) {return "$$x=>$$y"}],

    ],q{,}=>[

      [98,sub($x,$y) {return "$$x,"}],
      undef,

      [98,sub($x,$y) {return "$$x,$$y"}],

    ],q{!=}=>[

      undef,
      undef,

      [99,sub($x,$y) {return "$$x!=$$y"}],

    ],q{=}=>[

      undef,
      undef,

      [99,sub($x,$y) {return "$$x=$$y"}],

    ],

  };

# ---   *   ---   *   ---

BEGIN {

# ---   *   ---   *   ---
lang::def::nit(

  name=>'perl',
  ext=>'\.p[lm]$',
  hed=>'^#!.*perl',

  mag=>'Perl script',
  com=>'\#',

  drfc=>'(::|->)',

# ---   *   ---   *   ---

  op_prec=>$OPS,

  mcut_tags=>[qw(
    chars strings shcmd qstrs regexes

  )],

# ---   *   ---   *   ---

  sbl_decl=>q{

    \bsub\s*

    (?<name> $:names;>)?\s*
    (?<attrs> :$:names;>\s*)*

    \s*(?<args> \(.*?\))?\s*

    (?<scope> [{]

      (?<code> [^{}] | (?&scope))*

    [}])

  },

# ---   *   ---   *   ---

  types=>[

    '([$%&@][\#]?$:names;>)',
    '([$%&@]\^[A-Z?\^_])',

    '([$%&@][0-9]+)',

    '([$%&@]\{\^?$:names;>\})',
    '(([$%&@]\{\^[?\^][0-9]+)\})',

#    '([$%&@][!"\#\'()*+,.:;<=>?`|~-])',
#    '([$%&@]\{[!-/:-@\`|~]\})',

    '(\$[$%&@])',

  ],

  specifiers=>[qw(
    inlined

  )],

# ---   *   ---   *   ---

  buildtins=>[qw(

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

    push q qq qx rand read readdir readlink
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

  )],

  intrinsics=>[qw(
    eq ne lt gt le ge cmp x can isa

  )],

  fctls=>[qw(

    continue else elsif do for
    foreach if unless until while
    goto next last redo reset return
    try catch finally

  )],

# ---   *   ---   *   ---

# ugh, these effy line comments
);lang->perl->{lcom}=lang::eaf(

  lang::lkback(
    '$%&@\'"',
    lang->perl->com

  ),0,1
);

# ---   *   ---   *   ---

lang->perl->{hier_sort}=sub($rd) {

  my $id='-ROOT';
  my $block=$rd->select_block($id);
  my $tree=$block->{tree};

  my $nd_frame=$rd->{program}->{node};
  my @branches=$tree->branches_in(qr{^package$});

  my $i=0;

  for my $branch(@branches) {

    my $pkgname=$branch->{leaves}->[0]->{value};
    my $idex_beg=$branch->{idex}+1;
    my @children=@{$tree->{leaves}};

# ---   *   ---   *   ---

    my $ahead=$branches[$i+1];
    my $idex_end;

    if(defined $ahead) {
      $idex_end=$ahead->{idex};

    } else {
      $idex_end=$#children;

    };

# ---   *   ---   *   ---

    my $pkgroot=$nd_frame->nit($tree,$pkgname);

    @children=@children[$idex_beg..$idex_end];
    $pkgroot->pushlv(0,$branch,@children);

    $i++;

  };

};

# ---   *   ---   *   ---

};

# ---   *   ---   *   ---
1; # ret
