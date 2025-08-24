sum ($0: int, $1: int) int {
    $2: int;
    add $2, $0, $1
    ret $2
}

.main {
    x: int; // uninitialized variable
    store x, 60
    y: int = 9

    $0: int;
    call sum(int x, int y), $0
    
    print $0
    halt
}

