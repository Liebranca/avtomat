#!/usr/bin/perl
# ---   *   ---   *   ---
# C syntax defs

# ---   *   ---   *   ---

# deps
package langdefs::cee;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---

sub SYGEN_KEY {return -CEE;};
sub RC_KEY {return 'c';};

# ---   *   ---   *   ---

my %CEE=(

  -NAME => 'c',
  -EXT  => '\.([ch](pp|xx)?|C|cc|c\+\+|cu|H|hh|ii?)$',
  -HED  => '-\*-.*\<C(\+\+)?((;|[[:blank:]]).*)?-\*-',

  -MAG  => '^(C|C\+\+) (source|program)',

  -COM  => '//',

# ---   *   ---   *   ---

  -VARS =>[

    [0x04,lang::eiths(

      'auto,extern,inline,restrict,signed,'.
      'union,struct,unsigned,static,typedef,'.

      'const'

    ,1)],

# ---   *   ---   *   ---

    [0x04,lang::eiths(

      'sizeof,offsetof,typedef'

    ,1)],

# ---   *   ---   *   ---

    [0x04,lang::eiths(

      '_(Alignas|Alignof|Atomic|Bool|Complex'.
      '|Generic|Imaginary|Noreturn'.
      '|Static_assert|Thread_local),'.

      'class,explicit,friend,mutable,'.
      'namespace,override,private,'.
      'protected,public,register,'.

      'template,this,typename,'.
      'using,virtual,volatile'

    ,1)],

# ---   *   ---   *   ---

    [0x04,lang::eiths(

      'bool,char,double,float,'.
      'int,float,long,short,void,enum,'.

      '([a-z][a-z_]*'.
      '|(u_?)?int(8|16|32|64))'.

      '_t,'.

      'nihil,vec4,mat4,uint'

    ,1)],

# ---   *   ---   *   ---

    [0x04,lang::eiths(

      'gl_(Position|FragColor)'

    ,1)],

  ],

  -BILTN =>[

  ],

# ---   *   ---   *   ---


  -KEYS =>[

    [0x0D,lang::eiths(

      'if,else,for,while,do,switch,case,default,'.
      'try,throw,catch,operator,new,delete,'.
      'break,continue,goto,return'

    ,1)],

    [0x01,lang::eiths(

      '__attribute__[[:blank:]]*\(\([^)]*\)\)'.

      '|__('.

        'aligned|asm|builtin|hidden'.
        '|inline|packed|restrict|section'.
        '|typeof|weak'.

      ')__'

    ,1)],

  ],

# ---   *   ---   *   ---


);$CEE{-LCOM}=[
  [0x02,lang::eaf($CEE{-COM},0,1)],
  [0x02,lang::delim2('/*','*/',1)],

];

# ---   *   ---   *   ---

# in:C code
# returns code matches decl
sub cee_decl {

  my $s=shift;

  my $qualy=$CEE{-VARS}->[0]->[1];
  my $types=$CEE{-VARS}->[3]->[1];
  my $isptr='(\\**\\s+|\\s+\\**)';

  my $pat='('.$qualy.')*\s+('.
    $types.$isptr.')('.lang::_LUN.'*)'.'\s*';

  $pat.=lang::delim2('(',')',1);

  if(!($s=~ m/${pat}/sg)) {
    return undef;

  };$s=~ s/\n//sg;

  $s=~ m/^(.*)${pat}/;
  if($1) {$s=~ s/\Q${ 1 }//;};

  lang::ps_str($s);


# ---   *   ---   *   ---

  my %d=(

    -FN => {
      -QUAL =>[],
      -TYPE =>[],
      -NAME =>[],

    },-ARGS =>[],

  );my $i=0;while(lang::ps_str) {

    lang::ps_dst($d{-FN});if($i) {

      push @{ $d{-ARGS} },{
        -QUAL=>[],
        -TYPE=>[],
        -NAME=>[],

      };lang::ps_dst($d{-ARGS}->[-1]);

    };

# ---   *   ---   *   ---

    lang::ps(-QUAL,$qualy);
    lang::ps(-TYPE,$types.$isptr);
    lang::ps(-NAME,lang::_LUN.'*');

    my $test=lang::ps_str;
    my $mod=$test;

    $mod=~ s/^\s*[\(,\)]//sg;$i++;

    if(!length $mod) {last;};
    lang::ps_str($mod);

  };

# ---   *   ---   *   ---

  my $ret=[];
  for my $ar($d{-FN}, @{ $d{-ARGS} }) {

    push @$ret,(

      (join ' ',@{ $ar->{-QUAL} }),
      (join ' ',@{ $ar->{-TYPE} }),
      (join ' ',@{ $ar->{-NAME} })

    );

  };my $test=join '',@$ret;
  if($test=~ m/^\s*$/) {
    return undef;

  };return $ret;

# ---   *   ---   *   ---

};$CEE{-DECL}=\&cee_decl;
lang::DICT->{SYGEN_KEY()}=\%CEE;

# ---   *   ---   *   ---
1; # ret
