#!/usr/bin/perl
# ---   *   ---   *   ---
# RD
# reads pe files
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
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';

  use lang;
  use peso::program;

# ---   *   ---   *   ---
# getters/setters

;;sub line($;$) {

  my $self=shift;
  my $new=shift;

  if(defined $new) {
    $self->{-LINE}=$new;

  };return $self->{-LINE};

};sub rem($;$) {

  my $self=shift;
  my $new=shift;

  if(defined $new) {
    $self->{-REM}=$new;

  };return $self->{-REM};

# ---   *   ---   *   ---

};sub in_mls_block($;$) {

  my $self=shift;
  my $new=shift;

  if(defined $new) {
    $self->{-IN_MLS}=$new;

  };return $self->{-IN_MLS};

};sub mls_accum($;$) {

  my $self=shift;
  my $new=shift;

  if(defined $new) {
    $self->{-MLS_ACCUM}=$new;

  };return $self->{-MLS_ACCUM};

};

# ---   *   ---   *   ---

sub exps($) {return (shift)->{-EXPS};};
sub program($) {return (shift)->{-PROGRAM};};
sub lang($) {return (shift)->program->lang;};
sub strings($) {return (shift)->{-STRINGS};};
sub raw($) {return (shift)->{-RAW};};
sub cooked($) {return (shift)->{-COOKED};};

# ---   *   ---   *   ---

sub keep_comments($) {
  return (shift)->{-KEEP_COMMENTS};

};

# ---   *   ---   *   ---
# constructor

sub nit($$) {

  my ($program,$keep_comments)=@_;

  return bless {

    -PROGRAM=>$program,

    -LINE=>'',
    -REM=>'',

    -FNAME=>'',
    -FHANDLE=>undef,

    -EXPS=>[],

    -MLS_ACCUM=>'',
    -IN_MLS=>undef,

    -RAW=>[],
    -COOKED=>[],
    -STRINGS=>{},

    -KEEP_COMMENTS=>$keep_comments,

  },'peso::rd';

};

# ---   *   ---   *   ---
# flags

  use constant {
    FILE=>0x00,
    STR=>0x01,

  };

# ---   *   ---   *   ---

sub mls_block($$) {

  my ($self,$first_frame)=@_;

  my $ode=$self->in_mls_block->[0];
  my $cde=$self->in_mls_block->[1];
  my $doc=\$self->in_mls_block->[2];
  my $lvl=\$self->in_mls_block->[3];

  my ($s,$rem);

  if($first_frame) {
    ($s,$rem)=split ':__CUT__',$self->line;
    $self->in_mls_block->[4]=$s;

  } else {
    ($s,$rem)=('',$self->line);

  };

# ---   *   ---   *   ---
# iter the doc block line

  my $i=0;
  my $accum='';
  my $tok='';

  my @ar=split '',$rem;

  for my $c(@ar) {

    $tok.=$c;

# ---   *   ---   *   ---
# close char downs the depth

    if($cde=~ m/^\Q${tok}/) {

      if($tok=~ m/^${cde}/) {

        if($$lvl) {
          $$doc.=$tok;
          $tok='';

        };$$lvl--;

        if($$lvl<0) {$i++;last;};

      };$i++;next;

# ---   *   ---   *   ---
# open char ups the depth

    } elsif($ode=~ m/^\Q${tok}/) {

      if($tok=~ m/^${ode}/) {

        $$lvl++;
        $$doc.=$tok;
        $tok='';

      };$i++;next;

# ---   *   ---   *   ---
# no match

    } else {$$doc.=$tok;$tok='';};$i++;


  };

# ---   *   ---   *   ---

  if($$lvl<0) {

    my $v=$ode.$$doc;
    my $id;

    if(exists $self->strings->{$v}) {
      $id=$self->strings->{$v};

    } else {

      $id=sprintf(
        lang::cut_token_f(),
        'MLS',int(@{$self->strings})

      );

      $self->strings->{$id}=$v;
      $self->strings->{$v}=$id;

    };

    $s=$self->in_mls_block->[4].
      $id.(substr $rem,$i,length $cde);

    $accum=join '',@ar[$i+length $cde..$#ar];
    $self->in_mls_block(0);

  };

  $self->line($s);
  $self->rem($accum);

};

# ---   *   ---   *   ---
# abstracts away preprocessor, strings
# and related blocks that escape
# common interpretation

sub tokenize_block($) {

  my $self=shift;
  my $lang=$self->lang;
  my $matchtab=$lang->del_mt;

  my $first_frame=0;

# ---   *   ---   *   ---
# check for mls block beg

  TOP:if(!$self->in_mls_block) {

    my $pat=$lang->mls_rule->($lang,$self->line);
    if(!defined $pat) {goto END;};

    if($self->{-LINE}=~ s/^(.*)${pat}/$1:__CUT__/) {

      my $ode=$2;
      my $cde=$matchtab->{$ode};

      $self->in_mls_block([
        $ode,$cde,'',0

      ]);

    };$first_frame=1;

# ---   *   ---   *   ---
# beg found/processing pending

  };if($self->in_mls_block) {
    $self->mls_block($first_frame);

# ---   *   ---   *   ---
# new mls beg

    if(!$self->in_mls_block) {

      if(length lang::stripline($self->rem)) {

        $self->mls_accum(
          $self->mls_accum.
          $self->line

        );

        $self->line($self->rem);
        $self->rem('');

        goto TOP;

# ---   *   ---   *   ---
# no mls blocks pending

      };
    };

  };END:if(

       !$self->in_mls_block
    && $self->mls_accum

  ) {

    $self->line(
      $self->mls_accum.
      $self->line

    );

    $self->mls_accum('');
    $self->rem('');

  };
};

# ---   *   ---   *   ---
# abstracts away blocks that
# need to be kept intact

sub mangle($) {

  my $self=shift;

# ---   *   ---   *   ---

  #$self->tokenize_block();
  if(length lang::stripline($self->line)) {

    $self->{-LINE}=~ s/([>'])%/$1\%/sg;

    my $append=undef;
    if($self->keep_comments) {
      $append=[-LCOM];

    };

# ---   *   ---   *   ---

    my @tags=$self->lang->mcut_tags($append);
    $self->line(lang::mcut(

      $self->line,
      $self->strings,

      @tags,

    ));

  };push @{$self->raw},$self->line;

};

# ---   *   ---   *   ---
# sanitize line of code

sub clean($) {

  my $self=shift;
  my $lang=$self->lang;

  my $com=$lang->com;
  my $eb=$lang->exp_bound;

  # strip comments
  $self->{-LINE}=~ s/${com}.*//g;

  # remove indent
  $self->{-LINE}=~ s/^\s+//sg;

  # replace newlines with tokens
  $self->{-LINE}=~ s/\n/:__NL__:/sg;

  # no spaces surrounding commas
  $self->{-LINE}=~ s/\s*,\s*/,/sg;

  # force single spaces
  $self->{-LINE}=~ s/\s+/\$:rdclpad;>/sg;
  $self->{-LINE}=~ s/\$:rdclpad;>/ /sg;

  $self->{-LINE}=~ s/'.$eb.'\s+/'.$eb.'/sg;

# ---   *   ---   *   ---
# skip blanks

  if(!length lang::stripline($self->line)) {
    goto END;

  };

# ---   *   ---   *   ---
# cancel spaces around operators
# only if operator takes an operand
# on a given side

  my $op_prec=$lang->op_prec;
  my $op=$lang->ops;

  while($self->{-LINE}=~ m/[^\\\\]${op}/) {

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

      $self->{-LINE}=~ s/\s*${v}\s*/\$:op \\$key;>/sg;

    # x {op}
    } elsif(defined $op_prec->{$key}->[0]) {
      $self->{-LINE}=~ s/\s*${v}/\$:op \\$key;>/sg;

    # {op} x
    } elsif(defined $op_prec->{$key}->[1]) {
      $self->{-LINE}=~ s/${v}\s*/\$:op \\$key;>/sg;

    # undef
    } else {
      $self->{-LINE}=~ s/${v}/\$:op \\$key;>/sg;

    };

  };

# ---   *   ---   *   ---
# restore operators

  while($self->{-LINE}=~ s/\$:op \\([^;]+);>/$1/) {
    ;

  };

# ---   *   ---   *   ---

  END:
  return (length lang::stripline($self->line))>0;

};

# ---   *   ---   *   ---
# append leftovers from previous
# lines read

sub join_rem {

  my $self=shift;

  $self->line($self->rem.$self->line);
  $self->rem('');

};

# ---   *   ---   *   ---
# filters out an expression array

sub expfilt($@) {

  my ($self,@ar)=@_;
  my $lang=$self->lang;

  my $eb=$lang->exp_bound;

  # iter array
  for my $e(@ar) {

    # discard blanks
    if(!defined $e || !length $e) {
      next;

    };

# ---   *   ---   *   ---
# catch expression boundary

    if($e=~ m/${eb}/) {
      if(defined $self->exps->[-1]) {
        $self->exps->[-1]->{has_eb}=1;

      };next;

    };

# ---   *   ---   *   ---
# append to expression list

    push @{$self->exps},{
      body=>$e,
      has_eb=>0,

      lineno=>$self->{lineno},

    };

  };
};

# ---   *   ---   *   ---
# single-line expressions

sub slexps($) {

  my $self=shift;
  $self->join_rem();

  my $lang=$self->lang;
  $lang->exp_rule->($self);

  my $eb=$lang->exp_bound;
  my $sb=$lang->scope_bound;

  my @ar=split

    m/(${sb})|(${eb})$|(${eb})/,
    $self->line

  ;$self->expfilt(@ar);
};

# ---   *   ---   *   ---
# multi-line expressions

sub mlexps($) {

  my $self=shift;
  my $lang=$self->lang;

  my $eb=$lang->exp_bound;
  my $sb=$lang->scope_bound;

  $lang->exp_rule->($self);
  my @ar=split

    m/(${sb})|(${eb})/,
    $self->line

  ;

  my $entry=pop @ar;
  $self->expfilt(@ar);

  if($entry) {
    $self->rem($self->rem.$entry);

  };

# ---   *   ---   *   ---
# proc 'table' for branchless call

};my $rdprocs=[\&mlexps,\&slexps];

# ---   *   ---   *   ---
# blanks out instance

sub wipe {

  my $self=shift;

  $self->line('');
  $self->rem('');

  $self->fclose();
  $self->{-EXPS}=[];

};

# ---   *   ---   *   ---
# in: filepath

# cleans globals
# opens file
# checks header error

sub fopen {

  my ($self,$src)=@_;
  $self->wipe();

  my $lang=$self->lang;
  my $hed=$lang->hed;

  # open file
  $self->{-FNAME}=$src;open

    my $FH,'<',
    $self->{-FNAME} or die $!

  ;$self->{-FHANDLE}=$FH;

  # verify header
  my $line=readline $self->{-FHANDLE};
  if($hed eq 'N/A') {goto SKIP;};

  if(!($line=~ m/^${hed}/)) {
    printf STDERR $self->{-FNAME}.": bad header\n";
    fclose();

    exit;

  };

  SKIP:
  $self->line($line);

  # get remains
  $self->{-LINE}=~ s/^${hed}//;
  $self->rem('');

# ---   *   ---   *   ---
# errchk & close

};sub fclose {

  my $self=shift;

  if(defined $self->{-FHANDLE}) {
    close $self->{-FHANDLE};

  };$self->{-FHANDLE}=undef;

};

# ---   *   ---   *   ---
# shorthand for nasty one-liner
# use proc A if regex match, else use proc B

sub expsplit {

  my $self=shift;
  my $lang=$self->lang;

  my $eb=$lang->exp_bound;
  my $sb=$lang->scope_bound;

  $rdprocs
    ->[$self->line=~ m/([${sb}])|${eb}$|${eb}/]
    ->($self)

  ;

# ---   *   ---   *   ---
# process buffered line

};sub procline {

  my $self=shift;

  # skip if blank line
  if($self->clean) {

# ---   *   ---   *   ---
# split expressions at scope bound (def: '{ or }')
# or split at expression bound (def: ';')
    $self->expsplit();

  };$self->{lineno}++;

# ---   *   ---   *   ---
# read entire file

};sub file {

  my ($self,$src)=@_;

  # open & read first line
  $self->fopen($src);
  $self->mangle();

# ---   *   ---   *   ---
# pass body of file through mangler

  while(my $line=readline $self->{-FHANDLE}) {
    $self->line($line);
    $self->mangle();

  };

  # close file
  $self->fclose();

# ---   *   ---   *   ---
# iter mangled

  for my $line(@{$self->raw}) {
    $self->line($line);
    $self->procline();

  };

# ---   *   ---   *   ---
# read expressions from a string

};sub string {

  my ($self,$src)=@_;

  # flush cache
  $self->wipe();

  # split string into lines
  my @ar=split "\n",$src;

  my @filtered=();
  for my $l(@ar) {
    if($l) {push @filtered,$l."\n";};

  };

# ---   *   ---   *   ---
# pass str through mangler

  while(@filtered) {
    $self->line(shift @filtered);
    $self->mangle();

  };

# ---   *   ---   *   ---
# iter mangled

  for my $line(@{$self->raw}) {
    $self->line($line);
    $self->procline();

  };

};

# ---   *   ---   *   ---

sub no_blanks($) {

  my $self=shift;
  my @ar=();

  for my $exp(@{$self->exps}) {

    if(length lang::stripline($exp->{body})) {
      push @ar,$exp;

    };
  };

  $self->{-EXPS}=\@ar;
  $self->rm_nltoks();

};

# ---   *   ---   *   ---
# handles that one spacing issue with newlines

sub rm_nltoks($) {

  my $self=shift;
  my $lang=$self->lang;

  my $ode=$lang->ode;
  my $cde=$lang->cde;
  my $ndel_op=$lang->ndel_ops;

  my $notnl='(^|[^_]|_[^:])';

  for my $exp(@{$self->exps}) {
    while($exp->{body}=~
      m/${notnl}:__NL__:${notnl}/

    ) {

      my $a=$1;
      my $b=$2;
      my $c=' ';

      if(

         ( ($a=~ m/${ndel_op}|${ode}|${cde}/)
      ||   ($b=~ m/${ndel_op}|${ode}|${cde}/) )

      || ((!length $a) || (!length $b))

      ) {$c='';};

      $exp->{body}=~ s/:__NL__:/$c/;

    };$exp->{body}=~ s/:__NL__://sg;
  };
};

# ---   *   ---   *   ---

sub parse($$$;@) {

  my ($lang,$mode,$src,%opt)=@_;

  my $keep_comments=$opt{keep_comments};
  my $lineno=$opt{lineno};

  $keep_comments=(!defined $keep_comments)
    ? 0
    : $keep_comments
    ;

  $lineno=(!defined $lineno)
    ? 1
    : $lineno
    ;

  my $program=peso::program::nit($lang);
  my $rd=nit($program,$keep_comments);

  $rd->{lineno}=$lineno;
  (\&file,\&string)[$mode]->($rd,$src);

# ---   *   ---   *   ---
# handle leftovers

  if($rd->rem) {
    $rd->line($rd->rem);
    $rd->lang->exp_rule->($rd);

  };$rd->no_blanks();

# ---   *   ---   *   ---

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

  my $sb=$lang->scope_bound;
  my $ode=$lang->ode;
  my $cde=$lang->cde;

  for my $exp(@{$rd->exps}) {

    $exp->{body}=~ s/^\s*//;

    my $body=$exp->{body};
    my $has_eb=$exp->{has_eb};
    my $lineno=$exp->{lineno};

    push @{$rd->cooked},$body;

# ---   *   ---   *   ---

    if($body=~ m/${sb}/) {

      $exp=$fr_node->nit($anchor,$body);

      if($body=~ m/${ode}/) {
        push @anchors,$anchor;
        $anchor=$exp;

      } else {
        $anchor=pop @anchors;

      };

# ---   *   ---   *   ---

    } else {

      $exp=$fr_node->nit($anchor,'void');

      $exp->tokenize($body);
      $exp->agroup();
      $exp->subdiv();

# ---   *   ---   *   ---
# contextualize, so to speak

      my $f=$exp->fieldn(0);
      if($lang->is_keyword(
        $f->leaves->[0]->value

      )) {

        $exp->value($f->leaves->[0]->value);
        $exp->pluck($f);

        my $i=0;for my $leaf(@{$exp->leaves}) {
          $leaf->value("field_$i");$i++;

        };

      };

# ---   *   ---   *   ---
# remember if node has boundary char

    };$exp->{has_eb}=$has_eb;
      $exp->{lineno}=$lineno;

  };

# ---   *   ---   *   ---
# copy over read data to program

  $program->{tree}=$root;

  $program->{strings}=$rd->strings;
  $program->{raw}=$rd->raw;
  $program->{cooked}=$rd->cooked;

  return $program;

};

# ---   *   ---   *   ---

