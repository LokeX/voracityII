import malebolgia

proc dfs(depth, breadth: int): int {.gcsafe.} =
  if depth == 0: return 1

  # The seq where we collect the results of the subtasks:
  var sums = newSeq[int](breadth)

  # Create a Master object for task coordination:
  var m = createMaster()

  # Synchronize all spawned tasks using an AwaitAll block:
  m.awaitAll:
    for i in 0 ..< breadth:
      # Spawn subtasks recursively, store the result in `sums[i]`:
      m.spawn dfs(depth - 1, breadth) -> sums[i]

  result = 0
  for i in 0 ..< breadth:
    result += sums[i] # No `sync(sums[i])` required

let answer = dfs(8, 8)
echo answer