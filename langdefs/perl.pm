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
  use peso::defs;

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

use constant DIRECTIVE=>{

  'clan'=>[sbl_id,'1<bare>'],
  'reg'=>[sbl_id,'1<bare>'],
  'proc'=>[sbl_id,'1<bare>'],

};

# ---   *   ---   *   ---

use constant TYPE=>{

  'str'=>undef,
  'buf'=>undef,
  'tab'=>undef,

  'value_decl'=>[sbl_id,'1<op|bare>:*1<op|bare>'],

};

# ---   *   ---   *   ---

use constant SPECIFIER=>{

  'ptr'=>undef,

  'nihil'=>undef,
  'stark'=>undef,
  'signal'=>undef,

};

# ---   *   ---   *   ---

use constant INTRINSIC=>{

  'null'=>[sbl_id,'0'],
  'self'=>[sbl_id,'*1<op>'],
  'lis'=>[sbl_id,'1<bare>:*1<op|ptr|bare>'],

};

# ---   *   ---   *   ---

use constant FCTL=>{

  'eif'=>[sbl_id,'2<op>:*1<ptr>'],
  'jif'=>[sbl_id,'2<op>:*1<ptr>'],
  'ret'=>[sbl_id,'1<op|ptr|bare>'],

};

# ---   *   ---   *   ---
# utility methods

# DEPRECATED
sub typecon($) {

  my $key=shift;

  my $trtab={

    '$'=>'SCALAR',
    '@'=>'ARRAY',
    '%'=>'HASH',

  };

# ---   *   ---   *   ---

  my $fchar=$key;
  my $name=$key;

  $fchar=~ s/^([^_A-Za-z][^_A-Za-z0-9]*).+/$1/;

  my $type=$trtab->{$fchar};
  my $longname=$name;

  $name=~ s/^\Q${fchar}//;
  $longname=~ s/^\Q${fchar}/${type}_/;

  return ($fchar,$name,$longname);

};

# ---   *   ---   *   ---

sub beg_reg($) {

  my $program=shift;
  my $cur=$program->{defs}->{cur};

  return "BEG_reg_$cur->{key}";

# ---   *   ---   *   ---

};sub end_reg($) {

  my $program=shift;
  my $cur=$program->{defs}->{cur};

  my $beg;for my $node(@{$program->{tree}}) {

    if($node->value eq "BEG_reg_$cur->{key}") {
      $beg=$node;
      last;

    };
  };

# ---   *   ---   *   ---

  my $ref=$cur->{ref};
  my %attrs=@{$ref->{attrs}};

  my $fields='';
  my $getters='';

# ---   *   ---   *   ---

  my $i=0;
  for my $key(keys %attrs) {

    my $value=$attrs{$key};

    $fields.="\n$key=>".
      "(defined \$attrs{$key})".
      "\n?\$attrs{$key}\n:$value,\n"

    ;$i++;

  };

  $ref->{attrs}=\%attrs;

# ---   *   ---   *   ---

  $beg->value("sub new {my \%attrs=\@_;");

  return ''.

    "return bless".
    "{\n$fields\n},".
    "'$cur->{key}';}"

  ;

};

# ---   *   ---   *   ---


sub beg_proc($) {

  my $program=shift;
  my $cur=$program->{defs}->{cur};

  return "BEG_proc_$cur->{key}";

};sub end_proc($) {

  my $program=shift;
  my $cur=$program->{defs}->{cur};

  my $beg;for my $node(@{$program->{tree}}) {

    if($node->value eq "BEG_proc_$cur->{key}") {
      $beg=$node;
      last;

    };
  };

# ---   *   ---   *   ---
# here we'd handle args and return type
# we'll do that later on...

  $beg->value('($) {my $self=shift;');

  return "}";

};

# ---   *   ---   *   ---

BEGIN {
  sbl_new();

# ---   *   ---   *   ---

DEFINE 'clan',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0)=@fields;
  my $m=$frame->master;

  my $name=$f0->[0];
  my $ret='';

  if(exists $m->{defs}->{frames}->{$name}) {

    $ret="ERROR:Redeclaration of type $name";
    goto END;

  };

# ---   *   ---   *   ---
# create block

  $m->{defs}->{types}->{$name}=bless {

    attrs=>[],
    procs=>{},

  },'lyperl::frame';

# ---   *   ---   *   ---
# create block reference

  $m->{defs}->{cur}={

    key=>$name,
    tag=>'types',

    ref=>$m->{defs}->{types}->{$name},
    lvl=>$m->{defs}->{lvl},

    beg=>\&beg_class,
    end=>\&end_class,

  };$ret="package $name;";

  END:
  return $ret;

};

# ---   *   ---   *   ---

DEFINE 'reg',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0)=@fields;
  my $m=$frame->master;

  my $name=$f0->[0];
  my $ret='';

  if(exists $m->{defs}->{types}->{$name}) {

    $ret="ERROR:Redeclaration of type $name";
    goto END;

  };

# ---   *   ---   *   ---
# create block

  $m->{defs}->{types}->{$name}=bless {

    attrs=>[],
    procs=>{},

  },'lyperl::class';

# ---   *   ---   *   ---
# create block reference

  $m->{defs}->{cur}={

    key=>$name,
    tag=>'types',

    ref=>$m->{defs}->{types}->{$name},
    lvl=>$m->{defs}->{lvl},

    beg=>\&beg_class,
    end=>\&end_class,

  };$ret="package $name;";

  END:
  return $ret;

};

# ---   *   ---   *   ---

DEFINE 'proc',DIRECTIVE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0)=@fields;
  my $m=$frame->master;

  my $path=$f0->[0];
  my $ret='';

  if(exists $m->{defs}->{procs}->{$path}) {

    $ret="ERROR:Redefinition of method $path";
    goto END;

  };

# ---   *   ---   *   ---
# read path

  my ($name,$base);

  { my @ar=split '::',$path;

    $name=pop @ar;
    $base=join '::',@ar;

  };

# ---   *   ---   *   ---
# create block

  $m->{defs}->{procs}->{$path}=bless {

    args=>[],
    type=>undef,

    base=>$base,

  },'lyperl::proc';

# ---   *   ---   *   ---
# create block reference

  $m->{defs}->{cur}={

    key=>$path,
    tag=>'procs',

    ref=>$m->{defs}->{procs}->{$path},
    lvl=>$m->{defs}->{lvl},

    beg=>\&beg_proc,
    end=>\&end_proc,

  };$ret="sub $name";

# ---   *   ---   *   ---
# register proc to class

  $m->{defs}->{types}
    ->{$base}->{procs}
    ->{$name}

  =$m->{defs}->{procs}->{$path};

# ---   *   ---   *   ---

  END:
  return $ret;

};

# ---   *   ---   *   ---

DEFINE 'value_decl',TYPE,sub {

  my ($inskey,$frame,@fields)=@_;
  my ($f0,$f1)=@fields;
  my $m=$frame->master;

  my $trtab={

    'str'=>undef,

    'buf'=>[qw([ ])],
    'obj'=>[qw({ })],

  };

  my ($name,$value)=($f0->[0],$f1->[0]);

  if(defined $trtab->{$inskey}) {

    $value=''.

      $trtab->{$inskey}->[0].
      ((defined $value) ? $value : '').
      $trtab->{$inskey}->[1]

    ;

  };

  my $ref=$m->{defs}->{cur}->{ref};
  push @{$ref->{attrs}},($name,$value);

  return '';

};

# ---   *   ---   *   ---
# ^type keywords alias value_decl

#:!;> we might want to change
#:!;> this based on context

ALIAS 'str','value_decl';
ALIAS 'buf','value_decl';
ALIAS 'tab','value_decl';

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
  -SBL=>$SBL_TABLE,

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
    '(([$%&@]\{\^[?\^][0-9]+)\})',

    '([$%&@][!"#\'()*+,.:;<=>?`|~-])',
    '([$%&@]\{[!-/:-@\`|~]\})',

    '(\$[$%&@])',

    (keys %{&TYPE}),

  ],

  -SPECIFIERS=>[qw(

    ),(keys %{&SPECIFIER})

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

  ),(keys %{&DIRECTIVE})],

  -INTRINSICS=>[qw(
    eq ne lt gt le ge cmp x can isa

  ),(keys %{&INTRINSIC})],

  -FCTLS=>[qw(

    continue else elsif do for
    foreach if unless until while
    goto next last redo reset return
    try catch finally

  ),(%{&FCTL})],

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
