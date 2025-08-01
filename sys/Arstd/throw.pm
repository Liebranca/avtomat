# ---   *   ---   *   ---
# short for "not yet implemented"
#
# the lazy way: halt execution
# and spit notice at placeholders

sub nyi($errme,$src=undef) {
  state $tab=ansim('NYI:','err');
  $src //= (caller 1)[3];

  errout(
    "%s '%s' at <%s>\n",

    lvl  => $AR_FATAL,
    args => [$tab,$errme,$src],

  );

};


# ---   *   ---   *   ---
# error prints

sub errme($format,%O) {
  my $tab="$O{lvl}#:!;>\e[0m ";
  fstrout($format,$tab,%O,errout=>1);

  return $tab;

};


# ---   *   ---   *   ---
# ^coupled with backtrace
# ^plus exit on fatal

sub errout($format,%O) {

  # defaults
  $O{args}  //= [];
  $O{calls} //= [];
  $O{lvl}   //= $AR_WARNING;
  $O{back}  //= 1;

  # print initial message
  my $tab=errme($format,%O);

  # exec calls
  my @calls=@{$O{calls}};
  while(@calls) {
    my $call=shift @calls;
    my $args=shift @calls;

    $call->(@$args);

  };


  # give backtrace?
  if($O{back}) {
    my $mess=join "\n",(
      map   {fmat_btrace}
      split $NEWLINE_RE,longmess()

    );

    my $header=sprintf(
      "$tab\e[33;1mBACKTRACE\e[0m\n\n"
    . "%-21s%-21s%-12s\n",

      'Module',
      'File',
      'Line',

    );

    print {*STDERR} "$header\n$mess\n\n";

  };


  # quit on fatal error
  exit if $O{lvl} eq $AR_FATAL;

  # ^else give
  return;

};


# ---   *   ---   *   ---
# ^gives caller info

sub errcaller(%O) {

  # defaults
  $O{depth}   //= 3;
  $O{fatdump} //= 0;
  $O{lvl}     //= $AR_FATAL;


  # get caller info
  my (@call) = (caller $O{depth});
  my $pkg    = $call[0];
  my $line   = $call[2];
  my $fn     = (! defined $call[3])
    ? '(non)'
    : $call[3]
    ;


  # ^prepare message
  my @text=(
    q[[ctl]:%s on [err]:%s, ]
  . q[[goodtag]:%s at line (:%u)] . "\n\n"

  );

  my @args=('IRUPT',$fn,$pkg,$line);


  # optionally provide an objdump
  if($O{fatdump}) {
    push @text,q[[warn]:%s];
    push @args,"FATDUMP";

  };


  # ^spit it out
  errme(
    catar(@text),

    lvl   => $O{lvl},
    args  => \@args,
    nopad => 1,

  );

  say null;

  fatdump(\$O{fatdump},errout=>1)
  if $O{fatdump};

  return;

};

# ---   *   ---   *   ---
1; # ret
