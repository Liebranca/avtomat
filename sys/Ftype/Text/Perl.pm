#!/usr/bin/perl
# ---   *   ---   *   ---
# PERL
# There's more than one way
# to embarrass yourself ;>
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Ftype::Text::Perl;
  use v5.42.0;
  use strict;
  use warnings;

  use lib "$ENV{ARPATH}/lib/sys/";
  use Arstd::Re qw(re_eaf);
  use Ftype::Text;


# ---   *   ---   *   ---
# make ice

BEGIN { Ftype::Text->new(

  name   => 'Perl',
  mag    => 'Perl script',

  ext    => '\.p[lm]$',
  hed    => '^#!.*perl',

  use_sigils => {type=>1},


  type=>[
    '([$%&@][\#]?$:name_re;>)',
    '([$%&@]\^[A-Z?\^_])',

    '([$%&@][0-9]+)',

    '([$%&@]\{\^?$:name_re;>\})',
    '(([$%&@]\{\^[?\^][0-9]+)\})',

  ],


  builtin=>[qw(
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

  directive=>[qw(
    use no package my our sub state

  )],

  intrinsic=>[qw(
    eq ne lt gt le ge cmp x can isa

  )],

  fctl=>[qw(
    continue else elsif do for
    foreach if unless until while
    goto next last redo reset return
    try catch finally throw

  )],

)};


# ---   *   ---   *   ---
1; # ret
