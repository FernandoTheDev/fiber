<?php
function other_sum($x, $y)
{
    return $x + $y;
}

function sum_func($x, $y)
{
    return other_sum($x, $y);
}

function main()
{
    $result = sum_func(60, 9);
    echo $result . "\n";
}

main();
