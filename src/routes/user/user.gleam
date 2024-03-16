import wisp.{type Request, type Response}
import gleam/http.{Post}
import gleam/dynamic.{type Dynamic}
import gleam/json
import gleam/io
import gleam/crypto
import gleam/result
import gleam/string_builder
import gleam/bit_array
import errors/errors.{try}
import redis/redis
import ids/uuid
import radish

pub type User {
  User(
    id: String,
    username: String,
    author: Bool,
    password: String,
    posts: List(String),
    comments: List(String),
  )
}

pub type Session {
  Session(id: String, user_id: String, username: String)
}

pub type UserError {
  DecodeError(decode_errors: dynamic.DecodeErrors)
  HashingError
  SessionError
  DatabaseError
}

fn hash_password(user_request user: User) -> User {
  let hashed_password = crypto.hash(crypto.Sha256, <<user.password:utf8>>)
  let hashed_password_string = bit_array.base64_encode(hashed_password, False)
  User(..user, password: hashed_password_string)
}

fn store_session(
  req req: Request,
  user user: User,
  redis_client redis_client: redis.RedisClient,
) -> Result(User, UserError) {
  let existing_session = {
    use existing_cookie <- try(
      wisp.get_cookie(req, "blog_api", wisp.Signed),
      SessionError,
    )
    use session <- try(
      get_session(id: existing_cookie, redis_client: redis_client),
      SessionError,
    )
    Ok(session)
  }
  case existing_session {
    Ok(_) -> Ok(user)
    Error(_) -> {
      let result = create_session(user: user, redis_client: redis_client)
      case result {
        Ok(_) -> Ok(user)
        Error(_) -> Error(SessionError)
      }
    }
  }
}

fn insert_user(user user: User) -> Result(User, UserError) {
  todo
}

pub fn create_user(req: Request, redis_client: redis.RedisClient) -> Response {
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)
  let result = {
    use decoded_user <- result.try(decode_user(json))
    let hashed_password = hash_password(user_request: decoded_user)
    use stored_session <- result.try(store_session(
      req: req,
      user: hashed_password,
      redis_client: redis_client,
    ))
    use inserted_user <- result.try(insert_user(user: stored_session))
    let encoded_user = encode_user(inserted_user)
    Ok(encoded_user)
  }
  case result {
    Ok(json) -> wisp.json_response(json, 200)
    Error(_) -> wisp.internal_server_error()
  }
}

// utils

pub fn get_session(
  id id: String,
  redis_client redis_client: redis.RedisClient,
) -> Result(Session, UserError) {
  let result = {
    use session_string <- try(
      radish.get(redis_client.connection, id, 128),
      SessionError,
    )
    use session <- try(
      decode_session(dynamic.from(session_string)),
      SessionError,
    )
    Ok(session)
  }
  case result {
    Ok(session) -> Ok(session)
    Error(_) -> Error(SessionError)
  }
}

fn create_session(
  user user: User,
  redis_client redis_client: redis.RedisClient,
) -> Result(Nil, UserError) {
  let result = {
    use uuid <- try(uuid.generate_v4(), SessionError)
    let session = Session(id: uuid, user_id: user.id, username: user.username)
    use res <- try(
      radish.set(
        redis_client.connection,
        uuid,
        string_builder.to_string(encode_session(session)),
        128,
      ),
      SessionError,
    )
    Ok(res)
  }
  case result {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(SessionError)
  }
}

fn encode_session(sess session: Session) -> string_builder.StringBuilder {
  json.to_string_builder(
    json.object([
      #("id", json.string(session.id)),
      #("user_id", json.string(session.user_id)),
      #("username", json.string(session.username)),
    ]),
  )
}

fn encode_user(user user: User) -> string_builder.StringBuilder {
  json.to_string_builder(
    json.object([
      #("id", json.string(user.id)),
      #("username", json.string(user.username)),
      #("author", json.bool(user.author)),
      #("password", json.string(user.password)),
      #("posts", json.array(user.posts, of: json.string)),
      #("comments", json.array(user.comments, of: json.string)),
    ]),
  )
}

fn decode_session(json: Dynamic) -> Result(Session, UserError) {
  let decoder =
    dynamic.decode3(
      Session,
      dynamic.field("id", dynamic.string),
      dynamic.field("user_id", dynamic.string),
      dynamic.field("username", dynamic.string),
    )
  let result = decoder(json)
  case result {
    Ok(json) -> Ok(json)
    Error(err) -> Error(DecodeError(decode_errors: err))
  }
}

fn decode_user(json: Dynamic) -> Result(User, UserError) {
  let decoder =
    dynamic.decode6(
      User,
      dynamic.field("id", dynamic.string),
      dynamic.field("username", dynamic.string),
      dynamic.field("author", dynamic.bool),
      dynamic.field("password", dynamic.string),
      dynamic.field("posts", dynamic.list(of: dynamic.string)),
      dynamic.field("comments", dynamic.list(of: dynamic.string)),
    )
  let result = decoder(json)
  case result {
    Ok(json) -> Ok(json)
    Error(err) -> Error(DecodeError(decode_errors: err))
  }
}
