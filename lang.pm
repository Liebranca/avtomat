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

# ^ this note is outdated ;>
# dirty regexes are at their own language files now

# ---   *   ---   *   ---

# deps
package node;
  use strict;
  use warnings;

my %CACHE=(

  -TREES=>[],
  -NAMES=>'[_a-zA-Z][_a-zA-Z0-9]',

# ---   *   ---   *   ---

  -OPS=>''.

    '[\+\-\*\/\\\$\@\%\&'.
    '\^\<\>\!\|\?\{\[\(\)'.
    '\]\}\~\.\=\;\:]',

#((2 *: (y*^2)):/ 8) :+ 8

  -OP_PREC=>[

    '*^','*','/','++','+','--','-',

    '?','!','~',
    '<<','>>','|','^','&',

    '&&','||',

    ';>','$:',

  ],

# ---   *   ---   *   ---

  -ODE=>'[\(\[\{]',
  -CDE=>'[\}\]\)]',

  -DEPTH=>[],
  -LDEPTH=>0,
  -ANCHOR=>undef,

);

# ---   *   ---   *   ---

# in: self,val
# make child node or create a new tree
sub nit {

  # pass undef for new tree
  my $self=shift;

  # value for new node
  my $val=shift;

  # tree/root handle
  my %tree=(

    -FUSE=>undef,
    -ROOT=>undef,

  );my $tree_id;

# ---   *   ---   *   ---

  # make new tree if !$self
  if(!(defined $self)) {

    my @ar=@{ $CACHE{-TREES} };
    $tree_id=@ar;

    if(defined $CACHE{-ANCHOR}) {

      #printf "$val\n";

      $tree{-FUSE}=$CACHE{-DEPTH}->[-1];
      $tree{-ROOT}=undef;

    };

    push @{ $CACHE{-TREES} },\%tree;

# ---   *   ---   *   ---

  # ... or fetch from id
  } else {
    $tree_id=$self->{-ROOT};
    %tree=%{ $CACHE{-TREES}->[$tree_id] };

  # make node instance
  };my $node=bless {

    -VAL=>$val,
    -LEAVES=>[],

    -ROOT=>$tree_id,
    -PAR=>undef,

  },'node';

# ---   *   ---   *   ---

  # add leaf if $self
  if(defined $self) {
    push @{ $self->{-LEAVES} },$node;
    $node->{-PAR}=$self;

  } else {
    $tree{-ROOT}=$node;

  };return $node;

};

sub mksep {

  return bless {

    -VAL=>'$:cut;>',
    -LEAVES=>[],

    -ROOT=>0,
    -PAR=>undef,

  },'node';

};

# ---   *   ---   *   ---

sub branch_reloc {

  my $self=shift;

  # get branch reallocation
  my $tree_id=$self->{-ROOT};
  my %tree=%{ $CACHE{-TREES}->[$tree_id] };

  # move branches to saved tree node
  if($tree{-FUSE}) {
    $tree{-FUSE}->pushlv(0,$self);

  };
};

# ---   *   ---   *   ---

# {} open/close

sub ocurl {
  my $self=shift;
  my $val=shift;

  # use self as fake root
  push @{ $CACHE{-DEPTH} },$self;
  $CACHE{-LDEPTH}++;

  # new nodes append to
  $CACHE{-ANCHOR}=$self;

};sub ccurl {
  my $self=shift;
  my $val=shift;

  # remove last fake root
  my $node=pop @{ $CACHE{-DEPTH} };
  $CACHE{-LDEPTH}--;

  # unset dead anchors
  if(!$CACHE{-LDEPTH}) {
    $CACHE{-ANCHOR}=undef;

  };

  # reorder branches
  $node->pluck($self);
  my @leaves=$self->pluck(@{ $self->{-LEAVES} });
  push @leaves,$self;

  $node->pushlv(0,@leaves);

};

# ---   *   ---   *   ---

# () open/close

sub oparn {
  my $self=shift;
  my $val=shift;

  if($val) {
    $self->nit($val);

  };

  my $node=$self->nit('(');

  return $node;

}; sub cparn {
  my $self=shift;
  my $val=shift;

  if($val) {$self->nit($val);};
  my $node=$self->nit(')');

  return $node;

};

# ---   *   ---   *   ---

sub walkup {

  my $self=shift;
  my $top=shift;

  if(!defined $top) {
    $top=-1;

  };

  my $node=$self->{-PAR};
  my $i=0;

  while($top<$i) {
    my $par=$node->{-PAR};
    if($par) {
      $node=$par;

    } else {last;};$i++;
  };

  return $node;

};

# ---   *   ---   *   ---

# in:overwrite,node arr
# push node array to leaves
sub pushlv {

  my $self=shift;

  my $overwrite=shift;
  if($overwrite) {
    $self->{-LEAVES}=[];

  };

# ---   *   ---   *   ---

  # move nodes
  my %cl=();
  while(@_) {

    my $node=shift;
    if($node eq '$:cut;>') {
      $node=node::mksep();

    };

    my $par=$node->{-PAR};

    $node->{-ROOT}=$self->{-ROOT};
    $node->{-PAR}=$self;

    push @{ $self->{-LEAVES} },$node;

    if($par && $par!=$node->{-PAR}) {
      $par->pluck($node);
      $cl{$par}=$par;

    };

  };for my $node(keys %cl) {
    $node=$cl{$node};
    $node->cllv();

  };
};

# ---   *   ---   *   ---

# discard blank nodes
sub cllv {

  my $self=shift;
  my @cpy=();

  for(

    my $i=0;

    $i<@{ $self->{-LEAVES} };
    $i++

  ) {

    # push only nodes that arent plucked
    my $node=$self->{-LEAVES}->[$i];
    if(defined $node) {
      push @cpy,$node;

    };

  # overwrite with filtered array
  };$self->{-LEAVES}=[@cpy];

};

# ---   *   ---   *   ---

# in:self,pattern,string
# branch out node from pattern split
sub splitlv {

  # instance
  my $self=shift;

  # data
  my $pat=shift;
  my $exp=shift;

  my $exp_depth_a=0;
  my $exp_depth_b=0;

  my @anch=($self);

# ---   *   ---   *   ---

  # spaces are meaningless

  my @elems=();

  { my @ar=split m/([^\s]*)\s+/,$exp;

    while(@ar) {
      my $elem=shift @ar;
      if($elem) {
        push @elems,$elem;

      };
    };

# ---   *   ---   *   ---

  };{

    my @filt=();
    my $s='';

    my $op='[^\sA-Za-z0-9\.:]';
    my $ndel_op='[^\sA-Za-z0-9\.:\[\(\)\]]';

    my $i=0;for my $e(@elems) {

      my ($ol,$or)=(split '',$e)[0,-1];

      if(!defined $or) {
        $or=$ol;

      };

# ---   *   ---   *   ---

      # is a
      if(!$i) {
        push @filt,'$:%%join;>';

      # (x+y)
      } else {

        my ($pl,$pr)=(

          split '',
            $elems[$i-1]

        )[0,-1];

        if(!defined $pr) {
          $pr=$pl;

        };

# ---   *   ---   *   ---


        if(($ol=~ m/${op}/)) {

          if($ol=~ m/\(|\[/) {

            push @filt,$s;$s='';

            if( !($pr=~ m/${op}/) ) {

              #printf "A) $pr : $ol adds a join\n";
              push @filt,'$:/join;>';
              push @filt,'$:%%join;>';

            };

# ---   *   ---   *   ---

          } elsif($pr=~ m/\)|\]/ ) {

            if(!( $ol=~ m/${ndel_op}/) ) {
              #printf "B) $pr : $ol adds a join\n";
              push @filt,'$:/join;>';
              push @filt,'$:%%join;>';

            };

          };

# ---   *   ---   *   ---

        } elsif($pr ne '(') {

          push @filt,$s;$s='';

          if( ($pr=~ m/\)|\]/
          && !($ol=~ m/${op}/) )

          || (!($pr=~ m/${op}/)
          && !($ol=~ m/${op}/))

          ) {

            #printf "C) $pr : $ol adds a join\n";

            push @filt,'$:/join;>';
            push @filt,'$:%%join;>';

          };

          push @filt,$e;

          $i++;next;

# ---   *   ---   *   ---

        };

# ---   *   ---   *   ---

      };$s.=$e;
      $i++;

    };if($s) {push @filt,$s;};

    push @filt,'$:/join;>';
    @elems=@filt;

  };

# ---   *   ---   *   ---

  # split string at pattern
  #for my $sym(split m/(${pat})/,$exp) {
  for my $sym(@elems) {

    if(!length($sym)) {next;};

    # eliminate match
    $exp=~ m/^(.*)\Q${sym}/;
    if(defined $1 && length $1) {
      $exp=~ s/\Q${1}//;

    # space strip
    };$sym=~ s/\s+//sg;

    if($sym eq '$:%%join;>'
    || $sym eq '$:/join;>'

    ) {

      my $node=$self->nit($sym);
      next;

    };

# ---   *   ---   *   ---

  DELMTOP:

  # subdivide by delimiters
  if( $sym=~ m/^(\()/ ) {
    if(!length $sym){last;};

    my $c=$1;

    if($c eq '(') {

      #printf "$sym\n";

      my @ar=split '(\()',$sym;
      my $ex=shift @ar;
      shift @ar;

      $sym=join '',@ar;

      push @anch,$self->oparn($ex);
      $exp_depth_a++;

    };
  };

# ---   *   ---   *   ---

  if($exp_depth_a) {

    if($sym=~ m/\)/) {

      #printf "$sym\n";

      my $ex;
      ($ex,$sym)=split m/\)/,$sym;

      $anch[-1]->cparn($ex);
      pop @anch;

      $sym=~ s/\)//;
      $exp_depth_a--;

      goto DELMTOP;

    };

  };

# ---   *   ---   *   ---

    # make new node from token
    if(!length $sym) {next;$sym='$:cut;>';};
    my $node=$anch[-1]->nit($sym);

  };

};

# ---   *   ---   *   ---

# in: node to replace self by
# replaces a node in the hierarchy

sub repl {

  my $self=shift;
  my $other=shift;

  my $ref=$self->{-PAR}->{-LEAVES};
  my $i=-1;

  for my $node(@$ref) {

    $i++;if($node eq $self) {
      last;

    };
  };

  if($i>=0) {
    $ref->[$i]=$other;

  };

};

# ---   *   ---   *   ---

# in: node list
# removes leaves from node
sub pluck {

  # instance
  my $self=shift;

  # data
  my @ar=@_;

  # return value
  my @plucked=();

# ---   *   ---   *   ---

  # match nodes in list
  { my $i=0;for my $leaf(
    @{ $self->{-LEAVES} }

  # skip removed nodes
  ) { if(!$leaf) {next;};

      # iter node array
      my $j=0;for my $node(@ar) {

        # skip already removed ones
        if(!$node) {$j++;next;};

# ---   *   ---   *   ---

        # node is in remove list
        if($leaf->{-VAL} eq $node->{-VAL}) {

          # save the removed nodes
          push @plucked,$self->{-LEAVES}->[$i];

          # remove from list and leaves
          $ar[$j]=undef;
          $self->{-LEAVES}->[$i]=undef;

          # go to next leaf
          last;

        };$j++; # next in remove list
      };$i++; # next in leaves
    };
  };

# ---   *   ---   *   ---

  # discard blanks
  $self->cllv();

  # return removed nodes
  return @plucked;

};

# ---   *   ---   *   ---

# use peso rules for grouping tokens
sub agroup {

  my $self=shift;

  my @buf=();
  my @dst=();

  my $delims=${CACHE{-ODE}}.'|'.${CACHE{-CDE}};

# ---   *   ---   *   ---

  my @chest=();
  my @trash=();

  my $anchor=$self;

  # branch out at joins
  for my $node(@{ $self->{-LEAVES} }) {

    my $sym=$node->{-VAL};

    # group all nodes inside wrap
    if($sym eq '$:%%join;>') {

      $anchor=$node;
      $node->{-VAL}='L';

    # ^ wrap close
    } elsif($sym eq '$:/join;>') {
      $anchor->pushlv(0,@chest);
      @chest=();

      push @trash,$node;

# ---   *   ---   *   ---

    # accumulate elements
    } else {

      if(0>index $sym,',') {
        push @chest,$node;

      # comma found
      } else {

        my @left=split ',',$sym;
        while(@left) {
          my $tail=shift @left;

# ---   *   ---   *   ---

          # compound element
          if(@chest) {

            my $old=$anchor;
            $anchor=$anchor->nit('$:group;>');

            $anchor->pushlv(0,@chest);
            @chest=();

            $anchor->nit($tail);
            $anchor=$old;

# ---   *   ---   *   ---

          # common element
          } else {

            # push self
            push @chest,
              node::nit(undef,$tail);

            # push leftovers
            while(@left) {
              push @chest,node::nit(
                undef,
                shift @left

              );
            };

          # discard explored node
          };push @trash,$node;
        };

# ---   *   ---   *   ---

      };
    };

# ---   *   ---   *   ---

  };if(@chest) {
    $anchor->pushlv(1,@chest);

  };$self->pluck(@trash);

};

# ---   *   ---   *   ---

# breaks expressions down recursively
sub subdiv {

  my $self=shift;
  my $leaf=$self;
  my $root=$self;

  my @leafstack=();
  my @rootstack=();

  my @nodes=();

  my $ndel_op='[^\sA-Za-z0-9\.,:\[\(\)\]]';

# ---   *   ---   *   ---

TOP:{

  $self=$leaf;

  if(!$self->{-VAL}) {goto SKIP;};

  # non delimiter operator match
  my @ar=split m/(${ndel_op}+)/,$self->{-VAL};

  # we filter out
  my @ops=();
  my @elems=();

# ---   *   ---   *   ---

  # save operators and values separately
  while(@ar) {

    my $e=shift @ar;

    if($e=~ m/(${ndel_op}+)/) {
      push @ops,$e;

    } else {
      push @elems,$e;

    };

  };

  if(!@ops) {goto SKIP;};

# ---   *   ---   *   ---

  # priorities by index
  @ar=@{ $CACHE{-OP_PREC} };

  my @q=@ops;
  my $popped=0;

REPEAT:{

  # sort ops by priority
  my $highest=9999;
  my $hname=undef;
  my $hidex=0;

  my $i=0;

  for my $op(@q) {

    # skip if already matched
    if(!length $op) {
      $popped++;
      $i++;next;

    };

    # get index of op
    my $j=0;for my $e(@ar) {
      if($e eq $op) {last;};

      $j++;

    };

    # compare to previous
    if($j < $highest) {
      $highest=$j;
      $hname=$op;
      $hidex=$i;

    };$i++;

  };

# ---   *   ---   *   ---

  if(!defined $hname) {
    goto RELOC;

  };

  $q[$hidex]='';

  my $lhand=$elems[$hidex];
  my $rhand=$elems[$hidex+1];

  my $node=$self->{-PAR}->nit($hname);

  # handle operands
  my @mov=();
  for my $op_elem($lhand,$rhand) {

    # element is a node
    if((index $op_elem,'node=HASH')>=0) {

      # operand is at root level
      if($op_elem->{-PAR} eq $node->{-PAR}) {
        push @mov,$op_elem;

      # ^ or further down the chain
      } else {
        push @mov,$op_elem->{-PAR};

      };

    # element is a string
    } else {
      $node->nit($op_elem);

    };

# ---   *   ---   *   ---

  # copy operands into node
  };if(@mov) {
    $node->pushlv(0,@mov);

  };

  # overwrite used operands
  $elems[$hidex]=$node;
  $elems[$hidex+1]=$node;

  # loop back
  push @nodes,$node;
  $i=0;if($popped<@q) {goto REPEAT;};

RELOC:
  $self->{-PAR}->pluck($nodes[-1]);
  $self->repl($nodes[-1]);

# ---   *   ---   *   ---

};SKIP:{

  if(!@leafstack && !@{ $self->{-LEAVES} }) {
    return;

  };

  push @leafstack,@{ $self->{-LEAVES} };
  $leaf=pop @leafstack;

  @nodes=();
  goto TOP;

}}};

# ---   *   ---   *   ---

# print node leaves
sub prich {

  # instance
  my $self=shift;
  my $depth=shift;

# ---   *   ---   *   ---

  # print head
  if(!defined $depth) {
    printf "$self->{-VAL}\n";
    $depth=0;

  };

  # iter children
  for my $node(@{ $self->{-LEAVES} }) {

    printf ''.(
      '.  'x($depth).'\-->'.
      $node->{-VAL}


    )."\n";$node->prich($depth+1);

  };

# ---   *   ---   *   ---

  if(@{ $self->{-LEAVES} }) {
    printf '.  'x($depth)."\n";

  };

};

# ---   *   ---   *   ---

# deps
package lang;
  use strict;
  use warnings;

  use lib $ENV{'ARPATH'}.'/lib/';
  use ll;

# ---   *   ---   *   ---

  my $_LUN='[_a-zA-Z][_a-zA-Z0-9]';
  my $DRFC='(::|->|\.)';

  my $OPS='+-*/\$@%&\^<>!|?{[()]}~,.=;:';

# ---   *   ---   *   ---
# regex tools

# in:pattern
# escapes [*]: in pattern
sub lescap {

  my $s=shift;
  for my $c(split '','[*]:') {
    $s=~ s/\Q${ c }/\\${ c }/g;

  };return $s;

};

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
  $ml=(!$ml) ? '' : '\\x0D\\x0A|';

  my $do_uber=shift;
  my @chars=split '',$string;

  my $s=rescap( shift @chars );
  my $re="$ml"."[^$s\\\\]";

  for my $c(@chars) {

    $c=rescap($c);
    $re.='|'.$s."[^$c\\\\]";
    $s.=$c;

  };if($do_uber) {$re.='|'.UBERSCAP( rescap($string) );};
  return $re;
};

# ---   *   ---   *   ---

sub lkback {

  my $pat=rescap(shift);
  my $end=shift;

  return ('('.

    ' '.$end.

    # well, crap
    #'|[^'.$pat.']'.$end.
    '|^'.$end.

  ')');

};

# ---   *   ---   *   ---

# do not use
sub vcapitalize {
  my @words=split '\|',$_[0];
  for my $word(@words){
    $word=~ m/\b([a-z])[a-z]*\b/;

    my $c=$1;if(!$c) {next;};

    $c='('.(lc $c).'|'.(uc $c).')';

    $word=~ s/\b[a-z]([a-z]*)\b/FFFF${ 1 }/;
    $word=~ s/FFFF/${ c }/g;

  };return join '|',@words;

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
    "$beg".
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

  my @chars=split '',$string;
  if(!$disable_escapes) {
    for my $c(@chars) {$c=rescap($c);};

  };return '('.( join '|',@chars).')';

};

# in: "str0,...,strN",disable escapes,v(C|c)apitalize
# matches \b(str0|...|strN)\b
sub eiths {

  my $string=shift;
  my $disable_escapes=shift;

  if(!$disable_escapes) {
    $string=rescap($string);

  };my $vcapitalize=shift;

  my @words=split ',',$string;

  if($vcapitalize) {@words=vcapitalize(@words);};

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
    ;

  } elsif($line_beg>0) {
    $pat='^'.$pat;

  } elsif($line_beg<0) {
    $pat='^[\s|\n]*'.$pat;

  };return "($pat.*(\\x0D?\\x0A|\$))";

};

# ---   *   ---   *   ---
# general-purpose regexes

my %DICT=(-GPRE=>{

  -HIER =>[

    # class & hierarchy stuff
    [0x07,'[^[:blank:]]+'],
    [0x04,eiths('this,self')],
    [0x04,"$_LUN*$DRFC"],
    [0x0D,"\\b$_LUN*$DRFC$_LUN*$DRFC"],
    [0x04,"$DRFC$_LUN*$DRFC"],

  ],

# ---   *   ---   *   ---

  -PFUN =>[

    # functions with parens
    [0x01,"\\b$_LUN*[[:blank:]]*\\("],

  ],

  -GBL =>[

    # constants/globals
    [0x0D,'\b[_A-Z][_A-Z0-9]*\b'],

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

# ---   *   ---   *   ---

    # bin
    [0x03,'('.

      '((\b0|\\\\)b[0-1]+[L]*)|'.
      '([0-1]+[L]*b)'.

      ')\b'

    ],

    # float
    [0x03,'((\b[0-9]*|\.)+[0-9]+f?)\b'],

  ],

# ---   *   ---   *   ---

  -DEV =>[

    [0x0B,'('.( eiths('TODO,NOTE') ).
      ':?|#:\*+;>)'

    ],

    [0x09,'('.( eiths('FIX,BUG') ).
      ':?|#:\!+;>)'

    ],

    [0x66,'(^[[:space:]]+$)'],
    [0x66,'([[:space:]]+$)'],


# ---   *   ---   *   ---
  # preprocessor

    [0x0E,

      '#[[:blank:]]*include[[:blank:]]*'.
      delim2('<','>')

    ],

    [0x0E,

      '#[[:blank:]]*include[[:blank:]]*'.
      delim2('"')

    ],

    [0x0E,'(#[[:blank:]]*'.( eiths(

      '(el)?if,ifn?def,'.
      'undef,error,warning'

      ,1)).'[[:blank:]]*'.$_LUN.'*\n?)'

    ],[0x0E,'(#[[:blank:]]*'.eiths('else,endif').')'],

    [0x0E,'(#[[:blank:]]*'.

      'define[[:blank:]]*'.
      $_LUN.'*('.( delim2('(',')') ).

      ')?\n?)'

    ],

  ],

# ---   *   ---   *   ---
# hash fetch

});sub PROP {

  my $lang=shift;
  my $key=shift;

  return $DICT{$lang}->{$key};

};

# ---   *   ---   *   ---
# parse utils

my %PS=(

  -PAT => '',
  -STR => '',

  -DST => {},

);

# ---   *   ---   *   ---

# in: key into PS{-DST}
# looks for pattern and substs it
# matches are pushed to dst{key}

sub ps {

  my $key=shift;

  # well handle this later, for now its ignored
  $PS{-STR}=~ s/extern "C" \{//;

  while($PS{-STR}=~ m/^\s*(${PS{-PAT}})/sg) {

    if(!$1) {last;};;

    push @{ $PS{-DST}->{$key} },$1;
    $PS{-STR}=~ s/^\s*${PS{-PAT}}\s*//s;

  };

};

# ---   *   ---   *   ---

sub pscsl {

  my $key=shift;

  if(my @ar=split m/\s*,\s*/,$PS{-STR}) {

    push @{ $PS{-DST}->{$key} },@ar;
    $PS{-STR}='';

  };

};

# ---   *   ---   *   ---

# in: pattern,string,key
# looks for pattern in string
sub pss {

  my $pat=shift,
  my $str=shift;
  my $key=shift;

  $PS{-PAT}=$pat;

  if($str) {$PS{-STR}=$str;};

  if(!$PS{-DST}->{$key}) {
    $PS{-DST}->{$key}=[];

  };ps($key);return @{ $PS{-DST}->{$key} };

# ---   *   ---   *   ---

# in: string,key
# reads comma-separated list until end of string

};sub psscsl {

  my $str=shift;
  my $key=shift;

  if($str) {$PS{-STR}=$str;};

  if(!$PS{-DST}->{$key}) {
    $PS{-DST}->{$key}=[];

  };pscsl($key);return @{ $PS{-DST}->{$key} };

# ---   *   ---   *   ---

};sub clps {
  for my $key(keys %{ $PS{-DST} }) {
    $PS{-DST}->{$key}=[];

  };
};

# ---   *   ---   *   ---

sub pehex {

  my $x=shift;
  my $r=0;

  my $i=0;

  for my $c(reverse split '',$x) {

    if($c=~ m/[hHlL]/) {
      next;

    } elsif($c=~ m/[xX]/) {last;};

    my $v=ord($c);

    $v-=($v > 0x39) ? 55 : 0x30;
    $r+=$v<<($i*4);$i++;

  };return $r;

};

# ---   *   ---   *   ---
# langdefs pasted here by sygen
