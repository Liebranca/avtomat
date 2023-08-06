#!/usr/bin/perl
# ---   *   ---   *   ---
# perl && lyperl syntax

# ---   *   ---   *   ---

# deps
package Lang::Perl;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Arstd::Re;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Lang;

  use parent 'Lang::Def';

# ---   *   ---   *   ---

BEGIN {

  Readonly my $OPS=>Lang::quick_op_prec(

    q{->}=>$Lang::OP_B,

    q{!}=>$Lang::OP_R,
    q{~}=>$Lang::OP_R,

    q{<<}=>$Lang::OP_B,
    q{>>}=>$Lang::OP_B,

    q{|}=>$Lang::OP_B,
    q{&}=>$Lang::OP_B,
    q{^}=>$Lang::OP_B,

    q{**}=>$Lang::OP_B,
    q{*}=>$Lang::OP_B,

    q{/}=>$Lang::OP_B,
    q{%}=>$Lang::OP_B,

    q{++}=>$Lang::OP_L|$Lang::OP_R,
    q{+}=>$Lang::OP_B,

    q{--}=>$Lang::OP_L|$Lang::OP_R,
    q{-}=>$Lang::OP_B,

    q{<}=>$Lang::OP_B,
    q{<=}=>$Lang::OP_B,

    q{>}=>$Lang::OP_B,
    q{>=}=>$Lang::OP_B,

    q{<=>}=>$Lang::OP_B,

    q{!=}=>$Lang::OP_B,
    q{==}=>$Lang::OP_B,

    q{||}=>$Lang::OP_B,
    q{&&}=>$Lang::OP_B,

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

Lang::Perl->nit(

  name=>'Perl',
  ext=>'\.p[lm]$',
  hed=>'^#!.*perl',

  mag=>'Perl script',

  drfc=>'(::|->)',

  lcom=>re_eaf(re_lbeg('#',0),opscape=>0),

# ---   *   ---   *   ---

  op_prec=>$OPS,

  mcut_tags=>[qw(
    chars strings shcmd qstrs regexes

  )],

# ---   *   ---   *   ---

  sigils=>q{\\\\?[\$@%&]},

# ---   *   ---   *   ---

  fn_key=>q{sub},

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

    '([$%&@][\#]?$:names;>)',
    '([$%&@]\^[A-Z?\^_])',

    '([$%&@][0-9]+)',

    '([$%&@]\{\^?$:names;>\})',
    '(([$%&@]\{\^[?\^][0-9]+)\})',

#    '([$%&@][!"\#\'()*+,.:;<=>?`|~-])',
#    '([$%&@]\{[!-/:-@\`|~]\})',

#    '(\$[$%&@])',

  ],

  specifiers=>[qw(
    inlined

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

    $pkgroot->clear();
    $pkgroot->pushlv(@children);
    $i++;

# ---   *   ---   *   ---

  };

  $tree->clear();
  $tree->pushlv(@scopes);

};

# ---   *   ---   *   ---
1; # ret
