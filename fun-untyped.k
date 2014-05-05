require "modules/pattern-matching.k"

module FUN-UNTYPED-SYNTAX

/*@ FUN is an expression language.  The constructs below fall into
several categories: names, arithmetic constructs, conventional
functional constructs, patterns and pattern matching, data constructs,
lists, references, and call-with-current-continuation (callcc).
The arithmetic constructs are standard; they are present in almost all
our \K language definitions.  The meaning of FUN's constructs are
discussed in more depth when we define their semantics in the next
module.  */


//@ \subsection{The Syntactic Constructs}

/*@ We start with the syntactic definition of FUN names.
We have several categories of names: ones to be used for functions and
variables, others to be used for data constructors, others for types and
others for type variables.  We will introduce them as needed, starting
with the former category.  We prefer the names of variables and functions
to start with lower case letters.  We take the freedom to tacitly introduce
syntactic lists/sequences for each nonterminal for which we need them: */

  syntax Name ::= Token{[a-z][\_a-zA-Z0-9]*}       [notInRules]
  syntax Names ::= List{Name,","}

/*@ Expression constructs will be defined throughtout the syntax module.
Below are the very basic ones, namely the builtins, the names, and the
parentheses used as brackets for grouping.  Lists of expressions are
declared strict, so all expressions in the list get evaluated whenever
the list is on a position which can be evaluated: */

  syntax Exp ::= Int | Bool | String | Name
               | "(" Exp ")"                       [bracket]
  syntax Exps  ::= List{Exp,","}                   [strict]

/*@ We next define the syntax of arithmetic constructs, together with
their relative priorities and left-/non-associativities.  We also
tag all these rules with a new tag, ``arith'', so we can more easily
define global syntax priirities later (at the end of the syntax module). */

  syntax Exp ::= left:
                 Exp "*" Exp                       [strict, arith]
               | Exp "/" Exp                       [strict, arith]
               | Exp "%" Exp                       [strict, arith]
               > left:
                 Exp "+" Exp                       [strict, left, arith]
               | Exp "^" Exp                       [strict, left, arith]
// left attribute should not be necessary; currently a parsing bug
               | Exp "-" Exp                       [strict, prefer, arith]
// the "prefer" attribute above is to not parse x-1 as x(-1)
// Due to some parsing problems, we currently cannot add unary minus:
//               | "-" Exp                           [strict, arith]
               > non-assoc:
                 Exp "<" Exp                       [strict, arith]
               | Exp "<=" Exp                      [strict, arith]
               | Exp ">" Exp                       [strict, arith]
               | Exp ">=" Exp                      [strict, arith]
               | Exp "==" Exp                      [strict, arith]
               | Exp "!=" Exp                      [strict, arith]
               > "!" Exp                           [strict, arith]
               > Exp "&&" Exp                      [strict(1), left, arith]
               > Exp "||" Exp                      [strict(1), left, arith]

/*@ The conditional construct has the expected evaluation strategy,
stating that only the first argument is evaluate: */

  syntax Exp ::= "if" Exp "then" Exp "else" Exp    [strict(1)]

/*@ FUN's builtin lists are formed by enclosing comma-separated
sequences of expressions (i.e., terms of sort \textit{Exps}) in square
brackets.  The list constructor {\tt cons} adds a new element to the
top of the list, \texttt{head} and \texttt{tail} get the first element
and the tail sublist of a list if they exist, respectively, and get
stuck otherwise, and \texttt{null??} tests whether a list is empty or
not; syntactically, these are just expression constants.
In function patterns, we are also going to allow patterns following the
usual head/tail notation; for example, the pattern $\tt [x_1,...,x_n|t]$
binds $\tt x_1$, ..., $\tt x_n$ to the first elements of the matched list,
and $\tt t$ to the list formed with the remaining elements.  We define list
patterns as ordinary expression constructs, although we will make sure that
we do not give them semantics if they appear in any other place then in a
function case pattern. */

  syntax Exp ::= "[" Exps "]"                             [strict]
               | "cons" |  "head" | "tail" | "null?"
               | "[" Exps "|" Exp "]"

/*@ Data constructors start with capital letters and they may or may
not have arguments.  We need to use the attribute ``prefer'' to make
sure that, e.g., {\tt Cons(a)} parses as constructor {\tt Cons} with
argument {\tt a}, and not as the expression {\tt Cons} (because
constructor names are also expressions) regarded as a function applied
to the expression {\tt a}.  Also, note that the constructor is strict
in its second argument, because we want to evaluate its arguments but
not the constuctor name itsef. */

  syntax ConstructorName ::= Token{[A-Z][a-zA-Z0-9]*}   [notInRules]
  syntax Exp ::= ConstructorName
               | ConstructorName "(" Exps ")"    [prefer, strict(2)]

/*@ A function is essentially a ``\texttt{|}''-separated ordered
sequence of cases, each case of the form ``\verb|pattern -> expression|'',
preceded by the language construct \texttt{fun}.  Patterns will be defined
shortly, both for the builtin lists and for user-defined constructors.  
Recall that the syntax we define in \K is not meant to serve as a
ultimate parser for the defined language, but rather as a convenient
notation for \K abstract syntax trees, which we prefer when we write
the semantic rules.  It is therefore often the case that we define a
more ``generous'' syntax than we want to allow programs to use.
We do it here, too.  Specifically, the syntax of \textit{Cases}
below allows any expressions to appear as pattern.  This syntactic
relaxation permits many wrong programs to be parsed, but that is not a
problem because we are not going to give semantics to wrong combinations,
so those programs will get stuck; moreover, our type inferencer will reject
those programs anyway.  Function application is just concatenation of
expressions, without worrying about type correctness.  Again, the type
system will reject type-incorrect programs. */

  syntax Func ::= /*"fun" Cases |*/ "(" "fun" Cases")"
  syntax Exp ::= Func
               | Exp Exp                              [left]
// NOTE: We would like eventually to also have Exp "(" Exps ")
  syntax Case  ::= Exp "->" Exp
  syntax Cases ::= List{Case, "|"}

/*@ The \texttt{let} and \texttt{letrec} binders have the usual syntax
and functional meaning.  We allow multiple {\tt and}-separated bindings.
Like for the function cases above, we allow a more generous syntax for
the left-hand sides of bindings, noting that the semantics will get stuck
on incorrect bindings and that the type system will reject those programs. */

  syntax Exp ::= "let" Bindings "in" Exp
               | "letrec" Bindings "in" Exp                 [prefer]
// The "prefer" attribute for letrec currently needed due to tool bug,
// to make sure that "letrec" is not parsed as "let rec".
  syntax Binding  ::= Exp "=" Exp
  syntax Bindings ::= List{Binding,"and"}

/*@ References are first class values in FUN.  The construct \texttt{ref}
takes an expression, evaluates it, and then it stores the resulting value
at a fresh location in the store and returns that reference.  Syntactically,
\texttt{ref} is just an expression constant.  The construct \texttt{\&}
takes a name as argument and evaluates to a reference, namely the store
reference where the variable passed as argument stores its value; this
construct is a bit controversial and is further discussed in the
environment-based semantics of the FUN language, where we desugar
\texttt{ref} to it.  The construct \texttt{@} takes a reference
and evaluates to the value stored there.  The construct \texttt{:=} takes
two expressions, the first expected to evaluate to a reference; the value
of its second argument will be stored at the location to which the first
points (the old value is thus lost).  Finally, since expression evaluation
now has side effects, it makes sense to also add a sequential composition
construct, which is sequentially strict.  This evaluates to the value of
its second argument; the value of the first argument is lost (which has
therefore been evaluated only for its side effects. */

  syntax Exp ::= "ref"
               | "&" Name
               | "@" Exp                                     [strict]
               | Exp ":=" Exp                                [strict]
               | Exp ";" Exp                       [strict(1), right]

/*@ Call-with-current-continuation, named \texttt{callcc} in FUN, is a
powerful control operator that originated in the Scheme programming
language, but it now exists in many other functional languages.  It works
by evaluating its argument, expected to evaluate to a function, and by
passing the current continuation, or evaluation context (or computation,
in \K terminology), as a special value to it.  When/If this special value
is invoked, the current context is discarded and replaced with the one
held by the special value and the computation continues from there.
It is like taking a snapshot of the execution context at some moment
in time and then, when desired, being able to get back in time to that
point.  If you like games, it is like saving the game now (so you can
work on your homework!) and then continuing the game tomorrow or whenever
you wish.  To issustrate the strength of \texttt{callcc}, we also
allow exceptions in FUN by means of a conventional \texttt{try-catch}
construct, which will desugar to \texttt{callcc}.  We also need to
introduce the special expression contant \texttt{throw}, but we need to
use it as a function argument name in the desugaring macro, so we define
it as a name instead of as an expression constant: */

  syntax Exp ::= "callcc"
               | "try" Exp "catch" "(" Name ")" Exp
  syntax Name ::= "throw"

/*@ Finally, FUN also allows polymorphic datatype declarations.  These
will be useful when we define the type system later on. */

  syntax Exp ::= "datatype" Type "=" TypeCases Exp
// NOTE: In a future version of K, we want the datatype declaration
// to be a construct by itself, but that is not possible currently
// because K's parser wronly identifies the __ operation allowing
// a declaration to appear in front of an expression with the function
// application construct, giving ambiguous parsing errors.

/*@ We next need to define the syntax of types and type cases that appear
in datatype declarations.

Like in many functional languages, type parameters/variables in
user-defined types are quoted identifiers. */

  syntax TypeVar  ::= Token{[\'][a-z][\_a-zA-Z0-9]*}    [notInRules]
  syntax TypeVars ::= List{TypeVar,","}

/*@ Types can be basic types, function types, or user-defined
parametric types.  In the dynamic semantics we are going to simply ignore
all the type declations, so here the syntax of types below is only useful
for generating the desired parser.  To avoid syntactic ambiguities with 
the arrow construct for function cases, we use the symbol \verb|-->| as
a constructor for function types:  */

  syntax TypeName ::= Token{[a-z][\_a-zA-Z0-9]*}        [notInRules]
  syntax Type ::= "int" | "bool" | "string"
                | Type "-->" Type                            [right]
                | "(" Type ")"                             [bracket]
                | TypeVar
                | TypeName            [klabel('TypeName), onlyLabel]
                | Type TypeName  [klabel('Type-TypeName), onlyLabel]
                | "(" Types ")" TypeName                    [prefer]
  syntax Types ::= List{Type,","}

  syntax TypeCase ::= ConstructorName
                    | ConstructorName "(" Types ")"
  syntax TypeCases ::= List{TypeCase,"|"}


//@ \subsection{Additional Priorities}

  syntax priorities '@_
                  > '__
                  > arith
                  > '_:=_
                  > 'let_in_ 'letrec_in_ 'if_then_else_
                  > '_;_
                  //> 'fun_
                  > 'datatype_=__


//@ \subsection{Desugaring macros}

/*@ We desugar the list non-constructor operations to functions matching
over list patterns.  In order to do that we need some new variables; for
those, we follow the same convention like in the \K tutorial, where we
added them as new identifier constructs starting with the character $\$$,
so we can easily recognize them when we debug or trace the semantics. */

  syntax Name ::= "$h" | "$t"
  //rule head => fun [$h|$t] -> $h                             [macro]
  //rule tail => fun [$h|$t] -> $t                             [macro]
  //rule null? => fun [.Exps] -> true | [$h|$t] -> false       [macro]

//ADDED RULES
//@ Multiple-head list patterns desugar into successive one-head patterns:

  rule [E:Exp,Es|T] => [E|[Es|T]]  when Es =/=K .Exps        [macro]

//@ Uncurrying of multiple arguments in functions and binders:

  //rule P1 P2 -> E => P1 -> fun P2 -> E                       [macro]
  //rule F P = E => F = fun P -> E                             [macro]

/*@ We desugar the \texttt{try-catch} construct into callcc: */

  /*syntax Name ::= "$k" | "$v"
  rule try E catch(X) E'
    => callcc (fun $k -> (fun throw -> E)(fun X -> $k E'))   [macro]*/

//@ For uniformity, we reduce all types to their general form:
  rule 'TypeName(Tn:TypeName) => (.TypeVars) Tn              [macro]
  rule 'Type-TypeName(T:Type,,Tn:TypeName) => (T) Tn         [macro]

//@ The dynamic semantics ignores all the type declarations:

  rule datatype T = TCs E => E                               [macro]
  /* rewrite syntax */
  syntax MapExp ::= "map" ComposeExp
  syntax FoldExp ::= "fold" ComposeExp
  syntax Exp ::= ComposeExp | MapExp | FoldExp
  syntax ComposeExp ::= Func 
                        | ComposeExp "-|" Func
                        | ComposeExp "-|" "("ComposeExp")"

endmodule



/*@ \section{Semantics}

The semantics below is environment-based.  A substitution-based
definition of FUN is also available, but that drops the \texttt{\&}
construct as explained above. */

module FUN-UNTYPED
  imports FUN-UNTYPED-SYNTAX
  imports PATTERN-MATCHING
  imports SUBSTITUTION


/*@ \subsection{Configuration}

The \textsf{k}, \textsf{env}, and \textsf{store} cells are standard
(see, for example, the definition of LAMBDA++ or IMP++ in the first
part of the \K tutorial).  */

  configuration <T color="yellow">
                  <k color="green"> $PGM:Exp </k>
                  <env color="violet"> .Map </env>
                  <store color="white"> .Map </store>
                </T>


/*@ \subsection{Values and results}

We only define integers, Booleans and strings as values here, but will
add more values later.  */

  syntax Val ::= Int | Bool | String
  syntax Vals ::= List{Val,","}
  syntax Exp ::= Val
  syntax KResult ::= Val


//@ \subsection{Lookup}

  //rule <k> X:Name => V ...</k>
   //    <env>... X |-> L ...</env>
    //   <store>... L |-> V ...</store>


//@ \subsection{Arithmetic expressions}
/*  rule I1:Int * I2:Int => I1 *Int I2
  rule I1:Int / I2:Int => I1 /Int I2 when I2 =/=K 0
  rule I1:Int % I2:Int => I1 %Int I2 when I2 =/=K 0
  rule I1:Int + I2:Int => I1 +Int I2
  rule S1:String ^ S2:String => S1 +String S2
  rule I1:Int - I2:Int => I1 -Int I2
//  rule - I:Int => 0 -Int I
/*  rule I1:Int < I2:Int => I1 <Int I2
  rule I1:Int <= I2:Int => I1 <=Int I2
  rule I1:Int > I2:Int => I1 >Int I2
  rule I1:Int >= I2:Int => I1 >=Int I2
  rule V1:Val == V2:Val => V1 ==K V2
  rule V1:Val != V2:Val => V1 =/=K V2
  rule ! T:Bool => notBool(T)
  rule true  && E => E
  rule false && _ => false
  rule true  || _ => true
  rule false || E => E
*/

//@ \subsection{Conditional}

//  rule if  true then E else _ => E
 // rule if false then _ else E => E


/*@ \subsection{Lists}
  syntax Val ::= "cons" | "[" Vals "]"
  /*rule isVal(cons V:Val) => true
  rule cons V:Val [Vs:Vals] => [V,Vs]*/


/*@ \subsection{Data Constructors}

Constructors take values as arguments and produce other values: */

  syntax Val ::= ConstructorName
               | ConstructorName "(" Vals ")"

/*@ \subsection{Functions and Closures}

Like in the environment-based semantics of LAMBDA++ in the first part
of the \K tutorial, functions evaluate to closures.  A closure includes
the current environment besides the function contents; the environment
will be used at execution time to lookup all the variables that appear
free in the function body (we want static scoping in FUN). */
  syntax Val ::= closure(Map,Cases)
  //rule <k> fun Cases => closure(Rho,Cases) ...</k>  <env> Rho </env>
/*@ \paragraph{Note:} The reader may want to get familiar with
how the pre-defined pattern matching works before proceeding.
The best way to do that is to consult
\texttt{k/include/modules/pattern-matching.k}. */

/*@ To set up the pattern matching mechanism we need to specify what K
terms act as variables (for pattern matching, substitution, etc.).
This is currently done my subsorting those terms to the builtin
\texttt{Variable} sort.  In our case, we only want to allow the
\texttt{Name} identifiers to act as variables for pattern matching;
note that the \texttt{ConstructorName} identifiers are {\em not}
variables (they construct data values): */

  syntax Variable ::= Name

/*@ We distinguish two cases when the closure is applied.
If the first pattern matches, then we pick the first case: switch to
the closed environment, get the matching map and bind all its
variables, and finally evaluate the function body of the first case,
making sure that the environment is properly recovered afterwards.
If the first pattern does not match, then we drop it and thus move on
to the next one. */

/*  rule <k> closure(Rho, P->E | _) V:Val
           => bindTo(getMatching(P,V)) ~> E ~> env(Rho') ...</k>
       <env> Rho' => Rho </env>  when isMatching(P,V)
  rule closure(_, (P->_ | Cs:Cases => Cs)) V:Val  when notBool isMatching(P,V)*/

/*@ Besides the generic decomposition rules for patterns and values,
we also want to allow \texttt{[head|tail]} matching for lists, so we add
the following custom pattern decomposition rule: */

  rule decomposeMatching(([H:Exp|T:Exp] => H,T),
                         ([V:Val,Vs:Vals] => V,[Vs]))


/*  rule <k> let Bs in E
        => bindTo(names(Bs),exps(Bs)) ~> E ~> env(Rho) ...</k>
       <env> Rho </env>

  rule <k> letrec Bs in E
        => bind(names(Bs))~>assignTo(names(Bs),exps(Bs))~>E~>env(Rho)...</k>
       <env> Rho </env>
*/

/*@ Recall that our syntax allows \texttt{let} and \texttt{letrec} to
take any expression in place of its binding.  This allows us to use
the already existing function application construct to bind names to
functions, such as, e.g., ``\texttt{let x y = y in ...}''.
The desugaring macro in the syntax module uncurries such declarations,
and then the semantic rules above only work when the remaining
bindings are identifiers, so the semantics will get stuck on programs
that misuse the \texttt{let} and \texttt{letrec} binders. */


/*@ \subsection{References}

The semantics of references is self-explanatory, except maybe for the
desugaring rule of \texttt{ref}, which is further discussed.  Note
that \texttt{\&$X$} grabs the location of $X$ from the environment.
Sequential composition, which is needed only to accumulate the
side effects due to assignments, was strict in the first argument.
Once evaluated, its first argument is simply discarded: */

  syntax Name ::= "$x"
/*  rule ref => fun $x -> & $x                                 [macro]
  rule <k> & X => L ...</k>  <env>... X |-> L ...</env>
  rule <k> @ L:Int => V:Val ...</k>  <store>... L |-> V ...</store>
  rule <k> L:Int := V:Val => V ...</k>  <store>... L |-> (_=>V) ...</store>
  rule V:Val; E => E*/

/*@ The desugaring rule of \texttt{ref} (first rule above) works
because \texttt{\&} takes a variable and returns its location (like in C).
Note that some ``pure'' functional programming researchers strongly dislike
the \texttt{\&} construct, but favor \texttt{ref}.  We refrain from having
a personal opinion on this issue here, but support \texttt{\&} in the
environment-based definition of FUN because it is, technically speaking,
more powerful than \texttt{ref}.  From a language design perspective, it
would be equally easy to drop \texttt{\&} and instead give a direct
semantics to \texttt{ref}.  In fact, this is precisely what we do in the
substitution-based definition of FUN, because there appears to be no way
to give a substitution-based definition to the \texttt{\&} construct. */


/*@ \subsection{Callcc}

As we know it from the LAMBDA++ tutorial, call-with-current-continuation
is quite easy to define in \K.  We first need to define a special
value wrapping an execution context, that is, an environment saying
where the variables should be looked up, and a computation structure
saying what is left to execute (in a substitution-based definition,
this special value would be even simpler, as it would only need to
wrap the computation structure---see, for example, the
substitution-based semantics of LAMBDA++ in the the first part of the
\K tutorial, or the substitution-based definition of FUN).  Then
\texttt{callcc} creates such a value containing the current
environment and the current remaining computation, and passes it to
its argument function.  When/If invoked, the special value replaces
the current execution context with its own and continues the execution
normally. */

  syntax Val ::= "callcc" | cc(Map,K)
  /*rule <k> (callcc V:Val => V cc(Rho,K)) ~> K </k>  <env> Rho </env>
  rule <k> cc(Rho,K) V:Val ~> _ => V ~> K </k>  <env> _ => Rho </env>*/


//@ \subsection{Auxiliary operations}

/*@ \subsubsection{Environment recovery}

The environment recovery operation is the same as for the LAMBDA++
language in the \K tutorial and many other languages provided with the
\K distribution.  The first ``anywhere'' rule below shows an elegant
way to achieve the benefits of tail recursion in \K.  */

  syntax K ::= env(Map)
/*  rule (env(_) => .) ~> env(_)  [anywhere]
  rule <k> _:Val ~> (env(Rho) => .) ...</k> <env> _ => Rho </env>
    [structural]*/

/*@ \subsubsection{\texttt{bindTo}, \texttt{bind} and \texttt{assignTo}}

The meaning of these operations has already been explained when we
discussed the \texttt{let} and \texttt{letrec} language constructs
above. */

  syntax K ::= bindTo(Names,Exps)         [strict(2)]
             | bindTo(Map)
             | bind(Names)
/*
  rule bindTo(Xs:Names,Vs:Vals) => bindTo(getMatching(Xs,Vs))

  rule bindTo(.Map) => .  [structural]
  rule <k> bindTo((X:Name |-> V:Val => .) _) ...</k>
       <env> Rho => Rho[L/X] </env>
       <store>... . => L |-> V ...</store>
    when fresh(L:Int)  [structural]
*/
  /*rule bind(.Names) => .                  [structural]
  rule <k> bind(X:Name,Xs => Xs) ...</k>
       <env> Rho => Rho[L/X] </env>
    when fresh(L:Int)                   [structural]*/

  syntax K ::= assignTo(Names,Exps)  [strict(2)]

  //rule <k> assignTo(.Names,.Vals) => . ...</k>            [structural]
  /*rule <k> assignTo((X:Name,Xs => Xs),(V:Val,Vs => Vs)) ...</k>
       <env>... X |-> L ...</env>
       <store>... . => L |-> V ...</store>              [structural]*/

/*@ \subsubsection{Getters}

The following auxiliary operations extract the list of identifiers
and of expressions in a binding, respectively. */

  syntax Names ::= names(Bindings)  [function]
  //rule names(.Bindings) => .Names
  //rule names(X:Name=_ and Bs) => (X,names(Bs))::Names

  syntax Exps ::= exps(Bindings)  [function]
  //rule exps(.Bindings) => .Exps
  //rule exps(_:Name=E and Bs) => E,exps(Bs)

  rule map A:ComposeExp map B:Func => map (A -| B) [anywhere]
  rule map A:ComposeExp map B:ComposeExp => map (A -| (B)) [anywhere]

  rule fold A:ComposeExp map B:Func => fold (A -| B) [anywhere]

endmodule
