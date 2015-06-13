{
    var exprs = require('../ast/Expressions'), Literal = exprs.Literal, Sequence = exprs.Sequence,
                                                Aggregation = exprs.Aggregation, FunctionCall = exprs.FunctionCall
                                                InfixExpression = exprs.InfixExpression, AggregationSelector = exprs.AggregationSelector,
                                                Input = exprs.Input;

    var funcs = require('../ast/FunctionDefinition'), UserFunction = funcs.UserFunction;

    function infixExpr(operator, args) { return new InfixExpression(text().trim(), operator, args); }

    function exprOrInput(expr, functionName) {
        if (expr instanceof Input) {
            return new Input(functionName);
        }
        return expr;
    }
}

functionDefinitionList = functions:(functionDefinition __)+ { return functions.map(function(pair) { return pair[0]; }) ; }  / __ EOF { return []; }

functionDefinition = noArgsFunction / argsFunction
noArgsFunction = _ functionName:identifier _ "=" _ expr:functionExpressionOrInput EOS { return new UserFunction(functionName, [], exprOrInput(expr, functionName)); }
argsFunction = _ functionName:identifier  _ "(" _ argNames:identifierList _ ")"_ "=" expr:expression EOS { return new UserFunction(functionName, argNames, expr); }
identifierList = items:(
                     first:identifier
                     rest:(_ "," _ a:identifier { return a; })*
                     { return [first].concat(rest); }
                   )? { return result = items !== null ? items : []; }



functionExpressionOrInput = input / expression
functionExpression = expression  { return expr; }
input = _ "input" !identifierPart _ { return new Input(); }

expression = _ expr:anyExpression _  { return expr; }

anyExpression = expr:logical { return expr; }

functionCall = functionCallWithArgs / functionCallNoArgs
functionCallWithArgs = functionName:identifier _ "(" _ args:anyExpressionList _ ")" { return new FunctionCall(text().trim(), functionName, args); }
functionCallNoArgs = functionName:identifier { return new FunctionCall(text().trim(), functionName, []); }

anyExpressionList = items:(
                     first:anyExpression
                     rest:(_ "," _ a:anyExpression { return a; })*
                     { return [first].concat(rest); }
                   )? { return result = items !== null ? items : []; }

logical = or / andLike
or = left:andLike _ "or" _ right:logical { return infixExpr( 'or', [left, right]); }

andLike = and / comparative
and = left:comparative _ "and" _ right:andLike { return infixExpr( 'and', [left, right]); }

comparative = equal / notEqual / lessThanOrEqual / greaterThanOrEqual / lessThan / greaterThan / additive

equal = left:additive _ "==" _ right:comparative { return infixExpr( '==', [left, right]); }
notEqual = left:additive _ "<>" _ right:comparative { return infixExpr( '<>', [left, right]); }
lessThanOrEqual = left:additive _ "<=" _ right:comparative { return infixExpr( '<=', [left, right]); }
lessThan = left:additive _ "<" _ right:comparative { return infixExpr( '<', [left, right]); }
greaterThanOrEqual = left:additive _ ">=" _ right:comparative { return infixExpr( '>=', [left, right]); }
greaterThan = left:additive _ ">" _ right:comparative { return infixExpr( '>', [left, right]); }

additive = add / subtract / multiplicative

add = left:multiplicative _ "+" _ right:additive { return infixExpr( '+', [left, right]); }
subtract = left:multiplicative _ "-" _ right:additive { return infixExpr( '-', [left, right]); }

multiplicative = multiply / divide / selectorOrPrimary

multiply = left:selectorOrPrimary _ "*" _ right:multiplicative { return infixExpr( '*', [left, right]); }
divide = left:selectorOrPrimary _ "/" _ right:multiplicative { return infixExpr( '/', [left, right]); }

selectorOrPrimary = aggregationSelector / primary

aggregationSelector = _ aggExpr:(aggregation / functionCall / bracketedExpression) _ "." _ name:identifier _
                            { return new AggregationSelector(text().trim(), aggExpr, name)}

primary = aggregation / sequence / none / boolean / number / string / functionCall / bracketedExpression

none = "none" !identifierPart { return new Literal(text().trim(), null); }

booleanTrue  = val:("true" /  "yes") !identifierPart { return new Literal(text().trim(), true)}
booleanFalse  = val:("false" /  "no") !identifierPart { return new Literal(text().trim(), false)}
boolean "true/false" = booleanTrue / booleanFalse

floatOrInt = $ (digit+ ("." digit*)? / "." digit+)

number "number" = num:floatOrInt { var val = parseFloat(num, 10); return new Literal(text().trim(), val); }

string "string" = doubleQuote chars:[^"]* doubleQuote { var val = chars.join(""); return new Literal(text().trim(), val); }

identifier "identifier" = $(alpha identifierPart*)
identifierPart = (alpha/digit)

bracketedExpression = _ "(" _ expr:anyExpression _ ")" _ { return expr; }

sequence = _ "[" _ items:anyExpressionList _ "]" { return new Sequence(text().trim(), items); }

aggregation = _ "{" _ items:aggregateItemList _ "}" { var childMap = {};
                                                        items.forEach(function(it) { childMap[it.name] = it.expr; });
                                                        return new Aggregation(text().trim(), childMap);
                                                    }

aggregateItemList = items:(
                     first:aggregateItem
                     rest:(_ "," _ a:aggregateItem { return a; })*
                     { return [first].concat(rest); }
                   )? { return result = items !== null ? items : []; }

aggregateItem = _ name:identifier _ ":" _ expr:anyExpression { return {name: name, expr: expr}; }

digit = [0-9]
alpha = [a-zA-Z_]
doubleQuote "quote" = '"'

WhiteSpace "whitespace"
  = "\t"
  / "\v"
  / "\f"
  / " "
  / "\u00A0"
  / "\uFEFF"

LineTerminator
  = [\n\r\u2028\u2029]

LineTerminatorSequence "end of line"
  = "\n"
  / "\r\n"
  / "\r"
  / "\u2028"
  / "\u2029"

__  = (WhiteSpace / LineTerminatorSequence)*

_ = (WhiteSpace / LineTerminatorSequence)*

EOS = __ ";" / _ LineTerminatorSequence / __ EOF

EOF = !.