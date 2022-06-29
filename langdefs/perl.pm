#!/usr/bin/perl
# ---   *   ---   *   ---
# perl && lyperl syntax

# ---   *   ---   *   ---

# deps
package langdefs::perl;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
  use langdefs::peso;

# ---   *   ---   *   ---

use constant OPS=>{

  '->'=>[

    undef,
    undef,

    [-1,sub {my ($x,$y)=@_;return "$$x->$$y";}],

  ],'.'=>[

    undef,
    undef,

    [0,sub {my ($x,$y)=@_;return "$$x.$$y";}],

  ],'=>'=>[

    undef,
    undef,

    [97,sub {my ($x,$y)=@_;return "$$x=>$$y";}],

  ],','=>[

    [98,sub {my ($x,$y)=@_;return "$$x,";}],
    undef,

    [98,sub {my ($x,$y)=@_;return "$$x,$$y";}],

  ],'='=>[

    undef,
    undef,

    [99,sub {my ($x,$y)=@_;return "$$x=$$y";}],
  ],

};

# ---   *   ---   *   ---

BEGIN {

# ---   *   ---   *   ---
lang::def::nit(

  -NAME => 'perl',
  -EXT  => '\.p[lm]$',
  -HED  => '^#!.*perl',

  -MAG  => 'Perl script',
  -COM  => '#',

  -DRFC => '(::|->)',

# ---   *   ---   *   ---

  -DEL_OPS=>'[\(\[\{\}\]\)]',

  -NDEL_OPS=>''.
    '[^\s_A-Za-z0-9\.:\{'.
    '\[\(\)\]\}\\\\@$&]'.
    '|(^|\s|[^\\\\])[&%]',

  -OP_PREC=>OPS,
  #-SBL=>,

  -MCUT_TAGS=>[-STRING,-CHAR,-PESC],

  -EXP_RULE=>sub ($) {

    my $rd=shift;

    my $pesc=lang::CUT_TOKEN_RE;
    $pesc=~ s/\[A-Z\]\+/PESC/;

    while($rd->{line}=~ s/^(${pesc})//) {
      push @{$rd->{exps}},{
        body=>$1,
        has_eb=>0,
        lineno=>$rd->{lineno},

      };

    };

  },

# ---   *   ---   *   ---

  -TYPES=>[

    '([$%&@][#]?$:names;>)',
    '([$%&@]\^[A-Z?\^_])',

    '([$%&@][0-9]+)',

    '([$%&@]\{\^?$:names;>\})',
    '(([$%&@]\{\^[?\^][0-9]+)\})',

    '([$%&@][!"#\'()*+,.:;<=>?`|~-])',
    '([$%&@]\{[!-/:-@\`|~]\})',

    '(\$[$%&@])',

    (keys %{langdefs::peso->TYPE}),

  ],

  -SPECIFIERS=>[qw(

    ),(keys %{langdefs::peso->SPECIFIER})

  ],

# ---   *   ---   *   ---

  -BUILTINS=>[qw(

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

  ),keys %{langdefs::peso->BUILTIN}],

# ---   *   ---   *   ---

  -DIRECTIVES=>[qw(
    use package my our sub state

  ),(keys %{langdefs::peso->DIRECTIVE})],

  -INTRINSICS=>[qw(
    eq ne lt gt le ge cmp x can isa

  ),(keys %{langdefs::peso->INTRINSIC})],

  -FCTLS=>[qw(

    continue else elsif do for
    foreach if unless until while
    goto next last redo reset return
    try catch finally

  ),(keys %{langdefs::peso->FCTL})],

# ---   *   ---   *   ---

# ugh, these effy line comments
);lang->perl->{-LCOM}=lang::eaf(

  lang::lkback(
    '$%&@\'"',
    lang->perl->com

  ),0,1

);
};

# ---   *   ---   *   ---
1; # ret
