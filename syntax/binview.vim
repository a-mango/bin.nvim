" syntax/binview.vim — highlighting for bin.nvim ELF inspection buffers.
" Buffer-local, so (unlike matchadd) it neither accumulates on reload nor
" bleeds onto other files shown in the same window.

if exists("b:current_syntax")
  finish
endif

" section chrome and headings
syntax match elfChrome  "^[┌└│].*"
syntax match elfTitle   "^  bin\.nvim.*"
syntax match elfRule     "^  .*═.*"

" checksec-style labels: "  RELRO:" etc.
syntax match elfLabel    "^  \s*[A-Z][A-Za-z ]*:"

" addresses and bare numbers
syntax match elfHex      "0x[0-9a-fA-F]\+"
syntax match elfNum      "\<\d\+\>"

" section names in brackets
syntax match elfBracket  "\[.*\]"

" section and segment types
syntax keyword elfSecType PROGBITS NOBITS SYMTAB STRTAB RELA REL GNU_HASH GNU_RELRO DYNSYM NULL
syntax keyword elfSegType LOAD INTERP PHDR TLS GNU_STACK GNU_EH_FRAME DYNAMIC NOTE

" symbol attributes
syntax keyword elfFunc   FUNC
syntax keyword elfObject OBJECT
syntax keyword elfBind   GLOBAL LOCAL WEAK

" security property values (most severe defined last so it wins on overlap)
syntax match elfSecOk   "\<\(Full RELRO\|Canary found\|NX enabled\|PIE enabled\)\>"
syntax match elfSecWarn "\<\(Partial RELRO\|No canary\|No PIE\|Partial\)\>"
syntax match elfSecErr  "\<\(No RELRO\|NX disabled\)\>"

" status and info lines
syntax match elfTrunc "(\.\.\. (first.*)"
syntax match elfError "\[error\].*"
syntax match elfNote  "  (.*not installed.*)"
syntax match elfNote  "  (no .*)"
syntax match elfNote  "  (static binary.*)"

highlight default link elfChrome  Title
highlight default link elfTitle   Comment
highlight default link elfRule    Special
highlight default link elfLabel   Identifier
highlight default link elfHex     Number
highlight default link elfNum     Number
highlight default link elfBracket String
highlight default link elfSecType Type
highlight default link elfSegType Keyword
highlight default link elfFunc    Function
highlight default link elfObject  Type
highlight default link elfBind    Constant
highlight default link elfSecOk   DiagnosticOk
highlight default link elfSecWarn DiagnosticWarn
highlight default link elfSecErr  DiagnosticError
highlight default link elfTrunc   WarningMsg
highlight default link elfError   ErrorMsg
highlight default link elfNote    Comment

let b:current_syntax = "binview"
