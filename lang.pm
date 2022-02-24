#!/usr/bin/perl
# ---   *   ---   *   ---
# LANG
# Syntax wrangler
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# NOTE:
# Most of these regexes where taken from nanorc files!
# all I did was *manually* collect them to make this
# syntax file generator

# ---   *   ---   *   ---

# deps
package lang;
  use strict;
  use warnings;

# ---   *   ---   *   ---

  my $_LUN='[_a-zA-Z][_a-zA-Z0-9]';
  my $DRFC='::|->|\.';

  my $OPS='+-*/\$@%&\^<>!|?{[()]}~,.=;:';

# ---   *   ---   *   ---
# regex tools

# in:pattern
# escapes .^$([{}])+*?/|\: in pattern
sub rescap {

  my $s=shift;$s=~ s/\\/\\\\/g;


  for my $c(split '','.^$([{}])+*?/|:') {
    $s=~ s/\Q${ c }/\\${ c }/g;

  };

  return $s;

# ---   *   ---   *   ---
# lyeb@IBN-3DILA on Wed Feb 23 10:58:41 AM -03 2022:

# i apologize for writting this monster,
# but it had to be done

# it matches *** \[end]*** when [beg]*** \[end]*** [end]
# but it does NOT match when [beg]*** \[end]***

# in: delimiter end
# returns correct \end support
};sub UBERSCAP {

  my $o_end=shift;
  my $end="\\\\".$o_end;

  my @chars=split '',$end;
  my $s=rescap( shift @chars );
  my $re="[^$s$o_end]";

  my $i=0;for my $c(@chars) {

    $c=($i<1) ? rescap($c.$o_end) : rescap($c);
    $re.='|'.$s."[^$c]";$i++;

  };return "$end|$re";

};

# ---   *   ---   *   ---

# in:substr to exclude,allow newlines,do_uber
# shame on posix regexes, no clean way to do this
sub neg_lkahead {

  my $string=shift;
  my $ml=shift;
  $ml=(!$ml) ? '\n' : '';

  my $do_uber=shift;
  my @chars=split '',$string;

  my $s=rescap( shift @chars );
  my $re="[^$s$ml\\\\]";

  for my $c(@chars) {

    $c=rescap($c);
    $re.='|'.$s."[^$c$ml\\\\]";
    $s.=$c;

  };if($do_uber) {$re.='|'.UBERSCAP( rescap($string) );};
  return $re;
};


# ---   *   ---   *   ---
# delimiter patterns

# in: beg,end,is_multiline

# matches:
#   > beg
#   > unnested grab ([^end]|\end)*
#   > end

sub delim {

  my $beg=shift;
  my $end=shift;
  if(!$end) {
    $end=$beg;

  };my $allow=( neg_lkahead($end,shift,1) );

  $beg=rescap($beg);
  $end=rescap($end);

  return "$beg(($allow)*)$end";

};

# ---   *   ---   *   ---

# in: beg,end,is_multiline

# matches:
#   > ^[^beg]*beg
#   > nested grab ([^end]|end)*
#   > end[^end]*$

sub delim2 {

  my $beg=shift;
  my $end=shift;
  if(!$end) {
    $end=$beg;

  };my $allow=( neg_lkahead($end,shift,0) );

  $beg=rescap($beg);
  $end=rescap($end);

  return ''.
    "[^$beg]*$beg".
    "(($allow|$end)*)$end".
    "[^$end]*\$";

};

# ---   *   ---   *   ---
# one-of pattern

# in: string,disable escapes
# matches (char0|...|charN)
sub eithc {

  my $string=shift;
  my $disable_escapes=shift;

  if(!$disable_escapes) {
    $string=rescap($string);

  };my @chars=split '',$string;
  return '('.( join '|',@chars).')';

};

# in: "str0,...,strN",disable escapes
# matches \b(str0|...|strN)\b
sub eiths {

  my $string=shift;
  my $disable_escapes=shift;

  if(!$disable_escapes) {
    $string=rescap($string);

  };my @words=split ',',$string;
  return '\b('.( join '|',@words).')\b';

};

# ---   *   ---   *   ---

# in: pattern,line_beg,disable_escapes
# matches:
#   > pattern
#   > grab everything after pattern until newline
#   > newline

# line_beg=1 matches only at beggining of line
# line_beg=-1 doesnt match if pattern is first non-blank
# ^ line_beg=0 disregards these two

sub eaf {

  my $pat=shift;
  my $line_beg=shift;

  my $disable_escapes=shift;
  $pat=(!$disable_escapes) ? rescap($pat) : $pat;

  if(!$line_beg) {
    $pat='^[^"\']*'.$pat;

  } elsif($line_beg>0) {
    $pat='^'.$pat;

  } elsif($line_beg<0) {
    $pat='^[\s|\n]*'.$pat;

  };return "$pat([^\"']*)\\n?";

};

# ---   *   ---   *   ---
# base modeler for all syntax structures

# in: [metadata,[patterns]]
sub snx {

  my @mets=@{ $_[0] };shift;
  my %snx_s=();while(@mets) {

    my $meta=shift @mets;
    my @pats=@{ shift @mets };

  };

};

# ---   *   ---   *   ---
# general-purpose regexes

my %DICT=(-GPRE=>{

  -HIER =>[

    # class & hierarchy stuff
    [0x04,eiths('this,self')],
    [0x04,"$_LUN*($DRFC)"],
    [0x0D,"*($DRFC)"."$_LUN*($DRFC)"],
    [0x04,"($DRFC)$_LUN*($DRFC)"],

  ],

# ---   *   ---   *   ---

  -PFUN =>[

    # functions with parens
    [0x01,"\\b$_LUN*\\b".delim2('(',')',1)],
    [0x07,delim2('(',')',1)]

  ],

  -GBL =>[

    # constants/globals
    [0x0D,'\b[A-Z_0-9]*\b'],

  ],

  -OPS =>[

    # operators
    [0x0F,eithc($OPS)],

  ],

# ---   *   ---   *   ---

  -DELM0 =>[

    # level 0 delimiters
    [0x01,delim('`')],

  ],

  -DELM1 =>[

    # level 1 delimiters
    [0x0E,delim('$:',';>')],

  ],

  -DELM2 =>[

    # level 2 delimiters
    [0x0E,delim('"').'|'.delim("'")],

  ],

# ---   *   ---   *   ---

  -NUMS =>[

    # hex
    [0x03,'('.

      '((\b0*|\\\\)x[0-9A-Fa-f]+[L]*)|'.
      '(\b[0-9A-Fa-f]+[L]*h)'.

      ')\b'

    ],

    # octal
    [0x03,'('.

      '(\\\\[0-7]+[L]*)|'.
      '(\b[0-7]+[L]*o)'.

      ')\b'

    ],

    # bin
    [0x03,'('.

      '((\b0|\\\\)b[0-1]+[L]*)|'.
      '([0-1]+[L]*b)'.

      ')\b'

    ],

    # float
    [0x03,'((\b[0-9]*|\.)+[0-9]+f?)\b'],

  ],

  -DEV =>[

    [0x0B,eiths('TODO,NOTE').':?|\*+:'],
    [0x09,eiths('FIX,BUG').':?|\!+:'],
    [0x08,'\s+$'], #[[:space:]]

  ],

# ---   *   ---   *   ---
# hash fetch

});sub PAT {

  my $lang=shift;
  my $key=shift;
  my $idex=shift;

  print "$lang $key $idex\n";

  return $DICT{$lang}->{$key}->[$idex]->[1];

};

# ---   *   ---   *   ---

my %PERL=(

  -MAG  => 'Perl script',

  -NAME => 'perl',
  -EXT  => '\.p[lm]$',
  -HED  => '^#!.*perl',

  -COM  => '#',

# ---   *   ---   *   ---

  -VARS =>[

    [0x04,'[$%&@]('.

      '('.$_LUN.'*|'.
      '\^[][A-Z?\^_]|[0-9]+\b)|'.

      '(\{(\^?'.$_LUN.'*|'.
      '\^[][?\^][0-9]+)\})|'.

      '(([][!"#\'()*+,.:;<=>?`|~-]|'.
      '\{[][!-/:-@\`|~]\})|\$[$%&@])|'.

      '((^|[[:blank:]])[$%@][/\\\\])'.

    ')'

    ],

  ],

# ---   *   ---   *   ---

  -BILTN =>[

    [0x01,eiths(

      'accept,alarm,atan2,bin(d|mode),'.

      'c(aller|h(dir|mod|op|own|root)|lose(dir)?'.
      '|onnect|os|rypt),'.

      'd(bm(close|open)|efined|elete|ie|o|ump),'.

      'e(ach|of|val|x(ec|ists|it|p)),'.
      'f(cntl|ileno|lock|ork),'.

      'get(c|login|peername|pgrp|ppid|priority'.
      '|pwnam|(host|net|proto|serv)byname'.
      '|pwuid|grgid|(host|net)byaddr'.
      '|protobynumber|servbyport),'.

      '([gs]et|end)(pw|gr|host|net|proto|serv)ent,'.

# ---   *   ---   *   ---

      'getsock(name|opt),'.
      'gmtime,goto,grep,hex,index,int,ioctl,join'.

      'keys,kill,last,length,link,listen,'.
      'local(time)?,log,lstat,m,mkdir,'.

      'msg(ctl|get|snd|rcv),next,oct,open(dir)?,'.
      'ord,pack,pipe,pop,printf?,push,'.

      'q,qq,qx,rand,re(ad(dir|link)?,'.
      'cv|do|name|quire|set|turn|verse|winddir),'.

      'rindex,rmdir,s,scalar,seek(dir)?'.

      'se(lect|mctl|mget|mop|nd|tpgrp'.
      '|tpriority|tsockopt),'.

# ---   *   ---   *   ---

      'shift,shm(ctl|get|read|write),'.

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

    [0x05,eiths(

      'continue,else,elsif,do,for,foreach,'.
      'if,unless,until,while,eq,ne,lt,gt,'.
      'le,ge,cmp,x,my,sub,use,package,can,isa'

    ,1)],

  ],

# ---   *   ---   *   ---

# line comments
);$PERL{-LCOM}=[

  [0x02,eaf($PERL{-COM},0)]

];

$DICT{-PERL}=\%PERL;

# ---   *   ---   *   ---
