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

use constant LYPERL_DIRECTIVES=>qw(
  class

);

use constant LYPERL_TYPES=>qw(


);

# ---   *   ---   *   ---

my $perl_sbl=undef;

sub DEFINE($$$) {

  $perl_sbl->DEFINE(
    $_[0],$_[1],$_[2],

  );
};

# ---   *   ---   *   ---

sub ALIAS($$) {

  $perl_sbl->DEFINE(
    $_[0],$_[1],$_[2],

  );
};

# ---   *   ---   *   ---

my $SBL_ID=0;sub sbl_id() {return $SBL_ID++;};

# ---   *   ---   *   ---

use constant OPS=>{

  '->'=>[

    undef,
    undef,

    [-1,sub {my ($x,$y)=@_;return "$$x->$$y";}],

  ],'.'=>[

    undef,
    undef,

    [-1,sub {

      my ($x,$y)=@_;



      return "$$x.$$y";

    }],

  ],

};

# ---   *   ---   *   ---

use constant DIRECTIVE=>{

  'class'=>[sbl_id,'1<bare>'],

};

# ---   *   ---   *   ---
# utility methods

sub beg_class($) {

  my $program=shift;
  my $cur=$program->{defs}->{cur};

  return "BEG_class_$cur->{key}";

# ---   *   ---   *   ---

};sub end_class($) {

  my $program=shift;
  my $cur=$program->{defs}->{cur};

  my $beg;for my $node(@{$program->{tree}}) {

    if($node->value eq "BEG_class_$cur->{key}") {
      $beg=$node;
      last;

    };
  };

  my $args='$';
  $beg->value(

    'sub nit($'.$args.") {\n".
    'my $self=shift;'."\n"


  );

  return "return bless {},'$cur->{key}';\n}";

};

# ---   *   ---   *   ---

BEGIN {
$perl_sbl=peso::sbl::new_frame();

# ---   *   ---   *   ---

DEFINE 'class',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0)=@fields;
  my $m=$frame->master;

  my $name=$f0->[0];

  # TODO: add line number to error
  if(exists $m->{defs}->{types}->{$name}) {
    print "Redeclaration of type $name\n";
    exit;

  };

  $m->{defs}->{types}->{$name}=bless {

    attrs=>{},
    procs=>{},

  },'lyperl::class';

  $m->{defs}->{cur}={

    key=>$name,
    tag=>'types',

    ref=>$m->{defs}->{types}->{$name},
    lvl=>$m->{defs}->{lvl},

    beg=>\&beg_class,
    end=>\&end_class,

  };return "package $name;";

};

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
    '\[\(\)\]\}\\\\$&]'.
    '|(^|\s|[^\\\\])[&%]',

  -OP_PREC=>OPS,
  -SBL=>$perl_sbl,

  -MCUT_TAGS=>[-STRING,-CHAR,-PESC],

  -EXP_RULE=>sub ($) {

    my $rd=shift;

    my $pesc=lang::cut_token_re;
    $pesc=~ s/\[A-Z\]\+/PESC/;

    while($rd->{-LINE}=~ s/^(${pesc})//) {
      push @{$rd->exps},{body=>$1,has_eb=>0};

    };

  },

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
    bless blessed

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

    msgctl msgget msgsnd msgrcv oct open
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

    syswrite tell telldir time tr truncate

    umask undef unlink unpack unshift
    utime values vec wait waitpid

    wantarray warn write

  )],

# ---   *   ---   *   ---

  -DIRECTIVES=>[qw(
    use package my our sub

  ),LYPERL_DIRECTIVES],

  -INTRINSICS=>[qw(
    eq ne lt gt le ge cmp x can isa

  )],

  -FCTLS=>[qw(

    continue else elsif do for
    foreach if unless until while
    goto next last redo reset return
    try catch finally

  )],

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
