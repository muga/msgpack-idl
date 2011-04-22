
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case match

" Todo
syn keyword msgspecTodo TODO FIXME XXX contained

" Comments
syn match msgspecComment "#.*" contains=msgspecTodo
syn match msgspecComment "\/\/.*$" contains=msgspecTodo
syn region msgspecComment start="/\*" end="\*/" contains=msgspecTodo,msgspecComment

" Literal
syn match msgspecString "'\(\\.\|[^'\\]\)*'"
syn match msgspecString "\"\(\\.\|[^\"\\]\)*\""
syn match msgspecNumber "\<[0-9][0-9]*\(\.[0-9][0-9]*\)\?\>"
syn keyword msgspecBoolean true false

" Keywords
syn keyword msgspecKeyword default
syn keyword msgspecDeclareKeyword namespace include
syn keyword msgspecTypeKeyword const typedef typespec
syn keyword msgspecStructure interface service message exception enum application
"syn keyword msgspecStructureDeclaration import
syn keyword msgspecException throws
syn keyword msgspecModifier required optional
syn keyword msgspecBasicType void
syn keyword msgspecBasicType byte int short long
syn keyword msgspecBasicType ubyte uint ushort ulong
syn keyword msgspecBasicType float double bool string raw
syn keyword msgspecContainerType map list
"syn keyword msgspecSpecial obsolete
syn match msgspecSpecial "!"
syn match msgspecSpecial "+"
syn match msgspecSpecial "-"
"syn match msgspecSpecial "?"

" Special
syn match msgspecId "\<\d\+:"
syn match msgspecServiceVersion ":\d\+\>"

" Block
syn region msgspecBlock matchgroup=NONE start="{" end="}" contains=@msgspecBlockItems
syn cluster msgspecBlockItems contains=msgspecComment,msgspecString,msgspecNumber,msgspecKeyword,msgspecId,msgspecStructureDeclaration,msgspecException,msgspecModifier,msgspecBasicType,msgspecContainerType,msgspecSpecial,msgspecBlock

hi link msgspecTodo Todo
hi link msgspecComment Comment
hi link msgspecString String
hi link msgspecNumber Number
hi link msgspecBoolean Boolean
hi link msgspecTypeKeyword Type
hi link msgspecStructure Structure
hi link msgspecStructureDeclaration Special
hi link msgspecException Exception
hi link msgspecModifier Special
hi link msgspecDeclareKeyword PreProc
hi link msgspecKeyword Keyword
hi link msgspecBasicType Type
hi link msgspecSpecial Special
"hi link msgspecContainerType Type
hi link msgspecId Label
hi link msgspecServiceVersion Label
"hi link msgspecVersion Special

let b:current_syntax = "msgspec"

