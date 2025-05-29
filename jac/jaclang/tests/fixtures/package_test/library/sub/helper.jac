import from ..tools { tool_func }

def help_func() {
    return 'Helper function called' ;
}

with entry {
    print('Tool says:', tool_func()) ;
}