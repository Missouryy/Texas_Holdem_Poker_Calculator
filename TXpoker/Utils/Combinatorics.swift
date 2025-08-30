struct Combinatorics {
    static func combinations<T>(_ array: [T], k: Int) -> [[T]] {
        guard k > 0 else { return [[]] }
        if k == array.count { return [array] }
        if k > array.count { return [] }
        var result: [[T]] = []
        func dfs(_ start: Int, _ path: [T]) {
            if path.count == k { result.append(path); return }
            var i = start
            while i < array.count {
                dfs(i + 1, path + [array[i]])
                i += 1
            }
        }
        dfs(0, [])
        return result
    }
}
