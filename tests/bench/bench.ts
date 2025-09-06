function otherSum(x: number, y: number): number {
    return x + y;
}

function sum(x: number, y: number): number {
    return otherSum(x, y);
}

function main(): void {
    const result = sum(60, 9);
    console.log(result);
}

main();
