.main {
    call hello()
    halt
}

fn hello() void {
    $0: string = "Hello World\n"
    $1: int = 69
    call say_hello(string $0, int $1)
    ret;
}

fn say_hello(string str, int $1) void {
    print str
    print $1
    ret;
}
