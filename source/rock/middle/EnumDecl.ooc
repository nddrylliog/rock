import structs/HashMap
import ../io/TabbedWriter
import TypeDecl, Declaration, Visitor, Node, VariableAccess, Type,
       VariableDecl, IntLiteral, FloatLiteral, Expression
import tinker/[Trail, Resolver, Response, Errors]
import ../frontend/Token

EnumDecl: class extends TypeDecl {
    lastElementValue := IntLiteral new(0, nullToken)
    incrementOper := '+'
    incrementStep := 1
    fromType: Type

    init: func ~enumDecl(.name, .token) {
        super(name, token)
        fromType = instanceType
    }

    setFromType: func (=fromType) {}

    resolve: func (trail: Trail, res: Resolver) -> Response {
        {
            response := super(trail, res)
            if(!response ok()) return response
        }

        {
            response := fromType resolve(trail, res)
            if(!response ok()) return response
        }

        Response OK
    }

    addElement: func (element: EnumElement) {
        if(isExtern()) {
            if(!element isExtern()) {
                // Provide a default extern name if none is provided
                element setExternName(element getName())
            }
        } else {
            // If no value is provided for a non-extern element,
            // calculate it by incrementing the last used value.
            if(!element valueSet) {
                lastElementValue = match lastElementValue {
                        case intLit: IntLiteral =>
                            IntLiteral new(match incrementOper {
                                case '+' =>
                                    intLit value + incrementStep
                                case '*' =>
                                    intLit value * incrementStep
                            }, intLit token)
                        case floatLit: FloatLiteral =>
                            FloatLiteral new(match incrementOper {
                                case '+' =>
                                    floatLit value + incrementStep as Float
                                case '*' =>
                                    floatLit value * incrementStep as Float
                            }, floatLit token)
                        case =>
                            token module params errorHandler onError(ImpossibleIncrement new(element token,
                                "It's impossible to increment implicitly elements of type %s!" format(fromType toString() toCString())))
                            return
                            null
                }
                element setValue(lastElementValue)
            } else {
                lastElementValue = element getValue()
            }
        }

        element setType(fromType)
        getMeta() addVariable(element)
    }

    setIncrement: func (=incrementOper, =incrementStep) {}

    writeSize: func (w: TabbedWriter, instance: Bool) {
        w app("sizeof(")
        if(isExtern()) {
            if(externName && externName != "") {
                w app(externName)
            } else {
                w app(name)
            }
        } else {
            w app("int")
        }
        w app(")")
    }

    accept: func (visitor: Visitor) {
        visitor visitEnumDecl(this)
    }

    replace: func (oldie, kiddo: Node) -> Bool { false }
}

EnumElement: class extends VariableDecl {
    doc: String
    type: Type
    value: Expression
    valueSet := false

    init: func ~enumElementDecl(.type, .name, .token) {
        super(type, name, token)
    }

    setValue: func (=value) { valueSet = true }
    getValue: func -> Expression { value }

    setType: func (=type) {}
    getType: func -> Type { type }

    accept: func (visitor: Visitor) {}

    replace: func (oldie, kiddo: Node) -> Bool { false }
}

ImpossibleIncrement: class extends Error {
    init: super func ~tokenMessage
}

