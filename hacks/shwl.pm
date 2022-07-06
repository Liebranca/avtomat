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

# deps
package shwl;

  use v5.36.0;
  use strict;
  use warnings;

  use English qw(-no_match_vars);
  use Carp;

  use B qw(svref_2object);

  use lib $ENV{'ARPATH'}.'/lib/';
  use style;
  use arstd;

# ---   *   ---   *   ---
# info

  our $VERSION=v0.1;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  use constant {

    DEPS_STR=>":__DEPS__:",
    DEPS_RE=>"^\:__DEPS__\:(.*?)\:__DEPS__\:",

# ---   *   ---   *   ---

    EXT_RE=>qr{[.].*$},
    FNAME_RE=>qr{\/([_\w][_\w\d]*)$},

    CUT_FMAT=>':__%s_CUT_%i__:',
    CUT_RE=>':__\w+_CUT_(\d+)__:',

# ---   *   ---   *   ---

    STR_RE=>qr{

      (?<! ')

      "
      (?: \\" | [^"\n] )*

      "

    }x,

# ---   *   ---   *   ---

    CHR_RE=>qr{

      (?<! ")

      '
      (?: \\' | [^'\n] )*

      '

    }x,

# ---   *   ---   *   ---

    SUB_RE=>qr{(?<whole>

      \bsub\s*

      (?<name> [_\w][_\w\d]*)?\s*
      (?<attrs> :[_\w][_\w\d]*\s*)*

      \s*(?<args> \(.*?\))?\s*

      (?<scope> [{]

        (?<code> [^{}] | (?&scope))*

      [}])

    )}x,

# ---   *   ---   *   ---

    IS_PERLMOD=>qr{[.]pm$},

  };

# ---   *   ---   *   ---
# global state

  my $STRINGS={};

  sub STRINGS {return $STRINGS};
  sub DUMPSTRINGS {

    my $cpy=arstd::hashcpy($STRINGS);
    $STRINGS={};

    return $cpy;

  };

# ---   *   ---   *   ---
# utility funcs

sub coderef_name($ref) {
  return svref_2object($ref)->GV->NAME;

};

# ---   *   ---   *   ---

sub delm($beg,$end=undef) {

  $end//=$beg;
  for my $d($beg,$end) {$d="\Q$d"};

# ---   *   ---   *   ---

  my $re=qr{

    (?<delimiter>

    \s*$beg

      (?<body> [^$beg$end]* | (?&delimiter) )

    $end\s*

    )

  }x;

  return $re;

};

# ---   *   ---   *   ---

sub delm2($beg,$end=undef) {

  $end//=$beg;
  my ($beg_allow,$end_allow)=($beg,$end);

# ---   *   ---   *   ---

  for my $d($beg_allow,$end_allow) {

    my @chars=split NULLSTR,$d;
    my $i=1;

    my $c=shift @chars;
    my $allowed=q{[^}."\Q$c".q{]+};

# ---   *   ---   *   ---

    for $c(@chars) {

      my $left=NULLSTR;
      if($i) {$left=substr $d,0,$i};$i++;

      $allowed.=q{|}.$left.q{[^}."\Q$c".q{]+};

    };

# ---   *   ---   *   ---

    $d=q[(?:].$allowed.q[)];

  };

  for my $d($beg,$end) {$d="\Q$d"};

# ---   *   ---   *   ---

  my $re=qr{

    (?<delimiter>

    \s*$beg

      (?<body>

        $beg_allow | $end_allow | (?&delimiter)

      )

    $end\s*

    )

  }x;

  return $re;

};

# ---   *   ---   *   ---

sub cut($string_ref,$name,$pat) {

  my $matches=[];

# ---   *   ---   *   ---
# replace pattern with placeholder

  while($$string_ref=~ s/($pat)/#:cut;>/smx) {

    my $v=${^CAPTURE[0]};
    my $token=q{};

# ---   *   ---   *   ---
# construct a peso-style :__token__:

    # repeats aren't saved twice
    if(exists $STRINGS->{$v}) {
      $token=$STRINGS->{$v};

    # hash->{data}=token
    # hash->{token}=data
    } else {
      $token=sprintf CUT_FMAT,
        $name,int(keys %$STRINGS);

      $STRINGS->{$v}=$token;
      $STRINGS->{$token}=$v;

    };

# ---   *   ---   *   ---
# put the token in place of placeholder

    $$string_ref=~ s/#:cut;>/$token/;
    push @$matches,$token;

  };

  return $matches;

};

# ---   *   ---   *   ---

sub stitch($string_ref) {

  while($$string_ref=~ m/(${\CUT_RE})/) {
    my $key=${^CAPTURE[0]};
    my $value=$STRINGS->{$key};

    $$string_ref=~ s/${key}/$value/;

  };

  return;

};

# ---   *   ---   *   ---

sub mod_to_lib($fname) {

  my $arpath=$ENV{'ARPATH'};

  if(0<=index $fname,q{/}) {
    $fname=~ s/${arpath}//;
    my @ar=split m{/},$fname;
    my $ar0=$ar[0];

    $fname=~ s/${ar0}//;

# ---   *   ---   *   ---

  };if(!($fname=~ m{/lib/})) {
    $fname="lib/$fname";

  };if(!($fname=~ m{$arpath})) {
    $fname="$arpath/$fname";

  };

  $fname=~ s{/+} {/}sgx;

  return $fname;

};

# ---   *   ---   *   ---

sub darkside_of($the_force) {
  $the_force=~ s/${\EXT_RE}//;
  $the_force=~ s/${\FNAME_RE}/\/\.$1/;

  return $the_force;

};

# ---   *   ---   *   ---

sub ipret_decls($line) {

  state $COMMA=qr{,};
  state $EQUAL=qr{\*=>};

  my $value_table={order=>[]};
  my @elems=split m/$COMMA/,$line;

# ---   *   ---   *   ---

  for my $elem(@elems) {

    my ($key,$value)=split m/$EQUAL/,$elem;

    $key="\Q$key";
    $key=$key.'\b';
    $key=qr{$key};

# ---   *   ---   *   ---

    if($value=~ m/\$_\[(\d)\]/) {
      $value=${^CAPTURE[0]};

    } else {
      $value=eval($value);

    };

# ---   *   ---   *   ---

    $value_table->{$key}=$value;
    push @{$value_table->{order}},$key;

  };

  return $value_table;

};

# ---   *   ---   *   ---
# fetches symbol table from %INC
# by reading /.lib files

sub getlibs() {

  my $table={};

# ---   *   ---   *   ---
# filter out %INC

  my @imports=();
  for my $module(keys %INC) {

    my $fpath=darkside_of(mod_to_lib($module));
    if(-e $fpath) {push @imports,$fpath};

  };

# ---   *   ---   *   ---
# walk the imports list

  for my $fpath(@imports) {

    open my $FH,'<',
    $fpath or croak STRERR;

# ---   *   ---   *   ---
# process entries

    while(my $symname=readline $FH) {

      chomp $symname;
      if(!length $symname) {last};

      my $mem=readline $FH;chomp $mem;
      my $args=readline $FH;chomp $args;
      my $code=readline $FH;chomp $code;

      $mem=ipret_decls($mem);
      $args=ipret_decls($args);

# ---   *   ---   *   ---
# save symbol to table

      my $sbl=bless {

        id=>$symname,

        mem=>$mem,
        code=>$code,
        args=>$args,

      },'shwl::sbl';

      $table->{$symname}=$sbl;

# ---   *   ---   *   ---
# close file and repeat

    };

    close $FH or croak STRERR;

# ---   *   ---   *   ---
# give back symbol table

  };

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
# abstracts away details in
# every subroutine found in a file

sub codefold($fname) {

  my $body=arstd::orc($fname);

# ---   *   ---   *   ---

  my %dels=(

    q[{]=>q[}],
    q{[}=>q{]},
    q[(]=>q[)],

  );

  my %dels_id=(

    q[{]=>'CURLY',
    q{[}=>'BRACKET',
    q[(]=>'PARENS',

  );

  my @dels_order=qw'( [ {';
  my %dels_re=();

  for my $key(@dels_order) {
    my $re=delm($key,$dels{$key});
    $dels_re{$key}=$re;

  };

# ---   *   ---   *   ---

  my %blocks=();

  while($body=~ s/${\SUB_RE}//sxm) {

    my $fnbody=$+{scope};

    my $block=shwl::blk::nit();

    $fnbody=~ s/^\s*\{//;
    $fnbody=~ s/\s*\}$//;

# ---   *   ---   *   ---

    cut(\$fnbody,'STR',STR_RE);
    cut(\$fnbody,'CHR',CHR_RE);

    for my $key(@dels_order) {

      cut(
        \$fnbody,
        $dels_id{$key},
        $dels_re{$key}

      );

    };

# ---   *   ---   *   ---

    $block->{strings}=DUMPSTRINGS();
    $block->{body}=$fnbody;

    $blocks{$block->{name}}=$block;

  };

# ---   *   ---   *   ---

  return \%blocks;

};

# ---   *   ---   *   ---
1; # ret

# ---   *   ---   *   ---

package shwl::sbl;

  use v5.36.0;
  use strict;
  use warnings;

# ---   *   ---   *   ---

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

package shwl::blk;

  use v5.36.0;
  use strict;
  use warnings;

  use style;

# ---   *   ---   *   ---


sub nit {

  my $block=bless {

    name=>$+{name},
    attrs=>$+{attrs},
    body=>$+{code},
    args=>$+{args},

    strings=>{},

  };

  $block->{name}//=NULLSTR;
  $block->{attrs}//=NULLSTR;
  $block->{args}//=NULLSTR;
  $block->{body}//=NULLSTR;

  return $block;

};

# ---   *   ---   *   ---



# ---   *   ---   *   ---
