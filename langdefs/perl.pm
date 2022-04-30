#!/usr/bin/perl
# ---   *   ---   *   ---
# perl res

# ---   *   ---   *   ---

# deps
package langdefs::perl;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---

sub SYGEN_KEY {return -PERL;};
sub RC_KEY {return 'perl';};

# ---   *   ---   *   ---

my %PERL=(

  -NAME => 'perl',
  -EXT  => '\.p[lm]$',
  -HED  => '^#!.*perl',

  -MAG  => 'Perl script',

  -COM  => '#',

# ---   *   ---   *   ---

  -VARS =>[

    [0x04,'[$%&@]('.

      '('.lang::_LUN.'*|'.

      '\^[][A-Z?\^_]|[0-9]+\b)|'.

      '(\{(\^?'.lang::_LUN.'*|'.
      '\^[][?\^][0-9]+)\})|'.

      '(([][!"#\'()*+,.:;<=>?`|~-]|'.
      '\{[][!-/:-@\`|~]\})|\$[$%&@])|'.

      '((^|[[:blank:]])[$%@][/\\\\])'.

    ')'

    ],

  ],

# ---   *   ---   *   ---

  -BILTN =>[

    [0x01,lang::eiths(

      'accept,alarm,atan2,bin(d|mode),'.

      'c(aller|h(dir|mod|op|own|root)|lose(dir)?'.
      '|onnect|os|rypt),'.

      'd(bm(close|open)|efined|elete|ie|o|ump),'.

      'e(ach|of|val|x(ec|ists|it|p)),'.
      'f(cntl|ileno|lock|ork),'.

      'get(c|login|peername|pgrp|ppid|priority'.
      '|pwnam|(host|net|proto|serv)byname'.
      '|pwuid|grgid|(host|net)byaddr'.
      '|protobynumber|servbyport)'.

      '([gs]et|end)(pw|gr|host|net|proto|serv)ent,'.

# ---   *   ---   *   ---

      'getsock(name|opt),'.
      'gmtime,goto,grep,hex,index,int,ioctl,join,'.

      'keys,kill,last,length,link,listen,'.
      'local(time)?,log,lstat,m,mkdir,'.

      'msg(ctl|get|snd|rcv),next,oct,open(dir)?,'.
      'ord,pack,pipe,pop,printf?,push,'.

      'q,qq,qx,rand,re(ad(dir|link)?,'.

      'cv|do|name|quire|set|turn|verse|winddir),'.

      'rindex,rmdir,s,scalar,seek(dir)?,'.

      'se(lect|mctl|mget|mop|nd|tpgrp'.
      '|tpriority|tsockopt),'.

# ---   *   ---   *   ---

      'shift,shm(ctl|get|read(line)?|write),'.

      'shutdown,sin,sleep,socket(pair)?,'.

      'sort,spli(ce|t),sprintf,sqrt,srand,stat,'.
      'study,substr,symlink,'.

      'sys(call|read|tem|write),'.
      'tell(dir)?,time,tr(y)?,truncate,umask,'.

      'un(def|link|pack|shift),'.
      'utime,values,vec,wait(pid)?,'.
      'wantarray,warn,write'

    ,1)],

  ],

# ---   *   ---   *   ---

  -KEYS =>[

    [0x0D,lang::eiths(

      'continue,else,elsif,do,for,foreach,'.
      'if,unless,until,while,eq,ne,lt,gt,'.
      'le,ge,cmp,x,my,sub,use,package,can,isa'

    ,1)],

  ],

# ---   *   ---   *   ---

# line comments
);$PERL{-LCOM}=[
  [0x02,lang::eaf(
    lang::lkback('$%&@\'"',
    $PERL{-COM}),0,1)

  ],

];lang::DICT->{SYGEN_KEY()}=\%PERL;

# ---   *   ---   *   ---
1; # ret

