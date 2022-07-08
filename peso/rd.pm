#!/usr/bin/perl
# ---   *   ---   *   ---
# RD
# PLPS-capable parser frontend
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package peso::rd;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
  use style;

  use lib $ENV{'ARPATH'}.'/lib/hacks/';
  use shwl;
  use inline;

  use peso::program;
  use peso::fndmtl;

# ---   *   ---   *   ---
# info

  our $VERSION=v2.4;
  our $AUTHOR='IBN-3DILA';

# ---   *   ---   *   ---
# flags

use constant {
  FILE=>0x00,
  STR=>0x01,

};

# ---   *   ---   *   ---
# constructor

sub nit($program,$keep_comments) {

  return bless {

    program=>$program,
    lang=>$program->lang,

    line=>NULLSTR,
    rem=>NULLSTR,

    fname=>NULLSTR,
    fhandle=>undef,

    exps=>[],

    mls_accum=>NULLSTR,
    in_mls=>undef,

    raw=>[],
    cooked=>[],
    strings=>{},

    keep_comments=>$keep_comments,

  },'peso::rd';

};

# ---   *   ---   *   ---
# multi-line block processing

sub mls_block($self,$first_frame) {

  my $ode=$self->{in_mls}->[0];
  my $cde=$self->{in_mls}->[1];
  my $doc=\$self->{in_mls}->[2];
  my $lvl=\$self->{in_mls}->[3];

# ---   *   ---   *   ---
# catch keyword on first iteratioon

  my ($s,$rem);
  if($first_frame) {
    ($s,$rem)=split m/:__CUT__/,$self->{line};
    $self->{in_mls}->[4]=$s;

# ---   *   ---   *   ---
# use entire line

  } else {
    ($s,$rem)=(NULLSTR,$self->{line});

  };

# ---   *   ---   *   ---
# iter the doc block line

  my $i=0;
  my $accum=NULLSTR;
  my $tok=NULLSTR;

  my @ar=split m/${\NULLSTR}/,$rem;

  for my $c(@ar) {

    $tok.=$c;

# ---   *   ---   *   ---
# close char downs the depth

    if($cde=~ m/^\Q${tok}/) {

      if($tok=~ m/^${cde}/) {

        if($$lvl) {
          $$doc.=$tok;
          $tok=NULLSTR;

        };$$lvl--;

        if($$lvl<0) {$i++;last;};

      };$i++;next;

# ---   *   ---   *   ---
# open char ups the depth

    } elsif($ode=~ m/^\Q${tok}/) {

      if($tok=~ m/^${ode}/) {

        $$lvl++;
        $$doc.=$tok;
        $tok=NULLSTR;

      };$i++;next;

# ---   *   ---   *   ---
# no match

    } else {$$doc.=$tok;$tok=NULLSTR;};$i++;


  };

# ---   *   ---   *   ---
# multi-line block exit

  if($$lvl<0) {

    my $v=$ode.$$doc;
    my $id;

# ---   *   ---   *   ---
# use pre-existing id

    if(exists $self->{strings}->{$v}) {
      $id=$self->{strings}->{$v};

# ---   *   ---   *   ---
# generate new id

    } else {

      $id=sprintf(
        lang::cut_token_f(),
        'MLS',int(@{$self->{strings}})

      );

      $self->{strings}->{$id}=$v;
      $self->{strings}->{$v}=$id;

    };

# ---   *   ---   *   ---
# separate non-block sections of string

    $s=$self->{in_mls}->[4].
      $id.(substr $rem,$i,length $cde);

    $accum=join NULLSTR,@ar[$i+length $cde..$#ar];
    $self->{in_mls}=0;

  };

# ---   *   ---   *   ---
# save accumulated docs
# this is to account for cases where
# the end of one block and the beg
# of another are on the same line

  $self->{line}=$s;
  $self->{rem}($accum);

  return;

};

# ---   *   ---   *   ---
# abstracts away preprocessor, strings
# and related blocks that escape
# common interpretation

sub tokenize_block($self) {

  my $lang=$self->{lang};
  my $matchtab=$lang->{-DEL_MT};

  my $first_frame=0;

# ---   *   ---   *   ---
# check for mls block beg

  TOP:if(!$self->{in_mls}) {

    my $pat=$lang->{-MLS_RULE}->(
      $lang,$self->{line}

    );

    if(!defined $pat) {goto TAIL;};

    if($self->{line}=~ s/^(.*)${pat}/$1:__CUT__/) {

      my $ode=${^CAPTURE[1]};
      my $cde=$matchtab->{$ode};

      $self->{in_mls}=[
        $ode,$cde,NULLSTR,0

      ];

    };$first_frame=1;

# ---   *   ---   *   ---
# beg found/processing pending

  };if($self->{in_mls}) {
    $self->mls_block($first_frame);

# ---   *   ---   *   ---
# new mls beg

    if(!$self->{in_mls}) {

      if(length lang::stripline($self->{rem})) {

        $self->{mls_accum}=
          $self->{mls_accum}.
          $self->{line}

        ;

        $self->{line}=$self->{rem};
        $self->{rem}=NULLSTR;

        goto TOP;

# ---   *   ---   *   ---
# no mls blocks pending

      };
    };

  };TAIL:if(

       !$self->{in_mls}
    && $self->{mls_accum}

  ) {

    $self->{line}=
      $self->{mls_accum}.
      $self->{line}

    ;

    $self->{mls_accum}=NULLSTR;
    $self->{rem}=NULLSTR;

  };

  return;

};

# ---   *   ---   *   ---
# abstracts away blocks that
# need to be kept intact

sub mangle($self) {

  #$self->tokenize_block();
  if(length lang::stripline($self->{line})) {

    $self->{line}=~
      s/([>'])%/${^CAPTURE[0]}\%/sg;

    my $append=undef;
    if($self->{keep_comments}) {
      $append=[-LCOM];

    };

# ---   *   ---   *   ---

    my @tags=$self->{lang}->mcut_tags($append);
    $self->{line}=lang::mcut(

      $self->{line},
      $self->{strings},

      @tags,

    );

  };push @{$self->{raw}},$self->{line};

  return;

};

# ---   *   ---   *   ---
# sanitize line of code

sub clean($self) {

  my $lang=$self->{lang};

  my $com=$lang->{-COM};
  my $eb=$lang->{-EXP_BOUND};

  # strip comments
  $self->{line}=~ s/${com}.*//g;

  # remove indent
  $self->{line}=~ s/^\s+//sg;

  # replace newlines with tokens
  $self->{line}=~ s/\n/:__NL__:/sg;

  # no spaces surrounding commas
  $self->{line}=~ s/\s*,\s*/,/sg;

  # force single spaces
  $self->{line}=~ s/\s+/\$:rdclpad;>/sg;
  $self->{line}=~ s/\$:rdclpad;>/ /sg;

  $self->{line}=~ s/'.$eb.'\s+/'.$eb.'/sg;

# ---   *   ---   *   ---
# skip blanks

  if(!length lang::stripline($self->{line})) {
    goto TAIL;

  };

# ---   *   ---   *   ---
# cancel spaces around operators
# only if operator takes an operand
# on a given side

  my $op_prec=$lang->{-OP_PREC};
  my $op=$lang->{-OPS};

  while($self->{line}=~ m/[^\\\\]${op}/) {

    my $key=$1;
    my $v='('."\Q$key".')';

# ---   *   ---   *   ---
# NOTE:
#
#   I thought I could do this without
#   the loop. Well, turns out I can't.
#
#   If we ever find a way...
#
# ---   *   ---   *   ---

    # x {op} y
    if(

       defined $op_prec->{$key}->[2]

    || (  defined $op_prec->{$key}->[0]
       && defined $op_prec->{$key}->[1] )

    ) {

      $self->{line}=~
        s/\s*${v}\s*/:__OP\\${key}__:/sg;

    # x {op}
    } elsif(defined $op_prec->{$key}->[0]) {
      $self->{line}=~ s/\s*${v}/:__OP\\${key}__:/sg;

    # {op} x
    } elsif(defined $op_prec->{$key}->[1]) {
      $self->{line}=~ s/${v}\s*/:__OP\\${key}__:/sg;

    # undef
    } else {
      $self->{line}=~ s/${v}/:__OP\\${key}__:/sg;

    };

  };

# ---   *   ---   *   ---
# restore operators

  while($self->{line}=~ s/:__OP\\([^_]+)__:/$1/) {
    ;

  };

# ---   *   ---   *   ---

  TAIL:
  return (length lang::stripline($self->{line}))>0;

};

# ---   *   ---   *   ---
# append leftovers from previous
# lines read

sub join_rem($self) {

  $self->{line}=$self->{rem}.$self->{line};;
  $self->{rem}=NULLSTR;

  return;

};

# ---   *   ---   *   ---
# filters out an expression array

sub expfilt($self,@ar) {

  my $lang=$self->{lang};
  my $eb=$lang->{-EXP_BOUND};

  # iter array
  for my $e(@ar) {

    # discard blanks
    if(!defined $e || !length $e) {
      next;

    };

# ---   *   ---   *   ---
# catch expression boundary

    if($e=~ m/${eb}/) {
      if(defined $self->{exps}->[-1]) {
        $self->{exps}->[-1]->{has_eb}=1;

      };next;

    };

# ---   *   ---   *   ---
# append to expression list

    push @{$self->{exps}},{
      body=>$e,
      has_eb=>0,

      lineno=>$self->{lineno},

    };

  };

  return;

};

# ---   *   ---   *   ---
# single-line expressions

sub slexps($self) {

  $self->join_rem();

  my $lang=$self->{lang};
  $lang->{-EXP_RULE}->($self);

  my $eb=$lang->{-EXP_BOUND};
  my $sb=$lang->{-SCOPE_BOUND};

  my @ar=split

    m/(${sb})|(${eb})$|(${eb})/,
    $self->{line}

  ;$self->expfilt(@ar);
  return;

};

# ---   *   ---   *   ---
# multi-line expressions

sub mlexps($self) {

  my $lang=$self->{lang};

  my $eb=$lang->{-EXP_BOUND};
  my $sb=$lang->{-SCOPE_BOUND};

  $lang->{-EXP_RULE}->($self);
  my @ar=split

    m/(${sb})|(${eb})/,
    $self->{line}

  ;

# ---   *   ---   *   ---

  my $entry=pop @ar;
  $self->expfilt(@ar);

  if($entry) {
    $self->{rem}=$self->{rem}.$entry;;

  };

  return;

# ---   *   ---   *   ---
# proc 'table' for branchless call

};my $rdprocs=[\&mlexps,\&slexps];

# ---   *   ---   *   ---
# blanks out instance

sub wipe($self) {

  $self->{line}=NULLSTR;
  $self->{rem}=NULLSTR;

  $self->fclose();
  $self->{exps}=[];

  return;

};

# ---   *   ---   *   ---
# in: filepath

# cleans globals
# opens file
# checks header error

sub fopen($self,$src) {

  $self->wipe();

  my $lang=$self->{lang};
  my $hed=$lang->{-HED};

# ---   *   ---   *   ---
# open file

  $self->{fname}=$src;

  open my $FH,'<',
    $self->{fname} or croak STRERR;

  $self->{fhandle}=$FH;

# ---   *   ---   *   ---
# verify header

  my $line=readline $self->{fhandle};
  if($hed eq 'N/A') {goto SKIP;};

  if(!($line=~ m/^${hed}/)) {
    printf {*STDERR}
      $self->{fname}.": bad header\n";

    $self->fclose();
    exit;

  };

# ---   *   ---   *   ---

SKIP:
  $self->{line}=$line;

  # get remains
  $self->{line}=~ s/^${hed}//;
  $self->{rem}=NULLSTR;

  return;

# ---   *   ---   *   ---
# errchk & close

};sub fclose($self) {

  if(defined $self->{fhandle}) {
    close $self->{fhandle} or croak STRERR;

  };$self->{fhandle}=undef;

  return;

};

# ---   *   ---   *   ---
# shorthand for nasty one-liner
# use proc A if regex match, else use proc B

sub expsplit($self) {

  my $lang=$self->{lang};

  my $eb=$lang->{-EXP_BOUND};
  my $sb=$lang->{-SCOPE_BOUND};

  $rdprocs
    ->[$self->{line}=~ m/([${sb}])|${eb}$|${eb}/]
    ->($self)

  ;return;

# ---   *   ---   *   ---
# process buffered line

};sub procline($self) {

  # skip if blank line
  if($self->clean) {

# ---   *   ---   *   ---
# split expressions at scope bound (def: '{ or }')
# or split at expression bound (def: ';')
    $self->expsplit();

  };$self->{lineno}++;

  return;

# ---   *   ---   *   ---
# read entire file

};sub file($self,$src) {

  # open & read first line
  $self->fopen($src);
  $self->mangle();

# ---   *   ---   *   ---
# pass body of file through mangler

  while(my $line=readline $self->{fhandle}) {
    $self->{line}=$line;
    $self->mangle();

  };

  $self->fclose();

# ---   *   ---   *   ---
# iter mangled

  for my $line(@{$self->{raw}}) {
    $self->{line}=$line;
    $self->procline();

  };

  return;

# ---   *   ---   *   ---
# read expressions from a string

};sub string($self,$src) {

  # flush cache
  $self->wipe();

  # split string into lines
  my @ar=split m/\n/,$src;

  my @filtered=();
  for my $l(@ar) {
    if($l) {push @filtered,$l."\n";};

  };

# ---   *   ---   *   ---
# pass str through mangler

  while(@filtered) {
    $self->{line}=shift @filtered;
    $self->mangle();

  };

# ---   *   ---   *   ---
# iter mangled

  for my $line(@{$self->{raw}}) {
    $self->{line}=$line;
    $self->procline();

  };

  return;

};

# ---   *   ---   *   ---
# ensures there are no blank lines in exps

sub no_blanks($self) {

  my @ar=();

  for my $exp(@{$self->{exps}}) {

    if(length lang::stripline($exp->{body})) {
      push @ar,$exp;

    };
  };

  $self->{exps}=\@ar;
  $self->rm_nltoks();

  return;

};

# ---   *   ---   *   ---
# handles that one spacing issue with newlines

sub rm_nltoks($self) {

  my $lang=$self->{lang};

  my $ode=$lang->{-ODE};
  my $cde=$lang->{-CDE};
  my $ndel_op=$lang->{-NDEL_OPS};

  my $notnl='(^|[^_]|_[^:])';

# ---   *   ---   *   ---
# id rather not explain this bit c:
#
#   > it goes through all expressions in tree
#
#   > matches both sides of the expression,
#     ie $a:__NL__:$b
#
#   > decides whether to replace the newline
#     with a space or not

  for my $exp(@{$self->{exps}}) {
    while($exp->{body}=~
      m/${notnl}:__NL__:${notnl}/

    ) {

      my $a=$1;
      my $b=$2;
      my $c=q( );

# ---   *   ---   *   ---
# the criteria for replacing the newline
# goes more or less as follows:
#
#   > a|b is an operator, delimiters included
#
#   OR
#
#   > a|b is an empty string

      if(

         ( ($a=~ m/${ndel_op}|${ode}|${cde}/)
      ||   ($b=~ m/${ndel_op}|${ode}|${cde}/) )

      || ((!length $a) || (!length $b))

      ) {$c=NULLSTR;};

# ---   *   ---   *   ---
# :__NL__: (newline) token is replaced
#
#   > first time around, by either space or empty
#     (see above comment for criteria)
#
#   > second time around is guaranteed to be
#     a 'lone' newline, meaning, no $a:__NL__:$b
#
#     that means: there are no two sides of
#     the string that'd be mangled if we
#     split or join them without first checking
#
#     therefore, simply replace with empty

      $exp->{body}=~ s/:__NL__:/$c/;
    };$exp->{body}=~ s/:__NL__://sg;
  };

  return;

};

# ---   *   ---   *   ---
# BEG boiler for parsing an expression

sub exp_open($rd,$exp) {

  $exp->{body}=~ s/^\s*//;

  my $body=$exp->{body};
  my $has_eb=$exp->{has_eb};
  my $lineno=$exp->{lineno};

  push @{$rd->{cooked}},
    $lineno.':__COOKED__:'.$body;

  return ($body,$has_eb,$lineno);

};

# ---   *   ---   *   ---
# END boiler for parsing an expression

sub exp_close($exp,$has_eb,$lineno) {

  $exp->{has_eb}=$has_eb;
  $exp->{lineno}=$lineno;

  return;

};

# ---   *   ---   *   ---
# handles scope-bounds
#
# this call ensures that:
#
#   > parse tree will parent expressions
#     following a scope open ops ( default '{' )
#     to a node containing that operator
#
#   > subsequent scope open operators WILL
#     also be parented to precesding scopes
#
#   > scope close ops ( default '}' ) pop
#     one level from the hierarchy

sub exp_hierarchy(

  $rd,$exp,$anchor,
  $anchors,$body

) {

  my $lang=$rd->{lang};

  my $sb=$lang->{-SCOPE_BOUND};
  my $ode=$lang->{-ODE};
  my $cde=$lang->{-CDE};

  my $out=0;
  my $fr_node=$rd->{program}->node;

# ---   *   ---   *   ---
# match against bound open/close

  if($body=~ m/${sb}/) {

    $exp=$fr_node->nit($$anchor,$body);

    # on open
    if($body=~ m/${ode}/) {
      push @$anchors,$$anchor;
      $$anchor=$exp;

    # on close
    } else {
      $$anchor=pop @$anchors;

# ---   *   ---   *   ---
# returns truth if bound was matched

    };$out=1;
  };return $out;

};

# ---   *   ---   *   ---
# parsing solely with peso::node

sub regular_parse(
  $rd,$exp,
  $anchor,$anchors

) {

  my $lang=$rd->{lang};
  my $fr_node=$rd->{program}->node;

  my ($body,$has_eb,$lineno)=exp_open(
    $rd,$exp

  );

# ---   *   ---   *   ---
# check for scope open/close

  if(!exp_hierarchy(

    $rd,$exp,\$anchor,
    $anchors,$body

  )) {

# ---   *   ---   *   ---
# break down the expression

    $exp=$fr_node->nit($anchor,'void');

    # organize hierarchically
    $exp->tokenize($body);
    $exp->agroup();
    $exp->subdiv();

# ---   *   ---   *   ---
# check first field for keywords

    my $f=$exp->fieldn(0);
    if($lang->is_keyword(
      $f->{leaves}->[0]->{value}

    )) {

      # replace 'void' for found keyword
      $exp->{value}=$f->{leaves}->[0]->{value};
      $exp->pluck($f);

      # reorder leftover fields
      my $i=0;for my $leaf(@{$exp->{leaves}}) {
        $leaf->{value}="field_$i";$i++;

      };
    };

# ---   *   ---   *   ---
# remember if node has boundary char

  };exp_close($exp,$has_eb,$lineno);
  return ($exp,$anchor);

};

# ---   *   ---   *   ---
# parsing with peso::node and plps

sub plps_parse(
  $rd,$exp,
  $anchor,$anchors

) {

  my $lang=$rd->{lang};
  my $fr_node=$rd->{program}->node;

  my ($body,$has_eb,$lineno)=exp_open(
    $rd,$exp

  );

# ---   *   ---   *   ---
# check for scope open/close

  if(!exp_hierarchy(

    $rd,$exp,\$anchor,
    $anchors,$body

  )) {

# ---   *   ---   *   ---
# break down the expression

    $exp=$fr_node->nit($anchor,'void');

    # organize hierarchically
    $exp->tokenize($body);
    $exp->agroup();
    $exp->subdiv();

# ---   *   ---   *   ---
# extract data from tree

    # convert delimiters to references
    # save those to refs hash in program
    $exp->odeop(1);
    $exp->branchrefs($rd->{program}->{refs});

    # ^duplicate branch and undo conversion
    # on the original branch
    my $cpy=$exp->dup();
    $exp->odeop(0);

# ---   *   ---   *   ---
# collapse dup-ed tree to a single branch

    $cpy->nocslist();
    $cpy->defield();

    # flatten branch into a string
    my $s=$cpy->flatten(depth=>1);
    $s=~ s/^void //;
    $s=~ s/\s*$//s;

# ---   *   ---   *   ---
# match against plps patterns
# TODO: find 'likely' patterns to
# match string rather than iter them all

    my $exp_key=NULLSTR;
    my $tree=undef;

    for my $key(
      'ptr_decl',
      'type_decl',

    ) {

      $tree=$lang->plps_match(
        $key,$s

      # terminate loop on full match
      );if($tree->{full}) {
        $exp_key=$key;last;

      };

# ---   *   ---   *   ---
# use plps tree to encode expression

    };if(length $exp_key) {

      $exp->{btc}=peso::fndmtl::take(
        $rd->{program},
        $exp_key,
        $tree

      );

      # set expression context
      $exp->{value}=$exp_key;

# ---   *   ---   *   ---
# run on first pass for declarations
#
# this is solely to comply with
# peso rule 0x03, that is:
#
#   > no fwd decls
#
# which roughly means find all symbols first,
# THEN try to make sense of the program

      if($exp_key=~ m/_decl$/) {
        peso::fndmtl::give(
          $rd->{program},
          $exp

        );
      };

# ---   *   ---   *   ---
# errthrow on match fail
#
# TODO: allow exception for mixed-language
#       cases. lyperl would need that!

    } else {

      print {*STDERR}

        "$body\n".

        "\e[33;1m".
        "^couldn't match this line\n\n".
        "\e[0m";

      exit;

    };

# ---   *   ---   *   ---
# remember if node has boundary char

  };exp_close($exp,$has_eb,$lineno);
  return ($exp,$anchor);

};

# ---   *   ---   *   ---
# entry point

sub parse(
  $lang,$mode,$src,

  %opt

) {

  # opt defaults
  $opt{keep_comments}//=0;
  $opt{use_plps}//=1;
  $opt{lineno}//=1;

# ---   *   ---   *   ---
# nit program and read file/string

  my $program=peso::program::nit($lang);
  my $rd=nit($program,$opt{keep_comments});

  $rd->{lineno}=$opt{lineno};
  (\&file,\&string)[$mode]->($rd,$src);

# ---   *   ---   *   ---
# ^handle leftovers from read

  if($rd->{rem}) {
    $rd->{line}=$rd->{rem};
    $rd->{lang}->{-EXP_RULE}->($rd);

  };$rd->no_blanks();

# ---   *   ---   *   ---
# initialize the parse tree

  my $fr_node=$program->node;
  my $fr_ptr=$program->ptr;
  my $fr_blk=$program->blk;

  my $root=$fr_node->nit(
    undef,
    'PROGRAM_ROOT'

  );

  my $anchor=$root;
  my @anchors=($root);

# ---   *   ---   *   ---
# select parsing function

  my $parse_fn;
  my $plps_parsed=0;

  if(

      $lang->{-NAME} eq 'plps'
  || !$opt{use_plps}

  ) {

    $parse_fn=\&regular_parse;

  } else {

    $parse_fn=\&plps_parse;
    $plps_parsed=1;

  };

# ---   *   ---   *   ---
# execute parser

  for my $exp(@{$rd->{exps}}) {
    ($exp,$anchor)=$parse_fn->(
      $rd,$exp,$anchor,\@anchors

    );

  };

# ---   *   ---   *   ---
# test program execution

  if($plps_parsed) {

    $root->defield();
    $root->findptrs();
    $program->incpass();

    for my $branch(@{$root->{leaves}}) {
      peso::fndmtl::give($program,$branch);

    };

    $program->blk->NON->prich();

  };

# ---   *   ---   *   ---
# copy over read data to program

  $program->{tree}=$root;

  $program->{strings}=$rd->{strings};
  $program->{raw}=$rd->{raw};
  $program->{cooked}=$rd->{cooked};

  return $program;

};

# ---   *   ---   *   ---
# EXPERIMENTAL STUFF
# dont touch
# ---   *   ---   *   ---

# ---   *   ---   *   ---
# strips comments and blanks

sub cleaner($self,$body) {

  my @lines=();
  my $comment_re=$self->{lang}->{comment_re};

  for my $line(split NEWLINE_RE,$body) {
    $line=~ s/$comment_re//sg;
    if(length lang::stripline($line)) {
      push @lines,$line;

    };

  };

  return join NULLSTR,@lines;

};

# ---   *   ---   *   ---
# branches out node from token

sub tokenizer($self,$node,$body) {

  my $exp_bound_re=$self->{lang}->{exp_bound_re};
  my @exps=();

# ---   *   ---   *   ---
# filter out empties

  { my @tmp=split $exp_bound_re,$body;
    for my $s(@tmp) {
      if(

         defined $s
      && length lang::stripline($s)

      ) {

        push @exps,$s;

      };

    };

  };

# ---   *   ---   *   ---
# only attempt tokenization when
# there is more than one possible token!

  my $out=1;
  if(@exps==1) {$out=0;goto TAIL};

# ---   *   ---   *   ---
# convert the string into a tree branch

  my $nd_frame=$self->{program}->{node};
  for my $exp(@exps) {
    $exp=$nd_frame->nit($node,$exp);
    $exp->tokenize2();

  };

# ---   *   ---   *   ---

TAIL:
  return $out;

};

# ---   *   ---   *   ---
# TODO: move this ROM sec somewhere else

  my $cut_re=shwl::CUT_RE;
  my $cut_a_re="$cut_re";
  my $cut_b_re="$cut_re";

  $cut_a_re=~ s/\\w\+/(?:CURLY|BRACKET|PARENS)/;
  $cut_b_re=~ s/\\w\+/(?:STR|QSTR|CHR|EXE)/;

  $cut_a_re=qr{$cut_a_re};
  $cut_b_re=qr{$cut_b_re};

# ---   *   ---   *   ---
# executes expandable tokens across
# the given tree branch

sub recurse($self,@pending) {

  my $block=$self->{curblk};

# ---   *   ---   *   ---
# walk the hierarchy

  while(@pending) {
    my $node=shift @pending;

# ---   *   ---   *   ---
# check node for expandable tokens

TOP:

    my $key=$node->{value};
    if($key=~ m/($cut_a_re)/) {

      $key=${^CAPTURE[0]};

      # replace token with code string
      my $repl=$block->{strings}->{$key};
      $node->{value}=~ s/${key}/$repl/;

      my $body=$self->cleaner($node->{value});

# ---   *   ---   *   ---
# multiple expansions, consume root

      if($self->tokenizer($node,$body)) {
        unshift @pending,@{$node->{leaves}};
        $node->flatten_branch();

# ---   *   ---   *   ---
# single expansion, re-evaluate

      } else {
        goto TOP;

      };

# ---   *   ---   *   ---
# nothing to expand

    } else {
      unshift @pending,@{$node->{leaves}};

    };

  };

};

# ---   *   ---   *   ---

sub new_parser($lang,$fname) {

  my $m=peso::program::nit($lang);
  my $self=nit2($m,$fname);

  my $nd_frame=$m->{node};
  for my $id(keys %{$self->{blocks}}) {

    my $root=$nd_frame->nit(undef,$id);
    my $block=$self->{blocks}->{$id};
    my $body=$self->cleaner($block->{body});

    $self->tokenizer($root,$body);
    $block->{tree}=$root;

  };

  return $self;

};

# ---   *   ---   *   ---
# set current block from id

sub select_block($self,$id) {
  $self->{curblk}=$self->{blocks}->{$id};
  return $self->{curblk};

};

# ---   *   ---   *   ---

sub expand_branch($self,$root) {

  my $block=$self->{curblk};
  my $body=$self->cleaner($root->{value});

  $self->tokenizer(
    $root,
    $body

  );

  $self->recurse($root);
  $self->replstr($root);

};

# ---   *   ---   *   ---
# expands tokens into string literals

sub replstr($self,$root) {

  my $block=$self->{curblk};

  for my $branch($root->branches_in($cut_b_re)) {

    my $key=$branch->{value};
    if($key=~ m/($cut_b_re)/) {

      $key=${^CAPTURE[0]};

      # replace token with raw string
      my $repl=$block->{strings}->{$key};
      $branch->{value}=~ s/${key}/$repl/;

    };

  };

};

# ---   *   ---   *   ---

sub nit2($program,$fname) {

  my $rd=bless {

    program=>$program,

    lang=>$program->lang,

    blocks=>shwl::codefold($fname),
    curblk=>undef,

    fname=>$fname,

  },'peso::rd';

  return $rd;

};

# ---   *   ---   *   ---
1; # ret
