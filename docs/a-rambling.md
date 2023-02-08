# A MADMAN'S RAMBLING

## SYNOPSIS

Formal description favors spoken pseudo-code over foreign representation.

## THE DUCK TRICK

Describing what a program is supposed to do overpowers the brain in such a way that a higher dimention of sense is added to process of coding itself.

In formally describing the inner workings of my own programs, I have found that utilizing english more than suffices. Due to all the programming concepts that can be universally -- ie across-languages -- summarized with a single english word, the task is fairly simplified from the very start:

```pseudo

O has a stack;
size equals 8;

input byte X;

if top of O.stack equals size;
  pop O.stack into X;

else;
  push X to O.stack;

return X;

```

Quite the useless example, and not read much different than actual code. To give a not-so-pseudo example:

```$

reg O;
  byte buf  stack;
  byte size 8;

proc chk;

  io byte X;

  on stack.top eq size;
    X eq {pop stack};

  or;
    push stack,X;

  off;

ret;

```

Describing a program in 'plain' english tends to be much more clear and natural than utilizing equations; "foreign representation", as I believe I've said many times before, and more broadly: a non-programming language used to describe a concept exclusive to programming, or rather, idiocy itself.

Pseudo is preferred over these because it is such a natural fit for the task that *minimal* knowledge suffices for reading and writing.

But what is the relation between someone's understanding of a subject and their capacity to explain it?

Everything.

If you cannot explain it in a way that is at the very least clear to you, you do not understand the subject. And the more closely you understand it, the easier it is for you to express it in shorter, and shorter ways, proportional to how easy it is for others to understand it as well.

Compacting an idea is what naming is about, as you  convey the semantics of a construct through it's name. Once it clicks, it makes such strong sense that one simply cannot forget it.

Thus, producing explanations of programs as an excersice, even when they're entirely theoretical, is something we *must* commit to.

## WHY WE THEORIZE

Research. We want to know what's possible, which entails finding new ways it could be.

Reasearching new ways of accomplishing a certain effect broadens your view of the mediums it's study concern.

There is a 'how' to theory and it must eventually be proven or disproven, waltzarounds included; and in our case, if the methods we apply to modeling keep producing subpar results then the paradigms we cling to have done nothing but utterly fail us all.

I have many times suprised myself trying to prove an assertion I tought to be false, only to find out there's questionable ways to make it work __if__ you so desired -- and that is exactly the trap we have fell into.

We make things work. Badly.

For instance: conditional jumps can be implemented without conditionals in the strict sense, given that if you multiply an offset to an address by the result of a boolean operation, you still get the same effect regardless of the absence of keywords.

The solution is both more instructions __and__ incredibly inconvenient for any practical uses, but it *is* possible. And though one may not spend much of their time chasing these whimsical pursuits, for any non-questionable method to be conceived one must have a grasp of what is entirely off the question.

Our collective failure is not in vain; speaking for myself, many lessons have been learned. Beg to end, it's been a process of elimination. But one *must* think about code in formal terms to acquire the knack and sense.

## FORMALITY

Assume you are talking to a group of colleagues, and certain courtesies are due. This is essential, even if it's a single colleague and even if you duck it out.

And it's not as simple as utilizing big words, often times simple terms more than suffice, however it is necessary that you are expressive enough that little or nothing is left ambiguous.

This is where we loop back.

Point of theory *and* naming is that previously established concepts can be summoned. If your descriptions and titles are sufficiently sophisticated and thought out, it rarely needs explaining twice.

More importantly, to commit only as much time to a single area as possible, preferably looking at satelites at a surface level. Sufficiently abstracted constructs let us talk high level and simplify any compound machines they are components of.

Sparing me a long-winded sermon that goes nowhere is precisely the kind of formality I refer to. If you need to go on and on, then do what I do: leave your ramblings to documentation.

## STEPS NEEDED

State the goal of each limb. If it cannot be done, it's either too big a monolith or a redundancy pending forceful deprecation.

Ultimately, every abstraction becomes an IO-link to another -- thus, they must first be conceived as programs themselves. This is yet another subtle implication of `proc eq type`; to lack clarity of purpose is to lack a reason to be, and software is no different.

Secondly, breaking issues down into smaller tasks is the only natural strategy. Even by turning a theorized algorithm into an AST of pseudocode you have done more to understand both the problem __and__ solution than you would via any other method.

Furthermore, modeling a program after an actual data structure means one does not have to do it twice. I will go as far as to say all algorithms should be first expressed as trees; it is only ever proper to resort to foreign representation deep within it's branches.

How shameful of the entirety of our field that it must be the madman who makes the suggestion: save mathemathics to express mathemathical ideas within software, rather than using mathemathics to try and explain programs only mathematicians will understand.

As it stands, the academic bubble holding opinions to the contrary exists solely to be irrelevant. Everyone, even me, has read and writen garbage code and there is no number of books your mind can digest that will change this reality.

We think too much in every other direction but the right one and that is precisely why over half of the systems __we__ have produced are nothing but over-engineered junkyard bonfires.

## CONCLUSION

If the teachers we had were wise and the literature we've been forced to swallow was sound, then "good" programmers would not be quite as rare as they are, and our job would not so-oft evoke untold nightmares uppon us all.

Favor study of expression itself over individual languages, and you shall triumph: that is my advice.
