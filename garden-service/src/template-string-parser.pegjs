/*
 * Copyright (C) 2018 Garden Technologies, Inc. <info@garden.io>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

TemplateString
  = a:(FormatString)+ b:TemplateString? { return [...a, ...(b || [])] }
  / a:Prefix b:(FormatString)+ c:TemplateString? { return [a, ...b, ...(c || [])] }
  / InvalidFormatString
  / $(.*) { return text() === "" ? [] : [text()] }

FormatString
  = FormatStart e:Expression FormatEnd {
    return Promise.resolve(e)
      .then(v => {
        if (v && v._error) {
          return v
        }

        if (v === undefined && !options.allowUndefined) {
          const _error = new options.TemplateStringError("Unable to resolve one or more keys.", {
            text: text(),
          })
          return { _error }
        }
        return v
      })
      .catch(_error => {
        return { _error }
      })
  }

InvalidFormatString
  = Prefix? FormatStart .* {
  	throw new options.TemplateStringError("Unable to parse as valid template string.")
  }

FormatStart
  = "${" __

FormatEnd
  = __ "}"

Identifier
  = [a-zA-Z][a-zA-Z0-9_\-]* { return text() }

KeySeparator
  = "."

Key
  = head:Identifier tail:(KeySeparator Identifier)* {
    return [["", head]].concat(tail).map(p => p[1])
  }

Prefix
  = !FormatStart (. ! FormatStart)* . { return text() }

Suffix
  = !FormatEnd (. ! FormatEnd)* . { return text() }

// ---- expressions -----
// Reduced and adapted from: https://github.com/pegjs/pegjs/blob/master/examples/javascript.pegjs
PrimaryExpression
  = v:Literal {
    return v
  }
  / key:Key {
    return options.getKey(key, { allowUndefined: true })
      .catch(_error => {
        return { _error }
      })
  }
  / "(" __ e:Expression __ ")" {
    return e
  }

MultiplicativeExpression
  = head:PrimaryExpression
    tail:(__ MultiplicativeOperator __ PrimaryExpression)*
    { return options.buildBinaryExpression(head, tail); }

MultiplicativeOperator
  = $("*" !"=")
  / $("/" !"=")
  / $("%" !"=")

AdditiveExpression
  = head:MultiplicativeExpression
    tail:(__ AdditiveOperator __ MultiplicativeExpression)*
    { return options.buildBinaryExpression(head, tail); }

AdditiveOperator
  = $("+" ![+=])
  / $("-" ![-=])

RelationalExpression
  = head:AdditiveExpression
    tail:(__ RelationalOperator __ AdditiveExpression)*
    { return options.buildBinaryExpression(head, tail); }

RelationalOperator
  = "<="
  / ">="
  / $("<" !"<")
  / $(">" !">")

EqualityExpression
  = head:RelationalExpression
    tail:(__ EqualityOperator __ RelationalExpression)*
    { return options.buildBinaryExpression(head, tail); }

EqualityOperator
  = "=="
  / "!="

LogicalANDExpression
  = head:EqualityExpression
    tail:(__ LogicalANDOperator __ EqualityExpression)*
    { return options.buildLogicalExpression(head, tail); }

LogicalANDOperator
  = "&&"

LogicalORExpression
  = head:LogicalANDExpression
    tail:(__ LogicalOROperator __ LogicalANDExpression)*
    { return options.buildLogicalExpression(head, tail); }

LogicalOROperator
  = "||"

ConditionalExpression
  = test:LogicalORExpression __
    "?" __ consequent:Expression __
    ":" __ alternate:Expression
    {
      return Promise.all([test, consequent, alternate])
        .then(([t, c, a]) => {
          if (t && t._error) {
            return t
          }
          if (c && c._error) {
            return c
          }
          if (a && a._error) {
            return a
          }

          return t ? c : a
        })
        .catch(_error => {
          return { _error }
        })
    }
  / LogicalORExpression

Expression
  = ConditionalExpression

// Much of the below is based on https://github.com/pegjs/pegjs/blob/master/examples/json.pegjs
__ "whitespace" = [ \t\n\r]*

// ----- Literals -----

Literal
  = BooleanLiteral
  / NullLiteral
  / NumberLiteral
  / StringLiteral

BooleanLiteral
  = __ "true" __ { return true }
  / __ "false" __ { return false }

NullLiteral
  = __ "null" __ { return null }

NumberLiteral
  = __ Minus? Int Frac? Exp? __ { return parseFloat(text()); }

DecimalPoint
  = "."

Digit1_9
  = [1-9]

E
  = [eE]

Exp
  = E (Minus / Plus)? DIGIT+

Frac
  = DecimalPoint DIGIT+

Int
  = Zero / (Digit1_9 DIGIT*)

Minus
  = "-"

Plus
  = "+"

Zero
  = "0"

StringLiteral
  = __ '"' chars:DoubleQuotedChar* '"' __ { return chars.join(""); }
  / __ "'" chars:SingleQuotedChar* "'" __ { return chars.join(""); }

Escape
  = "\\"

DoubleQuotedChar
  = [^\0-\x1F\x22\x5C]
  / Escape
    sequence:(
        '"'
      / "\\"
      / "/"
      / "b" { return "\b"; }
      / "f" { return "\f"; }
      / "n" { return "\n"; }
      / "r" { return "\r"; }
      / "t" { return "\t"; }
      / "u" digits:$(HEXDIG HEXDIG HEXDIG HEXDIG) {
          return String.fromCharCode(parseInt(digits, 16));
        }
    )
    { return sequence; }

SingleQuotedChar
  = [^\0-\x1F\x27\x5C]
  / Escape
    sequence:(
        "'"
      / "\\"
      / "/"
      / "b" { return "\b"; }
      / "f" { return "\f"; }
      / "n" { return "\n"; }
      / "r" { return "\r"; }
      / "t" { return "\t"; }
      / "u" digits:$(HEXDIG HEXDIG HEXDIG HEXDIG) {
          return String.fromCharCode(parseInt(digits, 16));
        }
    )
    { return sequence; }

// ----- Core ABNF Rules -----

// See RFC 4234, Appendix B (http://tools.ietf.org/html/rfc4234).
DIGIT  = [0-9]
HEXDIG = [0-9a-f]i
