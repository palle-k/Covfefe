# BNF

Covfefe allows context free grammars to be specified using a language that is a superset of BNF.

## Contents

1. [Productions](#productions)
2. [Terminals](#terminals)
3. [Alternations](#alternations)
3. [Sequence Grouping](#sequence-grouping)
4. [Optional Sequences](#optional-sequences)
5. [Sequence Repetitions](#sequence-repetitions)
6. [Character Ranges](#character-ranges)
7. [Full Grammar](#full-grammar)

## Productions

A production in a context free grammar has the form `X -> b`, which indicates that `X` can be replaced by `b`.
`X` is a non-terminal, `b` is a string of terminals and non-terminals.

In BNF, a non-terminal is written as `<A>`, a terminal is written as `'a'` or `"a"`.
An assignment is written as `lhs ::= rhs`.

A grammar that produces `Hello World` can thereby be expressed as

```
<S> ::= 'hello' <whitespace> 'world'
<whitespace> ::= ' '
<whitespace> ::= '\t'
```

## Terminals

Terminals are strings of characters that are delimited either by `'`s or `"`s. 

### Escaping

To express characters such as newlines, tabs and unicode symbols, backslashes can be used:

```
<S> ::= '\n' | '\t' | '\\' | '\u{1F602}'
```

This grammar produces a single newline, a single tab, a single `\` or a single `😂`.

#### Warning

When adding grammars as strings in Swift code, backslashes need to be escaped.

The above grammar then becomes:

```swift
let grammarString = "<S> ::= '\\n' | '\\t' | '\\\\' | '\\u{1F602}'"
```


## Alternations

In the above example, whitespace can be replaced either by `' '` or by `'\t'`.
This can be written as

```
<whitespace> ::= ' ' | '\t'
```

Concatenation has a higher precedence than alternations, so the following grammar produces `ab` and `cd`

```
<S> ::= 'a' 'b' | 'c' 'd'
```

## Sequence Grouping

Parentheses (`(` and `)`) can be used to group symbols together.

The following grammar produces `abd` and `acd`:

```
<S> ::= 'a' ('b' | 'c') 'd'
```

## Optional Sequences

To mark a sequence as optional, brackets (`[` and `]`) can be used.

The following grammar produces `abc` and `ac`:

```
<S> ::= 'a' ['b'] 'c'
```

## Sequence Repetitions

To repeat a sequence, braces (`{` and `}`) can be used.

The following grammar produces `aba`, `abba`, `abbba`, etc. but not `aa`:

```
<S> ::= 'a' {'b'} 'a'
```

To also generate `aa`, repetitions can be matched with optional sequences:

```
<S> ::= 'a' [{'b'}] 'a'
```

It is preferred to make the entire repetition optional instead of repeating an optional sequence.

The repetition is generated using a left-recursive auxiliary rule.

## Character Ranges

To make it easier to specify grammars that recognize a large alphabet, character ranges can be used.
The following grammar recognizes all upper and lower case roman letters:

```
<S> ::= 'A' ... 'Z' | 'a' ... 'z'
```

The lower bound of a character range must be less than or equal the upper bound (e.g. `'b' ... 'a'` is an invalid range).
The bounds of a range must be exactly one character. The characters can consist of multiple unicode scalars.

## Full Grammar

The grammar that is recognized is the following:

```
(* Production rules are separated by newlines and optional whitespace *)
<syntax> ::= <optional-whitespace> | <newlines> | <rule> | <rule> <newlines> | <syntax> <newlines> <rule> <newlines> | <syntax> <newlines> <rule>

(* A rule consists of a non-terminal pattern name, an assignment operator and a production expression *)
<rule> ::= <optional-whitespace> <rule-name-container> <optional-whitespace> <assignment-operator> <optional-whitespace> <expression> <optional-whitespace>

(* Rule names are strings of alphanumeric characters *)
<rule-name-container> ::= "<" <rule-name> ">"
<rule-name> ::= <rule-name> <rule-name-char> | ""
<rule-name-char> ::= 'a' ... 'z' | 'A' ... 'Z' | '0' ... '9' | '_' | '-'

<assignment-operator> ::= ":" ":" "="

(* An expression can either be a concatenation or an alternation *)
<expression> ::= <concatenation> | <alternation>

(* An alternation is a list of concatenations separated by the | character *)
<alternation> ::= <expression> <optional-whitespace> "|" <optional-whitespace> <concatenation>

(* A concatenation is a string of terminals and non-terminals *)
<concatenation> ::= <expression-element> | <concatenation> <optional-whitespace> <expression-element>

(* An atom of a expression can either be a terminal literal, a non-terminal or a group *)
<expression-element> ::= <literal> | <rule-name-container> | <expression-group> | <expression-repetition> | <expression-optional>

<literal> ::= "'" <string-1> "'" | '"' <string-2> '"' | <range-literal>
<range-literal> ::= <single-char-literal> <optional-whitespace> "." "." "." <optional-whitespace> <single-char-literal>

<expression-group> ::= "(" <optional-whitespace> <expression> <optional-whitespace> ")"
<expression-repetition> ::= "{" <optional-whitespace> <expression> <optional-whitespace> "}"
<expression-optional> ::= "[" <optional-whitespace> <expression> <optional-whitespace> "]"

<string-1> ::= <string-1> <string-1-char> | ""
<string-1-char> ::= "[^'\\\\\r\n]" | <string-escaped-char> | <escaped-single-quote>
<string-2> ::= <string-2> <string-2-char> | ""
<string-2-char> ::= '[^"\\\\\r\n]' | <string-escaped-char> | <escaped-double-quote>
<single-char-literal> ::= "'" <string-1-char> "'" | '"' <string-2-char> '"'

<string-escaped-char> ::= <unicode-scalar> | <carriage-return> | <line-feed> | <tab-char> | <backslash>

<backslash> ::= "\\" "\\"
<line-feed> ::= "\\" "n"
<carriage-return> ::= "\\" "r"
<tab-char> ::= "\\" "t"

<escaped-double-quote> ::= "\\" '"'
<escaped-single-quote> ::= "\\" "'"

<unicode-scalar> ::= "\\" "u" "{" <unicode-scalar-digits> "}"
<unicode-scalar-digits> ::= <digit> [<digit>] [<digit>] [<digit>] [<digit>] [<digit>] [<digit>] [<digit>]
<digit> ::= '0' ... '9' | 'A' ... 'F' | 'a' ... 'f'

<newlines> ::= "\n" | "\n" <optional-whitespace> <newlines>

<optional-whitespace> ::= "" | <whitespace> <optional-whitespace>
<whitespace> ::= " " | "\t" | "\n" | <comment>
<comment> ::= "(" "*" <comment-content> "*" ")"
<comment-content> ::= <comment-content> <comment-content-char> | ""
<comment-content-char> ::= "[^*(]" | "*" "[^)]" | "(" "[^*]" | <comment>
```
