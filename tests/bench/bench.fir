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
    call other_sum(int x, int y), result
    ret result
}

fn other_sum (x, y) int {
    $0: int;
    add $0, x, y
    ret $0
}
