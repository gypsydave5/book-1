open Core.Std
open Async.Std
module Code = Rwo_code
module Html = Rwo_html
module Import = Rwo_import
module Toc = Rwo_toc
let (/) = Filename.concat

(******************************************************************************)
(* HTML fragments                                                             *)
(******************************************************************************)
let head_item : Html.item =
  let open Html in
  head [
    meta ~a:["charset","utf-8"] [];
    meta ~a:[
      "name","viewport";
      "content","width=device-width, initial-scale=1.0"
    ] [];
    title [data "Real World OCaml"];
    link ~a:["rel","stylesheet"; "href","css/app.css"] [];
    script ~a:["src","js/min/modernizr-min.js"] [];
    script ~a:["src","//use.typekit.net/gfj8wez.js"] [];
    script [data "try{Typekit.load();}catch(e){}"];
  ]

let title_bar,title_bar_frontpage =
  let open Html in
  let nav = nav [
    a ~a:["href","index.html"] [data "Home"];
    a ~a:["href","toc.html"] [data "Table of Contents"];
    a ~a:["href","faqs.html"] [data "FAQs"];
    a ~a:["href","install.html"] [data "Install"];
    a ~a:["href","https://ocaml.janestreet.com/ocaml-core/"]
      [data "API Docs"];
  ]
  in
  let h1 = h1 [data "Real World OCaml"] in
  let h4 = h4 [data "Functional programming for the masses"] in
  let h5 = h5 [data "2"; sup [data "nd"]; data " Edition (in progress)"] in
  let title_bar =
    div ~a:["class","title-bar"] [
      div ~a:["class","title"] [h1; h5; nav]
    ]
  in
  let title_bar_frontpage =
    div ~a:["class","splash"] [
      div ~a:["class","image"] [];
      div ~a:["class","title"] [h1; h4; h5; nav]
    ]
  in
  title_bar,title_bar_frontpage


let footer_item : Html.item =
  let open Html in
  let links = [
    "http://twitter.com/realworldocaml", "@realworldocaml";
    "http://twitter.com/yminsky", "@yminsky";
    "http://twitter.com/avsm", "@avsm";
    "https://plus.google.com/111219778721183890368", "+hickey";
    "https://github.com/realworldocaml", "GitHub";
    "http://www.goodreads.com/book/show/16087552-real-world-ocaml", "goodreads";
  ]
  |> List.map ~f:(fun (href,text) -> li [a ~a:["href",href] [data text]])
  |> ul
  in
  footer [
    div ~a:["class","content"] [
      links;
      p [data "Copyright 2012-2014 \
         Jason Hickey, Anil Madhavapeddy and Yaron Minsky."];
    ]
  ]

let toc chapters : Html.item list =
  let open Html in
  let open Toc in
  let parts = Toc.of_chapters chapters in
  List.map parts ~f:(fun {info;chapters} ->
    let ul = ul ~a:["class","toc-full"] (List.map chapters ~f:(fun chapter ->
      li [
        a ~a:["href",chapter.filename] [
          h2 [data (
            if chapter.number = 0
            then sprintf "%s" chapter.title
            else sprintf "%d. %s" chapter.number chapter.title
          )]
        ];
        ul ~a:["class","children"] (
          List.map chapter.sections ~f:(fun (sect1,sect2s) ->
            let href = sprintf "%s#%s" chapter.filename sect1.id in
            li [
              a ~a:["href",href] [h5 [data sect1.title]];
              ul ~a:["class","children"] (
                List.map sect2s ~f:(fun (sect2,sect3s) ->
                  let href = sprintf "%s#%s" chapter.filename sect2.id in
                  li [
                    a ~a:["href",href] [data sect2.title];
                    ul ~a:["class","children"] (
                      List.map sect3s ~f:(fun sect3 ->
                        let href = sprintf "%s#%s" chapter.filename sect3.id in
                        li [a ~a:["href",href] [data sect3.title]]
                      ) );
                  ]
                ) );
            ]
          ) );
      ]
    ) )
    in
    match info with
    | None -> [ul]
    | Some x -> [h5 [data (sprintf "Part %d: %s" x.number x.title)]; ul]
  )
  |> List.concat

let next_chapter_footer next_chapter : Html.item option =
  let open Html in
  let open Toc in
  match next_chapter with
  | None -> None
  | Some x -> Some (
    a ~a:["class","next-chapter"; "href", x.filename] [
      div ~a:["class","content"] [
        h1 [
          small [data (sprintf "Next: Chapter %02d" x.number)];
          data x.title
        ]
      ]
    ]
  )

(** Process the given [html], adding or replacing elements to satisfy
    our main template. *)
let main_template ?(next_chapter=None) ?(title_bar=title_bar) html : Html.t =
  let rec f item = match item with
    | Nethtml.Data _ -> item
    | Nethtml.Element ("head", _, _) -> head_item
    | Nethtml.Element ("html",attrs,childs) ->
      Nethtml.Element (
        "html",
        (("class","no-js")::("lang","en")::attrs),
        (List.map childs ~f)
      )
    | Nethtml.Element ("body",attrs,childs) ->
      let childs = List.map childs ~f in
      let main_content = Html.(
        div ~a:["class","wrap"] [
          div ~a:["class","left-column"] [];
          article ~a:["class","main-body"] childs;
        ])
      in
      Html.body ~a:attrs (List.filter_map ~f:ident [
        Some title_bar;
        Some main_content;
        next_chapter_footer next_chapter;
        Some footer_item;
        Some (Html.script ~a:["src","js/jquery.min.js"] []);
        Some (Html.script ~a:["src","js/min/app-min.js"] []);
      ]
      )
    | Nethtml.Element (name,attrs,childs) ->
      Nethtml.Element (name, attrs, List.map ~f childs)
  in
  List.map ~f html


(******************************************************************************)
(* Make Pages                                                                 *)
(******************************************************************************)
let make_frontpage ?(repo_root=".") () : Html.t Deferred.t =
  return (
  main_template ~title_bar:title_bar_frontpage
    Html.[
      html [head []; body [data "empty for now"]]
    ]
  )
;;

let make_toc_page ?(repo_root=".") () : Html.t Deferred.t =
  Toc.get_chapters ~repo_root () >>| fun chapters ->
  main_template Html.[
    html [head []; body (toc chapters)]
  ]
;;

let make_chapter ?run_pygmentize repo_root chapters chapter_file
    : Html.t Deferred.t
    =
  let import_base_dir = Filename.dirname chapter_file in
  let chapter = List.find_exn chapters ~f:(fun x ->
    x.Toc.filename = Filename.basename chapter_file)
  in
  let next_chapter = Toc.get_next_chapter chapters chapter in

  (* OCaml code blocks *)
  let code : Code.phrase list Code.t ref = ref Code.empty in

  let update_code lang href : unit Deferred.t =
    match Code.file_is_mem !code href with
    | true -> return ()
    | false ->
      Code.add_file_exn
        ~lang
        ~run:(Code.run_file_exn ~repo_root ~lang)
        !code href
      >>| fun new_code ->
      code := new_code
  in

  let import_node_to_html (i:Import.t) : Html.t Deferred.t =
    let href = import_base_dir/i.href in
    update_code i.data_code_language href
    >>= fun () -> return (Code.find_exn !code ~file:href ?part:i.part)
    >>= fun contents ->
    Code.phrases_to_html ?run_pygmentize i.data_code_language contents
    >>| fun x -> [x]
  in

  let rec loop html =
    (Deferred.List.map html ~f:(fun item ->
      if Import.is_import_html item then
        import_node_to_html (ok_exn (Import.of_html item))
      else match item with
      | Nethtml.Data _ -> return [item]
      | Nethtml.Element (name, attrs, childs) -> (
        Deferred.List.map childs ~f:(fun x -> loop [x])
        >>| List.concat
        >>| fun childs -> [Nethtml.Element (name, attrs, childs)]
      )
     )
    )
    >>| List.concat
  in
  Html.of_file chapter_file >>= fun html ->
  loop html >>| fun html ->
  main_template ~next_chapter html
;;


(******************************************************************************)
(* Main Functions                                                             *)
(******************************************************************************)
type src = [
| `Chapter of string
| `Frontpage
| `Toc_page
| `FAQs
| `Install
]

let make ?run_pygmentize ?(repo_root=".") ~out_dir = function
  | `Frontpage -> (
    let out_file = out_dir/"index.html" in
    make_frontpage ~repo_root () >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
  | `Toc_page -> (
    let out_file = out_dir/"toc.html" in
    make_toc_page ~repo_root () >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
  | `Chapter in_file -> (
    let out_file = out_dir/(Filename.basename in_file) in
    Toc.get_chapters ~repo_root () >>= fun chapters ->
    make_chapter ?run_pygmentize repo_root chapters in_file >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
  | `FAQs -> (
    let base = "faqs.html" in
    let in_file = repo_root/"book"/base in
    let out_file = out_dir/base in
    Html.of_file in_file >>= fun html ->
    return (main_template html) >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
  | `Install -> (
    let base = "install.html" in
    let in_file = repo_root/"book"/base in
    let out_file = out_dir/base in
    Html.of_file in_file >>= fun html ->
    return (main_template html) >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
