#!/usr/bin/perl
# ---   *   ---   *   ---
# SHADOWLIB
# Shady pre-compiled stuff
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# NOTE:
#
# this entire module is an
# embarrassment, the only
# sane thing to do with it
# is purging it from the
# codebase
#
# but because it's so old,
# i can't just take it out!
#
# so it'll stay here for a
# while until it's safe to
# shred it entirely

# ---   *   ---   *   ---
# deps

package Shwl;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use English qw(-no_match_vars);
  use Carp;

  use B qw(svref_2object);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Hash;
  use Arstd::IO;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.00.2;#b
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $DEPS_STR=>":__DEPS__:";
  Readonly our $DEPS_RE=>
    "^\:__DEPS__\:(.*?)\:__DEPS__\:";


  Readonly our $EXT_RE=>qr{[.].*$};
  Readonly our $FNAME_RE=>qr{\/([_\w][_\w\d]*)$};

  Readonly our $CUT_FMAT=>':__%s_CUT_%i__:';
  Readonly our $CUT_RE=>qr{\:__\w+_CUT_\d+__\:};

  Readonly our $PL_CUT=>':__CUT__:';
  Readonly our $PL_CUT_RE=>qr{\:__CUT__\:};


  Readonly our $ARG_FMAT=>':__ARG_%i__:';
  Readonly our $ARG_RE=>qr{\:__ARG_\d+__\:};

  Readonly our $RET_STR=>':__RETVAL__:';
  Readonly our $RET_RE=>qr{\:__RETVAL__\:};

  Readonly our $ASG_STR=>':__ASG__:';
  Readonly our $ASG_RE=>qr{\:__ASG__\:};


  Readonly our $UTYPE_PREFIX=>'user_type_';

# ---   *   ---   *   ---
# we need these two DISGUSTING REDUNDANCIES
# just so that we can bootstrap without making
# a dependency cycle with the perl langdef

  Readonly our $CHR_RE=>qr{

    (?<! ["`])

    '
    (?: \\' | [^'\n] )*

    '

  }x;

  Readonly our $STR_RE=>qr{

    (?<! ['`])

    "
    (?: \\" | [^"\n] )*

    "

  }x;

# ---   *   ---   *   ---
# GBL

  my $STRINGS={};

  sub STRINGS {return $STRINGS};
  sub DUMPSTRINGS {

    my $cpy=hash_cpy($STRINGS);
    $STRINGS={};

    return $cpy;

  };

# ---   *   ---   *   ---
# DEPRECATED
# utility funcs

sub coderef_name($ref) {
  return svref_2object($ref)->GV->NAME;

};

# ---   *   ---   *   ---
# DEPRECATED
# makes delimiter re

sub delm($beg,$end=undef) {

  $end//=$beg;
  for my $d($beg,$end) {$d="\Q$d"};


  my $re=qr{

    (?<delimiter>

    $beg

      (?<body> [^$beg$end]* | (?&delimiter) )

    $end

    )

  }x;

  return $re;

};

# ---   *   ---   *   ---
# DEPRECATED
# similar, but preceded by q|qq|qw|qr|m

sub qdelm($beg,$end=undef) {

  $end//=$beg;
  for my $d($beg,$end) {$d="\Q$d"};


  my $re=qr{

    (?: q|qq|qw|qr|m)

    (?<delimiter>

    \s*$beg

      (?<body> [^$beg$end]* | (?&delimiter) )

    $end\s*

    ) (?: [sxmge]?)

  }x;

  return $re;

};

# ---   *   ---   *   ---
# DEPRECATED
# fffn perl and it's undending corner cases

sub sdelm($beg,$end=undef) {

  $end//=$beg;
  for my $d($beg,$end) {$d="\Q$d"};

  my $mid;
  if($end ne $beg) {
    $mid=$end.q{\s*}.$beg;

  } else {
    $mid=$beg;

  };


  my $re=qr{

    (?: s)

    (?<delimiter>

    \s*$beg

      (?<body>

        [^$beg$end]*
      | (?&delimiter)

      )

    $mid

      (?<body>

        [^$beg$end]*
      | (?&delimiter)

      )

    $end\s*

    ) (?: [sxmge]?)

  }x;

  return $re;

};

# ---   *   ---   *   ---
# DEPRECATED
# same deal as delm

sub delm2($beg,$end=undef) {

  $end//=$beg;
  my ($beg_allow,$end_allow)=($beg,$end);


  for my $d($beg_allow,$end_allow) {

    my @chars=split $NULLSTR,$d;
    my $i=1;

    my $c=shift @chars;
    my $allowed=q{[^}."\Q$c".q{]+};


    for $c(@chars) {

      my $left=$NULLSTR;
      if($i) {$left=substr $d,0,$i};$i++;

      $allowed.=q{|}.$left.q{[^}."\Q$c".q{]+};

    };


    $d=q[(?:].$allowed.q[)];

  };

  for my $d($beg,$end) {$d="\Q$d"};


  my $re=qr{

    \s*
    (?<delimiter>

    $beg

      (?<body>

        $beg_allow | $end_allow | (?&delimiter)

      )

    $end

    )\s*

  }x;

  return $re;

};

# ---   *   ---   *   ---
# cut *all* matches of pattern
# then insert an ID for the match
#
# the matches themselves are
# saved for later replacing

sub cut($string_ref,$name,$pat) {

  my $matches=[];

  # replace pattern with placeholder
  while($$string_ref=~ s/($pat)/#:cut;>/smx) {

    my $v     = ${^CAPTURE[0]};
    my $token = q{};

    # construct a peso-style :__token__:
    # repeats aren't saved twice
    if(exists $STRINGS->{$v}) {
      $token=$STRINGS->{$v};

    # hash->{data}  = token
    # hash->{token} = data
    } else {

      $token=sprintf $CUT_FMAT,
        $name,int(keys %$STRINGS);

      $STRINGS->{$v}=$token;
      $STRINGS->{$token}=$v;

    };


    # put the token in place of placeholder
    $$string_ref=~ s/#:cut;>/$token/;
    push @$matches,$token;


  };

  return $matches;

};

# ---   *   ---   *   ---
# ^puts the matches back!

sub stitch($string_ref) {

  while($$string_ref=~ $CUT_RE) {
    my $key=${^CAPTURE[0]};
    my $value=$STRINGS->{$key};

    $$string_ref=~ s/${key}/$value/;

  };

  return;

};

# ---   *   ---   *   ---
# DEPRECATED
# weird mam shit

sub mod_to_lib($fname) {

  my $arpath=$ENV{'ARPATH'};

  if(0<=index $fname,q{/}) {
    $fname=~ s/${arpath}//;
    my @ar=split m{/},$fname;
    my $ar0=$ar[0];

    $fname=~ s/${ar0}//;


  };if(!($fname=~ m{/lib/})) {
    $fname="lib/$fname";

  };if(!($fname=~ m{$arpath})) {
    $fname="$arpath/$fname";

  };

  $fname=~ s{/+} {/}sgx;

  return $fname;

};

# ---   *   ---   *   ---
# DEPRECATED
# i couldn't resist ;>

sub darkside_of($the_force) {
  $the_force=~ s/$EXT_RE//;
  $the_force=~ s/$FNAME_RE/\/\.$1/;

  return $the_force;

};

# ---   *   ---   *   ---
# DEPRECATED

sub ipret_decls($line) {

  state $EQUAL=qr{\*=>};

  my $value_table={order=>[]};
  my @elems=split $COMMA_RE,$line;


  for my $elem(@elems) {

    my ($key,$value)=split $EQUAL,$elem;

    $key="\Q$key";
    $key=$key.'\b';
    $key=qr{$key};


    if($value=~ m/\$_\[(\d)\]/) {
      $value=${^CAPTURE[0]};

    } else {
      $value=eval($value);

    };


    $value_table->{$key}=$value;
    push @{$value_table->{order}},$key;

  };


  return $value_table;

};

# ---   *   ---   *   ---
# DEPRECATED
#
# fetches symbol table from %INC
# by reading /.lib files

sub getlibs() {

  my $table={};

  # filter out %INC
  my @imports=();
  for my $module(keys %INC) {

    my $fpath=darkside_of(mod_to_lib($module));
    if(-e $fpath) {push @imports,$fpath};

  };


  # walk the imports list
  for my $fpath(@imports) {

    open my $FH,'<',$fpath
    or croak STRERR($fpath);


    # process entries
    while(my $symname=readline $FH) {

      chomp $symname;
      if(!length $symname) {last};

      my $mem=readline $FH;chomp $mem;
      my $args=readline $FH;chomp $args;
      my $code=readline $FH;chomp $code;

      $mem=ipret_decls($mem);
      $args=ipret_decls($args);


      # save symbol to table
      my $sbl=bless {

        id=>$symname,

        mem=>$mem,
        code=>$code,
        args=>$args,

      },'Shwl::Sbl';

      $table->{$symname}=$sbl;

    };

    # close file and repeat
    close $FH or croak STRERR($fpath);

  };

  # give back symbol table
  my @names=sort {
    (length $a)<=(length $b)

  } keys %$table;

  if(!@names) {
    croak "Empty inlined symbol table";

  };

  my $re='\b('.(join '|',@names).')\b\(.*?\)';

  $table->{re}=qr{$re}xs;

  return $table;

};

# ---   *   ---   *   ---
# DEPRECATED
#
# abstracts away details in
# every subroutine found in a file

sub codefold($fname,$lang,%opts) {

  # opt defaults
  $opts{-f}//=1;

  my $body;
  if($opts{-f}) {
    $body=orc($fname);

  } else {
    $body=$fname;
    $fname='codestr';

  };


  my $fn_decl=$lang->{fn_decl};
  my $fn_key=$lang->{fn_key};

  my %blocks=Shwl::Blk::extract(

    \$body,

    $fn_decl,
    $fn_key,
    'FN',

    $lang

  );


  my $utype_decl=$lang->{utype_decl};
  my $utype_key=$lang->{utype_key};

  my %utypes=Shwl::Blk::extract(

    \$body,

    $utype_decl,
    $utype_key,
    'UTYPE',

    $lang,

  );

  for my $key(keys %utypes) {
    $blocks{$UTYPE_PREFIX.$key}=$utypes{$key};

  };


  Shwl::Blk::fold($lang,\$body);

  my $fblk=bless {

    name=>$fname,
    attrs=>$NULLSTR,
    body=>$body,
    args=>$NULLSTR,

    strings=>DUMPSTRINGS(),
    tree=>undef,

  },'Shwl::Blk';

  $blocks{-ROOT}=$fblk;
  return \%blocks;

};

# ---   *   ---   *   ---
1; # ret

# ---   *   ---   *   ---
# DEPRECATED

package Shwl::Sbl;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;

# ---   *   ---   *   ---
# DEPRECATED

sub paste($sbl,@passed) {

  my $mem=$sbl->{mem};
  my $args=$sbl->{args};
  my $code=$sbl->{code};

  for my $key(@{$mem->{order}}) {
    my $value=$mem->{$key};
    $code=~ s/$key/$value/sg;

  };

  for my $key(@{$args->{order}}) {
    my $value=$args->{$key};
    $value=$passed[$value];

    $code=~ s/$key/$value/sg;

  };

  $code=~ s/^\{|;?\s*\}\s*;?$//sg;

  return "$code";

};

# ---   *   ---   *   ---
# DEPRECATED

package Shwl::Blk;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Style;

# ---   *   ---   *   ---
# DEPRECATED

sub new($class) {

  my $block=bless {

    name=>$+{name},
    attrs=>$+{attrs},
    body=>$+{code},
    args=>$+{args},

    strings=>{},
    tree=>undef,

    cpyn=>0,

  },$class;

  $block->{name}//=$NULLSTR;
  $block->{attrs}//=$NULLSTR;
  $block->{args}//=$NULLSTR;
  $block->{body}//=$NULLSTR;

  return $block;

};

# ---   *   ---   *   ---
# DEPRECATED like this whole module

sub extract(

  $body_ref,

  $re,
  $cut_key,
  $cut_alias,

  $lang

) {

  my $i=0;

  my $cut_token=sprintf
    $Shwl::CUT_FMAT,
    $cut_alias,$i++

  ;

  my @ids=();
  my %frame=();


  while($$body_ref=~ s/$re/$cut_token/sxm) {

    my $fnbody=$+{scope};
    $fnbody//=$NULLSTR;

    my $block=Shwl::Blk->new();

    push @ids,$block->{name};

    $fnbody=~ s/^\s*\{//;
    $fnbody=~ s/\s*\}$//;

    fold($lang,\$fnbody);


    $block->{strings}=Shwl::DUMPSTRINGS();
    $block->{body}=$fnbody;

    $frame{$block->{name}}=$block;

    $cut_token=sprintf
      $Shwl::CUT_FMAT,
      $cut_alias,$i++

    ;

  };


  $i=0;
  $cut_token=sprintf
    $Shwl::CUT_FMAT,
    $cut_alias,$i++

  ;

  for my $id(@ids) {

    $$body_ref=~
      s/${cut_token}/$cut_key $id;/;

    $cut_token=sprintf
      $Shwl::CUT_FMAT,
      $cut_alias,$i++

    ;

  };


  return %frame;

};

# ---   *   ---   *   ---
# DOUBLY DEPRECATED

sub fold($lang,$body_ref) {

  my $foldtags=$lang->{foldtags};
  my $deldata=$lang->{delimiters};

  my $dels_re=$deldata->{re};
  my $dels_id=$deldata->{id};
  my $dels_order=$deldata->{order};


  for my $key(@$foldtags) {
    Shwl::cut($body_ref,uc $key,$lang->{$key});

  };

  for my $key(@$dels_order) {

    $key=~ s[^\\][];

    Shwl::cut(
      $body_ref,
      $dels_id->{$key},
      $dels_re->{$key}

    );

  };

};

# ---   *   ---   *   ---
# EVEN MORE DEPRECATED

package Shwl::Arg;

  use v5.36.0;
  use strict;
  use warnings;

  use Style;

sub new($class,$elem) {

  my ($name,$default)=split qr{=},$elem;

  my $arg=bless {
    name=>$name,
    default=>$default,

  },$class;

  return $arg;

};

# ---   *   ---   *   ---
