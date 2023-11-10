#!/usr/bin/perl
# ---   *   ---   *   ---
# FLATTEN
# flat assembler frontend
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package Avt::flatten;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use Cwd qw(abs_path);
  use English qw(-no_match_vars);

  use lib $ENV{'ARPATH'}.'/lib/sys/';
  use Style;

  use parent 'Shb7::Bk::front';

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# cstruc

sub new($class,%O) {

  return Shb7::Bk::front::new(

    $class,

    lang  => 'fasm',

    bk    => 'flat',
    entry => 'crux',
    flat  => 1,

    %O

  );

};

# ---   *   ---   *   ---
# ^fasm preprocessor

package Avt::flatten::preproc;

  use v5.36.0;
  use strict;
  use warnings;

  use Readonly;

  use English qw(-no_match_vars);
  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::Path;
  use Arstd::Re;
  use Arstd::IO;

  use Shb7::Path;

  use lib $ENV{'ARPATH'}.'/lib/';

  use Emit;
  use Emit::Std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly my $NTERM => re_escaped(
    '\n',

      mod   => '*',
      sigws => 1,

  );

  Readonly my $TERM  => re_nonscaped('\n');

  Readonly my $BODY  => re_delim(
    '{','}',capt=>'body'

  );

  Readonly my $WS    => qr{[\s\\]};

  Readonly my $MACRO => qr{

    macro
    (?:$WS+)

    (?<name> [^\s]+)
    (?:$WS*)

    (?<args> [^\{]*)
    (?:$WS*)

    $BODY

  }x;


  Readonly my $STR => qr{
    (?: ['] [^']+ ['])
  | (?: ["] [^"]+ ["])

  }x;

  Readonly my $STRSTRIP => qr{
    (?: ^['"]  )
  | (?:  ['"]$ )

  }x;


  Readonly my $LIB_OPEN => qr{

    library
    (?:$WS+)

    (?<env> [^\s]+)
    (?:$WS+)

    (?<path> $STR)
    (?:$WS*)
    (?:$TERM)

  }x;

  Readonly my $LIB_CLOSE => qr{
    library\.import (?:$TERM)

  }x;


  Readonly my $USE => qr{

    use
    (?:$WS+)

    (?<ext> $STR)
    (?:$WS+)

    (?<name> [^\s]+)
    (?:$WS*)
    (?:$TERM)

  }x;

  Readonly my $LIB => qr{

    (?<head> $LIB_OPEN)
    (?<uses> (?:$USE)+)

    $LIB_CLOSE

  }x;


  Readonly my $PROC_BODY => re_delim(
    'proc.new',
    'proc.leave',

  );

  Readonly my $PROC => qr{

    $PROC_BODY

    (?: $WS*)
    (?: ret|exit \s*[^\s]*)?

  }x;



  Readonly my $LCOM => re_eaf(';');
  Readonly my $SEG  => qr{(?:

    (?: (?:ROM|RAM|EXE) SEG)
  | (?: (?:section|segment) )

  ) $NTERM}x;

  Readonly my $REG => qr{

    (?: reg\.new) $NTERM
    (?<! \,public) $TERM


    (?:

      (?: (?! reg\.end) (?: .|\s) )+
    | (?R)

    )*


    reg\.end

  }x;

  Readonly my $REGICE => qr{
    (?: reg\.ice) $NTERM

  }x;


  Readonly my $PREIMP => q[

    MAM.xmode='__MODE__'
    MAM.head __ENTRY__

  ];

  Readonly my $GETIMP => q[

if ~ defined loaded?Imp
  include '%ARPATH%/forge/Imp.inc'

end if

];

  Readonly my $FOOT => q[

MAM.avto
MAM.foot

];

# ---   *   ---   *   ---
# scrap non-binary data
# (ie code) from file

sub get_nonbin($fpath) {

  my $body   = orc($fpath);
  my $macros = strip_macros(\$body);
  my $extrn  = get_exported($fpath,'extrn');

  strip_codestr(\$body);

  return "$extrn\n$body";

};

# ---   *   ---   *   ---
# ^remove macros from codestr
# save them to out

sub strip_macros($sref) {

  my $out=[];

  while($$sref=~ s[$MACRO][]sxm) {
    push @$out,
      "macro $+{name} $+{args} $+{body}"

  };


  return $out;

};

# ---   *   ---   *   ---
# get exported symbols

sub get_exported($fpath,$type) {

  state $re = qr{^$type};

  # get symbol file
  my @out=();
  my $src=extwap($fpath,'preshwl');

  # ^skip if non-existent
  goto TAIL if ! -f $src;

  # ^read file and get extrn decls
  my $body = orc($src);
     @out  = grep {$ARG=~ $re} split "\n",$body;

TAIL:
  return join "\n",@ar;

};

# ---   *   ---   *   ---
# ^remove private data

sub strip_codestr($sref) {
  $$sref=~ s[$LCOM][]sxmg;
  $$sref=~ s[$SEG][]sxmg;
  $$sref=~ s[$REG][]sxmg;
  $$sref=~ s[$REGICE][]sxmg;
  $$sref=~ s[$PROC][]sxmg;
  $$sref=~ s[^\s*$TERM][]sxmg;

};

# ---   *   ---   *   ---
# scrap deps meta from
# importer cmd

sub read_deps($base,$deps) {

  my @out=();

  while($deps=~ s[$USE][]sxm) {

    # get file name and extension
    my $ext  = $+{ext};
    my $name = $+{name};

    # ^clean
    $ext  =~ s[$STRSTRIP][]sxmg;
    $name =~ s[$DCOLON_RE][/]sxmg;

    # ^get fullpath
    my $fpath="$base$name$ext";

    # ^Q for expansion
    push @out,$fpath;

  };

  return @out;

};

# ---   *   ---   *   ---
# ^read in importer cmd

sub get_file_deps($body) {

  my @out=();

  while($body=~ s[$LIB][]sxm) {

    my $head=$+{head};
    my $uses=$+{uses};

    # ^scrap import meta
    my $env  = $+{env};
    my $path = $+{path};

    # ^get import path
    $env=($env ne '_')
      ? $ENV{$env}
      : $NULLSTR
      ;

    $path=~ s[$STRSTRIP][]sxmg;

    my $base="$env$path";

    push @out,read_deps($base,$uses);

  };


  return @out;

};

# ---   *   ---   *   ---
# ^recursively expand deps

sub get_deps($fpath) {

  my @out     = ();
  my @pending = ($fpath);


  while(@pending) {

    # open new file
    my $elem=shift @pending;
    my $body=orc($elem);

    # ^keep track of deps
    push @out,$elem;


    # recurse
    unshift @pending,get_file_deps($body);

  };


  # cleanup and give
  shift  @out;
  return @out;

};

# ---   *   ---   *   ---
# make pre-build trashfile

sub prebuild($fpath,%O) {

  # get build mode
  my $pre=$PREIMP;

  $pre=~ s[__MODE__][$O{mode}];
  $pre=~ s[__ENTRY__][$O{entry}];

  # get symbols
  my $public=get_exported($fpath,'public');

  # ^cat chunks
  my $body=orc($fpath);
     $body="$pre$GETIMP$public$body$FOOT";


  # emit
  my $dst=obj_from_src(

    $fpath,

    ext       => '.asmx3',
    use_trash => 0,

  );

  say $out;
  say $dst;

#  owc($dst,$out);

  return $dst;

};

# ---   *   ---   *   ---
# ^make post-build header

sub postbuild($fpath) {

  state $get_author=qr{AUTHOR  \s+ ($NTERM)}x;

  my $out=$NULLSTR;

  # scrap info
     $body     =~ $get_author;
  my $author   =  $1;
     $author //=  $Emit::ON_NO_AUTHOR;

  # ^make src
  $out.=Emit::Std::note($author,';');
  $out.=get_nonbin($fpath);


  # emit
  my $dst=obj_from_src(

    $fpath,

    ext       => '.hed',
    use_trash => 0,

  );

  say $out;
  say $dst;

#  owc($dst,$out);

  return $dst;

};

# ---   *   ---   *   ---
1; # ret
