#!/usr/bin/perl
# ---   *   ---   *   ---
# C syntax defs

# ---   *   ---   *   ---

# deps
package langdefs::c;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use lang;

# ---   *   ---   *   ---
# used to 'fold' multi-line directives

sub c_mls($$) {

  my ($self,$s)=@_;

  if($s=~ m/(#\s*if)/) {

    my $open=$1;
    my $close=$open;

    $close=~ s/(#\s*)//;
    $close=$1.'endif';

    $self->del_mt->{$open}=$close;

    return "($open)";

  } elsif($s=~ m/(#\s*define\s+)/) {

    my $open=$1;
    my $close="\n";

    $self->del_mt->{$open}=$close;

    return "($open)";

  } else {return undef;};

};

# ---   *   ---   *   ---

lang::def::nit(

  -NAME => 'c',
  -EXT  => '\.([ch](pp|xx)?|C|cc|c\+\+|cu|H|hh|ii?)$',
  -HED  => 'N/A',

  -MAG  => '^(C|C\+\+) (source|program)',

  -COM  => '//',

# ---   *   ---   *   ---

  -PREPROC=>[
    lang::delim2('#',"\n"),

  ],

  -MLS_RULE=>\&c_mls,
  -MCUT_TAGS=>[-STRING,-CHAR,-PREPROC],

# ---   *   ---   *   ---

  -VARS =>[

    lang::eiths(

      'auto,extern,inline,restrict,signed,'.
      'union,struct,unsigned,static,typedef,'.

      'const'

    ,1),

# ---   *   ---   *   ---

    lang::eiths(

      'sizeof,offsetof,typedef'

    ,1),

# ---   *   ---   *   ---

    lang::eiths(

      '_(Alignas|Alignof|Atomic|Bool|Complex'.
      '|Generic|Imaginary|Noreturn'.
      '|Static_assert|Thread_local),'.

      'class,explicit,friend,mutable,'.
      'namespace,override,private,'.
      'protected,public,register,'.

      'template,this,typename,'.
      'using,virtual,volatile'

    ,1),

# ---   *   ---   *   ---

    lang::eiths(

      'gl_(Position|FragColor)'

    ,1),

  ],

# ---   *   ---   *   ---

  -TYPES=>{

    'bool'=>1,
    'char'=>1,

    'short'=>2,
    'int'=>4,
    'long'=>8,

    'float'=>4,
    'double'=>8,

    'void'=>0,
    'enum'=>0,

    '([a-z][a-z_]*'.
    '|(u_?)?int(8|16|32|64))'.

    '_t'=>0,

    'nihil'=>8,
    'stark'=>8,
    'signal'=>8,

    'uint'=>4,
    'vec4'=>16,
    'mat4'=>64,

  },

# ---   *   ---   *   ---

  -BILTN =>[

  ],

# ---   *   ---   *   ---


  -KEYS =>[

    lang::eiths(

      'if,else,for,while,do,switch,case,default,'.
      'try,throw,catch,operator,new,delete,'.
      'break,continue,goto,return'

    ,1),

    lang::eiths(

      '__attribute__[[:blank:]]*\(\([^)]*\)\)'.

      '|__('.

        'aligned|asm|builtin|hidden'.
        '|inline|packed|restrict|section'.
        '|typeof|weak'.

      ')__'

    ,1),

  ],

);

# ---   *   ---   *   ---

# DEPRECATED
# this function needs a ground-up rewrite

# in:C code
# returns code matches decl
sub cdecl {

  my $s=shift;

  my $qualy=lang->c->vars->[0];
  my $types=lang->c->types;

  my $isptr='(\\**\\s+|\\s+\\**)';

  my $pat='('.$qualy.')*\s+('.
    $types.$isptr.')('.lang->c->names.'*)'.'\s*';

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
    lang::ps(-NAME,lang->c->names.'*');

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
};

# ---   *   ---   *   ---
1; # ret
