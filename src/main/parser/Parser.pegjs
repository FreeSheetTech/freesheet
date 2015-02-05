{
    var exprs = require('../ast/Expressions'), Literal = exprs.Literal, Sequence = exprs.Sequence,
                                                Aggregation = exprs.Aggregation, FunctionCall = exprs.FunctionCall;

    function returnType(fn) { return fn.returnType || "value"; }

    function getInputStream(name) {
        return options.context.getNamedFormula(name);
    }

    function asObservable(x) { return x instanceof Rx.Observable ? x : new Rx.BehaviorSubject(x); }
    function asObservables(xList) { return xList.map(asObservable); }
    function binaryOp(left, right, fn) {
        var leftObs = asObservable(left), rightObs = asObservable(right);
        return Rx.Observable.combineLatest(leftObs, rightObs, fn);
    }
    function addOp(left, right) { return binaryOp(left, right, function(l, r) { return l + r; }); }
    function subtractOp(left, right) { return binaryOp(left, right, function(l, r) { return l - r; }); }
    function multiplyOp(left, right) { return binaryOp(left, right, function(l, r) { return l * r; }); }
    function divideOp(left, right) { return binaryOp(left, right, function(l, r) { return l / r; }); }
    function functionCallOp(functionName, args) {
        var fn = functions[functionName];
        if (returnType(fn) == "value"  && fn.length > 0) {
            return Rx.Observable.combineLatest(asObservables(args), fn);
        } else {
            return fn.call(null, args);
        }
    }
}

start = _ expr:additive _  { return expr; }

functionCall = functionName:identifier _ "(" _ args:additiveList _ ")" { return new FunctionCall(text().trim(), functionName, args); }

additiveList = items:(
                     first:additive
                     rest:(_ "," _ a:additive { return a; })*
                     { return [first].concat(rest); }
                   )? { return result = items !== null ? items : []; }

additive = add / subtract / multiplicative

add = left:multiplicative _ "+" _ right:additive { return addOp(left, right); }
subtract = left:multiplicative _ "-" _ right:additive { return subtractOp(left, right); }

multiplicative = multiply / divide / primary

multiply = left:primary _ "*" _ right:multiplicative { return multiplyOp(left, right); }
divide = left:primary _ "/" _ right:multiplicative { return divideOp(left, right); }

primary = aggregation / sequence / number / string / functionCall / namedValue / bracketedExpression

floatOrInt = $ (digit+ ("." digit*)? / "." digit+)

number "number" = num:floatOrInt { var val = parseFloat(num, 10); return new Literal(text().trim(), val); }

string "string" = doubleQuote chars:[^"]* doubleQuote { var val = chars.join(""); return new Literal(text().trim(), val); }

identifier "identifier" = $(alpha (alpha/digit)*)

namedValue = id:identifier { return getInputStream(id); }

bracketedExpression = _ "(" _ additive:additive _ ")" _ { return additive; }

sequence = _ "[" _ items:additiveList _ "]" { return new Sequence(text().trim(), items); }

aggregation = _ "{" _ items:aggregateItemList _ "}" { var childMap = {};
                                                        items.forEach(function(it) { childMap[it.name] = it.expr; });
                                                        return new Aggregation(text().trim(), childMap);
                                                    }

aggregateItemList = items:(
                     first:aggregateItem
                     rest:(_ "," _ a:aggregateItem { return a; })*
                     { return [first].concat(rest); }
                   )? { return result = items !== null ? items : []; }

aggregateItem = _ name:identifier _ ":" _ expr:additive { return {name: name, expr: expr}; }


digit = [0-9]
alpha = [a-zA-Z_]
space = " "+
_ = space?
doubleQuote "quote" = '"'

