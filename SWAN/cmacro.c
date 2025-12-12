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
// NOTE
//
// these are just utility macros that
// are part of cmam core, and naturally, we
// define these using cmam ;>

// ---   *   ---   *   ---
// deps

package SWAN::cmacro;
  use PM Style qw(null);
  use PM Chk qw(is_null);
  use PM Type;
  use PM Arstd::String qw(strip);
  use PM Arstd::Bin qw(deepcpy);
  use PM Arstd::Re qw(crepl);
  use PM Arstd::throw;

  use PM CMAM::static qw(
    cpackage
    cmamlol
    cmamgbl
    cmamout
    ctree
  );


// ---   *   ---   *   ---
// first, let's define package info macros...

macro top PKGINFO($nd) {
  throw "No current package"
  if is_null(cpackage());

  my $k=cpackage() . "_" . $nd->{cmd};
  my $v=$nd->{expr};

  my $info=$v;
  ctree()->unstrtok($info);
  cmamout()->{info}->{$nd->{cmd}}=$info;

  my $dcolon_re=qr' *:: *';
  $k=~ s[$dcolon_re][_]g;

  clnd($nd);
  return strnd("static const unsigned char* $k=$v");
};

macro top VERSION($nd) {return PKGINFO($nd)};
macro top AUTHOR($nd)  {return PKGINFO($nd)};


// ---   *   ---   *   ---
// ^now we can write the info ;>

  VERSION "v0.00.7a";
  AUTHOR  "IBN-3DILA";


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
  // struct or union definition?
  if($nd->{type}=~ qr'\b(?:struc|union)\b') {
    my ($name)=Type::MAKE::strucdef($nd);
    $nd->{_afterblk}=" $name";

  // ^type alias?
  } elsif('utype' eq $nd->{type}) {
    Type::MAKE::utypedef($nd);

  // ^nope, invalid!
  } else {
    throw "Malformed typedef: ($nd->{type}) "
    .     "'$nd->{cmd} $nd->{expr}'";
  };

  // we output the node as is (rather than
  // clearing/consuming it) as C needs it.
  //
  // CMAM catches this happening, so
  // it won't go into recursion unless you
  // fail at giving the node back
  return $nd;
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

  // generate call to implementation
  my $call=crepl(
    "NAME##SUFFIX(RARGS)",
    NAME   => $fn->{name},
    SUFFIX => $suffix,
    RARGS  => join(',',$fn->{argname},@$argname),
  );

  // ^ now replace 'CALL' in body with an
  //   actual call to it!
  $body=crepl(
    $body,
    T      => $fn->{type},
    SUFFIX => $suffix,
    CALL   => $call,
  );

  // ^ then paste the contents inside a new F
  C T NAME(WARGS) {
    BODY
  };

  my @wrap=strnd(cmamclip(
    T      => $type,
    NAME   => $fn->{name},
    WARGS  => $fn->{argtype},
    BODY   => $body,
    SUFFIX => $suffix,
  ));

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
// RET
