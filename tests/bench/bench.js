function otherSum(x, y) {
    return x + y;
}

function sum(x, y) {
    return otherSum(x, y);
}

function main() {
    const result = sum(60, 9);
    console.log(result);
}

main();
