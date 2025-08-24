/*
.main {
    x: int = 60
    $0: int;
    store $0, 9
    $1: int;
    add $1, $0, x
    print $1
    halt
}
*/

.main {
    $0: int = 20
    $1: int;
    add $1, $1, $0 // $1 = 20
    add $1, $1, $0 // $1 = 40
    add $1, $1, $0 // $1 = 60

    $2: int = 9
    $3: int;
    add $3, $1, $2 // $3 = 60 + 9

    print $3
    halt
}
