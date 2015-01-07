# bash completion for qlist.pl
_qlist(){
    local cur opts prev
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    COMPREPLY=()
    opts=`$1 -h | tr ' ' '\n' | sed 's/^\s*//g;s/\s*$//g' | sed -n 's/\(^-[-a-z]\+\)/\1/p'  | sort -u`
    COMPREPLY=( $( compgen -W "$opts" -- "$cur" ) )
}

complete -o default -F _qlist qlist.pl
