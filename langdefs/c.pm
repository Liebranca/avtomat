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

lang::def::nit(

  -NAME=>'c',

  -EXT=>'\.([ch](pp|xx)?|C|cc|c\+\+|cu|H|hh|ii?)$',
  -MAG=>'^(C|C\+\+) (source|program)',
  -COM=>'//',

# ---   *   ---   *   ---

  -TYPES=>[qw(

    bool char short int long
    float double void enum

    int8_t int16_t int32_t int64_t
    uint8_t uint16_t uint32_t uint64_t

    nihil stark signal

  )],

  -SPECIFIERS=>[qw(

    auto extern inline restrict
    const signed unsigned
    union struct static

    class explicit friend mutable
    namespace override private
    protected public register

    template using virtual volatile
    noreturn _Atomic complex imaginary
    thread_local operator

  )],

# ---   *   ---   *   ---

  -INTRINSICS=>[qw(

    sizeof offsetof typeof alignof
    typedef typename alignas

    static_assert cassert
    _Generic __attribute__

    new delete

  )],

  -FCTLS=>[qw(

    if else for while do
    switch case default
    try throw catch break
    continue goto return

  )],

# ---   *   ---   *   ---

  -RESNAMES=>[qw(
    this

  )],

# ---   *   ---   *   ---

  -PREPROC=>[
    lang::delim2('#',"\n"),

  ],

  -MCUT_TAGS=>[-STRING,-CHAR,-PREPROC],

# ---   *   ---   *   ---

  -EXP_RULE=>sub ($) {

    my $rd=shift;

    my $preproc=lang::cut_token_re;
    $preproc=~ s/\[A-Z\]\+/PREPROC[A-Z]/;

    while($rd->{-LINE}=~ s/^(${preproc})//) {
      push @{$rd->exps},$1;

    };

  },

# ---   *   ---   *   ---

  -MLS_RULE=>sub ($$) {

    my ($self,$s)=@_;

    if($s=~ m/(#\s*if)/) {

      my $open=$1;
      my $close=$open;

      $close=~ s/(#\s*)//;
      $close=$1.'endif';

      $self->del_mt->{$open}=$close;

      return "($open)";

# ---   *   ---   *   ---

    } elsif($s=~ m/(#\s*define\s+)/) {

      my $open=$1;
      my $close="\n";

      $self->del_mt->{$open}=$close;

      return "($open)";

    } else {return undef;};

  },

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
