.main {
    name: string; age: int;
    $0: string = "Name: " $1: string = "Age: " $2: string = "Hello " $3: string = ", you're " $4: string = " years old\n"
    print $0 input name
    print $1 input age
    sconc $2, $2, name sconc $2, $2, $3
    print $2 print age print $4
    halt
}
