(* Read only the supplied document, never resolve links or start a server. *)
let read_stdin () =
  let buffer = Buffer.create 4096 in
  let chunk = Bytes.create 4096 in
  let rec read () =
    match input stdin chunk 0 (Bytes.length chunk) with
    | 0 -> Buffer.contents buffer
    | count -> Buffer.add_subbytes buffer chunk 0 count; read ()
  in
  read ()

let () =
  if Array.length Sys.argv <> 1 then begin
    prerr_endline "Usage: devchain-markdown < document.md > preview.html";
    exit 2
  end;
  let doc = Cmarkit.Doc.of_string ~strict:false (read_stdin ()) in
  let html = Cmarkit_html.of_doc ~safe:true ~backend_blocks:false doc in
  print_string {|<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<meta name="referrer" content="no-referrer">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Markdown preview</title>
<style>
body { max-width: 75ch; margin: 2rem auto; padding: 0 1rem; font: 1rem/1.6 system-ui, sans-serif; }
pre { overflow: auto; padding: 1rem; background: #f0f0f0; }
code { font-family: monospace; }
table { border-collapse: collapse; }
td, th { border: 1px solid #aaa; padding: .25rem .5rem; }
blockquote { border-left: 3px solid #aaa; margin-left: 0; padding-left: 1rem; }
</style>
</head>
<body>
|};
  print_string html;
  print_endline "</body>\n</html>"
