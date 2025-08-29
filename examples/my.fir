.main {
    $0: int;
    $1: int = 60
    $2: int = 9
    call sum(int $1, int $2), $0
    print $0
    halt
}

fn sum (x, y) int {
    result: int;
    add result, x, y
    ret result
}
