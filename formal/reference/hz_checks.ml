open Hz_semantics

let check label condition =
  if condition then Printf.printf "PASS %s\n%!" label
  else failwith label

let smoke () =
  let open HTyp in
  check "empty hole synthesizes a type hole"
    (HExp.syn Ctx.empty HExp.EmptyHole = Hole);
  check "ascribed identity synthesizes num -> num"
    (HExp.syn Ctx.empty
       (HExp.Asc (HExp.Lam ("x", HExp.Var "x"), Arrow (Num, Num)))
     = Arrow (Num, Num));
  let step state action =
    let ze, ty = Action.performSyn Ctx.empty action state in
    check "edit result synthesizes its reported type"
      (HExp.syn Ctx.empty (ZExp.erase ze) = ty);
    ze, ty
  in
  let final = List.fold_left step (ZExp.CursorE HExp.EmptyHole, Hole)
    [Action.Construct (Action.SLit 1); Action.Construct Action.SPlus;
     Action.Construct (Action.SLit 2); Action.Move Action.Parent]
  in
  check "construct 1 + 2 from an empty hole"
    (fst final = ZExp.CursorE (HExp.Plus (HExp.NumLit 1, HExp.NumLit 2)));
  let moved = Action.performSyn Ctx.empty (Action.Move (Action.Child 1)) final in
  check "movement preserves erasure" (ZExp.erase (fst moved) = ZExp.erase (fst final));
  let wrapped = Action.performAna Ctx.empty (Action.Construct (Action.SLit 7))
      (ZExp.CursorE HExp.EmptyHole) (Arrow (Num, Num)) in
  check "inconsistent construction creates a non-empty hole"
    (ZExp.erase wrapped = HExp.NonEmptyHole (HExp.NumLit 7));
  HExp.ana Ctx.empty (ZExp.erase wrapped) (Arrow (Num, Num));
  let rejected = try
      ignore (Action.performAna Ctx.empty Action.Finish
        (ZExp.CursorE (ZExp.erase wrapped)) (Arrow (Num, Num)));
      false
    with Action.InvalidAction -> true
  in
  check "finish rejects the incompatible enclosed literal" rejected;
  check "delete resets synthesis to an empty hole"
    (Action.performSyn Ctx.empty Action.Del final =
       (ZExp.CursorE HExp.EmptyHole, Hole))

(* Independent, componentwise formulation of the paper's consistency rules. *)
let rec paper_consistent a b =
  let open HTyp in
  match a, b with
  | Hole, _ | _, Hole | Num, Num -> true
  | Arrow (a1, a2), Arrow (b1, b2)
  | Sum (a1, a2), Sum (b1, b2) ->
      paper_consistent a1 b1 && paper_consistent a2 b2
  | _ -> false

let audit () =
  let open HTyp in
  let cases = [
    "arrow false positive", Arrow (Num, Num),
      Arrow (Arrow (Num, Num), Arrow (Num, Num));
    "arrow false negative", Arrow (Num, Arrow (Num, Num)),
      Arrow (Num, Arrow (Hole, Num));
    "sum false positive", Sum (Num, Num),
      Sum (Arrow (Num, Num), Arrow (Num, Num))
  ] in
  let failures = List.fold_left (fun failures (label, a, b) ->
    let expected = paper_consistent a b in
    let actual = HTyp.consistent a b in
    Printf.printf "%s: paper=%b upstream=%b %s\n%!"
      label expected actual (if expected = actual then "PASS" else "FAIL");
    failures + if expected = actual then 0 else 1) 0 cases
  in
  if failures <> 0 then exit 1

let () =
  match Array.to_list Sys.argv with
  | [_; "smoke"] -> smoke ()
  | [_; "audit"] -> audit ()
  | _ -> failwith "usage: hz_checks (smoke|audit)"
