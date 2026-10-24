# portico

ローカルの Rails アプリを `https://<名前>.test` で開くための gem。puma-dev の置き換え。

`bin/dev` を起動すると、空いているポートで puma を立ち上げ、手前の Caddy に
`<名前>.test → 127.0.0.1:<ポート>` を登録する。止めると外れる。ポート番号は意識しなくてよい。

## 前提: 入口 (Caddy + DNS)

アプリの外で、次の3つが動いていること。dotfiles の nix-darwin で宣言している (`portico.nix`)。

- Caddy が `:80` と `:443` で待ち受け、管理 API を `localhost:2019` で開いている。
  HTTP サーバの名前は `portico`。`tls internal` で証明書を発行する
- `*.test` が `127.0.0.1` に解決される (`/etc/resolver/test` + dnsmasq)
- Caddy の root CA が macOS のキーチェーンで信頼されている (`sudo caddy trust`)

## アプリに入れる

```ruby
# Gemfile
group :development do
  gem "portico", github: "ogijun/portico"
end
```

```ruby
# config/puma.rb
plugin :portico if Gem.loaded_specs.key?("portico")
```

これだけで `bin/dev` (または `bin/rails server`) のあとに `https://<名前>.test` が開く。
`PORT` や `-p` で渡したポートより、portico の選んだ空きポートが優先される。

### ホスト名

- 既定は `config/application.rb` の `module` 名から決める (`TeamWiki` → `team-wiki.test`)
- 変えたいときは `config/portico.yml`:

  ```yaml
  host: tominocle-pre
  ```

- git の linked worktree (Orca の作業フォルダなど) から起動すると、`<worktree名>.<名前>.test` になる。
  本来の名前は本体のチェックアウトが持つ。OAuth の redirect_uri は本来の名前にしか
  登録していないはずなので、worktree 側ではログインが通らないことがある

同じホスト名をすでに生きているプロセスが使っていたら、後から起動した側が理由を表示して止まる。
`kill -9` などで登録が残っているだけなら、そのまま引き継ぐ。

### Rails 側で面倒を見ること (development だけ)

- `config.hosts` に `<名前>.test` と `.<名前>.test` (worktree 用) を足す
- `APP_BASE_URL` が無ければ `https://<ホスト名>` にする。`.env` などで明示していればそちらが勝つ
https かどうかは Caddy が付ける `X-Forwarded-Proto` で Rails が判定する。`assume_ssl` は立てない
(立てると Caddy を通さない `http://localhost:3000` まで https 扱いになる)。

http でも開ける。ただし https で付いた Secure cookie は http 側には送られないので、
http 側ではログイン状態が保てない。

route は自分の Mac (127.0.0.1 / ::1) からの接続にだけ流す。Caddy は一般ユーザで動かすため
:80/:443 を全インターフェースで開いているが、LAN からは停止中ページしか見えない。

## 困ったとき

- **Caddy を再起動したら `bin/dev` を起動し直す。** 登録は Caddy のメモリにしかない
- Caddy に繋がらないときは、警告を1行出して portico 無しと同じように起動する
- 管理 API の場所を変えるには `PORTICO_CADDY_ADMIN=http://localhost:2019`
- 停止中や未登録のホスト名には「起動していません」のページが返る

## 開発

```sh
bundle install
bundle exec rake test   # Caddy の統合テストは caddy が PATH に無ければ skip する
```
