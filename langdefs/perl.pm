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

# ---   *   ---   *   ---

lang::def::nit(

  -NAME => 'perl',
  -EXT  => '\.p[lm]$',
  -HED  => '^#!.*perl',

  -MAG  => 'Perl script',

  -COM  => '#',

  -DRFC => '(::|->)',

# ---   *   ---   *   ---

  -TYPES=>[

    '([$%&@][#]?$:names;>)',
    '([$%&@]\^[A-Z?\^_])',

    '([$%&@][0-9]+)',

    '([$%&@]\{\^?$:names;>\})',
    '([$%&@]\{\^[?\^][0-9]+)\})',

    '([$%&@][!"#\'()*+,.:;<=>?`|~-])',
    '([$%&@]\{[!-/:-@\`|~]\})',

    '(\$[$%&@])',

  ],

# ---   *   ---   *   ---

  -BUILTINS=>[qw(

    accept alarm atan2 bin bind binmode

    caller chdir chmod chop chown chroot close
    closedir connect cos crypt

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
    log lstat m mkdir

    msgctl msgget msgsnd msgrcv next oct open
    opendir ord pack pipe pop print printf

    push q qq qx rand read readdir readlink
    readline recv rename require

    reverse rewinddir rindex rmdir

    s scalar seek seekdir select semctl semget
    semop send setpgrp setpriority setsockopt

    shift shmctl shmget shmread shmreadline
    shmwrite shutdown sin sleep socket socketpair

    sort splice split sprintf sqrt srand stat
    study substr symlink syscall sysread system

    syswrite tell telldir time tr try truncate

    umask undef unlink unpack unshift
    utime values vec wait waitpid

    wantarray warn write

  )],

# ---   *   ---   *   ---

  -DIRECTIVES=>[qw(
    use package my our sub

  )],

  -INTRINSICS=>[qw(
    eq ne lt gt le ge cmp x can isa

  )],

  -FCTLS=>[qw(

    continue else elsif do for
    foreach if unless until while
    goto next last redo reset return

  )],

# ---   *   ---   *   ---

# ugh, these effy line comments
);lang->perl->{-LCOM}=lang::eaf(

  lang::lkback(
    '$%&@\'"',
    lang->perl->com

  ),0,1

);

# ---   *   ---   *   ---
1; # ret

