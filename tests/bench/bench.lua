function other_sum(x, y)
    return x + y
end

function sum(x, y)
    return other_sum(x, y)
end

function main()
    local result = sum(60, 9)
    print(result)
end

main()
