# リモートブラウザ（無料VM向け）

Xをサーバーの本物のChromiumで開き、iPhoneから画面を遠隔操作します。
iPhone側のWebViewはリモート操作画面だけを表示し、XのJavaScriptを実行しません。
Xが利用するのはサーバーのLinux・Chromium・フォント・描画環境・送信元IPです。
Windows/Androidを実際に動かす構成ではありません。GPUなしではソフトウェア描画になり得ます。
この構成ではローカルのUA/フィンガープリント設定をリモートへ送信・注入しません。

## Xアプリ風表示

リモートChromiumは `--app=https://x.com/` で起動し、通常のタブバー・アドレスバーを出さないアプリモードを使います。
リモート画面は393×852の縦長表示に固定し、Xのレスポンシブなモバイルレイアウトが使われる構成です。
Selkiesの管理サイドバー・ロゴ・主要なデスクトップ操作ボタンは通常画面から隠します。iPhone側では、選択中のプロフィール名と再読み込みを置いた薄い上部バーを固定し、下部には「ホーム / プロファイル / 設定」の3タブを固定します。URL欄やChromiumのタブUIは表示しません。

BANチェックと環境確認は削除せず「設定」内のツールから開けます。日本語入力のためSelkiesのオンスクリーンキーボード呼び出し機能も残しています。

これはWeb版Xをアプリ専用ウィンドウで表示する構成であり、公式XアプリのネイティブUIそのものを複製するものではありません。

## 無料で動かす場所

Oracle Cloud Always Freeの対象VMを確保できれば利用可能です。
2026-09-24に確認した英語公式資料では、A1無料枠は合計2 OCPU・12 GB相当です。
必ず自分のコンソールのAlways Free表示と割当残量を確認してください。
無料VMの在庫不足やアイドル回収があり、常時稼働・永久無料を保証する構成ではありません。
有料枠への自動切替や、回収を避けるための疑似負荷は組み込みません。

Cloudflare Browser Run無料枠は1日10分で、日常的なリモート操作には適しません。
VM、アカウント、接続情報はこのリポジトリには含まれず、まだデプロイされていません。

## 起動

前提: Always Free対象Linux VM、Docker Engine/Compose、Tailscaleを用意し、
VMとiPhoneを自分のTailscaleアカウントへ接続します。
Tailscaleは個人利用の無料対象範囲を確認してください。
VMへの接続はOracleのCloud Shell/コンソール接続からも行えます。

VMでこのリポジトリのremoteディレクトリに移動して:

```sh
docker compose -p xgizou-profile-one config --quiet
docker compose -p xgizou-profile-one up -d
tailscale serve --bg http://127.0.0.1:3000
tailscale serve status
```

Tailscale Serveが案内するHTTPS URLを、アプリの「プロフィール → 編集 →
実行環境 → 独立環境」に入力します。保存時にアプリが環境IDを確認します。HTTPS有効化の案内が出たら、
自分のTailscale管理画面で有効化します。iPhone側でもTailscaleに接続します。

この構成はインターネット公開ではなく、自分のtailnet内からのアクセスです。
ブラウザポートは127.0.0.1だけに公開しています。3000/3001を外部に開放したり、
Funnelに変更したりしないでください。ブラウザ操作画面はログイン済みXを操作できるため、
Tailscaleのアクセス権は自分の信頼できるデバイスだけに限定してください。
サーバー管理者はブラウザデータへアクセスできるので、第三者の公開ブラウザは使いません。

## プロフィールと更新

- ログインデータはDockerの`browser-profile`ボリュームに永続化します。
- 同じボリューム内に`.xgizou-environment-id`を初回起動時だけ生成します。アプリは`/.well-known/xgizou-environment-id`からこのIDを取得し、別プロフィールとの重複や接続先の入れ替わりを検知します。
- 環境IDはブラウザ保存領域そのものに保存するため、URLだけが異なる同じブラウザ実体を「別環境」と誤認しません。
- 同じURLは同じブラウザです。アプリのプロフィールだけを増やしてもサーバー側は分離しません。
- 複数プロフィールを「独立ブラウザ環境」として使う場合は、プロフィールごとに別VM・別ホスト・別ブラウザ保存領域を用意します。
- 同じVM上のポート違い・パス違いは、現在のアプリでは独立環境として保存できません。ホスト名が同じなら共有基盤と判断します。
- 各VMでは同じ`compose.yaml`をそのまま使えます。VMごとにTailscaleへ参加させ、各VMのTailscale HTTPSホスト名をそれぞれのプロフィールへ設定してください。

```sh
docker compose -p xgizou-profile up -d
tailscale serve --bg http://127.0.0.1:3000
tailscale serve status
```

  iPhone側では、プロフィールAにVM AのHTTPSホスト、プロフィールBにVM BのHTTPSホストを設定します。これにより、ブラウザプロセス・Cookie/LocalStorage/IndexedDB・OS環境・ネットワーク出口をプロフィール単位で分離できます。サービス側の最終的な端末分類は外部サービスの判定に依存するため保証はできませんが、同一iPhone内のWKWebView値を書き換える方式ではなく、実際に別のブラウザ実行環境を使う構成です。
- アプリの削除・Cookie削除でサーバー側データは消えません。リモートブラウザ内でログアウト・データ削除します。
- `docker compose down`はデータを残します。`down -v`はログイン情報も削除するため通常は使用しません。
- ブラウザ更新は`docker compose pull`のあと`docker compose up -d`。`latest`を固定したい場合は確認済みイメージのdigestへ変更してください。
- フォントはコンテナに実際に入っているものです。架空の一覧を返しません。
- 送信元IPはサーバーのものです。住宅回線IPになったり、Xに保存された過去の関連付けが消えたりはしません。

## 検証状態

アプリはGitHub ActionsでReleaseビルドと設定・移行テストを行います。
CIでは一時的なLinuxコンテナを2組起動し、Chromiumプロセス・保存ボリューム・環境IDがそれぞれ異なることまで確認します。実VM上での起動、iPhoneでのストリーミング・文字入力・Xログインは、
実際のVM確保後に検証が必要です。未検証の状態を稼働済みとは扱いません。

## 公式資料

- https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- https://docs.linuxserver.io/images/docker-chromium/
- https://tailscale.com/docs/features/tailscale-serve
- https://developers.cloudflare.com/browser-run/pricing/
