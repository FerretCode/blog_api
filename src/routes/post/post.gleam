import wisp.{type Request, type Response}
import gleam/json
import gleam/string_builder

pub type Post {
  Post(
    id: String,
    title: String,
    content: String,
    user_id: String,
    comments: List(String),
  )
}

fn encode_post(post post: Post) -> string_builder.StringBuilder {
  json.to_string_builder(
    json.object([
      #("id", json.string(post.id)),
      #("title", json.string(post.title)),
      #("content", json.string(post.content)),
      #("user_id", json.string(post.user_id)),
      #("comments", json.array(post.comments, of: json.string)),
    ]),
  )
}

pub fn get_posts(req: Request) -> Response {
  let post =
    Post(
      id: "1",
      title: "test post",
      content: "test content",
      user_id: "test_user",
      comments: [],
    )
  let posts =
    json.to_string_builder(json.array(
      [string_builder.to_string(encode_post(post))],
      of: json.string,
    ))
  wisp.json_response(posts, 200)
}
