#!/usr/bin/perl
# ---   *   ---   *   ---
# LL
# low-level ops
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,
# ---   *   ---   *   ---

# deps
package ll;

  use strict;
  use warnings;

# ---   *   ---   *   ---
# in: a,b

# a+b
sub add {return eval(shift.'+'.shift);};

# a-b
sub sub0 {return eval(shift.'-'.shift);};

# a*b
sub mul {return eval(shift.'*'.shift);};

#a/b
sub div {return eval(shift.'/'.shift);};

#a<b
sub lt0 {return eval(shift.'<'.shift);};

#a>b
sub gt0 {return eval(shift.'>'.shift);};

# ---   *   ---   *   ---
# in: a

#?a
sub quest {return eval('('.shift.')!=0');};

#!a
sub neg {return eval('!('.shift.')');};

# ---   *   ---   *   ---
# peso-like ops

sub wap {my $x=shift;return (shift,$x);};

# ---   *   ---   *   ---
# I/O
# in: file handle

# ***: I/O redirection not implemented yet
sub out {;};
sub in {;};

# ---   *   ---   *   ---
# str cmp

sub oparn {;}
sub obrak {;}
sub ocurl {;}

sub cparn {;}
sub cbrak {;}
sub ccurl {;}

# ---   *   ---   *   ---



# ---   *   ---   *   ---
1; # ret
