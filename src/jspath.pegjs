{
    var undef;

    function applyPathFns(ctx, fns, data) {
        var fn, i = 0, ctxLen, fnRes,
            res = Array.isArray(ctx)? ctx.slice() : [ctx],
            j = 0;

        while(fn = fns[i++]) {
            ctxLen = res.length;
            while(j < ctxLen) {
                fnRes = fn(res[j++], data);
                if(Array.isArray(fnRes)) {
                    res = res.concat(fnRes);
                }
                else if(typeof fnRes !== 'undefined') {
                    res.push(fnRes);
                }
            }

            if(j === res.length) {
                break;
            }
        }

        return res.slice(j);
    }

    function applyPredFns(ctx, fns, data) {
        var fn, i = 0, res = ctx;

        while(typeof res !== 'undefined' && (fn = fns[i++])) {
            res = fn(res, data);
        }

        return res;
    }

    var comparisonOperators = {
        '===' : function(val1, val2) {
            return val1 === val2;
        },
        '==' : function(val1, val2) {
            return val1 == val2;
        },
        '>=' : function(val1, val2) {
            return val1 >= val2;
        },
        '>'  : function(val1, val2) {
            return val1 > val2;
        },
        '<=' : function(val1, val2) {
            return val1 <= val2;
        },
        '<'  : function(val1, val2) {
            return val1 < val2;
        },
        '!==' : function(val1, val2) {
            return val1 !== val2;
        },
        '!=' : function(val1, val2) {
            return val1 != val2;
        },
        '^==' : function(val1, val2) {
            return typeof val1 === 'string' &&
                typeof val2 === 'string' &&
                val1.indexOf(val2) === 0;
        },
        '^=' : function(val1, val2) {
            return val1 !== null && val2 !== null &&
                val1.toString().toLowerCase().indexOf(val2.toString().toLowerCase()) === 0;
        },
        '$==' : function(val1, val2) {
            return typeof val1 === 'string' &&
                typeof val2 === 'string' &&
                val1.indexOf(val2, val1.length - val2.length) > -1;
        },
        '$=' : function(val1, val2) {
            if(val1 === null || val2 === null) {
                return false;
            }

            var val1Str = val1.toString().toLowerCase(),
                val2Str = val2.toString().toLowerCase();

            return val1Str.indexOf(val2Str, val1Str.length - val2Str.length) > -1;
        },
        '*==' : function(val1, val2) {
            return typeof val1 === 'string' &&
                typeof val2 === 'string' &&
                val1.indexOf(val2) > -1;
        },
        '*=' : function(val1, val2) {
            return val1 !== null && val2 !== null &&
                val1.toString().toLowerCase().indexOf(val2.toString().toLowerCase()) > -1;
        }
    };

    function applyComparisonOperator(val1, val2, operator) {
        var operatorFn = comparisonOperators[operator];
        return Array.isArray(val1)?
            Array.isArray(val2)?
                val1.some(function(val1) {
                    return val2.some(function(val2) {
                        return operatorFn(val1, val2);
                    });
                }) :
                val1.some(function(val1) {
                    return operatorFn(val1, val2);
                }) :
            Array.isArray(val2)?
                val2.some(function(val2) {
                    return operatorFn(val1, val2);
                }) :
                operatorFn(val1, val2);
    }

    var arithmeticOperators = {
        '+' : function(val1, val2) {
            return val1 + val2;
        },
        '-' : function(val1, val2) {
            return val1 - val2;
        },
        '*' : function(val1, val2) {
            return val1 * val2;
        },
        '/' : function(val1, val2) {
            return val1 / val2;
        },
        '%' : function(val1, val2) {
            return val1 % val2;
        }
    };

    function applyArithmeticOperator(val1, val2, operator) {
        return arithmeticOperators[operator](
            Array.isArray(val1)? val1[0] : val1,
            Array.isArray(val2)? val2[0] : val2);
    }

    function findAllChildren(ctx) {
        return typeof ctx === 'object' && ctx !== null?
            Object.keys(ctx).map(function(prop) {
                return ctx[prop];
            }) :
            undef;
    }

    function findDescendants(ctx, prop) {
        var res = [], ctxs = [ctx], curCtx, childCtxs;
        while(ctxs.length) {
            curCtx = ctxs.shift();
            if(typeof curCtx !== 'object' || curCtx === null) {
                continue;
            }

            prop === '*'?
                res = res.concat(findAllChildren(curCtx)) :
                curCtx.hasOwnProperty(prop) && res.push(curCtx[prop]);

            childCtxs = undef;
            Array.isArray(curCtx)?
                curCtx.forEach(function(ctx) {
                    childCtxs = appendObjectToArray(childCtxs, ctx);
                }) :
                Object.keys(curCtx).forEach(function(key) {
                    childCtxs = appendObjectToArray(childCtxs, curCtx[key]);
                });
            childCtxs && (ctxs = childCtxs.concat(ctxs));
        }

        return res;
    }

    function appendObjectToArray(arr, val) {
        if(typeof val !== 'object') {
            return arr;
        }

        if(Array.isArray(val)) {
            return arr? arr.concat(val) : val.slice();
        }

        (arr || (arr = [])).push(val);
        return arr;
    }
}

start
    = path:path {
        return function(root, substs) {
            return path(root, { root : root, substs : substs }, true);
        }
    }

path
    = fromRoot:'^'? parts:(part)+ {
        return function(ctx, data, asValue) {
            var pathRes = applyPathFns(fromRoot? data.root : ctx, parts, data);
            return asValue? pathRes : !!pathRes.length;
        };
    }

part
    = selector:selector pred:pred* {
        return pred.length?
            function(ctx, data) {
                return applyPredFns(selector(ctx), pred, data);
            } :
            selector;
    }

selector
    = '..' prop:prop {
        return function(ctx) {
            return findDescendants(ctx, prop);
        };
    }
    / '.' prop:prop? {
        return prop?
            prop === '*'?
                findAllChildren :
                function(ctx) {
                    return typeof ctx === 'object' && ctx !== null?
                        ctx[prop] :
                        undef;
                } :
            function(ctx) {
                return ctx;
            };
    }

prop
    = prop:[-_a-z0-9:/]i+ {
        return prop.join('');
    }
    / '"' prop:[-_a-z0-9:/.]i+ '"' {
        return prop.join('');
    }
    / '*' {
        return '*';
    }

pred
    = '[' _ pred:(arrPred / objPred) _ ']' {
        return pred;
    }

objPred
    = expr:expr {
        return function(ctx, data) {
            return Array.isArray(ctx)?
                ctx.filter(function(ctx) {
                    return !!expr(ctx, data);
                }) :
                expr(ctx, data)? ctx : undef;
        }
    }

expr
    = logicalExpr
    / notLogicalExpr

logicalExpr
    = logicalANDExpr
    / logicalORExpr
    / logicalNOTExpr

logicalANDExpr
    = head:(notLogicalExpr / logicalNOTExpr) _ tail:('&&' _ expr)+ {
        return function(ctx, data) {
            if(!head(ctx, data)) {
                return false;
            }

            var i = 0, len = tail.length;
            while(i < len) {
                if(!tail[i++][2](ctx, data)) {
                    return false;
                }
            }

            return true;
        }
    }

logicalORExpr
    = head:(notLogicalExpr / logicalNOTExpr) _ tail:('||' _ expr)+ {
        return function(ctx, data) {
            if(head(ctx, data)) {
                return true;
            }

            var i = 0, len = tail.length;
            while(i < len) {
                if(tail[i++][2](ctx, data)) {
                    return true;
                }
            }

            return false;
        }
    }

logicalNOTExpr
    = '!' _ expr:notLogicalExpr {
        return function(ctx, data) {
            return !expr(ctx, data);
        }
    }

notLogicalExpr
    = bracketedExpr
    / operatorExpr
    / termExpr

bracketedExpr
    = '(' _ expr:expr _ ')' {
        return expr;
    }

operatorExpr
    = comparisonExpr
    / arithmeticExpr

comparisonExpr
    = left:arithmeticExpr _ comparisonOperator:comparisonOperator _ right:arithmeticExpr {
        return function(ctx, data) {
            return applyComparisonOperator(left(ctx, data, true), right(ctx, data, true), comparisonOperator);
        }
    }

comparisonOperator
    = '==='
    / '=='
    / '>='
    / '>'
    / '<='
    / '<'
    / '!=='
    / '!='
    / '^=='
    / '^='
    / '$=='
    / '$='
    / '*=='
    / '*='

arithmeticExpr
    = additiveExpr
    / multiplicativeExpr

additiveExpr
    = left:multiplicativeExpr _ additiveOperator:additiveOperator _ right:arithmeticExpr {
        return function(ctx, data) {
            return applyArithmeticOperator(left(ctx, data, true), right(ctx, data, true), additiveOperator);
        }
    }

multiplicativeExpr
    = left:primaryArithmeticExpr _ multiplicativeOperator:multiplicativeOperator _ right:multiplicativeExpr {
        return function(ctx, data) {
            return applyArithmeticOperator(left(ctx, data, true), right(ctx, data, true), multiplicativeOperator);
        }
    }
    / primaryArithmeticExpr

primaryArithmeticExpr
    = termExpr
    / '(' _ arithmeticExpr:arithmeticExpr _ ')' {
        return arithmeticExpr;
    }

additiveOperator
    = '+'
    / '-'

multiplicativeOperator
    = '*'
    / '/'
    / '%'

termExpr
    = path
    / substExpr
    / valueExpr

substExpr
    = '$' _ subst:[-_a-z0-9]i+ {
        return function(ctx, data) {
            return data.substs[subst.join('')];
        };
    }

valueExpr
    = value:value {
        return function() {
            return value;
        }
    }

arrPred
    = arrPred:(arrPredBetween / arrPredLess / arrPredMore / arrPredIdx) {
        return function(ctx, data) {
            return Array.isArray(ctx)?
                arrPred(ctx, data) :
                undef;
        }
    }

arrPredBetween
    = idxFrom:arrPredIdxExpr ':' idxTo:arrPredIdxExpr {
        return function(ctx, data) {
            return ctx.slice(idxFrom(ctx, data), idxTo(ctx, data));
        }
    }

arrPredLess
    = ':' idx:arrPredIdxExpr {
        return function(ctx, data) {
            return ctx.slice(0, idx(ctx, data));
        }
    }

arrPredMore
    = idx:arrPredIdxExpr ':' {
        return function(ctx, data) {
            return ctx.slice(idx(ctx, data));
        }
    }

arrPredIdx
    = idx:arrPredIdxExpr {
        return function(ctx, data) {
            var idxVal = idx(ctx, data);
            return idxVal >= 0? ctx[idxVal] : ctx[ctx.length + idxVal];
        }
    }

arrPredIdxExpr
    = int:int {
        return function(ctx) {
            return int;
        }
    }
    / substExpr

value
    = boolean / string / float / int

boolean
    = 'true' {
        return true;
    }
    / 'false' {
        return false;
    }

string
    = '""' {
        return '';
    }
    / '"' chars:char+ '"' {
        return chars.join('');
    }

char
    = [^"\\\0-\x1F\x7f]
    / '\\"' { return '"'; }
    / '\\\\' { return '\\'; }
    / '\\/' { return '/'; }
    / '\\b' { return '\b'; }
    / '\\f' { return '\f'; }
    / '\\n' { return '\n'; }
    / '\\r' { return '\r'; }
    / '\\t' { return '\t'; }
    / '\\u' h1:hexDigit h2:hexDigit h3:hexDigit h4:hexDigit {
        return String.fromCharCode(parseInt('0x' + h1 + h2 + h3 + h4));
    }

hexDigit
    = [0-9a-fA-F]

float
    = sign:'-'? int:[0-9]* '.' frac:[0-9]+ {
        return parseFloat(sign + int.join('') + '.' + frac.join(''));
    }

int
    = sign:'-'? int:[0-9]+ {
        return parseInt(sign + int.join(''), 10);
    }
_
    = [ \t]*