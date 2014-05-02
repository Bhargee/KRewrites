"foldl" (fun x -> fun y -> x + y) ("foldl" (fun z -> fun w -> z - w) ("map" (fun
a -> a + 2)))
