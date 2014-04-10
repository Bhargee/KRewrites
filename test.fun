/*letrec general_map f l = if null? l
                        then []
                        else cons (f (head l)) (general_map f (tail l))
in */ (("map" (fun x -> x + 2)) ("map" (fun x -> x * 3)))
