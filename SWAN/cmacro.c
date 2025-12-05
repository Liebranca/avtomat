// ---   *   ---   *   ---
// CMACRO
// powered by AR/CMAM
//
// LIBRE SOFTWARE
// Licensed under GNU GPL3
// be a bro and inherit
//
// CONTRIBUTORS
// lib,

// ---   *   ---   *   ---
// deps

package non; // global scope
  use PM Style qw(null);
  use PM Chk qw(is_null);
  use PM Type;
  use PM Arstd::String qw(strip);
  use PM Arstd::Bin qw(deepcpy);
  use PM Arstd::throw;

  use PM CMAM::static qw(
    cpackage
    cmamlol
    cmamgbl
    cmamout
  );


// ---   *   ---   *   ---
// first, let's define package info macros...

macro top PKGINFO($nd) {
  throw "No current package"
  if is_null(cpackage());

  my $k=cpackage() . "_" . $nd->{cmd};
  my $v=$nd->{expr};

  my $dcolon_re=qr' *:: *';
  $k=~ s[$dcolon_re][_]g;

  clnd($nd);
  return strnd("static const unsigned char* $k=$v");
};

macro top VERSION($nd) {return PKGINFO($nd)};
macro top AUTHOR($nd)  {return PKGINFO($nd)};


// ---   *   ---   *   ---
// NOTE: what follows also goes in global scope
//
// these are just minimal utility macros that
// are part of cmam core, and naturally, we
// define these using cmam ;>

// ---   *   ---   *   ---
// mark symbol for inclusion in
// generated header
//
// only works with source files, obviously

macro top public($nd) {
  $nd->{cmd}=tokenshift($nd);
  my $cpy=deepcpy($nd);
  my @out=CMAM::parse::exprproc($cpy);

  my $dst = cmamout()->{export};
  my $i   = int @$dst;
  push @$dst,[@out];

  clnd($nd);
  return strnd("__EXPORT_${i}__;");
};


// ---   *   ---   *   ---
// get the name of a variable's type
//
// you can use this inside other macros
// to cat [type] to something else

macro typename($nd) {
  my $sym=tokenshift($nd);
  if(is_null($sym)) {
    $sym=$nd->{cmd};
  };

  my $have=(exists cmamlol()->{$sym})
    ? cmamlol()->{$sym}
    : cmamgbl()->{$sym}
    ;

  throw "Undefined symbol '$sym'"
  if is_null($have);

  $nd->{cmd}  = "";
  $nd->{expr} = "$have";
  return $nd;
};


// ---   *   ---   *   ---
// ^an example of said catting
//
// gives [type]_deref($args), in accordance
// to the type of $args

macro deref($nd) {
  my $sym  = tokenshift($nd);
  my $name = tokenshift(typename(strnd($sym)));
  my $type = Type::derefof($name);

  $nd->{cmd}  = "";
  $nd->{expr} = (
    "$type->{name}_deref($sym) "
  . "$nd->{expr}"
  );

  strip($nd->{expr});
  return $nd;
};


// ---   *   ---   *   ---
// cats 'sign_' to type

macro sign($nd) {
  // get the type in question and
  // check that it's a valid type ;>
  my $type = tokenshift($nd);
     $type = Type::typefet("sign $type");

  // ^put in underscores at spaces (peso rules!)
  my $name = "$type->{name}";
  my $re   = qr"\s+";

  $name=~ s[$re][_]g;

  // give back name ;>
  $nd->{expr} = "$name $nd->{expr}";
  $nd->{cmd}  = "";

  strip($nd->{expr});
  return $nd;
};


// ---   *   ---   *   ---
// catches keyword

macro top typedef($nd) {
  // make copy of input
  my $cpy=deepcpy($nd);

  // get first keyword
  my $keyw=tokenshift($nd);
  my $name=null;

  // handle struct definitions
  if($keyw=~ qr'\b(?:struct|union)\b') {
    // get name of struct
    $name=tokenpop($nd);

    $nd->{cmd}  = $keyw;
    $nd->{expr} = $name;

    // parse the definition/validate name
    my @field=($keyw eq 'union')
      ? Type::MAKE::unionparse($nd)
      : Type::MAKE::strucparse($nd)
      ;

    Type::MAKE::strucmake($keyw=>$name=>@field);

    // ^ save to CMAM typetab
    //   this will be used to regen types on import
    push @{cmamout()->{type}},[
      $keyw=>$name=>[@field]
    ];

    $cpy->{_afterblk}=" $name";

  // ^strict type aliases
  } else {
    // put the first token back in ;>
    $nd->{expr}="$keyw $nd->{expr}";

    // get name...
    $name=tokenpop($nd);

    // expr is a C type and name is a peso type?
    my @args = ();
       $keyw = 'typedef';
    if(Type->is_valid($name)) {
      @args=($nd->{expr}=>$name);

    // ^nope, is expr a peso type?
    } elsif(Type->is_valid($nd->{expr})) {
      $keyw='typerev';
      @args=($name=>$nd->{expr});

    // ^nope, neither is valid!
    } else {
      throw "Invalid typedef: "
      .     "'$name' => '$nd->{expr}'";
    };

    // add to typetab
    strip($ARG) for @args;
    push @{cmamout()->{type}},[$keyw=>@args];
    Type::typedef(@args);
  };


  // we output the same line (rather than
  // consuming it) as C needs it.
  //
  // CMAM catches this happening, so
  // it won't go into recursion unless you
  // fail at giving this expression back
  clnd($nd);
  return $cpy;
};


// ---   *   ---   *   ---
// generates a wrapper for a given F
//
// this is for cases where you need some prelude
// that's identical for every F that uses it

macro internal fwraps($nd,$suffix,$body,@args) {
  // get function data from the node
  my ($fn,$type)=fnnd($nd);

  // handle additional parameters
  my $argname=[];
  my $argtype=[];
  for my $i(0..int(@args/2)-1) {
    my ($name,$type)=(
      $args[$i*2+0],
      $args[$i*2+1],
    );
    push @$argname,$name;
    push @$argtype,"$type $name";
  };

  // generate wrapper
  my @wrap=strnd(
    // (re)declare the function [yes]
    "$type $fn->{name} ($fn->{argtype}) {"

    // paste in the wrapper's body/prelude
    . $body

    // ^ then sneakily call the implementation,
    //   passing in the added parameters
    . "return $fn->{name}${suffix}("
      . join(',',$fn->{argname},@$argname)
    . ");"
  . "};"
  );

  // include the added argument that will be
  // passed in by the prelude
  push @{$nd->{args}},@$argtype;

  // add suffix to the original F name
  $nd->{expr} .= $suffix;

  // give back the 'mutated' function plus
  // the wrappers definition
  return ($nd,@wrap);
};


// ---   *   ---   *   ---
// _now_ write info at file scope ;>

package SWAN::cmacro;
  VERSION "v0.00.7a";
  AUTHOR  "IBN-3DILA";


// ---   *   ---   *   ---
// RET
