#!/usr/bin/perl
# ---   *   ---   *   ---
# ARSTD PPROC
# kinda like the C preprocessor
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lib,

# ---   *   ---   *   ---
# deps

package Arstd::pproc;
  use v5.42.0;
  use strict;
  use warnings;
  use English qw($ARG);

  use lib "$ENV{ARPATH}/lib/sys/";
  use Style qw(null);
  use Chk qw(is_null is_blessref);
  use Ftype;

  use Arstd::String qw(spacecat linecnt lineof);
  use Arstd::Bin qw(orc);
  use Arstd::strtok qw(
    strtok
    unstrtok
    strarmut
    strarvoid
    strarex
  );
  use Arstd::seq qw(seqtok_push);
  use Arstd::peso qw(peval);
  use Arstd::throw;

  use Shb7::Find qw(ffind);

  use lib "$ENV{ARPATH}/lib";
  use AR;


# ---   *   ---   *   ---
# adds to your namespace

  use Exporter 'import';
  our @EXPORT=qw(pproc);


# ---   *   ---   *   ---
# info

  our $VERSION = 'v0.00.5a';
  our $AUTHOR  = 'IBN-3DILA';


# ---   *   ---   *   ---
# we use this to record state across
# all subroutines

sub pproc_mem {
  state $mem={
    inc   => {},
    def   => {-stk=>{}},
    pkg   => {-cur=>null},
    if    => [],
    depth => 0,
    lnoff => 0,
    imap  => [],

    lang  => undef,
    syx   => undef,
    sref  => undef,
    stk   => [],
  };
  return $mem;
};


# ---   *   ---   *   ---
# entry point
#
# [0]: byte pptr ; array to save token contents to
# [1]: byte ptr  ; string to process
# [2]: byte pptr ; options
#
# [!]: overwrites input string

sub pproc {
  my $strar = shift;
  my $sref  = \$_[0];
  shift;

  # set defaults
  my %O=@_;
  $O{lang}     //= "C";
  $O{strtok}   //= 0;
  $O{unstrtok} //= 0;

  # up the recursion depth
  my $depth = pproc_enter($sref,$O{lang});
  my $mem   = pproc_mem();

  # generally, we perform tokenization before
  # invoking the preprocessor, but its nice to
  # have this option as well
  strtok($strar,$$sref,syx=>$mem->{syx})
  if $O{strtok};

  # we're only interested in preprocessor
  # lines, so fetch the indices of those
  my @pline=Arstd::strtok::fetln(
    $strar,
    $$sref,
    "pproc"
  );
  while(@pline) {
    # fetch and run command
    my ($i,$cmd,@args)=pproc_take($strar,\@pline);
    push @{$mem->{imap}},[$i,$cmd];

    my $ok=symtab($cmd)->($i,$strar,@args);

    # need to skip lines?
    while(@pline &&! $ok) {
      # jump to next clause...
      my ($si,$scmd,@sargs)=
        pproc_take($strar,\@pline);

      # ^invalid!! strip it!
      if($scmd ne "end" && $scmd ne "e$cmd") {
        strarvoid(
          $strar,
          $mem->{sref},
          $si->[0],
          "vpproc"
        );
        next;
      };
      # ^valid, so run it!
      push @{$mem->{imap}},[$si,$scmd];
      $ok=symtab($scmd)->($si,$strar,@sargs);
    };
  };
  # perform textual replacements last
  pproc_txtrepl($strar,$sref) if! $depth;

  # same story as with the strtok option
  unstrtok($$sref,$strar)
  if $O{unstrtok};

  # go down one recursion level
  return pproc_leave();
};


# ---   *   ---   *   ---
# saves current state before recursing

sub pproc_enter {
  my ($sref,$lang)=@_;

  # we cap the recursion depth here JIC
  #
  # NOTE: not sure if this limit is set too low,
  #       but it seems sensible to me...
  my $mem=pproc_mem();
  throw "pproc: recursion caphit"
  if    $mem->{depth} > 0x40;

  # save state
  my $stk=$mem->{stk};
  my $ctx={
    sref  => $mem->{sref},
    lang  => $mem->{lang},
    syx   => $mem->{syx},
    pkg   => $mem->{pkg}->{-cur},
  };
  push @$stk,$ctx;

  # get tokenizer rules...
  ($mem->{lang},$mem->{syx})=
    Ftype::getlang($lang);

  # overwrite generic values
  $mem->{sref}        = $sref;
  $mem->{pkg}->{-cur} = null;
  $mem->{honor}       = honor_need();

  # give depth *before* increment
  return $mem->{depth}++;
};


# ---   *   ---   *   ---
# ^iv

sub pproc_leave {
  my $mem=pproc_mem();
  my $stk=$mem->{stk};
  my $ctx=pop @$stk;

  throw "pproc: <leave> without <enter>"
  if    is_null($ctx);

  # restore previous state
  $mem->{sref}        = $ctx->{sref};
  $mem->{lang}        = $ctx->{lang};
  $mem->{syx}         = $ctx->{syx};
  $mem->{pkg}->{-cur} = $ctx->{pkg};
  $mem->{honor}       = honor_need();

  # give depth *after* decrement
  return --$mem->{depth};
};


# ---   *   ---   *   ---
# reads next line!

sub pproc_take {
  # get next line
  my ($strar,$pline)=@_;
  my $i=shift @$pline;

  # ^make copy of value and untokenize it
  my $cpy=$strar->[$i->[0]];
  unstrtok($cpy,$strar);

  # ^fetch command and give
  return ($i,Arstd::peso::getcmd($cpy));
};


# ---   *   ---   *   ---
# adds a blank token we can use for
# executing a function...
#
# effectively lets us generate clauses
# without having to recurse!

sub pproc_blankt {
  my ($i,$dst)=@_;

  my $si=int @$dst;
  seqtok_push({type=>"pproc"},$dst,"");

  return [$si,$i->[1]];
};


# ---   *   ---   *   ---
# opens file,
# recurses to process it,
# and then pastes it on original
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte ptr  ; filepath

sub pproc_fpaste {
  # either finds the file or throws
  my ($i,$dst,$fpath)=@_;
  $fpath=ffind(peval($fpath));

  # ^it's a nop if file already included ;>
  my $mem=pproc_mem();
  if($mem->{inc}->{$fpath}) {
    strarvoid($dst,$mem->{sref},$i->[0],"vpproc");
    return;
  };
  $mem->{inc}->{$fpath}=1;

  # note how we adjust the line-number offset
  # before recursing!
  $mem->{lnoff} += $i->[1];

  # read the file and recurse...
  my $strar = [];
  my $body  = orc($fpath);
  pproc(
    $strar,
    $body,
    lang     => Ftype::from_ext($fpath),
    strtok   => 1,
    unstrtok => 1,
  );
  # ^adjust offset again
  $mem->{lnoff} += linecnt($body);

  # overwrite preprocessor directive
  # with the body of the file
  strarmut(
    $dst,
    $mem->{sref},
    $i->[0],
    vpproc=>$body
  );
  return 1;
};


# ---   *   ---   *   ---
# wraps and mutates code in a language-sensitive
# way, accto `package_open/close`, which should
# be defined at Ftype::Text::(lang)
#
# both default to nop when no F is defined

sub pproc_package {
  my ($i,$dst,$name,@attr)=@_;
  throw "pproc: <package> without name"
  if    is_null($name);

  my $mem=pproc_mem();
  throw "pproc: redeclaration of package '$name'"
  if    exists $mem->{pkg}->{$name};

  $mem->{pkg}->{$name} = {map {$ARG=>1} @attr};
  $mem->{pkg}->{-cur}  = $name;

  my $body=join("\n",
    $mem->{lang}->package_open($name),
    null,
  );
  strarex(
    $dst,
    $mem->{sref},
    $i->[0],
    $body,
  );
  # define package name
  pproc_define(
    pproc_blankt($i,$dst),
    $dst,
    __PACKAGE__=>$name
  );
  return 1;
};
sub pproc_package_end {
  my ($i,$dst,$sref)=@_;

  my $mem  = pproc_mem();
  my $name = $mem->{pkg}->{-cur};
  my $flg  = $mem->{pkg}->{$name};
  my $out  = join("\n",
    $mem->{lang}->package_close(
      $dst,
      $sref,
      $name,
      $flg
    ),
    null,
  );
  # undefine the package name!!
  pproc_undef(
    pproc_blankt($i,$dst),
    $dst,
    "__PACKAGE__"
  );
  return $out;
};


# ---   *   ---   *   ---
# sets [key=>value]
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte ptr  ; key
# [3]: byte ptr  ; value

sub pproc_define {
  # value is optional...
  my ($i,$dst,$k,$v)=@_;
  $v //= null;

  # ^the key is not
  throw "pproc: <define> without a key"
  if    is_null($k);

  # saving the value is not quite as
  # straight-forward, given that it can
  # be re-or-un-defined later...
  #
  # what we do is save the idex of each token
  # that performs such an operation, so as to
  # have a coordinate that tells us *when* to
  # use each value for the replacement!
  my $mem = pproc_mem();
  my $ar  = $mem->{def}->{$k} //= [];
  my $stk = $mem->{def}->{-stk}->{$k} //= [];
  my $top = [$i->[1] + $mem->{lnoff},$v];

  push @$ar,$top;
  push @$stk,$top;

  # clear directive;
  # the replacement will be done later on
  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");
  return 1;
};


# ---   *   ---   *   ---
# ^ same, but cats input to
#   an existing [key=>value]

sub pproc_cat {
  my ($i,$dst,$k,$v)=@_;
  $v //= null;

  throw "pproc: <cat> without a key"
  if    is_null($k);

  my $mem=pproc_mem();
  throw "pproc: undefined key for <cat> '$k'"
  if!   exists $mem->{def}->{$k};

  my $ar=$mem->{def}->{$k};
  $ar->[-1]->[1] .= $v;

  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");
  return 1;
};


# ---   *   ---   *   ---
# ^also same, but adds newline ;>

sub pproc_catline {
  my ($i,$dst,$k,$v)=@_;
  $v //= null;
  $v  .= "\n";

  return pproc_cat($i,$dst,$k,$v);
};


# ---   *   ---   *   ---
# includes a file, but instead of pasting
# it directly, it saves the value to a
# definition!!

sub pproc_catinc {
  my ($i,$dst,$k,$fpath)=@_;

  pproc_fpaste($i,$dst,$fpath);
  return pproc_cat($i,$dst,$k,$dst->[$i->[0]]);
};


# ---   *   ---   *   ---
# roll back to the *last* definition of key,
# or set it to null if no previous definition
# exists

sub pproc_undef {
  my ($i,$dst,$k)=@_;

  throw "pproc: <undef> without a key"
  if    is_null($k);

  my $mem = pproc_mem();
  my $ar  = $mem->{def}->{$k};
  my $stk = $mem->{def}->{-stk}->{$k};
  my $top = pop @$stk // [0,null];

  push @$ar,[$i->[1] + $mem->{lnoff},$top->[1]];
  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");

  return 1;
};


# ---   *   ---   *   ---
# evaluates condition
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte pptr ; expr

sub pproc_if {
  # we strip the expression right away
  my ($i,$dst,@expr)=@_;
  my $mem=pproc_mem();
  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");

  # get truth of this statement...
  my $ok=pproc_ifeval(0,@expr);

  # remember line where this clause appeared;
  # we'll need it for stripping it later if
  # it evaluates to false
  my $ar  = [];
  push @$ar,[$i->[1] + $mem->{lnoff},$ok];
  push @{$mem->{if}},$ar;

  return $ok;
};
sub pproc_eif {
  my ($i,$dst,@expr)=@_;
  my $mem=pproc_mem();
  strarvoid($dst,$mem->{sref},$i->[0],"vpproc");

  my $ok=pproc_ifeval(1,@expr);
  my $ar=$mem->{if}->[-1];
  throw "pproc: <eif> without preceding <if>"
  if!   $ar;

  push @$ar,[$i->[1] + $mem->{lnoff},$ok];
  return $ok;
};


# ---   *   ---   *   ---
# evaluate expression for if/eif...

sub pproc_ifeval {
  # we give default value when there is
  # no expression!
  my ($ok,@expr)=@_;
  my $mem  = pproc_mem();
  my $have = int(@expr);

  return $ok if! $have;

  # checking if a value is defined...
  if($have && $expr[0] eq "def") {
    $ok=exists $mem->{def}->{$expr[1]};

  # ^checking if it's *not* defined!
  } elsif($have && $expr[0] eq "ndef") {
    $ok=! exists $mem->{def}->{$expr[1]};

  # ^checking truth of a statement!! \( ^ .^)/
  } else {
    for(@expr) {
      # we want to use the latest definition
      # of this value, *if* it was `#define`-d
      if(exists $mem->{def}->{$ARG}) {
        $ARG=$mem->{def}->{$ARG}->[-1]->[1];
      };
    };
    # ^and then we can just eval :D
    $ok=eval(spacecat(@expr));
  };
  return $ok;
};


# ---   *   ---   *   ---
# terminates multi-line clause (!!)
#
# [0]: qword     ; token idex
# [1]: byte pptr ; token array
# [2]: byte pptr ; expr

sub pproc_end {
  # you gotta tell me what to end...
  my ($i,$dst,$clause)=@_;
  throw "pproc: <end> without clause"
  if    is_null($clause);

  # capture the code between the start
  # and end (this clause!)
  my $mem  = pproc_mem();
  my $imap = $mem->{imap};
  my $beg;
  for(reverse @$imap) {
    my ($bi,$cmd)=@$ARG;
    if($cmd eq $clause) {
      $beg=$bi;
      last;
    };
  };
  # we need to do the honor dance to get
  # accurate line numbers!
  my $cpy=${$mem->{sref}};
  honor_line(\$cpy,"pproc","vpproc");
  my @line=split("\n",$cpy);
  my $body=join("\n",
    grep {$ARG}
    @line[$beg->[1]..$i->[1]]
  );
  # clauses can have a "close" F to mutate
  # the code!! \( ^ .^)/
  my $fn={
    package=>\&pproc_package_end,

  }->{$clause} // \&null;

  my $foot=$fn->($i,$dst,\$body);

  # ^ and it *may* also modify the enclosed
  #   code via the reference to $body :D
  @line[$beg->[1]..$i->[1]]=($body);
  @line=grep {$ARG} @line;
  $cpy=join("\n",@line);
  dishonor_line(\$cpy,"pproc","vpproc");
  ${$mem->{sref}}=$cpy;

  # ^ $foot determines what we repl this line with;
  #   defaults to null
  strarex(
    $dst,
    $mem->{sref},
    $i->[0],
    $foot
  );
  # mark the line where this clause ends ;>
  my $ar=[];
  push @$ar,[$i->[1] + $mem->{lnoff},1];
  push @{$mem->{$clause}},$ar;

  return 1;
};


# ---   *   ---   *   ---
# fetch from function table
#
# [0]: byte ptr ; F name

sub symtab {
  my $out={
    include => \&pproc_fpaste,
    define  => \&pproc_define,
    undef   => \&pproc_undef,
    package => \&pproc_package,
    cat     => \&pproc_cat,
    catline => \&pproc_catline,
    catinc  => \&pproc_catinc,
    if      => \&pproc_if,
    eif     => \&pproc_eif,
    end     => \&pproc_end,

  }->{$_[0]}

  or throw "pproc: undefined function '$_[0]'";

  return $out;
};


# ---   *   ---   *   ---
# performs textual replacement of
# any `#define`-d symbols ;>

sub pproc_txtrepl {
  my ($strar,$sref)=@_;

  # we need to put the line that terminates
  # the expression back in there, so as to
  # get the actual number of lines
  honor_line($sref,"pproc");

  # these expressions can be safely expanded now
  unstrtok($$sref,$strar,"vpproc");

  # walk definitions!
  my $mem=pproc_mem();
  my @key=(
    grep {$ARG ne "-stk"}
    keys %{$mem->{def}}
  );
  for my $k(@key) {
    # replace KEY within tokenized body...
    my $re=qr{(?<!\\)\b$k\b};
    while($$sref=~ $re) {
      last if! pproc_txtrepl_inner(0,$k,$sref,$re);
    };
    # ^unescape
    $re=qr{\\\b$k\b};
    $$sref=~ s[$re][$k];

    # replace #KEY; inside strings!! /YES
    $re=qr{(?<!\\)\#$k;};
    pproc_txtrepl_inner(
      $ARG->[1],
      $k,
      \$strar->[$ARG->[0]],
      $re,
      $sref,
      Arstd::seq::tok_re("str",$ARG->[0])

    ) for Arstd::strtok::fetln(
      $strar,
      $$sref,
      "str"
    );
    # ^also unescape!
    $re=qr{\\\b$k\b};
    $$sref=~ s[$re][$k];
  };
  # remove the lines we added
  dishonor_line($sref,"pproc");
  return;
};
sub pproc_txtrepl_inner {
  my ($off,$k,$dst,$dst_re,$src,$src_re)=@_;
  $src    //= $dst;
  $src_re //= $dst_re;

  # get line number for this match...
  my $lnx=lineof($$src,$src_re)+$off;

  # ^select definition accto line number!
  my $ok=0;
  for(reverse @{pproc_mem()->{def}->{$k}}) {
    my ($lny,$v)=@$ARG;
    if($lnx >= $lny) {
      ($dst ne $src)
        ? $$dst=~ s[$dst_re][$v]g
        : $$dst=~ s[$dst_re][$v]
        ;
      last;
      $ok=1;
    };
  };
  return $ok;
};


# ---   *   ---   *   ---
# the tokenizer removes newline characters
# on preprocessor lines, and sometimes we
# need to put them back in

sub honor_line {
  return if! pproc_mem()->{honor};

  my ($sref,@t)=@_;
  my $nl="\n";
  for(@t) {
    my $tok_re=Arstd::seq::tok_re($ARG);
    $$sref=~ s[$tok_re][$+{full}$nl]g;
  };
  return;
};


# ---   *   ---   *   ---
# ^undo

sub dishonor_line {
  return if! pproc_mem()->{honor};

  my ($sref,@t)=@_;
  for(@t) {
    my $tok_re=Arstd::seq::tok_re($ARG)."\n";
    $$sref=~ s[$tok_re][$+{full}]g;
  };
  return;
};


# ---   *   ---   *   ---
# ^checks whether such a thing is necessary ;>
#
# what we do here is just check whether
# preprocessor lines for the current syntax
# are actually terminated by a newline;
#
# in that case, we have to honor/dishonor lines!
#
# note that in say 90% of the codebase this
# is currently true -- this check is just here
# to support different syntaxes! \( ^ .^)/

sub honor_need {
  my $syx=pproc_mem()->{syx};
  return int grep {
     $ARG->{type} eq "pproc"
  && $ARG->{end}  eq "\n"

  } @$syx;
};


# ---   *   ---   *   ---
1; # ret
