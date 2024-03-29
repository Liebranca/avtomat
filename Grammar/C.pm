#!/usr/bin/perl
# ---   *   ---   *   ---
# C GRAMMAR
# Don't cast the RET of malloc!
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Grammar::C;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/avtomat/sys/';

  use Style;
  use Chk;
  use Fmat;

  use Arstd::Array;
  use Arstd::Re;
  use Arstd::IO;

  use Tree::Grammar;

  use lib $ENV{'ARPATH'}.'/avtomat/hacks/';
  use Shwl;

  use lib $ENV{'ARPATH'}.'/avtomat/';

  use Lang;
  use Grammar;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.4;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  our $REGEX;

BEGIN {

  $REGEX={

    term  => re_nonscaped(';'),
    nterm => re_escaped(

      ';',

      mod    => '+',
      sigws  => 1,

    ),

    clist => re_nonscaped(','),
    line  => qr{(\\ \n | [^\n])+}x,

    nline => re_nonscaped("\n"),
    lcom  => re_eaf('//'),

    q[preproc-key]=>re_eiths(

      [qw(

        define if ifndef
        ifdef include

      )],

      bwrap => 1,

    ),

# ---   *   ---   *   ---

    prim=>re_eiths(

      [qw(

        bool char short int long
        float double void

        int8_t int16_t int32_t int64_t
        uint8_t uint16_t uint32_t uint64_t

        wchar_t size_t
        intptr_t uintptr_t

        FILE

        nihil stark signal

      )],

      bwrap => 1,

    ),

    indlvl=>qr{\*+},

# ---   *   ---   *   ---

    spec=>re_eiths(

      [qw(

        auto extern inline restrict
        const signed unsigned static

        explicit friend mutable
        namespace override private
        protected public register

        template using virtual volatile
        noreturn _Atomic complex imaginary
        thread_local operator

      )],

      bwrap=>1,

    ),

    name=>qr{[_\w][_\w\d]*},

  };

# ---   *   ---   *   ---

  rule('~<term>');

  rule('*~<spec>');
  rule('~<prim>');
  rule('~?<indlvl>');
  rule('~<name>');
  rule('?~<clist> &rew');

  rule('$<decl> spec prim indlvl name');
  rule('$<decl-list> &decl_list decl clist');

# ---   *   ---   *   ---
# ^post-parse

sub decl($self,$branch) {

  my $st=$branch->bhash();
  $st->{spec}   //= $NULLSTR;
  $st->{indlvl} //= $NULLSTR;
  $st->{name}   //= $NULLSTR;

  return if ! $st->{prim};

  $branch->{value}={

    name => $st->{name},
    type => "$st->{prim}$st->{indlvl}",

    spec => $st->{spec},

  };

  $branch->clear();

};

sub decl_list($self,$branch) {

  my @ar=$branch->branch_values();
  pop @ar if $ar[-1] eq 'clist';

  $branch->{value}=\@ar;
  $branch->clear();

};

# ---   *   ---   *   ---

  rule('%<beg_parens=\(>');
  rule('%<end_parens=\)>');

  rule(q[

    $<args>
    &args_rd

    beg_parens
    decl-list
    end_parens

  ]);

# ---   *   ---   *   ---
# ^post-parse

sub args_rd($self,$branch) {

  my $lv=$branch->{leaves};
  my $ar=$lv->[1]->{value};

  $branch->{value}=$ar;
  $branch->clear();

};

# ---   *   ---   *   ---
# ^combo

  rule('$<fn-decl> &fn_decl decl args');

# ---   *   ---   *   ---
# ^post-parse

sub fn_decl($self,$branch) {

  my @ar=$branch->branch_values();

  my $st={

#    name  => $ar[0]->{name},
#
#    spec  => $ar[0]->{spec},
#    rtype => $ar[0]->{prim},

    %{$ar[0]},
    args=>$ar[1],

  };

  $branch->clear();
  $branch->inew($st);

};

# ---   *   ---   *   ---

  rule('?<opt-name> &clip name');

  rule('%<struct-key=struct>');
  rule('%<typedef-key=typedef>');

  rule('%<beg_scope=\{>');
  rule('%<end_scope=\}>');

  rule('+<struct-elems> decl term');

  rule(q[

    $<struct-body>
    &struct_body

    beg_scope
    struct-elems

    end_scope

  ]);

# ---   *   ---   *   ---
# ^post-parse

sub struct_body($self,$branch) {

  my @lv    = @{$branch->{leaves}};
  my @elems = $lv[1]->branch_values();

  $branch->clear();
  $branch->{value}='elems';
  $branch->inew(\@elems);

};

# ---   *   ---   *   ---
# ^combo

  rule(q[

    $<typedef-struct>
    &clip

    typedef-key
    struct-key

    opt-name

    struct-body
    name

  ]);

  rule(q[

    $<c-struct>
    &clip

    struct-key
    name

    struct-body

  ]);

  rule('|<struct> &clip typedef-struct c-struct');
  rule('$<utype-decl> &utype_decl struct');

# ---   *   ---   *   ---
# ^post-parse

sub utype_decl($self,$branch) {
  $branch->pluck($branch->{leaves}->[0]);

};

# ---   *   ---   *   ---

  rule('~<line>');
  rule('~<nline> &discard');
  rule('~<nclist>');

  rule('~<preproc-key>');
  rule('%<endif-key=endif>');

  rule(q[

    $<preproc-macro-args-elems>
    &list_flatten

    name clist

  ]);

  rule(q[

    ?$<preproc-macro-args>
    &tween_clip

    beg_parens
    preproc-macro-args-elems

    end_parens

  ]);

  rule('%<hashtag=\#>');

  rule(q[

    $<preproc-macro>
    &preproc_macro

    hashtag preproc-key
    name preproc-macro-args

    line nline

  ]);

  rule(q[

    $<preproc-dir>
    &preproc_dir

    hashtag preproc-key
    line nline

  ]);

  rule(q[

    $<preproc-endif>
    &preproc_dir

    hashtag endif-key nline

  ]);

# ---   *   ---   *   ---
# ^post-parse

sub preproc_macro($self,$branch) {

  $self->tween($branch);

  my $st=$branch->bhash();

  my $o={
    args  => $st->{q[macro-args]},
    value => $st->{line},

  };

  $branch->clear();
  $branch->inew($o);

  $branch->{value}=$st->{name};

};

sub preproc_dir($self,$branch) {

  $self->tween($branch);

  my $st=$branch->bhash();

  $branch->clear();
  $branch->{value}=$st->{q[preproc-key]};
  $branch->{value}//='endif';

  $branch->inew($st->{line})
  if $st->{line};

};

# ---   *   ---   *   ---
# ^combo

  rule(q[

    |<preproc>
    &clip

    preproc-macro preproc-endif preproc-dir

  ]);

# ---   *   ---   *   ---

  rule('~<lcom>');
  rule('|<meta> &clip lcom preproc');

  rule(q[
    |<needs-term-list>
    &clip

    fn-decl utype-decl decl

  ]);

  rule(q[

    <needs-term>
    &clip

    needs-term-list
    term

  ]);

  our @CORE=qw(meta needs-term);

# ---   *   ---   *   ---

}; # BEGIN

# ---   *   ---   *   ---
# removes meta/annoyances

sub strip($class,$progr) {
  $$progr=~ s[$REGEX->{lcom}][]sxmg;

};

# ---   *   ---   *   ---
# grab symbols from file

sub mine($class,$prog) {

  state $fn_re    = qr{^fn\-decl$};
  state $utype_re = qr{^utype$};

  my $o={

    utypes    => {},
    functions => {},
    variables => {},
    constants => {},

  };

  my $ice  = $class->parse($prog,skip=>1);
  my @data = $ice->{p3}->branches_in($fn_re);

  # walk function decls
  for my $nd(@data) {

    my $st   = $nd->leaf_value(0);
    my $name = $st->{name};

    my $ref  = \$o->{functions}->{$name};
    my $args = [];

    # build fn argument array
    map { push @$args,

      $ARG->{name},
      $ARG->{type}

    } @{$st->{args}};

    # write table entry
    $$ref={
      rtype => $st->{type},
      args  => $args,

    };

  };

  return $o;

};

# ---   *   ---   *   ---
1; # ret
